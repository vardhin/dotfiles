#version 440
// TvScreen: video as LED dots, at its own pitch (the Tv.screen settings), in
// the MEDIA pane. Same math as mpv/.config/mpv/shaders/dotled.glsl, which
// draws the Dot TV window: one sample per dot from its center, then a color
// mode, then a round / square / bubble dot with glow on dark glass.
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
    float mode;       // 0 era ramp, 1 mono, 2 RGB332, 3 RGB565, 4 full color, 5 raw
    float glow;       // 0 .. 1
    float dither;     // 1 = ordered dither
    vec4 ramp0;
    vec4 ramp1;
    vec4 ramp2;
    vec4 ramp3;
    vec4 tube;        // mono's color
    vec4 unlitColor;
    vec4 glassColor;
};

layout(binding = 1) uniform sampler2D source;

float bayer4(vec2 cell) {
    vec2 p = mod(cell, 4.0);
    int i = int(p.x) + int(p.y) * 4;
    const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    return (m[i] + 0.5) / 16.0 - 0.5;
}

vec3 quantize(vec3 c, vec3 bits, float t) {
    vec3 n = exp2(bits) - 1.0;
    return clamp(floor(c * n + 0.5 + t) / n, 0.0, 1.0);
}

void main() {
    if (mode > 4.5) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }
    vec2 px = qt_TexCoord0 * size;
    vec2 cell = floor(px / pitch);
    vec2 f = (px - cell * pitch) / pitch - 0.5;
    vec4 s = texture(source, clamp((cell + 0.5) * pitch / size, 0.0, 1.0));
    vec3 c = s.a > 0.0 ? s.rgb / s.a : vec3(0.0);
    float t = dither > 0.5 ? bayer4(cell) : 0.0;
    float l = dot(c, vec3(0.30, 0.59, 0.11));

    vec3 col;
    bool lit = l > 0.04 || mode > 1.5;
    if (mode < 0.5) {
        float lv = clamp(floor(l * 4.2 + t), 0.0, 3.0);
        col = lv < 0.5 ? ramp0.rgb : lv < 1.5 ? ramp1.rgb : lv < 2.5 ? ramp2.rgb : ramp3.rgb;
    } else if (mode < 1.5) {
        // Mono: one tube, eight brightness steps.
        float lv = clamp(floor(l * 8.0 + 0.5 + t), 0.0, 8.0) / 8.0;
        col = mix(unlitColor.rgb, tube.rgb, lv);
        lit = lv > 0.0;
    } else if (mode < 2.5) {
        col = quantize(c, vec3(3.0, 3.0, 2.0), t);
    } else if (mode < 3.5) {
        col = quantize(c, vec3(5.0, 6.0, 5.0), t);
    } else {
        col = c;
    }
    vec3 dotCol = lit ? col : unlitColor.rgb;

    float r = dotSize * 0.5;
    float d = shape > 0.5 && shape < 1.5 ? max(abs(f.x), abs(f.y)) : length(f);
    float aa = 1.0 / pitch;
    float m = 1.0 - smoothstep(r - aa, r + aa, d);
    if (shape > 1.5) {
        float hl = 1.0 - smoothstep(0.0, r * 0.4, length(f - vec2(-0.16, -0.16) * dotSize));
        dotCol = mix(dotCol, vec3(1.0), hl * 0.3);
    }
    float halo = lit ? glow * 0.45 * (1.0 - smoothstep(r, 0.5, d)) : 0.0;
    fragColor = vec4(mix(glassColor.rgb + col * halo, dotCol, m), 1.0) * qt_Opacity;
}
