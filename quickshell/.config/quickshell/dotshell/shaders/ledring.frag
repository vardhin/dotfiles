#version 440
// Animated LED border (LedRing.qml, driven by services/LedFx.qml): the
// outermost ring of a DotSurface canvas, one fragment per dot. Everything
// inside the ring is left clear. A dot's brightness is a blend from the unlit
// dot toward its color, since dot.frag reads canvas alpha as on / off.
//
// `u` is the dot's place along the ring, 0 .. 1 clockwise from the top left;
// `m` folds it about the top middle (0 at the top middle, 1 at the bottom
// middle), so effects can run down both sides at once.
//
//   -1 still    the whole ring in `still` (borders without animation)
//    0 comet    one head with a fading tail
//    1 twins    two comets, opposite
//    2 flow     the three tubes as a gradient, scrolling
//    3 breathe  the whole ring, slow in and out
//    4 marquee  theater-chase dashes
//    5 sparkle  dots twinkle at random
//    6 scanner  a pair sweeping down both sides and back
//    7 wipe     the ring fills clockwise, then empties
//   music (`level`, `bass`, `beat` and 16 `bands` from cava):
//    8 spectrum the bands around the ring, bass at the bottom, mirrored
//    9 pulse    the whole ring on the bass, flashing on beats
//   10 rider    a comet whose speed and tail follow the loudness
//   11 fizz     sparkle, denser and brighter with the treble
// Rebuild after editing: ./build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;        // cols, rows
    float mode;
    float time;       // seconds
    float phase;      // laps: speeds up with the music
    float offset;     // per ring, 0 .. 1
    float dir;        // 1 clockwise, -1 counter
    float gain;       // 0 .. 1: focused 1, the rest dimmer
    float level;      // music, 0 .. 1
    float bass;
    float treble;
    float beat;       // 1 on a beat, decaying
    float kick;       // 1 when the mode changes, decaying
    vec4 bandsA;      // 16 bands, low to high
    vec4 bandsB;
    vec4 bandsC;
    vec4 bandsD;
    vec4 c0;          // first tube
    vec4 c1;          // second tube
    vec4 c2;          // accent
    vec4 still;
    vec4 unlit;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float band(float i) {
    int k = int(clamp(i, 0.0, 15.0));
    vec4 v = k < 4 ? bandsA : k < 8 ? bandsB : k < 12 ? bandsC : bandsD;
    int j = k - (k / 4) * 4;
    return v[j];
}

// Distance from `x` to `head` going backwards along the ring, 0 .. 1.
float behind(float x, float head) {
    return fract((head - x) * dir);
}

vec3 tubes(float x) {
    x = fract(x) * 3.0;
    return x < 1.0 ? mix(c0.rgb, c1.rgb, x) : x < 2.0 ? mix(c1.rgb, c2.rgb, x - 1.0) : mix(c2.rgb, c0.rgb, x - 2.0);
}

// A VU color: first tube, second, then accent at the top.
vec3 vu(float v) {
    return v < 0.6 ? c0.rgb : v < 0.85 ? c1.rgb : c2.rgb;
}

void main() {
    vec2 cell = floor(qt_TexCoord0 * grid);
    float W = grid.x - 1.0, H = grid.y - 1.0;
    bool edge = cell.x < 0.5 || cell.y < 0.5 || cell.x > W - 0.5 || cell.y > H - 0.5;
    if (!edge || W < 1.0 || H < 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    float P = 2.0 * (W + H);
    float s = cell.y < 0.5 ? cell.x
            : cell.x > W - 0.5 ? W + cell.y
            : cell.y > H - 0.5 ? W + H + (W - cell.x)
            : 2.0 * W + H + (H - cell.y);
    float u = s / P;
    float top = 0.5 * W / P;                 // u of the top middle
    float m = abs(fract(u - top + 0.5) - 0.5) * 2.0;   // 0 at the top middle, 1 at the bottom
    float h = hash(cell + offset * 97.0);
    float ph = phase + offset;

    float k = 0.0;
    vec3 col = c0.rgb;
    int md = int(mode + 0.5);
    if (mode < -0.5) {
        k = 1.0;
        col = still.rgb;
    } else if (md == 0) {
        float b = behind(u, fract(ph * 0.5));
        k = b < 0.35 ? pow(1.0 - b / 0.35, 2.0) : 0.0;
        col = mix(c1.rgb, c0.rgb, k);
    } else if (md == 1) {
        float b = behind(fract(u * 2.0), fract(ph * 0.6));
        k = b < 0.4 ? pow(1.0 - b / 0.4, 1.6) : 0.0;
        col = mix(c1.rgb, u < 0.5 ? c0.rgb : c2.rgb, k);
    } else if (md == 2) {
        k = 0.85 + 0.15 * sin((u * 6.0 - ph) * 6.2832);
        col = tubes(u - ph * 0.25 * dir);
    } else if (md == 3) {
        k = 0.2 + 0.8 * (0.5 + 0.5 * sin(time * 2.2 + offset * 6.2832));
        col = mix(c1.rgb, c0.rgb, k);
    } else if (md == 4) {
        float q = floor(s + ph * 8.0 * dir);
        float on = mod(q, 4.0) < 2.0 ? 1.0 : 0.0;
        k = on;
        col = mod(floor(q / 4.0), 2.0) < 1.0 ? c0.rgb : c1.rgb;
    } else if (md == 5) {
        float t = time * 1.5 + h * 10.0;
        float tw = fract(t);
        float on = hash(cell + floor(t)) > 0.72 ? 1.0 : 0.0;
        k = on * (1.0 - tw);
        col = hash(cell + floor(t) + 3.0) > 0.8 ? c2.rgb : c0.rgb;
    } else if (md == 6) {
        float p = 0.5 - 0.5 * cos(ph * 3.1416);
        float d = abs(m - p);
        k = d < 0.12 ? pow(1.0 - d / 0.12, 1.5) : 0.0;
        col = mix(c1.rgb, c0.rgb, k);
    } else if (md == 7) {
        float c = fract(ph * 0.35);
        float x = fract((u - offset) * dir);
        k = c < 0.5 ? (x < c * 2.0 ? 1.0 : 0.0) : (x > (c - 0.5) * 2.0 ? 1.0 : 0.0);
        col = tubes(x * 0.66);
    } else if (md == 8) {
        float v = band(m * 15.99);
        k = v > 0.04 ? 0.25 + 0.75 * v : 0.0;
        col = vu(v);
    } else if (md == 9) {
        float v = clamp(bass * 1.2 + beat * 0.5, 0.0, 1.0);
        k = 0.15 + 0.85 * v;
        col = beat > 0.5 ? c2.rgb : mix(c1.rgb, c0.rgb, v);
    } else if (md == 10) {
        float tail = 0.08 + 0.5 * level;
        float b = behind(u, fract(ph * 0.5));
        float b2 = behind(u, fract(ph * 0.5 + 0.5));
        k = max(b < tail ? pow(1.0 - b / tail, 1.5) : 0.0, beat * (b2 < tail ? pow(1.0 - b2 / tail, 1.5) : 0.0));
        col = mix(c1.rgb, beat > 0.4 ? c2.rgb : c0.rgb, k);
    } else {
        float t = time * (2.0 + 6.0 * treble) + h * 10.0;
        float on = hash(cell + floor(t)) > 0.95 - 0.6 * level ? 1.0 : 0.0;
        k = on * (1.0 - fract(t)) * (0.4 + 0.6 * level);
        col = hash(cell + floor(t) + 3.0) > 1.0 - treble ? c2.rgb : c0.rgb;
    }

    // A mode change: a burst of random dots in the accent.
    if (kick > 0.01 && hash(cell + floor(time * 30.0)) < kick * 0.6) {
        k = 1.0;
        col = c2.rgb;
    }

    k = clamp(k, 0.0, 1.0) * gain;
    if (k < 0.06) {
        fragColor = vec4(0.0);
        return;
    }
    fragColor = vec4(mix(unlit.rgb, col, k), 1.0) * qt_Opacity;
}
