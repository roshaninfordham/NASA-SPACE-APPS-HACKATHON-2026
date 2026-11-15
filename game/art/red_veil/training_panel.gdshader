shader_type spatial;
render_mode cull_back;

// An opaque manufactured array, with presentation detail independent of power
// calculations. Only the real model fraction moves the dust-removal front.
uniform float clean_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float work_feedback : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cell_color : source_color = vec4(0.025, 0.11, 0.23, 1.0);
uniform vec4 dust_color : source_color = vec4(0.66, 0.43, 0.27, 1.0);
uniform vec4 trace_color : source_color = vec4(0.50, 0.69, 0.77, 1.0);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 point) {
	vec2 grid = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash(grid), hash(grid + vec2(1.0, 0.0)), blend.x),
		mix(hash(grid + vec2(0.0, 1.0)), hash(grid + vec2(1.0, 1.0)), blend.x), blend.y);
}

float fine_line(float distance_to_line, float width, float footprint) {
	return 1.0 - smoothstep(width, width + max(footprint, 0.001), distance_to_line);
}

void fragment() {
	vec2 tiles = UV * vec2(8.0, 4.0);
	vec2 local = fract(tiles);
	vec2 centered = abs(local - 0.5);
	// Slightly clipped corners and narrow inter-cell gaps distinguish actual
	// photovoltaic cells from a bright rectangular HUD grid.
	float cell_distance = min(0.488 - max(centered.x, centered.y),
		(0.925 - centered.x - centered.y) * 0.707);
	float footprint = max(fwidth(tiles.x), fwidth(tiles.y));
	float cell_mask = smoothstep(0.0, max(footprint * 0.8, 0.004), cell_distance);
	float cell_tint = hash(floor(tiles));
	vec3 silicon = cell_color.rgb * (0.90 + cell_tint * 0.19);
	// Fine silver fingers fade smoothly below pixel size instead of producing
	// a checkerboard or moiré on narrow viewports.
	float finger_phase = fract(local.y * 25.0);
	float finger = fine_line(min(finger_phase, 1.0 - finger_phase), 0.035, fwidth(tiles.y * 25.0));
	finger *= 1.0 - smoothstep(0.35, 0.95, fwidth(tiles.y * 25.0));
	float busbar = max(fine_line(abs(local.x - 0.28), 0.004, fwidth(tiles.x)),
		fine_line(abs(local.x - 0.72), 0.004, fwidth(tiles.x)));
	silicon = mix(silicon, trace_color.rgb, clamp(finger * 0.13 + busbar * 0.30, 0.0, 0.45));
	vec3 glass = mix(vec3(0.009, 0.023, 0.041), silicon, cell_mask);
	// Broad, subtle coating variation supplements real material highlights.
	glass *= 0.95 + 0.10 * smoothstep(0.0, 1.0, UV.y);

	float broad = soft_noise(UV * vec2(7.0, 5.0));
	float grain = soft_noise(UV * vec2(95.0, 65.0));
	// Fade subpixel grain at distance; a stable material is preferable to
	// sparkling pixels on mobile and integrated-GPU screens.
	float grain_coverage = 1.0 - smoothstep(0.35, 1.0, max(fwidth(UV.x * 410.0), fwidth(UV.y * 270.0)));
	float fine = mix(0.5, soft_noise(UV * vec2(410.0, 270.0)), grain_coverage);
	vec3 regolith = dust_color.rgb * (0.91 + broad * 0.11 + grain * 0.045 + fine * 0.025);
	// A small irregular, feathered edge is a material detail. It is anchored
	// to clean_fraction and cannot advance independently or change the model.
	float irregularity = (soft_noise(vec2(UV.y * 27.0, 4.3)) - 0.5) * 0.007;
	float front = clean_fraction + irregularity;
	float dust = smoothstep(front - 0.006, front + 0.006, UV.x);
	if (clean_fraction <= 0.0001) { dust = 1.0; }
	if (clean_fraction >= 0.9999) { dust = 0.0; }
	// Thin brushed streaks behind the clearing front are material finish only:
	// they do not advance or invent work, and are invisible under untouched dust.
	float brushed_finish = sin(UV.y * 235.0) * 0.006 * grain_coverage;
	glass *= 1.0 + brushed_finish;
	ALBEDO = mix(glass, regolith, dust);
	// A shallow tangent-space grain normal differentiates rough regolith from
	// flat photovoltaic glass without textures, transparency or extra geometry.
	vec2 grain_normal = vec2(cos(UV.x * 126.0), sin(UV.y * 133.0));
	NORMAL_MAP = normalize(vec3(grain_normal * 0.055 * dust * grain_coverage, 1.0)) * 0.5 + 0.5;
	// Dust stays fully opaque. No cell lines leak through untouched regolith.
	ROUGHNESS = mix(0.22 + cell_tint * 0.035, 0.92 + grain * 0.06, dust);
	METALLIC = 0.22 * (1.0 - dust);
	SPECULAR = mix(0.72, 0.30, dust);
	CLEARCOAT = 0.78 * (1.0 - dust);
	CLEARCOAT_ROUGHNESS = 0.22;
	EMISSION = glass * (1.0 - dust) * 0.025;

	// A quiet freshly brushed highlight and fine lifted-looking grains are
	// driven by observed work, never TIME. Reduced motion disables both.
	float working = step(0.001, clean_fraction) * step(clean_fraction, 0.999) * work_feedback;
	float edge = (1.0 - smoothstep(0.002, 0.015, abs(UV.x - front))) * working;
	float satin = smoothstep(front - 0.055, front - 0.018, UV.x)
		* (1.0 - smoothstep(front - 0.018, front, UV.x)) * (1.0 - dust);
	EMISSION += vec3(0.36, 0.64, 0.71) * satin * working * 0.12;
	vec2 grit = UV * vec2(180.0, 110.0);
	float seed = hash(floor(grit));
	vec2 position = fract(grit + vec2(0.0, clean_fraction * 31.0 * (0.4 + seed)));
	float fleck = (1.0 - smoothstep(0.035, 0.12, length(position - 0.5))) * step(0.84, seed);
	ALBEDO = mix(ALBEDO, dust_color.rgb * 1.24, edge * fleck * 0.45);
}
