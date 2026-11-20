shader_type sky;

uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_low : source_color = vec3(0.17, 0.32, 0.48);
uniform vec3 night_high : source_color = vec3(0.025, 0.079, 0.174);
uniform vec3 dawn_low : source_color = vec3(0.94, 0.51, 0.28);
uniform vec3 dawn_high : source_color = vec3(0.19, 0.38, 0.63);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.23, 289.41))) * 43758.54);
}

float cloud_noise(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(uv));
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), blend.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), blend.x), blend.y);
}

void sky() {
	float h = max(EYEDIR.y, 0.0);
	vec3 low = mix(night_low, dawn_low, dawn);
	vec3 high = mix(night_high, dawn_high, dawn);
	vec3 color = mix(low, high, smoothstep(0.0, 0.63, h));
	vec3 moon_direction = normalize(vec3(0.49, 0.25, -0.91));
	float moon = dot(EYEDIR, moon_direction);
	float crescent = smoothstep(0.99969, 0.99977, moon);
	crescent *= 1.0 - smoothstep(0.99971, 0.99979,
		dot(EYEDIR, normalize(moon_direction + vec3(-0.012, 0.006, 0.0))));
	vec2 star_uv = EYEDIR.xz / max(EYEDIR.y + 0.49, 0.33) * 125.0;
	float star = step(0.989, hash(floor(star_uv))) * (1.0 - smoothstep(0.0, 0.13,
		length(fract(star_uv) - 0.5))) * smoothstep(0.1, 0.48, h);
	color += (vec3(0.54, 0.77, 1.0) * (crescent * 0.95 + star * 0.36 + pow(max(moon, 0.0), 280.0) * 0.045)) * (1.0 - dawn);
	vec2 clouds = vec2(atan(EYEDIR.x, -EYEDIR.z) * 8.0, EYEDIR.y * 43.0);
	float streaks = cloud_noise(clouds) * 0.62 + cloud_noise(clouds * 2.23) * 0.38;
	float cloud = smoothstep(0.53, 0.73, streaks) * smoothstep(0.04, 0.09, h)
		* (1.0 - smoothstep(0.16, 0.44, h));
	vec3 cloud_light = mix(vec3(0.18, 0.30, 0.51), vec3(0.99, 0.47, 0.32), dawn);
	color = mix(color, cloud_light, cloud * mix(0.25, 0.68, dawn));
	vec3 sun_direction = normalize(vec3(-0.42, 0.185, -0.91));
	float daylight = max(dot(EYEDIR, sun_direction), 0.0);
	color += vec3(1.0, 0.45, 0.14) * dawn * (pow(daylight, 12.0) * 0.18 + smoothstep(0.998, 0.999, daylight) * 3.0);
	COLOR = color;
}
