shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Original procedural mineral surface: not a NASA terrain reconstruction.
uniform vec4 dust_color : source_color = vec4(0.71, 0.46, 0.33, 1.0);
uniform vec4 mineral_color : source_color = vec4(0.85, 0.64, 0.47, 1.0);
uniform float grain_scale = 24.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.42;
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
	float broad = noise(p * 0.048);
	float fine = noise(p * 2.4);
	float grain_visibility = clamp(1.0 - length(fwidth(p * grain_scale)), 0.0, 1.0);
	float grains = mix(0.5, noise(p * grain_scale), grain_visibility);
	// Wide, coherent wind ripples with derivative filtering: no animated
	// textures, displacement, repeating pebbles or screen-space dependence.
	float phase = dot(p, vec2(2.4, 1.15)) + broad * 5.0;
	float ripple_visibility = 1.0 - smoothstep(0.5, 2.6, fwidth(phase));
	float ripple = sin(phase) * ripple_visibility;
	float mineral = clamp(0.27 + broad * 0.48 + fine * 0.08, 0.0, 1.0);
	vec3 base = mix(dust_color.rgb, mineral_color.rgb, mineral);
	base *= 1.0 + ((grains - 0.5) * 0.12 + ripple * 0.09) * grain_strength;
	ALBEDO = base;
	ROUGHNESS = 0.92;
	SPECULAR = 0.22;
	// Normal detail affects light only; the authoritative floor stays level.
	NORMAL_MAP = vec3(0.5 + cos(phase) * ripple_visibility * 0.12 * grain_strength,
		0.5 + (grains - 0.5) * 0.08 * grain_strength, 1.0);
	NORMAL_MAP_DEPTH = 0.32;
}
