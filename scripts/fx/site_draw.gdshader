shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 source_tint : source_color = vec4(.24, .82, .77, 1.0);
uniform vec4 sun_tint : source_color = vec4(1.0, .71, .27, 1.0);
uniform float draw_clock = 0.0;
uniform float abundance = 1.0;
uniform bool quiet = false;

void vertex() {
	// The mesh normal carries the curve tangent. Extrude across the eye direction
	// so a stream rising vertically out of the river keeps its width from either camera.
	vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 span = cross(tangent, normalize(-eye));
	span /= max(.04, length(span));
	// Leave room around the centerline for the pointed head of each packet.
	float width = UV2.x * ((quiet || UV2.y >= 1.0) ? 1.0 : 1.46);
	eye += span * (UV.y * 2.0 - 1.0) * width;
	POSITION = PROJECTION_MATRIX * vec4(eye, 1.0);
}

void fragment() {
	float x = UV.x;
	float lateral = abs(UV.y * 2.0 - 1.0);
	float feather = pow(max(0.0, 1.0-lateral), 1.5);
	float heart = 1.0 - smoothstep(.001, .32, lateral);
	float phase = fract(x * 1.22 - draw_clock * .73 + UV2.y + .5) - .5;
	bool dust = UV2.y >= 1.0;
	// Concentrate each head ahead of a longer tapering tail.
	float packet = exp(-abs(phase) * (phase < 0.0 ? 13.0 : 54.0));
	float arrival = smoothstep(.65, .94, x);
	vec3 pigment = mix(source_tint.rgb, sun_tint.rgb, arrival);
	if (quiet) {
		ALBEDO = pigment * 1.32;
		ALPHA = dust ? 0.0 : feather * (.31 + abundance * .26);
	} else if (dust) {
		float seeds = pow(max(0.0, cos(x * 111.0 - draw_clock * 9.0)), 4.0);
		ALBEDO = pigment * 2.0 + vec3(.23,.18,.08);
		ALPHA = feather * packet * (.38 + .62 * seeds) * (.64 + .36 * abundance);
	} else {
		float along = phase / (phase < 0.0 ? .065 : .034);
		float shape = length(vec2(along, lateral));
		float body = 1.0 - smoothstep(.82, 1.0, shape);
		float inner = 1.0 - smoothstep(.62, .75, shape);
		vec3 rim = mix(vec3(.003,.090,.105), vec3(.24,.073,.009), arrival);
		vec3 lit = mix(pigment * 1.8, vec3(2.25,1.04,.21), arrival);
		vec3 packet_color = mix(rim, lit, inner) + vec3(.28,.26,.17) * inner * heart;
		float trail = feather * .18 + heart * (.21 + packet * .38);
		ALBEDO = mix(pigment * 1.42, packet_color, body);
		ALPHA = max(trail, body * .97) * (.78 + .22 * abundance);
	}
}
