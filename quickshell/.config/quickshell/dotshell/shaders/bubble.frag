#version 440
// Frutiger Aero's dots (aero/Dots.qml): only the lit dots, as glossy
// bubbles, straight on the crisp sky glass under them. The design's `.dm`
// with no `.pn` behind it: no unlit grid, no glass between the dots.
//
// The canvas is one texel per dot. A texel's alpha says how much of the
// dot shows: past about half it is a whole dot (text's antialiased edges
// land on whole dots), and below that it fades out, so ink authored at a
// third opacity reads as a faint dot.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;        // cols, rows
    float dotSize;    // dot diameter as a fraction of pitch
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 g = qt_TexCoord0 * grid;
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    vec2 uv = (cell + 0.5) / grid;

    vec4 t = texture(source, uv);
    float a = t.a;
    if (a < 0.2) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 rgb = t.rgb / a;   // source is premultiplied

    float r = dotSize * 0.5;
    float d = length(f);
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);

    // The bubble: a small glossy highlight in the upper left of each dot,
    // kept tight so dark ink still reads as dark.
    float hl = 1.0 - smoothstep(0.0, r * 0.45, length(f - vec2(-0.17, -0.17) * dotSize));
    rgb = mix(rgb, vec3(1.0), hl * 0.35);

    float o = m * smoothstep(0.2, 0.55, a);
    fragColor = vec4(rgb * o, o) * qt_Opacity;
}
