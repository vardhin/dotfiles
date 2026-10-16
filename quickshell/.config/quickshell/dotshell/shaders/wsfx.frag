#version 440
// Workspace switch (panes/WorkspaceFx.qml): the old workspace, snapshotted
// just before the switch, dissolves into LED dots that flip over in a wave
// toward the direction of travel. The overlay is transparent where a dot has
// turned, so the new workspace (live, underneath) shows through.
//
// Per dot, through its turn (`ph` 0 .. 1):
//   0         the snapshot as it was, crisp
//   0 .. .5   a dot in the old color on glass, squashing like a flip-disc;
//             the glass around it thins out
//   .5 .. 1   the dot's back: a spark in the era's second tube that fades,
//             leaving the live screen
// Rebuild after editing: ./build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // overlay size in device px
    float pitch;      // effect dot pitch in device px
    float t;          // 0 .. 1 through the dissolve; < 0 = whole snapshot
    float dir;        // 1 = travelling right (wave runs left to right), -1 = left
    float dotSize;    // fraction of the pitch
    float shape;      // 0 round, 1 square, 2 bubble
    float glow;
    vec4 sparkColor;
    vec4 glassColor;
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    if (t < 0.0) {
        fragColor = texture(source, uv) * qt_Opacity;
        return;
    }
    vec2 px = uv * size;
    vec2 grid = max(floor(size / pitch), vec2(1.0));
    vec2 cell = floor(px / pitch);
    vec2 f = fract(px / pitch) - 0.5;

    float along = dir > 0.0 ? cell.x / grid.x : 1.0 - cell.x / grid.x;
    float delay = along * 0.7 + (cell.y / grid.y) * 0.15 + hash(cell) * 0.15;
    float ph = clamp((t * 1.25 - delay) / 0.25, 0.0, 1.0);

    if (ph <= 0.0) {
        fragColor = texture(source, uv) * qt_Opacity;
        return;
    }
    if (ph >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // A turning dot is squashed vertically: a disc seen edge-on at ph = .5.
    float squash = max(abs(cos(ph * 3.14159265)), 0.04);
    vec2 fs = vec2(f.x, f.y / squash);
    float r = dotSize * 0.5;
    float d = shape > 0.5 && shape < 1.5 ? max(abs(fs.x), abs(fs.y)) : length(fs);
    float aa = max(fwidth(d), 1e-4);
    float m = 1.0 - smoothstep(r - aa, r + aa, d);

    vec3 col;
    float a;
    if (ph < 0.5) {
        // Front: one color per dot, from its center in the snapshot.
        vec3 s = texture(source, (cell + 0.5) * pitch / size).rgb;
        float edge = smoothstep(0.3, 0.5, ph);
        col = mix(s, sparkColor.rgb, edge * 0.7);
        if (shape > 1.5) {
            float hl = 1.0 - smoothstep(0.0, r * 0.4, length(fs - vec2(-0.16, -0.16) * dotSize));
            col = mix(col, vec3(1.0), hl * 0.3);
        }
        float glassA = 1.0 - ph * 2.0;
        float halo = glow * 0.45 * edge * (1.0 - smoothstep(r, 0.5, d));
        vec3 glass = glassColor.rgb + sparkColor.rgb * halo;
        col = mix(glass, col, m);
        a = max(m, max(glassA, halo));
    } else {
        // Back: a spark that fades out.
        float k = 1.0 - (ph - 0.5) * 2.0;
        float halo = glow * 0.6 * (1.0 - smoothstep(r, 0.5, d));
        col = sparkColor.rgb;
        a = (m + halo * (1.0 - m)) * k;
    }
    fragColor = vec4(col * a, a) * qt_Opacity;
}
