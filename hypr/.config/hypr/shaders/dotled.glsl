// Hypr-DarkWindow window shader: the window drawn as LED dots in the era's
// ramp (unlit → mid → lit by brightness). Dot Shell's `winshade` token puts
// it on every unfocused window (lua/dotshell.lua), so focus reads as the one
// window that is not a dot board. It fades in and out with the rule
// (x_FadeIn / x_FadeOut), so losing focus dissolves a window into dots.
//
// Same cell math as Dot Shell's dot.frag: one dot per `pitch` pixels,
// sampled at the cell's centre, round or square, `dotSize` of the pitch.
// Colors arrive premultiplied; the sample is un-premultiplied for its
// brightness and the result premultiplied again.

uniform float pitch;
uniform float dotSize;
uniform float square;
uniform vec3 lit;
uniform vec3 glow;   // the ramp's middle
uniform vec3 unlit;
uniform float bright; // the whole board's level: unfocused windows sit below the focused one

void windowShader(inout vec4 color) {
    float k = clamp(x_FadeIn - x_FadeOut, 0.0, 1.0);
    if (k <= 0.0)
        return;

    float p = max(pitch, 2.0);
    vec2 pos = x_PixelPos;
    vec2 center = (floor(pos / p) + 0.5) * p;

    // x_TextureOffset samples at (this pixel - offset).
    vec4 s = x_TextureOffset(pos - center);
    vec3 rgb = s.a > 0.0 ? s.rgb / s.a : vec3(0.0);
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 ramp = l < 0.5 ? mix(unlit, glow, l * 2.0) : mix(glow, lit, l * 2.0 - 1.0);
    // Always zero (pitch > 0), but not foldable: Hypr-DarkWindow test-compiles
    // shaders against a plain white window, where `l` is a constant 1 and
    // the compiler drops `glow`, failing the shader for a missing uniform.
    ramp += glow * max(0.0, -pitch);

    // 0 at the centre, 1 at the cell's edge.
    vec2 d = abs(pos - center) / p * 2.0;
    float r = square > 0.5 ? max(d.x, d.y) : length(d);
    float edge = 1.5 / p;
    float m = 1.0 - smoothstep(dotSize - edge, dotSize + edge, r);

    vec3 led = mix(unlit * 0.5, ramp, m);
    color.rgb = mix(color.rgb, led * bright * color.a, k);
}
