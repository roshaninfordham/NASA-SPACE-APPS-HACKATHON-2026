shader_type sky;
// Original calm dawn palette. Artistic dust scattering, not a weather model.
// Static sky keeps reduced-motion mode still and radiance caching inexpensive.
uniform vec3 zenith : source_color = vec3(0.44, 0.55, 0.67);
uniform vec3 horizon : source_color = vec3(0.92, 0.71, 0.63);
uniform vec3 sunset : source_color = vec3(1.0, 0.88, 0.68);
void sky() {
	float height = clamp(EYEDIR.y, 0.0, 1.0);
	// Matches the world key's azimuth/elevation, rather than a second sun.
	vec3 light_direction = normalize(vec3(-0.748, 0.407, 0.524));
	float facing = max(dot(EYEDIR, light_direction), 0.0);
	float warm_aureole = pow(facing, 8.0) * exp(-height * 1.5);
	vec3 color = mix(horizon, zenith, pow(height, 0.45));
	color = mix(color, sunset, warm_aureole * 0.52);
	color += sunset * pow(facing, 1800.0) * 1.2;
	// Warm lower hemisphere reflects regolith into polished suit undersides.
	if (EYEDIR.y < 0.0) {
		color = mix(horizon * 0.68, vec3(0.27, 0.16, 0.13), smoothstep(0.0, 0.85, -EYEDIR.y));
	}
	COLOR = color;
}
