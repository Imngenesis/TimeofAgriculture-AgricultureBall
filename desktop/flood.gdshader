shader_type spatial;
render_mode cull_disabled;
uniform float stage=0.0;
uniform float river_time=0.0;
varying vec3 site;
void vertex(){
	site=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y=mix(0.025,0.70,stage)+0.016*sin(site.z*2.0-river_time*0.35);
}
void fragment(){
	float current=sin(site.z*5.2+site.x*2.4-river_time*0.85+sin(site.x*4.1));
	float shallow=COLOR.r-0.055*sin(site.z*3.7+site.x*4.5)-mix(0.88,0.22,stage);
	if(shallow<0.0){discard;}
	float edge=1.0-smoothstep(0.0,0.07,shallow);
	ALBEDO=mix(vec3(0.255,0.33,0.29),vec3(0.46,0.49,0.38),edge*0.63)+0.013*current;
	ROUGHNESS=0.80;SPECULAR=0.17;
	ALPHA=mix(0.48,0.91,smoothstep(0.0,0.34,shallow));
}
