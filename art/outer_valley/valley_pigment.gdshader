shader_type spatial;
render_mode cull_disabled;

uniform sampler2D route_paint : filter_linear_mipmap, repeat_enable;
uniform bool moves_in_wind = false;

varying vec3 world_point;
varying vec3 up_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float pigment(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1,0)), f.x),
		mix(hash21(cell+vec2(0,1)), hash21(cell+vec2(1,1)), f.x), f.y);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up_normal = MODEL_NORMAL_MATRIX * NORMAL;
	if (moves_in_wind) {
		float gust = sin(world_point.x * .41 + world_point.z * .22 + TIME * 1.56);
		VERTEX.x += gust * .061;
		VERTEX.z += gust * .046;
	}
}

void fragment() {
	vec2 p = world_point.xz + world_point.y * vec2(.57,.74);
	float marbling = pigment(p*1.3) * .55 + pigment(p*.32) * .45;
	float grain = pigment(p*8.3);
	vec3 brush = texture(route_paint, p * .29).rgb;
	float moss = smoothstep(.64,.86,marbling) * smoothstep(.34,.95,up_normal.y);
	vec3 paint = COLOR.rgb * (.77 + marbling*.26 + grain*.055 + mix(brush.r, brush.g, float(moves_in_wind))*.15);
	moss *= mix(.70, 1.18, brush.b);
	ALBEDO = mix(paint, paint*vec3(.64,.82,.60), moss*.68);
	ROUGHNESS = .92;
	SPECULAR = .17;
}
