shader_type spatial;
render_mode cull_disabled;

// Chalk, copper and timber in the dry uplands pick up less moss than flooded stone.
varying vec3 point_ws;
varying vec3 normal_ws;
varying vec3 base_tone;
varying float lit_inlay;
uniform sampler2D route_paint : filter_linear_mipmap, repeat_enable;
uniform sampler2D brush_detail : filter_linear_mipmap, repeat_enable;
uniform vec3 mineral_tint = vec3(1.0, 0.98, 0.94);
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
	vec2 uv = point_ws.xz + point_ws.y * vec2(0.62, 0.28);
	vec3 axis = abs(normal_ws);
	float broad = patches(uv * 0.78);
	float level = smoothstep(0.10, 0.82, normal_ws.y);
	float chalk = smoothstep(0.21, 0.55, base_tone.r) * smoothstep(0.46, 0.75, base_tone.g / max(base_tone.r, 0.001));
	float deposits = smoothstep(0.49, 0.83, broad) * chalk;
	vec2 side_uv = mix(point_ws.zy, point_ws.xy, smoothstep(0.24, 0.72, axis.z));
	vec4 pigment = mix(texture(route_paint, side_uv * vec2(0.22, 0.35)), texture(route_paint, point_ws.xz * 0.24), axis.y);
	vec2 plane = axis.y > max(axis.x,axis.z) ? point_ws.xz : (axis.x > axis.z ? point_ws.zy : point_ws.xy);
	vec4 brush = texture(brush_detail, plane * .27);
	float streak = mix(pigment.g, pigment.r, chalk);
	float seams = smoothstep(0.71, 0.91, cos((point_ws.y + broad * 0.26 + point_ws.x * 0.07) * 10.0));
	vec3 c = base_tone * mix(0.86, 1.13, broad) * (.58 + .88 * streak);
	c *= mix(vec3(1.0), mineral_tint, deposits);
	c *= mix(vec3(1.0), vec3(0.73, 0.67, 0.62), seams * (1.0 - axis.y) * chalk * 0.26);
	float quarry = smoothstep(1.06,1.16,mineral_tint.r);
	// Timber sleds leave paired scours across the quarry paving; cliff strata remain clean.
	float hauling = brush.a*chalk*level*quarry*.31;
	c *= 1.0 - hauling;
	c += vec3(.034, .030, .018)*quarry*deposits*level;
	float bronze = (1.-chalk)*smoothstep(1.09,1.8, base_tone.r/max(base_tone.g,.002));
	float tarnish = smoothstep(.60,.78,pigment.a) * bronze * (1.-quarry);
	c = mix(c,c*vec3(.55,1.11,1.05),tarnish*.74);
	ALBEDO = c;
	EMISSION = c * (vec3(0.19, 0.128, 0.071) * chalk * level + vec3(1.4) * lit_inlay);
	ROUGHNESS = mix(0.93,.55,bronze*(1.-tarnish));
	SPECULAR = 0.24;
}
