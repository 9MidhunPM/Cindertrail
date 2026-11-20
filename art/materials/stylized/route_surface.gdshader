shader_type spatial;

uniform sampler2D paint_masks : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform int surface_kind : hint_enum("Limestone", "Timber", "Bronze", "Moss") = 0;
uniform float tiles_per_meter = 1.15;
uniform float emission_gain = 0.0;

varying vec3 model_point;
varying vec3 model_normal;
varying vec2 instance_offset;

void vertex() {
	model_point = VERTEX;
	model_normal = NORMAL;
	instance_offset = MODEL_MATRIX[3].xz * .073;
}

void fragment() {
	vec3 n = abs(normalize(model_normal));
	vec2 projection = n.y >= max(n.x, n.z) ? model_point.xz :
		(n.x > n.z ? model_point.zy : model_point.xy);
	if (surface_kind == 1 && n.y >= max(n.x, n.z)) {
		// The grain follows the long side of horizontal bridge planks.
		projection = projection.yx;
	}
	vec4 marks = texture(paint_masks, projection * tiles_per_meter + instance_offset);
	vec3 pigment = tint.rgb;
	float metal_response = 0.0;
	float polish = .92;
	if (surface_kind == 0) {
		float damp = smoothstep(.36, .79, marks.b) * .30;
		pigment *= mix(.66, 1.34, marks.r);
		pigment = mix(pigment, pigment * vec3(.58, .77, .51), damp);
		polish = mix(.92, .71, damp);
	} else if (surface_kind == 1) {
		pigment *= mix(.51, 1.42, marks.g);
	} else if (surface_kind == 2) {
		float oxidized = smoothstep(.39, .80, marks.a);
		pigment *= mix(.74, 1.15, marks.r);
		pigment = mix(pigment, vec3(.069, .164, .132), oxidized * .52);
		metal_response = mix(.62, .22, oxidized);
		polish = mix(.46, .8, oxidized);
	} else {
		pigment *= mix(.62, 1.35, marks.b);
		polish = .72;
	}
	ALBEDO = pigment;
	ROUGHNESS = polish;
	METALLIC = metal_response;
	EMISSION = pigment * emission_gain;
}
