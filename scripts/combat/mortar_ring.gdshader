shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float flight = 0.0;
uniform float impact = -1.0;
uniform vec4 amber : source_color = vec4(1.0, 0.64, 0.25, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.90, 0.64, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float feather = max(fwidth(r), 0.012);
	float radius = mix(0.64, 0.92, flight);
	float width = 0.012;
	float opacity = mix(0.16, 0.54, flight);
	if (impact >= 0.0) {
		float travel = 1.0 - pow(1.0 - impact, 2.4);
		radius = mix(0.10, 0.98, travel);
		width = mix(0.14, 0.012, travel);
		opacity = 1.0 - smoothstep(0.26, 1.0, impact);
	}
	float line = 1.0 - smoothstep(width, width + feather, abs(r - radius));
	ALBEDO = mix(amber.rgb, hot.rgb, line * 0.7);
	ALPHA = line * opacity;
}
