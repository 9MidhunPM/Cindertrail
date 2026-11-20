shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float strike : hint_range(0.0, 1.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(0.38, 0.90, 0.88);
uniform vec3 strike_color : source_color = vec3(0.85, 1.0, 0.92);

void fragment() {
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(0.53 - strike * 0.11, 0.97, edge);
	ALBEDO = mix(rim_color, strike_color, strike) * (1.15 + strike * 0.15);
	ALPHA = strength * rim * (0.64 + strike * 0.25);
}
