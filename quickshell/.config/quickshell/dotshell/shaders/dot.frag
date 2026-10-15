#version 440
// DotSurface: turns a low-res buffer into LED dots.
// One texel of `source` = one dot. The effect item is cols*pitch x rows*pitch,
// so every cell is square and exactly `pitch` px.
// Same math as the Dot Shell prototype: low-res color buffer -> upscale -> dot mask.
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
};

layout(binding = 1) uniform sampler2D source;

vec3 quantize(vec3 c, vec3 bits) {
    vec3 n = exp2(bits) - 1.0;
    return floor(c * n + 0.5) / n;
}

vec3 toDepth(vec3 c) {
    if (depth > 20.0) return c;
    if (depth > 12.0) return quantize(c, vec3(5.0, 6.0, 5.0));
    return quantize(c, vec3(3.0, 3.0, 2.0));
}

vec3 eraRamp(vec3 c) {
    float l = dot(c, vec3(0.30, 0.59, 0.11));
    float lv = min(3.0, floor(l * 4.2));
    if (lv < 0.5) return ramp0.rgb;
    if (lv < 1.5) return ramp1.rgb;
    if (lv < 2.5) return ramp2.rgb;
    return ramp3.rgb;
}

void main() {
    vec2 g = qt_TexCoord0 * grid;
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;

    // One sample per dot, from the dot's center.
    vec4 t = texture(source, (cell + 0.5) / grid);
    float a = t.a;
    vec3 rgb = a > 0.0 ? t.rgb / a : vec3(0.0);   // source is premultiplied

    bool lit;
    vec3 col;
    if (imageMode > 0.5) {
        lit = a > 0.05;
        col = depth < 1.0 ? eraRamp(rgb) : toDepth(rgb);
    } else {
        // Content mode: two brightness levels, like a real panel.
        lit = a > 0.35;
        col = rgb * (a > 0.7 ? 1.0 : 0.7);
        if (depth > 1.0) col = toDepth(col);
    }
    vec3 dotCol = lit ? col : unlitColor.rgb;

    // Dot mask with a one-pixel antialiased edge.
    float r = dotSize * 0.5;
    float d = shape > 0.5 && shape < 1.5 ? max(abs(f.x), abs(f.y)) : length(f);
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);

    // Bubble: glossy highlight in the upper left of each dot.
    if (shape > 1.5) {
        float hl = 1.0 - smoothstep(0.0, r * 0.55, length(f - vec2(-0.14, -0.14) * dotSize));
        dotCol = mix(dotCol, vec3(1.0), hl * 0.35);
    }

    // Halo: lit dots bleed a little light into the glass around them.
    float halo = lit ? glow * 0.45 * (1.0 - smoothstep(r, 0.5, d)) : 0.0;

    vec3 glass = gapColor.rgb + col * halo;
    vec3 outc = mix(glass, dotCol, m);
    float outa = mix(gapColor.a, 1.0, m);
    fragColor = vec4(outc * outa, outa) * qt_Opacity;
}
