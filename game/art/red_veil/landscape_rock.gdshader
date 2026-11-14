shader_type spatial;
render_mode diffuse_burley;
uniform vec4 stone_color : source_color = vec4(0.37, 0.19, 0.17, 1.0);
uniform vec4 strata_color : source_color = vec4(0.58, 0.34, 0.29, 1.0);
varying vec3 stone_position;
float grain(vec3 p) { return fract(sin(dot(p, vec3(17.13, 63.71, 38.39))) * 43758.5453); }
void vertex() { stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float distortion = sin(stone_position.x * 0.17 + stone_position.z * 0.11) * 1.8 + sin(stone_position.z * 0.73) * 0.4;
	float bands = sin(stone_position.y * 1.7 + distortion) * 0.5 + 0.5;
	float grain_visibility = clamp(1.0 - length(fwidth(stone_position * 32.0)), 0.0, 1.0);
	float speckle = mix(0.5, grain(floor(stone_position * 32.0)), grain_visibility);
	ALBEDO = mix(stone_color.rgb, strata_color.rgb, 0.18 + bands * 0.14) * (0.96 + speckle * 0.08);
	ROUGHNESS = 0.96;
	SPECULAR = 0.13;
}
