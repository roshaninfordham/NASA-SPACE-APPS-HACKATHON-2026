shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 pearl : source_color = vec4(0.95,0.89,0.91,1.0);
uniform float shimmer = 0.22;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float facing = clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
	vec3 film = 0.5 + 0.5*cos(vec3(0.0,2.1,4.2) + (1.0-facing)*8.0);
	vec3 cell = abs(fract(local_position*22.0)-0.5);
	float seam = smoothstep(0.465,0.495,max(cell.x,max(cell.y,cell.z)));
	ALBEDO = mix(pearl.rgb,film,shimmer*(0.25+0.75*(1.0-facing))) * (1.0-seam*0.09);
	METALLIC = 0.16;
	ROUGHNESS = 0.29 + seam*0.12;
	CLEARCOAT = 0.4;
	CLEARCOAT_ROUGHNESS = 0.35;
}
