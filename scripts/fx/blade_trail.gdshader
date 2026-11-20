shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 ember : source_color = vec4(1.0, 0.58, 0.18, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform bool quiet = false;

void fragment() {
	float life = clamp(COLOR.a, 0.0, 1.0);
	// Two narrow filaments run along the blade edge. The body falls away
	// towards the wrist, keeping the cloak and the target readable.
	float edge = smoothstep(0.76, 0.95, UV.y);
	float filament = 1.0 - smoothstep(0.015, 0.048, abs(UV.y - 0.69));
	float width = smoothstep(quiet ? 0.68 : 0.13, 0.86, UV.y);
	vec3 tint = mix(ember.rgb, core.rgb, edge * 0.94 + filament * 0.22);
	ALBEDO = tint * (1.4 + edge * 1.7 + filament * 0.65);
	ALPHA = pow(life, 1.55) * width * (quiet ? 0.42 : 0.83);
}
