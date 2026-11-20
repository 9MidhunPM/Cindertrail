shader_type canvas_item;

// Warm red edge pulse when the shrine loses integrity.
uniform float strength = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.55, 1.35, length(p * vec2(0.9, 1.1)));
	COLOR = vec4(0.85, 0.16, 0.08, edge * strength * 0.55);
}
