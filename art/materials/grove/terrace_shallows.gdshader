shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform sampler2D brush_detail : filter_linear_mipmap, repeat_enable;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float center = 1.0 - smoothstep(.36, 1.0, length(UV));
	float flow = sin(dot(world_xz, vec2(4.1, 2.9)) - TIME * 1.44
		+ sin(world_xz.y * 2.47 + TIME * .57) * .67);
	float caustic = texture(brush_detail, world_xz * .20 + vec2(TIME * .012, -TIME * .009)).b;
	float glint = smoothstep(.82, .98, flow) * smoothstep(.12, .64, caustic);
	vec3 tide = mix(vec3(.026, .071, .083), vec3(.015, .26, .26), .34 + .66 * center);
	ALBEDO = tide;
	EMISSION = tide * (.16 + .49 * center)
		+ vec3(.024, .11, .13) * glint * (.34 + .33 * center);
	ROUGHNESS = mix(.67, .40, center);
	SPECULAR = .24;
}
