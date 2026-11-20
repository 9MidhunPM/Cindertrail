shader_type spatial;
render_mode cull_disabled;

// Chalk, copper and timber in the dry uplands pick up less moss than flooded stone.
varying vec3 point_ws;
varying vec3 normal_ws;
varying vec3 base_tone;
varying float lit_inlay;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float patches(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.,0)),f.x),mix(hash21(i+vec2(0,1.)),hash21(i+vec2(1)),f.x),f.y);
}
void vertex() {
	point_ws=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	normal_ws=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	base_tone=COLOR.rgb;
	lit_inlay=1.0-step(.8,COLOR.a);
	if (!OUTPUT_IS_SRGB) {
		base_tone=mix(base_tone/12.92,pow((base_tone+.055)/1.055,vec3(2.4)),step(vec3(.04045),base_tone));
	}
}
void fragment() {
	vec2 uv=point_ws.xz+point_ws.y*vec2(.62,.28);
	float broad=patches(uv*.78);
	float grain=patches(uv*7.0);
	float level=smoothstep(.1,.82,normal_ws.y);
	float chalk=smoothstep(.21,.55,base_tone.r)*step(base_tone.b*.9,base_tone.g);
	float deposits=smoothstep(.51,.84,broad*.75+grain*.25)*chalk;
	vec3 c=base_tone * mix(.90,1.09,broad) * mix(.97,1.03,grain);
	c*=mix(vec3(1),vec3(1.08,1.02,.88),deposits);
	ALBEDO=c;
	EMISSION=c*(vec3(.17,.121,.067)*chalk*level+vec3(1.4)*lit_inlay);
	ROUGHNESS=.93;
	SPECULAR=.24;
}
