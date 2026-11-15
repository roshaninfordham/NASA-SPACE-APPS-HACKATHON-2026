shader_type spatial;
render_mode cull_back;

// A readable, illustrative dust layer. Cleaning progress is supplied by the
// mission model; this shader neither estimates solar output nor advances work.
uniform float clean_fraction : hint_range(0.0, 1.0) = 0.0;
// Set only when the model has advanced; zero for reduced motion and pause.
uniform float work_feedback : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cell_color : source_color = vec4(0.025, 0.12, 0.26, 1.0);
uniform vec4 dust_color : source_color = vec4(0.62, 0.36, 0.19, 1.0);
uniform vec4 trace_color : source_color = vec4(0.26, 0.76, 0.86, 1.0);

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
	// A steady progress seam makes small, truthful changes easy to see. It
	// follows the same model fraction; it does not clear additional surface.
	float seam = (1.0 - smoothstep(0.0, 0.006, abs(UV.x - clean_fraction))) * step(0.001, clean_fraction) * step(clean_fraction, 0.999);
	EMISSION = trace_color.rgb * (0.13 * clamp(edge + trace, 0.0, 1.0) * (1.0 - dust) + 0.35 * seam);
	// A soft satin reflection trails the real clearing edge. Its position depends
	// on actual removed dust, never TIME, and it never changes the dust mask.
	float fresh_strip = smoothstep(clean_fraction - 0.07, clean_fraction - 0.018, UV.x) * (1.0 - smoothstep(clean_fraction - 0.018, clean_fraction, UV.x)) * (1.0 - dust);
	float satin = 0.35 + 0.65 * pow(max(0.0, 1.0 - abs(UV.y - 0.5) * 2.0), 2.0);
	EMISSION += trace_color.rgb * fresh_strip * satin * work_feedback * 0.30;
	// Sparse lifted-looking grains stay on the surface beside that same edge.
	// These are small warm dust flecks, not sparks or an exposure simulation.
	vec2 grit = UV * vec2(100.0, 60.0);
	float grit_seed = grain(floor(grit));
	vec2 grit_position = fract(grit + vec2(0.0, clean_fraction * 48.0 * (0.4 + grit_seed * 0.4)));
	float fleck = (1.0 - smoothstep(0.025, 0.11, length(grit_position - vec2(0.5)))) * step(0.78, grit_seed);
	float dust_edge = (1.0 - smoothstep(0.005, 0.05, UV.x - clean_fraction)) * step(clean_fraction, UV.x) * dust;
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.73, 0.40), fleck * dust_edge * work_feedback * 0.45);
	ROUGHNESS = mix(0.26, 0.98, dust);
	METALLIC = 0.18 * (1.0 - dust);
}
