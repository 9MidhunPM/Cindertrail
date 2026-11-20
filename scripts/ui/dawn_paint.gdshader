shader_type canvas_item;
render_mode unshaded;

// The plate fixes the silhouettes. Small, masked displacements give water and
// nearby leaves depth without making stonework swim.
uniform int plate = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool still = false;
varying vec4 panel_tint;

void vertex() {
	panel_tint = COLOR;
}

float patch(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.45, 1.0, length((uv - center) / radius));
}

// The three painted herons are separate silhouettes in the ford sky. Shift
// just their wingtips against the clear sky, with an independent beat per bird.
float wingbeat(vec2 uv, vec2 center, vec2 radius, float age, float delay) {
	vec2 local = (uv - center) / radius;
	return patch(uv, center, radius) * min(1.0, abs(local.x) * 1.7)
		* sin(age * 19.0 + delay) * radius.y * 0.18;
}

void fragment() {
	vec2 uv = UV;
	float t = still ? 0.78 : progress;
	float moving = still ? 0.0 : 1.0;
	float envelope = smoothstep(0.0, 0.08, t);
	vec3 base = texture(TEXTURE, uv).rgb;
	float leaf = smoothstep(0.025, 0.17, base.r - base.b)
		* (1.0 - smoothstep(0.13, 0.45, base.g - base.r));
	float water = smoothstep(0.01, 0.17, base.g - base.r)
		* smoothstep(0.50, 0.80, uv.y);
	float border = smoothstep(0.0, 0.07, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	float front = smoothstep(0.28, 0.97, uv.y) + leaf * 0.35;
	vec2 drift = vec2(plate == 1 ? -0.010 : 0.010, -0.003) * (t - 0.45) * front;
	if (plate == 1) {
		drift.x += sin(uv.y * 119.0 + t * 9.0) * 0.002 * water;
		drift.y += sin(uv.x * 65.0 + t * 11.0) * 0.0008 * water;
		drift.y += wingbeat(uv, vec2(.783,.181), vec2(.025,.038), t, 1.0)
			+ wingbeat(uv, vec2(.834,.133), vec2(.032,.042), t, 2.7)
			+ wingbeat(uv, vec2(.916,.082), vec2(.05,.064), t, .2);
		float waterfall = patch(uv, vec2(.39,.47), vec2(.055,.14));
		drift.y -= waterfall * sin(uv.y * 105.0 - t * 15.0) * .0028;
	}
	drift.x += leaf * sin(uv.y * 30.0 + t * 8.0) * 0.0008;
	vec3 paint = texture(TEXTURE, uv + drift * border * moving).rgb;
	float line = 0.25 * uv.x + 0.75 * uv.y;
	if (plate == 2) {
		line = 0.74 * uv.x + 0.26 * (1.0 - uv.y);
	}
	float dawn = 1.0 - smoothstep(t * 1.38 - 0.23, t * 1.38 + 0.04, line);
	float value = dot(paint, vec3(0.2126, 0.7152, 0.0722));
	float pigment = smoothstep(0.10, 0.66, value);
	vec3 cool = paint * vec3(0.88, 0.94, 1.02);
	vec3 honey = paint * vec3(1.04, 1.015, 0.96) + vec3(0.036, 0.019, 0.0) * pigment;
	vec3 lit = mix(cool, honey, dawn);
	if (plate == 1) {
		float shimmer = pow(max(0.0, sin(uv.y * 184.0 + t * 14.0 + sin(uv.x * 14.0))), 9.0);
		lit += vec3(0.034, 0.022, 0.006) * shimmer * water * envelope * moving;
	}
	COLOR = vec4(lit, 1.0) * panel_tint;
}
