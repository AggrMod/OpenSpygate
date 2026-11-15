// Street-tree foliage: each card carries a dense spray of small leaves drawn here (no texture), scattered on
// a jittered grid, cut out with alpha scissor, lit through from behind, tinted per tree, moving in the wind.
// UV is 0..1 across the card (about 1.2 m), UV2.x is a random number per card.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 leaf_dark : source_color = vec3(0.075, 0.13, 0.04);
uniform vec3 leaf_light : source_color = vec3(0.22, 0.32, 0.09);
uniform float wind = 1.0;
uniform float cells = 7.0;

varying float tree_tint;
varying float card_rnd;

uint lpcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

vec3 lhash(vec2 c, float s) {
	ivec2 i = ivec2(c);
	uint h = lpcg(uint(i.x) + lpcg(uint(i.y) + uint(s * 65535.0)));
	uint h2 = lpcg(h);
	uint h3 = lpcg(h2);
	return vec3(float(h & 0xffffu), float(h2 & 0xffffu), float(h3 & 0xffffu)) / 65535.0;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_tint = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	card_rnd = UV2.x;
	float h = max(VERTEX.y - 2.5, 0.0);
	float t = TIME * 1.1 + origin.x * 0.21 + origin.z * 0.17;
	vec3 sway = vec3(sin(t), 0.0, cos(t * 0.8)) * 0.015 * h * wind;
	vec3 flutter = vec3(sin(TIME * 7.0 + VERTEX.y * 9.0 + card_rnd * 40.0), sin(TIME * 6.0 + VERTEX.x * 11.0), cos(TIME * 7.5 + VERTEX.z * 10.0)) * 0.01 * wind;
	VERTEX += sway + flutter;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// the spray thins out toward the card's edge so cards do not show as squares
	float edge = length(uv);
	vec2 g = UV * cells;
	float mask = 0.0;
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = floor(g) + vec2(float(x), float(y));
			vec3 h = lhash(cell, card_rnd);
			vec2 cc = (cell + 0.5) / cells * 2.0 - 1.0;
			if (h.z < 0.18 + 0.75 * smoothstep(0.55, 1.0, length(cc))) {
				continue;
			}
			vec2 c = cell + 0.5 + (h.xy - 0.5) * 0.7;
			float a = h.x * 6.2831 + h.y * 2.0;
			vec2 dir = vec2(cos(a), sin(a));
			float len = 0.95 + 0.4 * h.y;
			vec2 q = g - c + dir * len * 0.5;
			vec2 lp = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) / len;
			if (lp.x > 0.0 && lp.x < 1.0) {
				float w = 0.3 * pow(sin(3.14159 * pow(lp.x, 0.8)), 0.8);
				if (abs(lp.y) < w) {
					mask = 1.0;
					shade = h.z + 0.25 * lp.x - 0.3 * step(abs(lp.y), 0.025);
				}
			}
		}
	}
	if (mask < 0.5 || edge > 1.05) {
		discard;
	}
	vec3 col = mix(leaf_dark, leaf_light, clamp(shade * 0.65 + tree_tint * 0.3, 0.0, 1.0));
	col *= 0.85 + 0.3 * tree_tint;
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = col * 0.8;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
