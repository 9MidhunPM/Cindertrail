shader_type spatial;
render_mode cull_disabled;
varying vec3 place;
varying vec3 pigment;
varying vec3 normal_w;
varying float foliage;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float field(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
 place=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 foliage=1.-step(.8,COLOR.a);
 if (COLOR.a < .8) {
  float gust=sin(place.x*.93+place.z*.59+TIME*1.35)+.4*sin(place.z*2.6-TIME*2.2);
  VERTEX.x+=gust*.042;
  VERTEX.y+=gust*.013;
 }
 normal_w=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 pigment=COLOR.rgb;
 if(!OUTPUT_IS_SRGB){pigment=mix(pigment/12.92,pow((pigment+.055)/1.055,vec3(2.4)),step(vec3(.04045),pigment));}
}
void fragment(){
 vec2 uv=place.xz + place.y*vec2(.63,.34);
 float broad=field(uv*1.65);
 float grain=field(uv*11.);
 float mottled=field(uv*4.4)*.38+broad*.62;
 float mineral=step(pigment.b*.92,pigment.r)*smoothstep(.12,.30,pigment.r);
 float lichen=smoothstep(.64,.78,mottled)*smoothstep(.08,.65,normal_w.y);
 vec3 c=pigment*mix(.80,1.12,broad)*mix(.94,1.06,grain);
 c=mix(c,c*vec3(.59,.83,.57),lichen*mineral*.85);
 float wear=smoothstep(.70,.86,grain)*mineral;
 c=mix(c,c*vec3(1.14,1.09,.96),wear);
 float wet=smoothstep(.55,.75,broad)*smoothstep(.51,.67,field(uv*vec2(1.13,2.1)))*mineral*smoothstep(.52,.98,normal_w.y);
 ALBEDO=c*mix(1.,.82,wet);EMISSION=pigment*(.16*foliage);ROUGHNESS=mix(.91,.26,wet);SPECULAR=mix(.26,.62,wet);
}
