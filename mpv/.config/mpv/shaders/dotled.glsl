// Dot TV: the video as LED dots, in the colors of the Dot Shell era.
// The successor of the Media Center's CPU renderer (blocks, RGB332, diffuser,
// glow), now one pass on the GPU at display resolution.
//
// Each dot samples the frame once at its center, then takes the era ramp
// (ordered-dithered luma -> four levels) or a color depth, and is drawn as a
// round, square or bubble dot with a little glow on dark glass.
//
// Dot Shell writes the era's values to ${XDG_STATE_HOME}/dotshell/mpv-led.conf
// (glsl-shader-opts=...) on every era change; `dottv led reload` pushes them to
// a running player. Toggle the shader with L in Dot TV, or `dottv led`.

//!PARAM pitch
//!DESC dot pitch in screen px
//!TYPE float
//!MINIMUM 2.0
//!MAXIMUM 48.0
6.0

//!PARAM dotsize
//!DESC dot diameter, fraction of the pitch
//!TYPE float
//!MINIMUM 0.3
//!MAXIMUM 1.0
0.8

//!PARAM shape
//!DESC 0 round, 1 square, 2 bubble
//!TYPE float
0.0

//!PARAM depth
//!DESC 0 era ramp, 8 RGB332, 16 RGB565, 24 true color
//!TYPE float
0.0

//!PARAM glow
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.5

//!PARAM r0r
//!TYPE float
0.12
//!PARAM r0g
//!TYPE float
0.05
//!PARAM r0b
//!TYPE float
0.0
//!PARAM r1r
//!TYPE float
0.45
//!PARAM r1g
//!TYPE float
0.22
//!PARAM r1b
//!TYPE float
0.0
//!PARAM r2r
//!TYPE float
0.8
//!PARAM r2g
//!TYPE float
0.45
//!PARAM r2b
//!TYPE float
0.05
//!PARAM r3r
//!TYPE float
1.0
//!PARAM r3g
//!TYPE float
0.7
//!PARAM r3b
//!TYPE float
0.25
//!PARAM unr
//!TYPE float
0.1
//!PARAM ung
//!TYPE float
0.06
//!PARAM unb
//!TYPE float
0.03
//!PARAM glr
//!TYPE float
0.03
//!PARAM glg
//!TYPE float
0.02
//!PARAM glb
//!TYPE float
0.01

//!HOOK OUTPUT
//!BIND HOOKED
//!DESC dotshell LED video

float bayer4(vec2 p) {
    // 4x4 ordered dither threshold, 0 .. 1.
    int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
    int i = x + y * 4;
    float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    return (m[i] + 0.5) / 16.0;
}

vec3 quantize(vec3 c, vec3 bits, float t) {
    vec3 n = exp2(bits) - 1.0;
    return floor(c * n + t) / n;
}

vec4 hook() {
    vec2 px = HOOKED_pos * HOOKED_size;
    vec2 cell = floor(px / pitch);
    vec2 f = (px - cell * pitch) / pitch - 0.5;
    vec2 uv = (cell + 0.5) * pitch / HOOKED_size;
    vec3 c = clamp(HOOKED_tex(uv).rgb, 0.0, 1.0);

    vec3 unlit = vec3(unr, ung, unb);
    vec3 glass = vec3(glr, glg, glb);
    float t = bayer4(cell);

    vec3 col;
    bool lit = true;
    if (depth < 1.0) {
        float l = dot(c, vec3(0.30, 0.59, 0.11));
        float lv = clamp(floor(l * 4.2 + t - 0.5), 0.0, 3.0);
        col = lv < 0.5 ? vec3(r0r, r0g, r0b) : lv < 1.5 ? vec3(r1r, r1g, r1b) : lv < 2.5 ? vec3(r2r, r2g, r2b) : vec3(r3r, r3g, r3b);
        lit = l > 0.04;
    } else if (depth < 12.0) {
        col = quantize(c, vec3(3.0, 3.0, 2.0), t);
    } else if (depth < 20.0) {
        col = quantize(c, vec3(5.0, 6.0, 5.0), t);
    } else {
        col = c;
    }
    vec3 dotCol = lit ? col : unlit;

    float r = dotsize * 0.5;
    float d = shape > 0.5 && shape < 1.5 ? max(abs(f.x), abs(f.y)) : length(f);
    float aa = 1.0 / pitch;
    float m = 1.0 - smoothstep(r - aa, r + aa, d);
    if (shape > 1.5) {
        float hl = 1.0 - smoothstep(0.0, r * 0.4, length(f - vec2(-0.16, -0.16) * dotsize));
        dotCol = mix(dotCol, vec3(1.0), hl * 0.3);
    }
    float halo = lit ? glow * 0.45 * (1.0 - smoothstep(r, 0.5, d)) : 0.0;
    return vec4(mix(glass + col * halo, dotCol, m), 1.0);
}
