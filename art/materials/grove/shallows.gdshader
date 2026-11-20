shader_type spatial;
render_mode cull_disabled;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 deep : source_color = vec4(0.009,0.31,0.44,1.0);
uniform vec4 jade : source_color = vec4(0.025,0.71,0.66,1.0);
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float field(vec2 p){
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

vec3 reflection(vec3 start, vec3 ray, mat4 projection, mat4 inv_projection, vec3 fallback){
	float last=0.12;
	for(int i=1;i<=21;i++){
		float range=0.12+float(i)*(.13+float(i)*.092);
		vec3 pos=start+ray*range;
		vec4 clip=projection*vec4(pos,1.);
		if(clip.w<=0.) break;
		vec2 uv=clip.xy/clip.w*.5+.5;
		if(any(lessThan(uv,vec2(.001)))||any(greaterThan(uv,vec2(.999)))) break;
		float z=textureLod(scene_depth,uv,0.).r;
		vec4 hit=inv_projection*vec4(uv*2.-1.,mix(z*2.-1.,z,step(-.5,CLIP_SPACE_FAR)),1.);
		float depth=hit.z/hit.w-pos.z;
		if(depth>0. && depth<range-last+1.05){
			// Refine the sampled silhouette edge where the ray first crossed opaque geometry.
			for(int j=0;j<3;j++){
				float mid=(range+last)*.5;
				pos=start+ray*mid;
				clip=projection*vec4(pos,1.);
				vec2 tap=clip.xy/clip.w*.5+.5;
				z=textureLod(scene_depth,tap,0.).r;
				hit=inv_projection*vec4(tap*2.-1.,mix(z*2.-1.,z,step(-.5,CLIP_SPACE_FAR)),1.);
				if(hit.z/hit.w>pos.z){range=mid;uv=tap;}else{last=mid;}
			}
			vec2 border=smoothstep(vec2(0.),vec2(.065),min(uv,1.-uv));
			return mix(fallback,textureLod(scene_color,uv,0.).rgb,border.x*border.y);
		}
		last=range;
	}
	return fallback;
}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec2 p=world_pos.xz;
	float pool=field(p*.21)*.7+field(p*.53)*.3;
	float wave=sin(p.y*5.6+p.x*.74+sin(p.x*1.25+TIME*.64)*.7-TIME*1.14);
	float crosswave=sin(dot(p,vec2(2.5,3.4))+TIME*.78+field(p*.42)*4.);
	vec3 wn=normalize(vec3(crosswave*.009,1.,wave*.013+crosswave*.006));
	vec3 n=normalize(mat3(VIEW_MATRIX)*wn);
	vec3 reflect_ray=reflect(-VIEW,n);
	vec3 bed=mix(deep.rgb,jade.rgb,pool);
	vec3 ground_color=textureLod(scene_color,SCREEN_UV,0.).rgb;
	bed=mix(ground_color*vec3(.41,1.10,1.05),bed,.34+.27*pool);
	float caustic=sin(p.x*4.1+p.y*1.8+sin(p.y*2.5+TIME*.41)*.92)
		+.82*sin(p.y*5.1-p.x*1.3+sin(p.x*2.05-TIME*.38)*.78);
	bed+=vec3(.027,.098,.061)*(1.-smoothstep(.035,.145,abs(caustic)))*smoothstep(.31,.72,pool);
	vec3 sky=mix(vec3(.009,.065,.10),vec3(.031,.129,.162),pool);
	vec3 reflected=reflection(VERTEX+n*.075,reflect_ray,PROJECTION_MATRIX,INV_PROJECTION_MATRIX,sky);
	float fresnel=pow(1.-clamp(dot(n,VIEW),0.,1.),1.6);
	float glint=smoothstep(.865,.971,wave*.64+crosswave*.36)*smoothstep(.42,.76,field(p*vec2(.85,.49)));
	ALBEDO=vec3(0.);
	EMISSION=mix(bed,reflected*vec3(.80,.98,1.05),.21+.68*fresnel)+vec3(.10,.24,.22)*glint*(.21+.34*fresnel);
	ROUGHNESS=.42;SPECULAR=.12;
	ALPHA=.995;
}
