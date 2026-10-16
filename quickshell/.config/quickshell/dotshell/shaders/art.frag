#version 440
// DitherArt: a picture in the era's colors, one texel per dot, for art drawn
// inside a DotSurface canvas (pane art, media panels). Luma goes onto the four
// era levels through a 4x4 ordered dither, or the color depth is dithered, so
// album art keeps its shading on an LED board. The canvas' own DotSurface then
// draws each texel as a dot.
// Rebuild after editing: ./build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;        // the item's size in dots
    float depth;      // 0 = era ramp, 8 / 16 / 24 bits
    vec4 ramp0;       // era ramp, dark -> bright
    vec4 ramp1;
    vec4 ramp2;
    vec4 ramp3;
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
    vec2 cell = floor(qt_TexCoord0 * grid);
    vec4 t = texture(source, (cell + 0.5) / grid);
    vec3 rgb = t.a > 0.0 ? t.rgb / t.a : vec3(0.0);
    float d = bayer4(cell);
    vec3 col;
    if (depth < 1.0) {
        float l = dot(rgb, vec3(0.30, 0.59, 0.11));
        float lv = clamp(floor(l * 4.2 + d), 0.0, 3.0);
        col = lv < 0.5 ? ramp0.rgb : lv < 1.5 ? ramp1.rgb : lv < 2.5 ? ramp2.rgb : ramp3.rgb;
    } else if (depth < 12.0) {
        col = quantize(rgb, vec3(3.0, 3.0, 2.0), d);
    } else if (depth < 20.0) {
        col = quantize(rgb, vec3(5.0, 6.0, 5.0), d);
    } else {
        col = rgb;
    }
    // Full alpha: the canvas' DotSurface lights every dot of the picture.
    fragColor = vec4(col, 1.0) * t.a * qt_Opacity;
}
