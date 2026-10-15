// Night warmth: Hyprland screen shader (decoration:screen_shader).
// Roughly 4000 K, the old hyprsunset setting. Toggled by services/Night.qml.
// GLSL ES 1.0 style, which every Hyprland version accepts for screen shaders.
precision highp float;

varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 c = texture2D(tex, v_texcoord);
    gl_FragColor = vec4(c.rgb * vec3(1.0, 0.81, 0.65), c.a);
}
