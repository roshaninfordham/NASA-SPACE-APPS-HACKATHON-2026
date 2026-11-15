shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Thin stylized visor with a readable edge. This is not optical/radiation physics.
void fragment() {
	vec3 n = normalize(NORMAL);
	float facing = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	float highlight = pow(max(dot(n, normalize(vec3(-0.5, 0.8, 0.6))), 0.0), 50.0);
	ALBEDO = mix(vec3(0.34, 0.66, 0.76), vec3(0.89, 0.96, 1.0), highlight);
	ALPHA = 0.035 + fresnel * 0.26 + highlight * 0.17;
	ROUGHNESS = 0.09;
	METALLIC = 0.04;
	EMISSION = vec3(0.48, 0.79, 0.86) * fresnel * 0.16;
}
