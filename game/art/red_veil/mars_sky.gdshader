shader_type sky;
// Art-directed dust haze; presentation only, never a weather/irradiance model.
uniform vec3 zenith : source_color = vec3(0.20, 0.13, 0.21);
uniform vec3 horizon : source_color = vec3(0.65, 0.37, 0.39);
uniform vec3 sunset : source_color = vec3(0.96, 0.65, 0.49);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 float height=clamp(EYEDIR.y,0.0,1.0);
 vec3 light_direction=normalize(vec3(-0.72,0.22,0.48));
 float facing=max(dot(EYEDIR,light_direction),0.0);
 float haze=pow(facing,10.0)*exp(-height*3.0);
 vec3 color=mix(horizon,zenith,pow(height,0.48));
 color=mix(color,sunset,haze*0.55);
 vec2 sky_uv=vec2(atan(EYEDIR.z,EYEDIR.x)*4.0,EYEDIR.y*24.0);
 float clouds=noise(sky_uv)+noise(sky_uv*2.1)*0.35;
 float veil=smoothstep(0.65,1.1,clouds)*smoothstep(0.015,0.12,height)*(1.0-smoothstep(0.2,0.55,height));
 color=mix(color,color*0.8+sunset*0.15,veil*0.3);
 color+=sunset*pow(facing,650.0)*0.8;
 if(EYEDIR.y<0.0) color=mix(horizon*0.5,vec3(0.16,0.09,0.09),clamp(-EYEDIR.y*3.0,0.0,1.0));
 COLOR=color;
}
