shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

// Additive white pass shown for a moment when a creature is struck.
instance uniform float flash = 0.0;

void fragment() {
	ALBEDO = vec3(1.0, 0.86, 0.62) * flash * 0.85;
}
