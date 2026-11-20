shader_type spatial;
render_mode unshaded, cull_back;

void fragment() {
	// Compact painted reflections for a shallow pool bordered by limestone.
	float current = sin(UV.x * 16.0 + UV.y * 21.0 - TIME * 0.84);
	float ripple = sin(UV.y * 55.0 + UV.x * 7.0 + current * 1.4 - TIME * 1.45);
	float crest = smoothstep(0.79, 0.995, ripple);
	float grazing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 teal = mix(vec3(0.012, 0.052, 0.065), vec3(0.023, 0.108, 0.115), 0.48 + current * 0.27);
	float lamp = smoothstep(0.63, 0.95, UV.x * 0.59 + UV.y * 0.41);
	vec3 glint = mix(vec3(0.028, 0.112, 0.124), vec3(0.25, 0.105, 0.032), lamp);
	ALBEDO = teal + glint * crest * (0.47 + 0.27 * grazing);
}
