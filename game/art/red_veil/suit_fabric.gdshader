shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 pearl : source_color = vec4(0.95, 0.91, 0.88, 1.0);
uniform float shimmer = 0.10;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.5);
	vec3 film = mix(vec3(1.0, 0.84, 0.72), vec3(0.69, 0.84, 0.97), edge);
	// Fine, low-contrast weave reads as cloth, not a drawn grid across the suit.
	float weave = sin(local_position.x * 230.0) * sin(local_position.y * 240.0) * 0.006;
	ALBEDO = mix(pearl.rgb, film, shimmer * (0.25 + edge * 0.75)) + weave;
	METALLIC = 0.045;
	ROUGHNESS = 0.38 + weave;
	CLEARCOAT = 0.24;
	CLEARCOAT_ROUGHNESS = 0.27;
	EMISSION = pearl.rgb * 0.025;
}
