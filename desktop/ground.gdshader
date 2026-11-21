shader_type spatial;
render_mode cull_disabled;
varying vec3 site;
uniform vec3 season_tint=vec3(1.0);
uniform sampler2D meadow : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
float hash(vec2 p) { return fract(sin(dot(p,vec2(32.7,91.3))) * 43758.53); }
float noise2(vec2 p) { vec2 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1)),f.x),f.y); }
void vertex(){site=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float large=noise2(site.xz*0.94);
	float grain=noise2(site.xz*14.0);
	float blades=noise2(vec2(site.x*33.0+site.z*4.0,site.z*12.0));
	float shade=noise2(site.xz*0.23+vec2(9.5,2.8));
	vec3 fine=texture(meadow,site.xz*0.27).rgb;
	vec3 broad=texture(meadow,vec2(site.z,-site.x)*0.091+0.32).rgb;
	float detail=dot(fine,vec3(0.3,0.59,0.11));
	float river=0.36*site.z+1.18*sin(site.z*0.42+0.6)-0.15;
	float breadth=1.14+0.14*sin(site.z*0.62+0.1);
	float bank=abs(site.x-river)-breadth;
	float cover=smoothstep(0.25,1.8,bank+large*0.55);
	vec3 grass=mix(COLOR.rgb*(0.42+detail*0.87+large*0.14+shade*0.13)+broad*0.09,fine*vec3(0.91,1.05,0.95),0.24);
	vec3 silt=COLOR.rgb*(0.46+grain*0.18+large*0.20);
	float path_x=river-breadth-1.38-0.24*sin(site.z*0.95);
	float path_edge=abs(site.x-path_x)+0.08*(grain-0.5)+0.045*sin(site.z*4.6);
	float path=(1.0-smoothstep(0.07,0.24,path_edge))*(1.0-smoothstep(22.0,25.0,abs(site.z)));
	vec3 earth=mix(silt,vec3(0.36,0.265,0.165),0.58)*(0.88+0.22*grain+0.15*blades);
	ALBEDO=mix(mix(silt,grass,cover),earth,path*0.85)*season_tint;
	ROUGHNESS=mix(0.53,0.96,cover);
}
