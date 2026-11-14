shader_type spatial;
render_mode cull_disabled;
// Lightweight authored pearl/lacquer finish. Angle tint is an art approximation,
// not a physically calibrated thin-film optical simulation.
uniform vec4 shell_color : source_color = vec4(0.91, 0.88, 0.85, 1.0);
uniform bool lacquer = false;
uniform float surface_roughness = 0.25;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    vec3 pearl_tint = mix(vec3(1.0, 0.93, 0.89), vec3(0.88, 0.94, 1.0), rim);
    float micro = sin(local_position.x * 95.0) * sin(local_position.y * 81.0 + local_position.z * 69.0);
    ALBEDO = shell_color.rgb * (lacquer ? vec3(1.0) : pearl_tint) * (1.0 + micro * 0.006);
    METALLIC = lacquer ? 0.36 : 0.22;
    ROUGHNESS = surface_roughness + micro * 0.012;
    CLEARCOAT = lacquer ? 0.85 : 0.45;
    CLEARCOAT_ROUGHNESS = 0.18;
}
