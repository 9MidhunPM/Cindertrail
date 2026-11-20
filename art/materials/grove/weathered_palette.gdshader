shader_type spatial;
render_mode cull_disabled;
uniform sampler2D route_paint : filter_linear_mipmap, repeat_enable;
uniform sampler2D brush_detail : filter_linear_mipmap, repeat_enable;
uniform float waterline = 0.245;
varying vec3 place;
varying vec3 pigment;
varying vec3 normal_w;
varying float foliage;
varying float reed;
varying float wood;
varying float stone_edge;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float field(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
 place=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 reed=1.-step(.46,COLOR.a);
 foliage=(1.-step(.8,COLOR.a))*(1.-reed);
 stone_edge=clamp((1.-COLOR.a)/.078,0.,1.)*step(.915,COLOR.a);
 wood=step(.82,COLOR.a)*(1.-step(.91,COLOR.a));
 if (reed > .5) {
  float tip=clamp((.44-COLOR.a)/.32,0.,1.);
  float motion=sin(place.x*.83+place.z*.61+TIME*1.85)*.72
        +sin(place.z*1.89+TIME*2.7)*.28;
  VERTEX.x+=motion*.19*tip*tip;
  VERTEX.z+=motion*.072*tip*tip;
 } else if (foliage > .5) {
  float gust=sin(place.x*.93+place.z*.59+TIME*1.35)+.4*sin(place.z*2.6-TIME*2.2);
  VERTEX.x+=gust*.042;
  VERTEX.y+=gust*.013;
 }
 normal_w=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 pigment=COLOR.rgb;
 if(!OUTPUT_IS_SRGB){pigment=mix(pigment/12.92,pow((pigment+.055)/1.055,vec3(2.4)),step(vec3(.04045),pigment));}
}
void fragment() {
 vec3 axis = abs(normalize(normal_w));
 vec2 plane = axis.y > max(axis.x, axis.z) ? place.xz : (axis.x > axis.z ? place.zy : place.xy);
 vec2 local = plane * .32;
 vec2 patch = place.xz * .28 + place.y * vec2(.11,.13);
 float broad = field(patch);
 vec4 carving = texture(route_paint, local + vec2(broad*.033, 0.));
 vec4 brush = texture(brush_detail, local * 1.27);
 float foliage_type = max(foliage,reed);
 float stone = (1.-max(wood,foliage_type))*smoothstep(.82,1.28,pigment.r/max(.005,pigment.b));
 float moss = smoothstep(.56,.86,carving.b*.58+broad*.42);
 float wet_line = 1.-smoothstep(waterline+.035,waterline+.39,place.y+(broad-.5)*.16);
 float damp = stone*max(wet_line, moss*.24*smoothstep(.65,.86,normal_w.y));
 vec3 c=pigment*mix(.87,1.12,broad);
 c *= mix(1., .39+carving.r*1.20, stone);
 float joint = smoothstep(.66,.99,stone_edge)*stone;
 float edge_moss = smoothstep(.36,.70,carving.b*.62 + broad*.38) * joint;
 c = mix(c,c*vec3(.42,.66,.42),edge_moss*.60);
 c = mix(c,c*vec3(.67,.82,.91),joint*(.22+.23*wet_line));
 vec3 pale_chips = c*vec3(1.25,1.18,1.06);
 c = mix(c,pale_chips,joint*smoothstep(.52,.65,carving.r)*(1.-edge_moss));
 c *= mix(1., .49+carving.g*1.16, wood);
 c *= mix(1., .67+brush.r*.76, foliage_type);
 c = mix(c, c*vec3(.78,1.07,1.12), foliage_type*(.25+.33*brush.r));
 c = mix(c, c*vec3(.60,.92,.52),stone*moss*(.40+.24*wet_line));
 c = mix(c, c*vec3(.38,.64,.70),damp*.78);
 float wet_patches = .51*stone*smoothstep(.49,.79,carving.b*.48+broad*.52)*smoothstep(.6,.95,normal_w.y);
 damp = max(damp,wet_patches);
 c *= 1.-wet_patches*.27;
 float silt_line = (1.-smoothstep(.014,.075,abs(place.y-waterline-.088+(broad-.5)*.11)))*stone;
 c += vec3(.064,.094,.071)*silt_line;
 ALBEDO = c;
 EMISSION = pigment*.12*foliage_type;
 ROUGHNESS = mix(.89,.39,damp);
 SPECULAR = mix(.23,.54,damp);
}
