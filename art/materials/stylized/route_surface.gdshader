shader_type spatial;

uniform sampler2D paint_masks : filter_linear_mipmap, repeat_enable;
uniform sampler2D brush_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_sheet : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform int surface_kind : hint_enum("Limestone", "Timber", "Bronze", "Moss", "Leaf", "Rope", "Enamel") = 0;
uniform int trim_row : hint_range(0,5) = 3;
uniform float tiles_per_meter = 1.15;
uniform float emission_gain = 0.0;

varying vec3 model_point;
varying vec3 model_normal;

void vertex() {
	model_point = VERTEX;
	model_normal = NORMAL;
}

void fragment() {
	vec3 n = abs(normalize(model_normal));
	vec2 projection = n.y >= max(n.x, n.z) ? model_point.xz :
		(n.x > n.z ? model_point.zy : model_point.xy);
	if (surface_kind == 1 && n.y >= max(n.x, n.z)) {
		projection = projection.yx;
	}
	vec2 uv = projection * tiles_per_meter;
	vec4 marks = texture(paint_masks, uv*.65);
	vec2 strip_uv = uv * vec2(.50,1.55);
	// Wrap each row independently. Explicit gradients keep distant rows from leaking together.
	vec2 atlas_uv = vec2(strip_uv.x, (float(trim_row) + .025 + .95*fract(strip_uv.y)) / 6.0);
	vec3 trim = textureGrad(trim_sheet,atlas_uv, dFdx(strip_uv)*vec2(1.,.95/6.),
			dFdy(strip_uv)*vec2(1.,.95/6.)).rgb;
	vec3 pigment = tint.rgb;
	float metal_response = 0.0;
	float polish = .92;
	if (surface_kind == 0) {
		float damp = smoothstep(.39,.85,marks.b) * .35;
		pigment *= (.57 + marks.r*.97) * (.94 + trim*.19);
		pigment = mix(pigment,pigment*vec3(.53,.81,.58),damp);
		polish = mix(.92,.69,damp);
	} else if (surface_kind == 1 || surface_kind == 5) {
		pigment *= .61 + marks.g*.91;
		pigment *= clamp(.69+trim*1.09,vec3(.74),vec3(1.32));
	} else if (surface_kind == 2) {
		float oxidized = smoothstep(.47,.82,marks.a);
		pigment *= clamp(.64+trim*1.29,vec3(.71),vec3(1.42));
		pigment = mix(pigment,pigment*vec3(.37,.81,.72)+vec3(.006,.022,.021),oxidized*.65);
		metal_response = mix(.60,.26,oxidized);
		polish = mix(.41,.70,oxidized);
	} else if (surface_kind == 4) {
		pigment *= .65 + texture(brush_detail,uv*.48).r*.88;
		polish = .86;
	} else if (surface_kind == 6) {
		pigment *= .77 + trim*.65;
		polish = .32;
	} else {
		pigment *= .70 + marks.b*.55;
		polish = .76;
	}
	ALBEDO = pigment;
	ROUGHNESS = polish;
	METALLIC = metal_response;
	EMISSION = pigment * emission_gain;
}
