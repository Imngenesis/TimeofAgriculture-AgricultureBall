shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D reed_roof : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 site;
varying float finish;
void vertex(){site=VERTEX;finish=UV.x;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){
	vec2 i=floor(p),f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
	vec3 colour=COLOR.rgb;
	float grain=noise2(site.xz*20.0+site.y*3.0);
	float rough=0.86;
	if(finish>0.5 && finish<1.5){
		vec3 straw=texture(reed_roof,vec2(site.x*1.42,site.z*1.85+site.y*0.31)).rgb;
		colour=mix(colour*0.65,straw,0.74);
	}else if(finish>1.5 && finish<2.5){
		float stripe=noise2(vec2(site.x*14.0+site.z*23.0,site.y*3.0));
		colour*=0.70+0.25*stripe+0.09*grain;
	}else if(finish>2.5 && finish<3.5){
		colour*=0.68+0.22*grain+0.10*noise2(site.xz*5.0);
		rough=0.52;
	}else if(finish>3.5 && finish<4.5){
		colour*=0.84+0.14*grain;
	}else if(finish>4.5){
		float ripple=sin(site.x*24.0+site.z*17.0+TIME*1.2+sin(site.z*5.3));
		colour*=0.83+0.08*ripple+0.055*grain;
		rough=0.44;
	}else{colour*=0.86+0.11*grain;}
	ALBEDO=colour;ROUGHNESS=rough;SPECULAR=0.20;
}
