#version 440
// Split-Flap's dots (flap/Dots.qml): only the lit dots, square, printed
// straight on the crisp flap tiles under them. The design's `.dm` in
// `.sh-square`: an 80% square per dot, no unlit grid, no glass between.
//
// The canvas is one texel per dot. A texel's alpha says how much of the
// dot shows: past about half it is a whole dot (text's antialiased edges
// land on whole dots), below that it fades, so ink authored at a third
// opacity reads as a faint dot.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;        // cols, rows
    float dotSize;    // square side as a fraction of pitch
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 g = qt_TexCoord0 * grid;
    vec2 cell = floor(g);
    vec2 f = fract(g);
    vec2 uv = (cell + 0.5) / grid;

    vec4 t = texture(source, uv);
    float a = t.a;
    if (a < 0.2) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 rgb = t.rgb / a;   // source is premultiplied

    // The square sits in the top left of its cell, like the design's
    // conic mask (lit from 0 to 80%, a dark gap on the right and below).
    vec2 aa = max(fwidth(g), vec2(1e-4));
    vec2 m2 = 1.0 - smoothstep(vec2(dotSize) - aa, vec2(dotSize) + aa, f);
    float m = m2.x * m2.y;

    float o = m * smoothstep(0.2, 0.55, a);
    fragColor = vec4(rgb * o, o) * qt_Opacity;
}
