shader_type sky;

uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_direction;
uniform vec3 sun_direction;
uniform vec3 night_low : source_color = vec3(0.085, 0.202, 0.382);
uniform vec3 night_high : source_color = vec3(0.018, 0.061, 0.17);
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

// Tile around the azimuth, with unfiltered interpolation for angular peaks.
float ridge_noise(float angle, float count, float seed) {
	float t=angle*count;
	float i=floor(t);
	return mix(hash(vec2(mod(i,count),seed)),hash(vec2(mod(i+1.,count),seed)),fract(t));
}

float ridge_line(float angle,float layer) {
	return .018+layer*.031
		+ridge_noise(angle,28.,layer+19.)*.091
		+ridge_noise(angle,71.,layer+52.)*.046
		+ridge_noise(angle,182.,layer+83.)*.017;
}

void sky() {
	float h = max(EYEDIR.y, 0.0);
	vec3 low = mix(night_low, dawn_low, dawn);
	vec3 high = mix(night_high, dawn_high, dawn);
	vec3 color = mix(low, high, smoothstep(0.0, 0.63, h));
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
	vec3 cloud_light = mix(vec3(0.057, 0.123, 0.216), vec3(0.99, 0.47, 0.32), dawn);
	color = mix(color, cloud_light, cloud * mix(0.25, 0.68, dawn));
	float daylight = max(dot(EYEDIR, sun_direction), 0.0);
	color += vec3(1.0, 0.45, 0.14) * dawn * (pow(daylight, 12.0) * 0.18 + smoothstep(0.998, 0.999, daylight) * 3.0);
	// Infinite sky silhouettes preserve every playable terrain sightline.
	float angle=atan(EYEDIR.z,EYEDIR.x)/6.2831853+.5;
	for(int i=2;i>=0;i--){
		float layer=float(i);
		float profile=ridge_line(angle,layer);
		float edge=1.-smoothstep(profile-.0007,profile+.0007,EYEDIR.y);
		float depth=profile-EYEDIR.y;
		float left=ridge_line(angle-.0015,layer);
		float slope=clamp(.48+(profile-left)*36.,.06,.94);
		float fold=ridge_noise(angle+depth*.076,147.,layer+5.);
		float snow=smoothstep(.0,.65,slope)*(1.-smoothstep(.003,.045,max(0.,depth)+(fold-.45)*.072));
		vec3 dark=mix(vec3(.012,.040,.070),vec3(.020,.064,.135),layer*.48);
		vec3 lit=mix(vec3(.027,.073,.102),vec3(.051,.124,.228),layer*.48);
		vec3 ridge=mix(dark,lit,clamp(slope*.74+step(.56,fold)*.22,0.,1.));
		ridge=mix(ridge,vec3(.076,.179,.32),snow*layer*.27);
		ridge=mix(ridge,ridge*vec3(1.66,1.25,1.11)+vec3(.10,.055,.032),dawn*.75);
		color=mix(color,ridge,edge);
	}
	COLOR = color;
}
