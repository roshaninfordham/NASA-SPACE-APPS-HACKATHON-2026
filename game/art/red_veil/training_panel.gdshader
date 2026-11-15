shader_type spatial;
render_mode cull_back;

// A readable, illustrative dust layer. Cleaning progress is supplied by the
// mission model; this shader neither estimates solar output nor advances work.
uniform float clean_fraction : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cell_color : source_color = vec4(0.035, 0.16, 0.23, 1.0);
uniform vec4 dust_color : source_color = vec4(0.62, 0.36, 0.19, 1.0);
uniform vec4 trace_color : source_color = vec4(0.33, 0.60, 0.64, 1.0);

float grain(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = fract(UV * vec2(8.0, 3.0));
	float edge = step(cell.x, 0.025) + step(0.975, cell.x) + step(cell.y, 0.025) + step(0.975, cell.y);
	float trace = step(fract(cell.y * 5.0), 0.035);
	vec3 glass = mix(cell_color.rgb, trace_color.rgb, clamp(edge * 0.5 + trace * 0.2, 0.0, 0.75));
	float noise = grain(floor(UV * vec2(130.0, 80.0)));
	float dust = smoothstep(clean_fraction - 0.012, clean_fraction + 0.012, UV.x);
	if (clean_fraction <= 0.0001) { dust = 1.0; }
	if (clean_fraction >= 0.9999) { dust = 0.0; }
	vec3 regolith = dust_color.rgb * (0.85 + noise * 0.28);
	ALBEDO = mix(glass, regolith, dust * (0.90 + noise * 0.10));
	ROUGHNESS = mix(0.38, 0.98, dust);
	METALLIC = 0.18 * (1.0 - dust);
}
