// Calder's sky: a scattering gradient with a sun glow, sun and moon discs, stars, and two moving cloud layers
// (low broken cumulus and high streaky cirrus). Colours and energies come from CitySky, keyed on the sun.
// Below the horizon there is nothing: the world has not been built there.
shader_type sky;
render_mode use_debanding;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 zenith_col = vec3(0.10, 0.22, 0.55);
uniform vec3 horizon_col = vec3(0.55, 0.62, 0.72);
uniform vec3 sun_col = vec3(1.0, 0.95, 0.9);
uniform float sun_disc = 60.0;
uniform float glow = 1.0;
uniform float night = 0.0;
uniform vec3 city_glow = vec3(0.007, 0.0062, 0.0058);
uniform float stars = 0.0;
uniform float moon_bright = 0.0;
uniform float cloud_cover = 0.42;
uniform vec3 cloud_lit = vec3(1.0, 0.97, 0.92);
uniform vec3 cloud_shade = vec3(0.40, 0.44, 0.50);
uniform float cloud_speed = 1.0;

uint sky_pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

vec2 sky_hash2(vec2 c) {
	ivec2 i = ivec2(c);
	uint h = sky_pcg(uint(i.x) + sky_pcg(uint(i.y) + 1013u));
	uint h2 = sky_pcg(h ^ 0x9e3779b9u);
	return vec2(float(h & 0xffffu), float(h2 & 0xffffu)) / 65535.0;
}

float sky_hash3(vec3 c) {
	ivec3 i = ivec3(c);
	uint h = sky_pcg(uint(i.x) + sky_pcg(uint(i.y) + sky_pcg(uint(i.z) + 77u)));
	return float(h & 0xffffu) / 65535.0;
}

float sky_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(sky_hash2(i) * 2.0 - 1.0, f);
	float b = dot(sky_hash2(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
	float c = dot(sky_hash2(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
	float d = dot(sky_hash2(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float sky_fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		s += a * sky_noise(p);
		p = rot * p * 2.07 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return s * 0.9 + 0.5;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float up = max(h, 0.0);
	float mu = dot(d, sun_dir);
	float mu_m = dot(d, moon_dir);

	// Scattering gradient: horizon to zenith, warmer and brighter toward the sun.
	vec3 col = mix(horizon_col, zenith_col, 1.0 - exp(-up * 6.5));
	float toward_sun = max(mu, 0.0);
	float horizon_band = exp(-up * 9.0);
	col += sun_col * (pow(toward_sun, 5.0) * 0.30 + pow(toward_sun, 48.0) * 0.55) * glow * (0.35 + 0.65 * horizon_band);
	col += sun_col * horizon_band * pow(toward_sun * 0.5 + 0.5, 3.0) * 0.12 * glow;
	// City glow: the town lights up the haze near the horizon at night.
	col += city_glow * (exp(-up * 7.0) * 1.0 + 0.15) * night;

	// Stars and moon, only once the sky is dark enough.
	if (!AT_CUBEMAP_PASS && stars > 0.001 && h > 0.0) {
		vec3 sp = d * 260.0;
		vec3 cell = floor(sp);
		float hs = sky_hash3(cell);
		if (hs > 0.9965) {
			vec3 pos = cell + 0.5 + (vec3(sky_hash3(cell + 11.0), sky_hash3(cell + 23.0), sky_hash3(cell + 37.0)) - 0.5) * 0.6;
			float dist = length(sp - pos);
			float mag = pow((hs - 0.9965) / 0.0035, 3.0);
			float twinkle = 0.75 + 0.25 * sin(TIME * (2.0 + hs * 9.0) + hs * 100.0);
			vec3 tint = mix(vec3(0.8, 0.88, 1.0), vec3(1.0, 0.86, 0.7), sky_hash3(cell + 5.0));
			col += tint * exp(-dist * dist * 22.0) * (0.25 + 2.5 * mag) * twinkle * stars * smoothstep(0.0, 0.25, h);
		}
	}
	if (moon_bright > 0.001) {
		float moon_r = 0.0098;
		float md = acos(clamp(mu_m, -1.0, 1.0));
		if (md < moon_r * 1.2) {
			// a gibbous moon with darker seas, lit from the side away from the sun
			vec3 right = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
			vec3 upm = cross(right, moon_dir);
			vec2 mp = vec2(dot(d, right), dot(d, upm)) / moon_r;
			float disc = smoothstep(1.02, 0.96, length(mp));
			float z = sqrt(max(1.0 - dot(mp, mp), 0.0));
			vec3 sn = vec3(mp, z);
			float lit = smoothstep(-0.15, 0.25, dot(sn, normalize(vec3(-0.75, 0.25, 0.6))));
			float seas = smoothstep(0.45, 0.65, sky_fbm(mp * 2.2 + 3.0, 4));
			vec3 mc = vec3(1.0, 0.97, 0.9) * (1.0 - 0.32 * seas) * lit + vec3(0.02, 0.025, 0.035);
			col = mix(col, mc * moon_bright, disc);
		}
		col += vec3(0.6, 0.65, 0.75) * pow(max(mu_m, 0.0), 300.0) * moon_bright * 0.06;
	}

	// The sun's disc, bright enough to bloom.
	col += sun_col * sun_disc * smoothstep(0.99993, 0.99997, mu);

	// Clouds on two layers, moving with the wind.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.10);
		vec2 wind = vec2(TIME * 0.0016, TIME * 0.0006) * cloud_speed;
		int oct = AT_CUBEMAP_PASS ? 3 : 6;
		vec2 cuv = uv * 0.9 + wind;
		vec2 warp = vec2(sky_noise(cuv * 0.5), sky_noise(cuv * 0.5 + 7.0)) * 0.5;
		float base = sky_fbm(cuv + warp, oct);
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, base);
		float toward = sky_fbm(cuv + warp + sun_dir.xz * 0.06, AT_CUBEMAP_PASS ? 2 : 4);
		float lit = clamp(0.55 + (base - toward) * 4.0, 0.0, 1.0);
		vec3 ccol = mix(cloud_shade, cloud_lit, lit);
		// thin edges glow when the sun is behind them
		ccol += sun_col * pow(toward_sun, 10.0) * (1.0 - cov) * 1.6 * glow;
		ccol += city_glow * night * 1.6;
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, ccol, cov * fade * 0.96);
		// cirrus streaks, high and slow
		vec2 ruv = uv * vec2(0.25, 1.4) + wind * 0.6 + 40.0;
		float ci = sky_fbm(ruv, AT_CUBEMAP_PASS ? 2 : 5);
		float ccov = smoothstep(0.58, 0.85, ci) * 0.45 * (1.0 - cov);
		col = mix(col, cloud_lit * 0.95 + sun_col * pow(toward_sun, 6.0) * 0.4, ccov * fade);
	}

	// Below the horizon there is void.
	col *= smoothstep(-0.035, 0.004, h);
	COLOR = col;
}
