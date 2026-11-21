shader_type spatial;
render_mode cull_disabled;
varying vec3 site;
uniform vec3 season_tint=vec3(1.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(32.7,91.3))) * 43758.53); }
float noise2(vec2 p) { vec2 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1)),f.x),f.y); }
void vertex(){site=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float large=noise2(site.xz*0.94);
	float grain=noise2(site.xz*14.0);
	float blades=noise2(vec2(site.x*33.0+site.z*4.0,site.z*12.0));
	float shade=noise2(site.xz*0.23+vec2(9.5,2.8));
	ALBEDO=COLOR.rgb*season_tint*(0.66+large*0.20+grain*0.08+blades*0.055+shade*0.12);
	ROUGHNESS=0.98;
}
