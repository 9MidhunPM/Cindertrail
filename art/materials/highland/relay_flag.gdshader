shader_type spatial;
render_mode cull_disabled;

uniform float wind_phase = 0.0;

void vertex() {
	float slack = UV.x * UV.x;
	float twist = UV.x * 10.0 - UV.y * 2.0;
	VERTEX.z += sin(TIME * 4.8 + twist + wind_phase) * slack * 0.22;
	VERTEX.y += sin(TIME * 3.2 + twist + wind_phase) * slack * 0.10;
}

void fragment() {
	float torn_end = 0.95 - 0.15 * pow(abs(sin(UV.y * 14.6)), 8.0);
	float loose_thread = 0.98 - 0.12 * pow(abs(cos(UV.x * 20.0)), 11.0);
	if (UV.x > torn_end || UV.y > loose_thread) {
		discard;
	}
	vec2 mark = abs(UV - vec2(0.37, 0.44)) * vec2(1.0, 0.35);
	float insignia = 1.0 - smoothstep(0.088, 0.097, mark.x + mark.y);
	float seam = 1.0 - smoothstep(0.013, 0.021, abs(UV.y - 0.085));
	float thread = 0.93 + 0.07 * sin(UV.y * 340.0);
	ALBEDO = mix(vec3(0.32, 0.071, 0.020), vec3(0.74, 0.38, 0.093), max(insignia, seam)) * thread;
	ROUGHNESS = 0.9;
}
