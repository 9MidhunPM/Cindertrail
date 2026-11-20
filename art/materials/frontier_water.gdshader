shader_type spatial;
render_mode cull_back;

varying vec2 creek_position;

void vertex() {
	creek_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 current = creek_position * vec2(0.42, 1.23);
	float sweep = sin(current.y + sin(current.x * 0.52 + TIME * 0.36) * 1.27 - TIME * 0.91);
	float ripple = sin(current.y * 2.7 + current.x * 0.91 + sweep * 0.58 + TIME * 1.38);
	float light = smoothstep(0.83, 0.995, ripple) * (sweep * 0.28 + 0.50);
	float stream = sin(current.x * 0.93 + sin(current.y * 0.072) * 1.66);
	vec3 tide = mix(vec3(0.018, 0.105, 0.122), vec3(0.025, 0.246, 0.242), stream * 0.34 + 0.50);
	ALBEDO = mix(tide, vec3(0.097, 0.41, 0.43), light * 0.48);
	EMISSION = vec3(0.014, 0.049, 0.065) + vec3(0.043, 0.13, 0.15) * light;
	ROUGHNESS = 0.29 + 0.22 * light;
}
