#version 300 es
// Night warmth: Hyprland's full-screen post-process (decoration:screen_shader),
// over windows and all. services/ScreenShader.qml hands it to Hyprland only
// while the night token is on. The glass / LED look is not here: it runs on
// the wallpaper alone (shaders/wall.frag), so windows stay untouched.
//
// Every screen shader is GLSL ES 3.00 (`#version 300 es`, `in` / `out`,
// `texture()`): it links against Hyprland's own 300 es vertex shader, and a
// mismatched version fails to link ("all shaders must use same shading
// language version").
precision highp float;

//@DEFINES

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 t = texture(tex, v_texcoord);
    // ~4000 K, the old hyprsunset setting.
    fragColor = vec4(clamp(t.rgb * vec3(1.0, 0.81, 0.65), 0.0, 1.0), t.a);
}
