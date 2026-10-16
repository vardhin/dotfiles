#version 440
// Window open/close effect (panes/WindowFx.qml): the window's rect as a board
// of LED dots on a click-through overlay, since Hyprland runs no custom
// shaders per window. Gaps stay clear, so the window shows through.
//
//   open   a raster sweep paints the window in, top to bottom: a ragged band
//          of lit dots with a fading tail, the frame drawn in the second tube
//          color behind it, while Hyprland fades the window in underneath
//   close  dots light at random over the vanishing window, then the board
//          collapses to its middle row and fades, like a CRT switching off
// Rebuild after editing: ./build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;        // cols, rows
    float t;          // 0 .. 1 through the effect
    float kind;       // 0 = open, 1 = close
    float dotSize;    // dot diameter as a fraction of pitch
    float shape;      // 0 = round, 1 = square, 2 = bubble
    float glow;
    vec4 litColor;
    vec4 edgeColor;   // the board's outline row and column
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 g = qt_TexCoord0 * grid;
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    vec2 v = (cell + 0.5) / grid;
    float h = hash(cell);
    float h2 = hash(cell + 17.0);

    bool edge = cell.x < 0.5 || cell.y < 0.5 || cell.x > grid.x - 1.5 || cell.y > grid.y - 1.5;
    float on;
    if (kind < 0.5) {
        const float tail = 0.28;
        float front = t / 0.78 * (1.0 + tail) + (h2 - 0.5) * 0.03;
        float dist = front - v.y;
        float band = dist > 0.0 && dist < tail && h > 0.35 ? 1.0 - dist / tail : 0.0;
        float frame = edge && dist > 0.0 ? 1.0 - smoothstep(0.6, 1.0, t) : 0.0;
        on = max(band, frame);
    } else {
        float lightAt = h * 0.22;
        // Only some dots, so the window can be seen leaving under them.
        on = h2 > 0.45 || edge ? 1.0 : 0.0;
        float halfH = 0.5 * (1.0 - smoothstep(0.30, 0.82, t)) + 0.5 / grid.y;
        float band = step(abs(v.y - 0.5), halfH);
        on *= step(lightAt, t) * band * (1.0 - smoothstep(0.78, 1.0, t));
    }
    if (on <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec3 col = edge ? edgeColor.rgb : litColor.rgb;

    float r = dotSize * 0.5;
    float d = shape > 0.5 && shape < 1.5 ? max(abs(f.x), abs(f.y)) : length(f);
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);
    if (shape > 1.5) {
        float hl = 1.0 - smoothstep(0.0, r * 0.4, length(f - vec2(-0.16, -0.16) * dotSize));
        col = mix(col, vec3(1.0), hl * 0.3 * m);
    }
    float halo = glow * 0.35 * (1.0 - smoothstep(r, 0.5, d));
    float a = clamp(m + halo * (1.0 - m), 0.0, 1.0) * on;
    fragColor = vec4(col * a, a) * qt_Opacity;
}
