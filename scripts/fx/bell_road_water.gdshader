shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform bool radial = false;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 gold : source_color = vec4(1.0, .73, .26, 1.0);
uniform vec4 foam : source_color = vec4(.62, .93, .83, 1.0);

void fragment() {
	float alpha;
	vec3 color;
	if (radial) {
		vec2 p = UV * 2.0 - 1.0;
		float radius = length(p) + .005 * sin(p.x * 42.0 + p.y * 21.0);
		float wave = radius - (.06 + .95 * progress);
		float outer = 1.0 - smoothstep(.007, .018, abs(wave));
		float inner = (1.0 - smoothstep(.004, .012, abs(wave + .094))) * .71;
		float breakup = smoothstep(-.45, .2, sin(p.x * 14.0 + p.y * 23.0) + .55 * sin(p.x * 47.0));
		alpha = max(outer, inner) * (.32 + .68 * breakup);
		color = mix(foam.rgb, gold.rgb, inner * .50);
	} else {
		float trail = (progress * 1.32 - .025) - UV.x;
		float head = smoothstep(-.045, .005, trail) * (1.0 - smoothstep(.014, .31, trail));
		float width = abs(UV.y * 2.0 - 1.0);
		alpha = head * (1.0 - smoothstep(.15, 1.0, width));
		color = mix(gold.rgb, vec3(1.0, .93, .59), (1.0 - width) * head);
	}
	ALBEDO = color * 1.7;
	ALPHA = alpha * strength * smoothstep(0.0, .05, progress) * (1.0 - smoothstep(.80, 1.0, progress));
}
