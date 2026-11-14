shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
// A faint physical-space grid; no flicker or unsupported refraction dependency.
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    float angle = atan(local_position.z, local_position.x);
    float vertical = abs(fract(angle * 6.3662) - 0.5);
    float horizontal = abs(fract(local_position.y * 4.0) - 0.5);
    float line = 1.0 - smoothstep(0.012, 0.032, min(vertical, horizontal));
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    vec3 tint = vec3(1.0, 0.43, 0.57);
    ALBEDO = tint;
    EMISSION = tint * (0.20 + line * 0.25 + rim * 0.35);
    ALPHA = 0.012 + line * 0.16 + rim * 0.08;
}
