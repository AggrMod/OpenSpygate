// Pedestrian signal lens: the raised hand (orange, left) and the walking person (white, right), drawn as
// shapes made of discs and capsules on a grid of LEDs. 'walk' and 'hand' switch them on (0 or 1).
shader_type spatial;

uniform float walk = 0.0;
uniform float hand = 0.0;
uniform float energy = 7.0;

float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float rbox(vec2 p, vec2 c, vec2 b, float r) {
	vec2 d = abs(p - c) - b + r;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV;
	// hand: palm, four fingers and a thumb
	float h = rbox(p, vec2(0.25, 0.58), vec2(0.11, 0.12), 0.03);
	for (int i = 0; i < 4; i++) {
		float x = 0.165 + float(i) * 0.057;
		float top = 0.25 + abs(float(i) - 1.5) * 0.03;
		h = min(h, capsule(p, vec2(x, 0.50), vec2(x, top), 0.024));
	}
	h = min(h, capsule(p, vec2(0.15, 0.62), vec2(0.085, 0.47), 0.026));
	// walking person
	float m = length(p - vec2(0.75, 0.22)) - 0.048;
	m = min(m, capsule(p, vec2(0.75, 0.32), vec2(0.735, 0.52), 0.042));
	m = min(m, capsule(p, vec2(0.735, 0.52), vec2(0.67, 0.78), 0.03));
	m = min(m, capsule(p, vec2(0.735, 0.52), vec2(0.81, 0.77), 0.03));
	m = min(m, capsule(p, vec2(0.75, 0.34), vec2(0.67, 0.47), 0.025));
	m = min(m, capsule(p, vec2(0.75, 0.34), vec2(0.83, 0.45), 0.025));
	// LED grid
	vec2 g = fract(p * 48.0) - 0.5;
	float led = smoothstep(0.5, 0.25, length(g));
	float in_h = step(h, 0.0) * step(p.x, 0.5);
	float in_m = step(m, 0.0) * step(0.5, p.x);
	vec3 orange = vec3(1.0, 0.42, 0.04);
	vec3 white = vec3(0.85, 0.92, 1.0);
	vec3 col = vec3(0.012) + orange * in_h * 0.05 + white * in_m * 0.04;
	ALBEDO = col;
	ROUGHNESS = 0.2;
	EMISSION = (orange * in_h * hand + white * in_m * walk) * led * energy;
}
