shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
uniform float storm_level : hint_range(0.0, 1.0) = 0.0;
uniform vec4 coral : source_color = vec4(1.0, 0.19, 0.38, 1.0);
uniform vec4 pale : source_color = vec4(1.0, 0.67, 0.72, 1.0);
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
    vec3 p = normalize(local_point);
    float terrain = sin(p.x * 6.0 + sin(p.z * 5.0)) * cos(p.y * 7.0 + p.z * 2.0);
    terrain += 0.31 * sin(p.x * 17.0 + p.y * 7.0) * cos(p.z * 15.0 - p.y * 9.0);
    terrain += 0.13 * sin(p.x * 34.0 - p.z * 20.0) * sin(p.y * 27.0 + p.z * 8.0);
    float land = smoothstep(-0.24, 0.29, terrain);
    float contour = 1.0 - smoothstep(0.018, 0.055, abs(fract(terrain * 4.0) - 0.5));
    float scan = 0.80 + 0.20 * sin(local_point.y * 145.0 - TIME * 1.3);
    float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float edge = pow(1.0 - facing, 2.2);
    vec3 ocean = vec3(0.28, 0.025, 0.13);
    vec3 color = mix(ocean, coral.rgb, land);
    color = mix(color, pale.rgb, contour * 0.33 + edge * 0.55);
    ALBEDO = color;
    EMISSION = color * (0.9 + contour * 0.75 + edge * 0.8) * scan;
    ALPHA = clamp(0.48 + land * 0.22 + edge * 0.22 + storm_level * 0.05, 0.0, 0.94);
}
