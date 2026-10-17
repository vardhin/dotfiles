// Hypr-DarkWindow window shader: the theme flip. When the era changes, Dot
// Shell (services/Export.qml) turns every window that recolors live into a
// flip-dot board, the way its own panes cascade: the window settles into LED
// dots, the dots turn over in a wave to their blank back (the new era's
// board), hold while the app swaps its colors underneath, then turn back over
// in the same direction showing the app in its new colors.
//
// Driven by the dispatch fade (lua/dotshell.lua, dotshell.flip): x_FadeIn
// runs the close (0 -> 1), the hold is x_FadeIn = 1, and removing the shader
// runs x_FadeOut (0 -> 1) for the open. Same cell math as dotled.glsl.

uniform float pitch;
uniform float dotSize;
uniform float square;
uniform vec3 back;   // the dots' blank side (the new era's unlit)
uniform vec3 rim;    // light caught on a dot's edge as it turns
uniform vec3 gap;    // the board between the dots

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void windowShader(inout vec4 color) {
    float p = max(pitch, 2.0);
    vec2 pos = x_PixelPos;
    vec2 cell = floor(pos / p);
    vec2 center = (cell + 0.5) * p;
    vec2 grid = max(x_WindowSize / p, vec2(1.0));
    vec2 uv = clamp(cell / grid, 0.0, 1.0);

    // A cell's turn starts at d (top left first, a little ragged) and takes
    // `span` of the fade; the last ones finish exactly at 1.
    const float span = 0.3;
    float d = (uv.x * 0.35 + uv.y * 0.65) * 0.62 + hash(cell) * 0.08;
    float q = x_FadeOut > 0.0
        ? 1.0 - clamp((x_FadeOut - d) / span, 0.0, 1.0)
        : clamp((x_FadeIn - d) / span, 0.0, 1.0);
    if (q <= 0.0)
        return;

    vec3 pixel = color.a > 0.0 ? color.rgb / color.a : vec3(0.0);
    vec4 s = x_TextureOffset(pos - center);
    vec3 face = s.a > 0.0 ? s.rgb / s.a : vec3(0.0);

    // First the picture settles into dots, then the dot turns over.
    float a = clamp(q / 0.25, 0.0, 1.0);
    float f = clamp((q - 0.25) / 0.75, 0.0, 1.0);
    float ang = f * 3.14159265;
    float sy = abs(cos(ang));
    vec3 side = ang < 1.5707963 ? face : back;

    // A dot squashed to its height while it turns, gone when edge-on.
    vec2 dd = (pos - center) / p * 2.0;
    dd.y /= max(sy, 0.04);
    float r = square > 0.5 ? max(abs(dd.x), abs(dd.y)) : length(dd);
    float edge = 1.5 / p;
    float m = sy < 0.04 ? 0.0 : 1.0 - smoothstep(dotSize - edge, dotSize + edge, r);

    float turning = step(0.001, f) * (1.0 - step(0.999, f));
    vec3 dotc = side * (0.55 + 0.45 * sy) + rim * pow(1.0 - sy, 6.0) * 0.6 * turning;
    vec3 led = mix(gap, dotc, m);
    color.rgb = mix(pixel, led, a) * color.a;
}
