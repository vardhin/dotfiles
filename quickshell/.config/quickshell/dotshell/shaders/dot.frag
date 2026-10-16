#version 440
// DotSurface: turns a low-res buffer into LED dots.
// One texel of `source` = one dot. The effect item is cols*pitch x rows*pitch,
// so every cell is square and exactly `pitch` px.
// Same math as the Dot Shell prototype: low-res color buffer -> upscale -> dot mask.
//
// Era cascade (flip < 1): every dot turns over like a flip-disc, in a wave from
// the top left. Until a dot's turn it shows the old era (`oldSource` + old*
// uniforms), squashing to an edge; past the edge it opens in the new era.
// Rebuild after editing: ./build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;        // cols, rows
    float dotSize;    // dot diameter as a fraction of pitch, 0.4 .. 1.0
    float depth;      // 0 = era palette, 8 = RGB332, 16 = RGB565, 24 = true color
    float imageMode;  // 0 = content (authored in era colors), 1 = image (luma -> era ramp)
    float shape;      // 0 = round, 1 = square, 2 = bubble
    float glow;       // 0 .. 1 halo around lit dots
    vec4 unlitColor;  // dot that is off
    vec4 gapColor;    // glass between dots
    vec4 ramp0;       // era ramp, dark -> bright (image mode, era depth)
    vec4 ramp1;
    vec4 ramp2;
    vec4 ramp3;
    float useMask;    // 1 = dots where `mask` is clear are cut out (no dot, no glass)
    float flip;       // cascade progress 0 .. 1; 1 = idle
    float oldShape;   // the era being flipped away from
    float oldGlow;
    vec4 oldUnlit;
    vec4 oldGap;
    vec4 oldRamp0;
    vec4 oldRamp1;
    vec4 oldRamp2;
    vec4 oldRamp3;
    float gain;       // lit dots blend toward unlit by 1 - gain (wallpaper board: 0.55)
    float dither;     // 1 = image mode spreads levels with a 4x4 ordered dither (album art)
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;      // panel shape, one texel per dot
layout(binding = 3) uniform sampler2D oldSource; // canvas grabbed before the era swap

// `t` (-0.5 .. 0.5) is the ordered-dither offset, in steps of the output level.
vec3 quantize(vec3 c, vec3 bits, float t) {
    vec3 n = exp2(bits) - 1.0;
    return clamp(floor(c * n + 0.5 + t) / n, 0.0, 1.0);
}

vec3 toDepth(vec3 c, float t) {
    if (depth > 20.0) return c;
    if (depth > 12.0) return quantize(c, vec3(5.0, 6.0, 5.0), t);
    return quantize(c, vec3(3.0, 3.0, 2.0), t);
}

// 4x4 Bayer threshold for a dot, -0.5 .. 0.5.
float bayer4(vec2 cell) {
    vec2 p = mod(cell, 4.0);
    int i = int(p.x) + int(p.y) * 4;
    const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    return (m[i] + 0.5) / 16.0 - 0.5;
}

vec3 eraRamp(vec3 c, vec4 r0, vec4 r1, vec4 r2, vec4 r3, float t) {
    float l = dot(c, vec3(0.30, 0.59, 0.11));
    float lv = clamp(floor(l * 4.2 + t), 0.0, 3.0);
    if (lv < 0.5) return r0.rgb;
    if (lv < 1.5) return r1.rgb;
    if (lv < 2.5) return r2.rgb;
    return r3.rgb;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 g = qt_TexCoord0 * grid;
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    vec2 uv = (cell + 0.5) / grid;

    // Shaped panels: a dot outside the shape does not exist at all.
    if (useMask > 0.5 && texture(mask, uv).a < 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    // Cascade: this dot's turn. `delay` runs 0 .. ~1.1 along a diagonal with
    // a little jitter, `width` is how long one dot takes to turn over.
    bool old = false;
    float squash = 1.0;
    if (flip < 1.0) {
        const float width = 0.28;
        float delay = (cell.x / max(grid.x, 1.0)) * 0.7 + (cell.y / max(grid.y, 1.0)) * 0.3 + hash(cell) * 0.12;
        float phase = clamp((flip * (1.12 + width) - delay) / width, 0.0, 1.0);
        old = phase < 0.5;
        squash = max(abs(cos(phase * 3.14159265)), 0.04);
    }

    float sh = old ? oldShape : shape;
    float gl = old ? oldGlow : glow;
    vec3 unlit = old ? oldUnlit.rgb : unlitColor.rgb;
    vec4 gap = old ? oldGap : gapColor;

    // One sample per dot, from the dot's center.
    vec4 t = old ? texture(oldSource, uv) : texture(source, uv);
    float a = t.a;
    vec3 rgb = a > 0.0 ? t.rgb / a : vec3(0.0);   // source is premultiplied

    bool lit;
    vec3 col;
    if (imageMode > 0.5) {
        lit = a > 0.05;
        float t = dither > 0.5 ? bayer4(cell) : 0.0;
        if (depth < 1.0)
            col = old ? eraRamp(rgb, oldRamp0, oldRamp1, oldRamp2, oldRamp3, t) : eraRamp(rgb, ramp0, ramp1, ramp2, ramp3, t);
        else
            col = toDepth(rgb, t);
    } else {
        // Content mode: two brightness levels, like a real panel.
        lit = a > 0.35;
        col = rgb * (a > 0.7 ? 1.0 : 0.7);
        if (depth > 1.0) col = toDepth(col, 0.0);
    }
    // Toward the unlit dot, not black, so light eras fade toward their glass.
    col = mix(unlit, col, gain);
    vec3 dotCol = lit ? col : unlit;

    // Dot mask with a one-pixel antialiased edge. A turning dot is squashed
    // vertically, so it reads as a disc seen edge-on.
    vec2 fs = vec2(f.x, f.y / squash);
    float r = dotSize * 0.5;
    float d = sh > 0.5 && sh < 1.5 ? max(abs(fs.x), abs(fs.y)) : length(fs);
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);

    // Bubble: a small glossy highlight in the upper left of each dot. Kept
    // tight so dark ink on light glass (Frutiger Aero) still reads as dark.
    if (sh > 1.5) {
        float hl = 1.0 - smoothstep(0.0, r * 0.4, length(fs - vec2(-0.16, -0.16) * dotSize));
        dotCol = mix(dotCol, vec3(1.0), hl * 0.3);
    }

    // Halo: lit dots bleed a little light into the glass around them.
    float halo = lit ? gl * 0.45 * squash * (1.0 - smoothstep(r, 0.5, d)) : 0.0;

    vec3 glass = gap.rgb + col * halo;
    vec3 outc = mix(glass, dotCol, m);
    float outa = mix(gap.a, 1.0, m);
    fragColor = vec4(outc * outa, outa) * qt_Opacity;
}
