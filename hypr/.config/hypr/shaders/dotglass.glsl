// Hypr-DarkWindow window shader: a faint LED dot mask over the focused window
// (`winshade = all`), so even the window you work in sits on the panel's dot
// grid. The picture is untouched apart from the gaps between dots, which are
// darkened by `strength`.

uniform float pitch;
uniform float dotSize;
uniform float square;
uniform float strength;

void windowShader(inout vec4 color) {
    float k = clamp(x_FadeIn - x_FadeOut, 0.0, 1.0);
    if (k <= 0.0)
        return;

    float p = max(pitch, 2.0);
    vec2 pos = x_PixelPos;
    vec2 center = (floor(pos / p) + 0.5) * p;
    vec2 d = abs(pos - center) / p * 2.0;
    float r = square > 0.5 ? max(d.x, d.y) : length(d);
    float edge = 1.5 / p;
    float m = 1.0 - smoothstep(dotSize - edge, dotSize + edge, r);

    color.rgb *= mix(1.0, mix(1.0 - strength, 1.0, m), k);
}
