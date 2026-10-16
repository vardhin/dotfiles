#version 300 es
// The screen: Hyprland's full-screen post-process (decoration:screen_shader).
// services/Screen.qml fills in the defines below from the tokens, writes the
// result to the state dir and points Hyprland at it. Hyprland gives screen
// shaders no custom uniforms (only tex, fullSize, wl_output and time, and
// time needs damage tracking off), so every setting is baked in as a constant
// and a token change writes a new file.
//
//   MODE 0  glass: faint dot mask, phosphor tint, vignette. Always on.
//   MODE 1  full LED: the screen as dots on the era's glass, quantized to
//           the era (ramp or RGB332/565). Screen = board samples one color
//           per dot (LED_DETAIL 0); led keeps every pixel inside its dot.
//   MODE 2  pass-through (screen = off with night on: warmth only).
//   LED_DETAIL 1  full LED keeps every pixel inside a dot instead of one
//           color per dot: text stays legible at fine pitches.
//   NIGHT 1 warmth (~4000 K, the old hyprsunset setting) on top of either.
//
// Coordinates: in Hyprland's screen pass v_texcoord (0, 0) is the top left,
// so the dot grid starts at the top-left pixel like the shell's own panes.
//
// Every screen shader is GLSL ES 3.00 (`#version 300 es`, `in` / `out`,
// `texture()`): it links against Hyprland's own 300 es vertex shader, and a
// mismatched version fails to link ("all shaders must use same shading
// language version").
precision highp float;

//@DEFINES
#ifndef MODE
#define MODE 0
#define NIGHT 0
#define PITCH 3.6
#define DOT 0.8
#define SHAPE 0
#define DEPTH 0
#define GLOW 0.55
#define TINT vec3(1.0, 0.70, 0.28)
#define GLASS vec3(0.047, 0.035, 0.024)
#define UNLIT vec3(0.165, 0.125, 0.082)
#define RAMP0 vec3(0.18, 0.125, 0.05)
#define RAMP1 vec3(0.42, 0.29, 0.12)
#define RAMP2 vec3(0.72, 0.51, 0.20)
#define RAMP3 vec3(1.0, 0.70, 0.28)
#endif
#ifndef LED_DETAIL
#define LED_DETAIL 0
#endif

// Glass strength. Small on purpose: text must stay as sharp as without it.
const float MASK = 0.10;      // how much the gaps between dots darken
const float TINT_MIX = 0.06;  // pull toward the era's phosphor color
const float VIGNETTE = 0.22;  // corner darkening

in vec2 v_texcoord;
uniform sampler2D tex;
uniform vec2 fullSize;
out vec4 fragColor;

float luma(vec3 c) {
    return dot(c, vec3(0.30, 0.59, 0.11));
}

vec3 quantize(vec3 c, vec3 bits) {
    vec3 n = exp2(bits) - 1.0;
    return floor(c * n + 0.5) / n;
}

vec3 eraRamp(float l) {
    float lv = min(3.0, floor(l * 4.2));
    if (lv < 0.5) return RAMP0;
    if (lv < 1.5) return RAMP1;
    if (lv < 2.5) return RAMP2;
    return RAMP3;
}

// Distance from the dot's center in pitch units, by era shape.
float dotDist(vec2 f) {
#if SHAPE == 1
    return max(abs(f.x), abs(f.y));
#else
    return length(f);
#endif
}

float vignette(vec2 uv) {
    vec2 q = uv - 0.5;
    return 1.0 - VIGNETTE * pow(clamp(length(q) * 1.4142, 0.0, 1.0), 2.5);
}

void main() {
    vec2 px = v_texcoord * fullSize;
    vec2 g = px / PITCH;
    vec2 f = fract(g) - 0.5;
    float d = dotDist(f);
    float r = DOT * 0.5;
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);

#if MODE == 1
#if LED_DETAIL == 1
    // Detail: every pixel inside a dot keeps its own color, so strokes thinner
    // than a dot survive; only the gaps between dots are glass.
    vec3 s = texture(tex, v_texcoord).rgb;
#else
    // One color per dot, from the 3x3 tap that stands out most from the
    // cell's mean: a 1 px text stroke wins over the background around it
    // (an average would blur it to the background's grey), on dark and light
    // themes alike.
    vec2 center = (floor(g) + 0.5) * PITCH;
    float o = PITCH / 3.0;
    vec3 taps[9];
    vec3 mean = vec3(0.0);
    for (int i = 0; i < 9; i++) {
        vec2 at = center + vec2(float(i % 3 - 1), float(i / 3 - 1)) * o;
        taps[i] = texture(tex, at / fullSize).rgb;
        mean += taps[i];
    }
    mean /= 9.0;
    vec3 s = taps[4];
    float best = -1.0;
    for (int i = 0; i < 9; i++) {
        float dl = abs(luma(taps[i]) - luma(mean));
        if (dl > best) {
            best = dl;
            s = taps[i];
        }
    }
#endif
    float l = luma(s);
    // Dark-theme backgrounds stay unlit, like the off dots of a real board.
    bool lit = l > 0.11;
#if DEPTH == 0
    // Stretched so mid-grey UI text lands on the bright levels, not the dim
    // ones: the ramp is for contrast, the dots carry the detail.
    vec3 col = eraRamp(clamp((l - 0.11) / 0.5, 0.0, 1.0) * 0.99);
#elif DEPTH == 8
    vec3 col = quantize(s, vec3(3.0, 3.0, 2.0));
#elif DEPTH == 16
    vec3 col = quantize(s, vec3(5.0, 6.0, 5.0));
#else
    vec3 col = s;
#endif
    vec3 dotCol = lit ? col : UNLIT;
#if SHAPE == 2
    // Bubble: a small glossy highlight in the upper left of each dot.
    float hl = 1.0 - smoothstep(0.0, r * 0.4, length(f - vec2(-0.16, -0.16) * DOT));
    dotCol = mix(dotCol, vec3(1.0), hl * 0.3);
#endif
    float halo = lit ? GLOW * 0.45 * (1.0 - smoothstep(r, 0.5, d)) : 0.0;
    vec3 c = mix(GLASS + col * halo, dotCol, m);
    float a = 1.0;
#elif MODE == 2
    vec4 t = texture(tex, v_texcoord);
    vec3 c = t.rgb;
    float a = t.a;
#else
    vec4 t = texture(tex, v_texcoord);
    vec3 c = t.rgb;
    float a = t.a;
    // Phosphor: a little of the era's primary in everything, by brightness.
    vec3 tint = TINT / max(max(TINT.r, max(TINT.g, TINT.b)), 1e-3);
    c = mix(c, luma(c) * tint, TINT_MIX);
    // Faint dot mask; the 1/(1 - MASK/2) keeps overall brightness level.
    c *= mix(1.0 - MASK, 1.0, m) / (1.0 - MASK * 0.5);
#endif

#if MODE != 2
    c *= vignette(v_texcoord);
#endif
#if NIGHT == 1
    c *= vec3(1.0, 0.81, 0.65);
#endif
    fragColor = vec4(clamp(c, 0.0, 1.0), a);
}
