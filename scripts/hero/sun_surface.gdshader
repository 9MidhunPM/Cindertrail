shader_type spatial;
render_mode unshaded;

varying vec3 sphere_pos;

void vertex() {
	sphere_pos = normalize(VERTEX);
}

void fragment() {
	vec3 p = sphere_pos;
	float swirl = sin(p.y * 10.0 + p.x * 5.0 + TIME * .6
			+ sin(p.z * 9.0 + p.y * 5.0 + TIME * .29) * 2.1);
	float filament = pow(1.0 - abs(swirl), 3.0);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	ALBEDO = mix(vec3(1.0, .34, .022), vec3(1.0, .90, .41),
			clamp(.27 + filament * .6 + rim, 0.0, 1.0));
	EMISSION = ALBEDO * 1.4;
}
