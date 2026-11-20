shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep : source_color = vec4(0.015,0.24,0.29,1.0);
uniform vec4 jade : source_color = vec4(0.03,0.59,0.49,1.0);
uniform vec4 glint : source_color = vec4(0.42,0.80,0.73,1.0);
varying vec2 world_xz;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 vec2 p=world_xz;
 float pool=noise2(p*.21)*.78+noise2(p*.56)*.22;
 float wave=noise2(p*vec2(.80,3.1)+vec2(TIME*.07,-TIME*.12));
 float ripple=noise2(p*vec2(.93,10.)+vec2(TIME*.04,-TIME*.12));
 float fresnel=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),2.5);
 vec3 c=mix(deep.rgb,jade.rgb,clamp(.04+pool*.98+wave*.14,0.,1.));
 c=mix(c,glint.rgb,smoothstep(.66,.89,ripple)*(.12+.3*fresnel));
 ALBEDO=c;EMISSION=c*.21;ROUGHNESS=.27+wave*.1;SPECULAR=.47;
 ALPHA=clamp(.40+fresnel*.47+.12*(1.-pool),.38,.91);
}
