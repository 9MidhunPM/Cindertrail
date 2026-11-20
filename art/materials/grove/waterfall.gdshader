shader_type spatial;
render_mode cull_disabled;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float strands=sin(UV.x*59.+sin(UV.y*4.3-TIME*1.3+UV.x*9.)*.57+1.9*sin(UV.x*17.))*.5+.5;
	float flow=sin(UV.y*17.-TIME*4.7+UV.x*8.+sin(UV.x*31.)*1.9)*.5+.5;
	float ripples=sin(pos.z*17.-TIME*3.9+UV.x*7.)*.5+.5;
	float seam=smoothstep(.65,.93,strands)*(.18+flow*.55);
	float foam=smoothstep(.79,.98,UV.y)*(.43+strands*.37);
	vec3 c=mix(vec3(.018,.20,.235),vec3(.56,.84,.81),seam+.16*flow+foam*.39+ripples*.065);
	ALBEDO=c;EMISSION=c*.35;ROUGHNESS=.38;
}
