#version 440
// The screen look, on the wallpaper only (panes/Wallpaper.qml runs its own
// content through it). It used to be Hyprland's screen_shader, which covers
// every window too; this keeps windows untouched. The `screen` token:
//   mode 0  glass: faint dot mask, phosphor tint, vignette
//   mode 1  LED: the wallpaper as dots on the era's glass, quantized to the
//           era (ramp or RGB332/565). detail 1 (led) keeps every pixel inside
//           its dot; detail 0 (board) samples one color per dot.
// Era cascade (flip < 1): every dot turns over in the same wave as the
// DotSurfaces (shaders/dot.frag), showing the old era's colors until its turn.
// Night warmth stays in Hyprland (shaders/screen.glsl), so it reaches windows.
// Rebuild after editing: ./build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in device px
    float pitch;      // dot pitch in device px
    float dotSize;    // fraction of the pitch
    float shape;      // 0 round, 1 square, 2 bubble
    float mode;       // 0 glass, 1 LED
    float detail;     // LED: 1 every pixel kept, 0 one color per dot
    float depth;      // 0 era ramp, 8 / 16 / 24 bits
    float glow;       // 0 .. 1
    vec4 tint;        // the era's primary
    vec4 glassColor;
    vec4 unlitColor;
    vec4 ramp0;
    vec4 ramp1;
    vec4 ramp2;
    vec4 ramp3;
    float flip;       // cascade progress 0 .. 1; 1 = idle
    float oldShape;   // the era being flipped away from
    float oldGlow;
    vec4 oldTint;
    vec4 oldGlass;
    vec4 oldUnlit;
    vec4 oldRamp0;
    vec4 oldRamp1;
    vec4 oldRamp2;
    vec4 oldRamp3;
};

layout(binding = 1) uniform sampler2D source;

// Glass strength.
const float MASK = 0.10;      // how much the gaps between dots darken
const float TINT_MIX = 0.06;  // pull toward the era's phosphor color
const float VIGNETTE = 0.22;  // corner darkening

float luma(vec3 c) {
    return dot(c, vec3(0.30, 0.59, 0.11));
}

vec3 quantize(vec3 c, vec3 bits) {
    vec3 n = exp2(bits) - 1.0;
    return floor(c * n + 0.5) / n;
}

vec3 eraRamp(float l, bool old) {
    float lv = min(3.0, floor(l * 4.2));
    if (lv < 0.5) return old ? oldRamp0.rgb : ramp0.rgb;
    if (lv < 1.5) return old ? oldRamp1.rgb : ramp1.rgb;
    if (lv < 2.5) return old ? oldRamp2.rgb : ramp2.rgb;
    return old ? oldRamp3.rgb : ramp3.rgb;
}

// Distance from the dot's center in pitch units, by era shape.
float dotDist(vec2 f, float sh) {
    return sh > 0.5 && sh < 1.5 ? max(abs(f.x), abs(f.y)) : length(f);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vignette(vec2 uv) {
    vec2 q = uv - 0.5;
    return 1.0 - VIGNETTE * pow(clamp(length(q) * 1.4142, 0.0, 1.0), 2.5);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    vec2 g = px / pitch;
    vec2 cell = floor(g);
    vec2 grid = max(size / pitch, vec2(1.0));

    // Cascade: this dot's turn, the same wave as dot.frag. Until then it shows
    // the old era; a turning dot squashes to an edge like a flip-disc.
    bool old = false;
    float squash = 1.0;
    if (flip < 1.0) {
        const float width = 0.28;
        float delay = (cell.x / grid.x) * 0.7 + (cell.y / grid.y) * 0.3 + hash(cell) * 0.12;
        float phase = clamp((flip * (1.12 + width) - delay) / width, 0.0, 1.0);
        old = phase < 0.5;
        squash = max(abs(cos(phase * 3.14159265)), 0.04);
    }
    float sh = old ? oldShape : shape;
    float gl = old ? oldGlow : glow;

    vec2 f = fract(g) - 0.5;
    f.y /= squash;
    float d = dotDist(f, sh);
    float r = dotSize * 0.5;
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);
    vec3 c;

    if (mode > 0.5) {
        vec3 s;
        if (detail > 0.5) {
            s = texture(source, uv).rgb;
        } else {
            // One color per dot, from the 3x3 tap that stands out most from
            // the cell's mean, so thin strokes win over their background.
            vec2 center = (cell + 0.5) * pitch;
            float o = pitch / 3.0;
            vec3 taps[9];
            vec3 mean = vec3(0.0);
            for (int i = 0; i < 9; i++) {
                vec2 at = center + vec2(float(i % 3 - 1), float(i / 3 - 1)) * o;
                taps[i] = texture(source, at / size).rgb;
                mean += taps[i];
            }
            mean /= 9.0;
            s = taps[4];
            float best = -1.0;
            for (int i = 0; i < 9; i++) {
                float dl = abs(luma(taps[i]) - luma(mean));
                if (dl > best) {
                    best = dl;
                    s = taps[i];
                }
            }
        }
        float l = luma(s);
        // Dark backgrounds stay unlit, like the off dots of a real board.
        bool lit = l > 0.11;
        vec3 col;
        if (depth < 1.0)
            col = eraRamp(clamp((l - 0.11) / 0.5, 0.0, 1.0) * 0.99, old);
        else if (depth < 12.0)
            col = quantize(s, vec3(3.0, 3.0, 2.0));
        else if (depth < 20.0)
            col = quantize(s, vec3(5.0, 6.0, 5.0));
        else
            col = s;
        vec3 dotCol = lit ? col : (old ? oldUnlit.rgb : unlitColor.rgb);
        if (sh > 1.5) {
            // Bubble: a small glossy highlight in the upper left of each dot.
            float hl = 1.0 - smoothstep(0.0, r * 0.4, length(f - vec2(-0.16, -0.16) * dotSize));
            dotCol = mix(dotCol, vec3(1.0), hl * 0.3);
        }
        float halo = lit ? gl * 0.45 * squash * (1.0 - smoothstep(r, 0.5, d)) : 0.0;
        c = mix((old ? oldGlass.rgb : glassColor.rgb) + col * halo, dotCol, m);
    } else {
        c = texture(source, uv).rgb;
        // Phosphor: a little of the era's primary in everything, by brightness.
        vec3 tc = old ? oldTint.rgb : tint.rgb;
        vec3 t = tc / max(max(tc.r, max(tc.g, tc.b)), 1e-3);
        c = mix(c, luma(c) * t, TINT_MIX);
        // Faint dot mask; the 1/(1 - MASK/2) keeps overall brightness level.
        c *= mix(1.0 - MASK, 1.0, m) / (1.0 - MASK * 0.5);
    }

    c *= vignette(uv);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * qt_Opacity;
}
