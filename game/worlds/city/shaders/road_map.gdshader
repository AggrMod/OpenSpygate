// The transit map in a bus shelter: a pale street grid with the river, three coloured routes and stop dots,
// behind glass, lit from behind after dark. Drawn from the panel's local position (it is 1.0 x 1.6 m).
shader_type spatial;

uniform float backlight = 0.0;

varying vec3 lpos;

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.6, w, abs(d));
}

void fragment() {
	// the panel's faces are in local y/z; use whichever face we are on
	vec2 p = vec2(lpos.z / 1.0 + 0.5, (lpos.y - 0.55) / 1.6);
	vec3 col = vec3(0.86, 0.87, 0.84);
	// street grid
	float grid = max(line(fract(p.x * 9.0) - 0.5, 0.06), line(fract(p.y * 13.0) - 0.5, 0.06));
	col = mix(col, vec3(0.74, 0.75, 0.72), grid);
	// the river along one side
	float river = p.x - (0.18 + 0.05 * sin(p.y * 7.0));
	col = mix(col, vec3(0.55, 0.68, 0.78), step(river, 0.0));
	// routes
	col = mix(col, vec3(0.8, 0.15, 0.1), line(p.y - 0.42 - 0.08 * step(0.6, p.x), 0.012) * step(0.18, p.x));
	col = mix(col, vec3(0.1, 0.35, 0.75), line(p.x - 0.55, 0.012));
	col = mix(col, vec3(0.1, 0.55, 0.25), line(p.x + p.y - 1.05, 0.012) * step(0.2, p.x));
	// stops
	vec2 sc = fract(p * vec2(9.0, 13.0)) - 0.5;
	col = mix(col, vec3(0.1), step(length(sc * vec2(1.0, 13.0 / 9.0)), 0.06) * step(0.5, line(p.x - 0.55, 0.02)));
	// header band
	col = mix(col, vec3(0.05, 0.25, 0.15), step(0.9, p.y));
	ALBEDO = col * 0.35;
	ROUGHNESS = 0.08;
	EMISSION = col * backlight * 1.1;
}

void vertex() {
	lpos = VERTEX;
}
