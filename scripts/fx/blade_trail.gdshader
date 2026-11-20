shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 ember : source_color = vec4(1.0, 0.58, 0.18, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.93, 0.72, 1.0);

void fragment() {
	// UV.x is remaining life, UV.y runs from the hilt (0) to the tip (1).
	float life = COLOR.a;
	float edge = smoothstep(0.15, 0.95, UV.y);
	vec3 tint = mix(ember.rgb, core.rgb, edge * life);
	float alpha = life * life * (0.25 + 0.75 * edge);
	ALBEDO = tint * alpha * 2.4;
}
