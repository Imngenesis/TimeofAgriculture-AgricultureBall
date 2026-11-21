shader_type spatial;
render_mode cull_disabled;
uniform vec3 reach_pollution=vec3(0.0);
uniform float alarm=0.0;
uniform float river_level=0.0;
uniform float sim_time=0.0;
varying vec3 site;
void vertex(){VERTEX.y+=river_level;site=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=site.xz;
	float pollution=mix(mix(reach_pollution.x,reach_pollution.y,smoothstep(-3.8,-2.2,p.y)),reach_pollution.z,smoothstep(2.3,3.8,p.y));
	float w=sin(p.y*4.8+p.x*8.0+sin(p.y*2.4-sim_time*0.38)+sim_time*0.6)*0.5+0.5;
	float r=sin(p.x*13.0-p.y*4.0+sim_time*1.24+sin(p.y*3.0))*0.5+0.5;
	float ribbon=smoothstep(0.89,0.99,w)*r;
	vec3 clean=mix(vec3(0.135,0.277,0.25),vec3(0.27,0.36,0.29),COLOR.r);
	clean=mix(clean, vec3(0.40,0.38,0.225),clamp(pollution*(0.5+0.5*COLOR.g)+alarm*0.55,0.0,0.85));
	ALBEDO=clean+vec3(0.030,0.041,0.038)*ribbon+0.011*w;
	NORMAL=normalize(NORMAL+vec3(0.017*(r-0.5),0.0,0.021*(w-0.5)));
	ROUGHNESS=0.76; SPECULAR=0.13;
}
