shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D leaves : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform float flex=0.019;
uniform bool rice=false;
uniform vec3 seasonal_tint=vec3(1.0);
varying vec3 variation;

void vertex(){
	variation=INSTANCE_CUSTOM.rgb;
	float free_tip=pow(1.0-UV.y,1.7);
	VERTEX.x+=free_tip*flex*(sin(TIME*1.42+variation.z*16.0)+0.31*sin(TIME*2.31+UV.y*4.1));
}

void fragment(){
	vec2 uv=vec2(variation.x>0.5?1.0-UV.x:UV.x,UV.y);
	vec4 leaf=texture(leaves,uv);
	vec3 colour=leaf.rgb;
	if(rice && variation.y<0.5){
		float value=dot(colour,vec3(0.28,0.59,0.13));
		colour=mix(vec3(0.040,0.086,0.036),vec3(0.32,0.46,0.20),smoothstep(0.025,0.81,value));
	}
	ALBEDO=colour*seasonal_tint*mix(0.80,1.10,variation.x);
	NORMAL=normalize((VIEW_MATRIX*vec4(0.1,1.0,0.17,0.0)).xyz);
	ROUGHNESS=0.94;
	SPECULAR=0.12;
	ALPHA=leaf.a;
	ALPHA_SCISSOR_THRESHOLD=0.37;
}
