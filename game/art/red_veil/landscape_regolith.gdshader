shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 dust_color : source_color = vec4(0.32, 0.15, 0.125, 1.0);
uniform vec4 mineral_color : source_color = vec4(0.49, 0.275, 0.23, 1.0);
uniform float grain_scale = 48.0;
// Presentation strength: reduced at the calm outpost, with derivative filtering.
uniform float grain_strength : hint_range(0.0, 1.0) = 0.18;
varying vec3 ground_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = ground_position.xz;
	float broad = noise(p * 0.065);
	float patches = noise(p * 0.63 + broad * 2.0);
	float fine = noise(p * 6.0);
	float grain_visibility = clamp(1.0 - length(fwidth(p * grain_scale)), 0.0, 1.0);
	float grains = mix(0.5, noise(p * grain_scale), grain_visibility);
	float ripple = sin(p.x * 4.1 + p.y * 1.8 + noise(p * 0.38) * 8.0) * 0.5 + 0.5;
	float mineral = clamp(broad * 0.50 + patches * 0.35 + fine * 0.15, 0.0, 1.0);
	vec3 base = mix(dust_color.rgb, mineral_color.rgb, mineral);
	base *= 0.97 + ((grains - 0.5) * 0.21 + (ripple - 0.5) * 0.05) * grain_strength;
	ALBEDO = base;
	ROUGHNESS = 0.97 + (fine - 0.5) * 0.04 * grain_strength;
	SPECULAR = 0.14;
	// Minute relief only: the playable surface and collision remain level.
	NORMAL_MAP = vec3(0.5 + (grains - 0.5) * 0.12 * grain_strength, 0.5 + (fine - 0.5) * 0.08 * grain_strength, 1.0);
	NORMAL_MAP_DEPTH = 0.38;
}
