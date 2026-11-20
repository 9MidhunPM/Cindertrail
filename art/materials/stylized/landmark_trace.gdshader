shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color;
uniform float phase = -0.2;

void fragment() {
	float pulse = clamp(1.0 - abs(UV.y - phase) * 5.0, 0.0, 1.0);
	float edge = smoothstep(0.0, 0.24, 1.0 - abs(UV.x * 2.0 - 1.0));
	float crest = pow(0.5 + 0.5 * sin(UV.y * 76.0 - abs(UV.x - 0.5) * 6.0), 2.0);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.95, 0.78), crest * 0.44);
	EMISSION = tint.rgb * (0.18 + crest * 0.66);
	ALPHA = edge * pulse * (0.23 + crest * 0.66);
}
