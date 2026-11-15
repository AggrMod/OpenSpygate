// Shared noise and street geometry for the city's ground shaders.
// Everything is in world space (metres), so nothing tiles and nothing shows a grid.

uniform float pitch_x = 108.0;      // distance between north-south street centre lines
uniform float pitch_z = 78.0;       // distance between east-west street centre lines
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

uint osg_pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// Hash of an integer cell: two values in 0..1.
vec2 osg_hash2(vec2 cell) {
	ivec2 i = ivec2(cell);
	uint h = osg_pcg(uint(i.x) + osg_pcg(uint(i.y) + 1013u));
	uint h2 = osg_pcg(h ^ 0x9e3779b9u);
	return vec2(float(h & 0xffffu), float(h2 & 0xffffu)) / 65535.0;
}

float osg_hash1(vec2 cell) {
	return osg_hash2(cell).x;
}

// Gradient noise with a quintic fade: smooth, no blocky value-noise steps. Roughly -0.7..0.7.
float osg_gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 ga = osg_hash2(i) * 2.0 - 1.0;
	vec2 gb = osg_hash2(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
	vec2 gc = osg_hash2(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
	vec2 gd = osg_hash2(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
	float a = dot(ga, f);
	float b = dot(gb, f - vec2(1.0, 0.0));
	float c = dot(gc, f - vec2(0.0, 1.0));
	float d = dot(gd, f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal gradient noise, each octave rotated so no axis lines up. Roughly 0..1.
float osg_fbm(vec2 p, int octaves) {
	float s = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < octaves; i++) {
		s += a * osg_gnoise(p);
		p = rot * p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s * 0.85 + 0.5;
}

// Cellular noise: distance to the nearest and second-nearest feature point.
vec2 osg_voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + osg_hash2(i + g) - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return vec2(sqrt(d1), sqrt(d2));
}

// Distance from the nearest north-south (x) and east-west (y) street centre lines.
vec2 osg_street_offsets(vec2 p) {
	return vec2(abs(p.x - round(p.x / pitch_x) * pitch_x), abs(p.y - round(p.y / pitch_z) * pitch_z));
}

// Puddle mask for a given wetness: water collects first where 'low' is high (0..1).
float osg_puddles(vec2 p, float low) {
	if (wetness <= 0.001) {
		return 0.0;
	}
	vec2 q = p + vec2(osg_gnoise(p * 0.11), osg_gnoise(p * 0.11 + 5.2)) * 3.0;
	float n = osg_fbm(q * 0.23, 4);
	float level = n + low * 0.4;
	float threshold = mix(1.35, 0.56, wetness);
	return smoothstep(threshold, threshold + 0.035, level);
}

// Turn a world-space normal into the view-space NORMAL the renderer wants.
vec3 osg_view_normal(mat4 view, vec3 n_world) {
	return normalize((view * vec4(n_world, 0.0)).xyz);
}
