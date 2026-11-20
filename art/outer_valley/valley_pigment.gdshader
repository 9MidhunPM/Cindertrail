shader_type spatial;
render_mode cull_disabled;

uniform sampler2D route_paint : filter_linear_mipmap, repeat_enable;
uniform sampler2D brush_detail : filter_linear_mipmap, repeat_enable;
uniform int family : hint_enum("Masonry","Soil","Bark") = 0;
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
	vec3 axis = abs(normalize(up_normal));
	vec2 plane = axis.y > max(axis.x,axis.z) ? world_point.xz :
		(axis.x > axis.z ? world_point.zy : world_point.xy);
	vec2 uv = plane*.27;
	vec4 mineral = texture(route_paint,uv);
	vec4 brush = texture(brush_detail,uv*1.18);
	float broad = pigment(world_point.xz*.36 + world_point.y*.09);
	float stroke = family == 2 ? mineral.g : (family == 1 ? brush.g : mineral.r);
	if (moves_in_wind) { stroke = brush.r; }
	vec3 paint = COLOR.rgb*(.65+.65*stroke)*(.88+.22*broad);
	float moss = smoothstep(.56,.82,mineral.b*.63+broad*.37) * smoothstep(.25,.88,up_normal.y);
	paint=mix(paint,paint*vec3(.64,.92,.67),moss*(moves_in_wind ? .19 : .55));
	ALBEDO = paint;
	ROUGHNESS = .91;
	SPECULAR = .18;
}
