shader_type spatial;
render_mode cull_disabled;
uniform vec3 reach_pollution=vec3(0.0);
uniform float alarm=0.0;
uniform float river_level=0.0;
uniform float sim_time=0.0;
varying vec3 site;
float water_hash(vec2 p){return fract(sin(dot(p,vec2(19.43,47.81)))*23941.73);}
float variation(vec2 p){
	vec2 cell=floor(p),f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(water_hash(cell),water_hash(cell+vec2(1,0)),f.x),mix(water_hash(cell+vec2(0,1)),water_hash(cell+vec2(1,1)),f.x),f.y);
}
float wavelet(vec2 p,float detail){
	float drift=variation(p*vec2(1.8,0.85));
	float phase=p.y*detail+drift*1.37+0.31*sin(p.x*4.2+p.y);
	float edge=abs(fract(phase)-0.5);
	return (1.0-smoothstep(0.018,0.029+fwidth(phase)*0.5,edge))*smoothstep(0.44,0.77,variation(p*vec2(3.3,2.7)));
}
void vertex(){VERTEX.y+=river_level;site=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=site.xz;
	float pollution=mix(mix(reach_pollution.x,reach_pollution.y,smoothstep(-3.8,-2.2,p.y)),reach_pollution.z,smoothstep(2.3,3.8,p.y));
	float w=sin(p.y*4.8+p.x*8.0+sin(p.y*2.4-sim_time*0.38)+sim_time*0.6)*0.5+0.5;
	float r=sin(p.x*13.0-p.y*4.0+sim_time*1.24+sin(p.y*3.0))*0.5+0.5;
	float bank=abs(p.x-(0.36*p.y+1.18*sin(p.y*0.42+0.6)-0.15))/(1.14+0.14*sin(p.y*0.62+0.1));
	float ripple=sin(17.0*p.y+sin(5.4*p.x+sim_time*0.53)+sim_time*1.52);
	vec2 flow=vec2(p.x-0.35*p.y,p.y-sim_time*0.16);
	float current=variation(flow*vec2(1.5,0.55));
	float glints=wavelet(flow,5.2)+0.6*wavelet(flow*1.7+vec2(3.0,sim_time*0.045),5.8);
	vec3 clean=mix(vec3(0.112,0.215,0.213),vec3(0.29,0.365,0.284),smoothstep(0.18,1.12,bank));
	clean=mix(clean, vec3(0.40,0.38,0.225),clamp(pollution*(0.5+0.5*COLOR.g)+alarm*0.55,0.0,0.85));
	float skim=smoothstep(0.86,1.07,bank)*(0.5+0.5*ripple);
	ALBEDO=clean+vec3(0.062,0.071,0.063)*glints+vec3(0.012)*skim+vec3(0.041,0.053,0.048)*(current-0.5);
	NORMAL=normalize(NORMAL+vec3(0.063*(r-0.5),0.0,0.045*(w-0.5)));
	ROUGHNESS=0.36; SPECULAR=0.42;
}
