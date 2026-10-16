#version 300 es
// Night warmth: Hyprland screen shader (decoration:screen_shader).
// Roughly 4000 K, the old hyprsunset setting. Toggled by services/Night.qml.
//
// Every screen shader is GLSL ES 3.00 (`#version 300 es`, `in` / `out`,
// `texture()`): it links against Hyprland's own 300 es vertex shader, and a
// mismatched version fails to link ("all shaders must use same shading
// language version"). Keep any future screen shader (Phase 6 glass) the same.
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    fragColor = vec4(c.rgb * vec3(1.0, 0.81, 0.65), c.a);
}
