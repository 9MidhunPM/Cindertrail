shader_type canvas_item;

uniform int page = 0;
uniform bool motion_enabled = true;
uniform float age = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float ellipse(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.76, 1.04, length((uv - center) / radius));
}

void fragment() {
	vec2 uv = UV;
	float depth = 0.0;
	float falling_water = 0.0;
	float ripples = 0.0;
	float sun = 0.0;
	if (page == 0) {
		// The stone arch and its orange canopy frame a distant observatory.
		depth = 1.0 - ellipse(uv, vec2(0.56, 0.53), vec2(0.42, 0.59));
		falling_water = ellipse(uv, vec2(0.78, 0.69), vec2(0.05, 0.065))
			+ ellipse(uv, vec2(0.59, 0.81), vec2(0.05, 0.055));
	} else if (page == 1) {
		depth = ellipse(uv, vec2(0.30, 0.55), vec2(0.32, 0.70));
		depth = max(depth, smoothstep(0.61, 0.77, uv.y) * smoothstep(0.43, 0.58, uv.x));
		sun = ellipse(uv, vec2(0.723, 0.55), vec2(0.09, 0.14));
	} else if (page == 2) {
		depth = ellipse(uv, vec2(0.38, 0.63), vec2(0.37, 0.87));
		sun = ellipse(uv, vec2(0.397, 0.659), vec2(0.073, 0.11));
	} else {
		// The traveler and paving stones are closest, with open water on both sides.
		depth = max(ellipse(uv, vec2(0.295, 0.59), vec2(0.10, 0.34)), smoothstep(0.66, 1.0, uv.y));
		ripples = smoothstep(0.50, 0.73, uv.y) * max(0.0, 1.0 - ellipse(uv, vec2(0.40, 0.72), vec2(0.19, 0.43)));
		falling_water = ellipse(uv, vec2(0.157, 0.456), vec2(0.057, 0.106));
	}
	float moving = float(motion_enabled);
	float t = age;
	vec2 drift = vec2(sin(t * 0.31), sin(t * 0.24 + 0.35)) * vec2(0.0044, 0.0018);
	vec2 border = smoothstep(vec2(0.0), vec2(0.06), min(uv, vec2(1.0) - uv));
	uv += (depth - 0.17) * drift * border * moving;
	uv.y += (falling_water * sin(t * 3.0 - uv.y * 100.0) * 0.0018
		+ ripples * sin(uv.y * 225.0 + t * 1.8) * 0.0007) * moving;
	vec4 ink = texture(TEXTURE, uv);
	float warm = smoothstep(0.12, 0.49, ink.r - ink.b);
	ink.rgb += vec3(0.07, 0.041, 0.009) * sun * warm * (0.5 + 0.5 * sin(t * 2.1)) * moving;
	COLOR = ink * tint;
}
