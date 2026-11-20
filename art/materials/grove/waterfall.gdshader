shader_type spatial;
render_mode cull_disabled;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float streams=sin(pos.x*22.+sin(pos.y*3.5+TIME*3.)*.8)*.5+.5;
 float bands=sin(pos.y*13.+pos.x*18.+TIME*4.2)*.5+.5;
 vec3 c=mix(vec3(.034,.34,.37),vec3(.55,.93,.90),pow(streams,3.)*.50+bands*.16);
 ALBEDO=c;EMISSION=c*.30;ROUGHNESS=.39;
}
