// Road markings: thermoplastic paint a few millimetres proud of the asphalt, with ragged edges,
// grime, and wear where tyres run over it. Worn-through paint is cut away so the asphalt shows.
// Vertex COLOR is the fresh paint colour; UV.x runs 0..1 across the stripe, UV.y is metres along it.
shader_type spatial;
render_mode cull_back;

#include "res://worlds/city/shaders/road_common.gdshaderinc"

uniform float half_road = 5.5;

varying vec3 wpos;
varying vec3 paint;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	paint = COLOR.rgb;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 off = osg_street_offsets(p);
	float on_ew = (1.0 - step(half_road + 0.1, off.y)) * smoothstep(half_road, half_road + 5.0, off.x);
	float on_ns = (1.0 - step(half_road + 0.1, off.x)) * smoothstep(half_road, half_road + 5.0, off.y);
	float lat = on_ew > on_ns ? off.y : off.x;
	float lane_w = max(on_ew, on_ns);
	float wheel = (exp(-pow((lat - 0.78) / 0.36, 2.0)) + exp(-pow((lat - 2.52) / 0.36, 2.0))) * lane_w;

	// Wear: big soft worn areas, eaten faster in the wheel paths; small flakes everywhere.
	float big = osg_fbm(p * 0.35 + 3.0, 3);
	float flakes = osg_fbm(p * 9.0 + 1.0, 3);
	float wear = big * 0.55 + flakes * 0.45 + wheel * 0.35;
	// Ragged stripe edges.
	float edge = min(UV.x, 1.0 - UV.x);
	float rag = osg_gnoise(p * 23.0) * 0.12 + osg_gnoise(p * 61.0) * 0.06;
	if (edge + rag < 0.0 || wear > 0.83) {
		discard;
	}
	float thin = smoothstep(0.83, 0.72, wear);           // where the paint is thinning, the black shows through
	vec3 col = paint * (0.82 + 0.18 * flakes);
	col = mix(vec3(0.07), col, 0.35 + 0.65 * thin);
	col *= 1.0 - 0.25 * smoothstep(0.4, 0.8, osg_fbm(p * 1.3 + 8.0, 2));   // road grime
	float rough = mix(0.62, 0.48, wheel);

	float pud = osg_puddles(p, wheel * 0.25);
	col *= mix(1.0, 0.82, wetness);
	rough = mix(rough, 0.18, wetness);
	rough = mix(rough, 0.03, pud);

	// Glass beads and the raised edge catch the light a little.
	vec3 n = normalize(vec3(osg_gnoise(p * 140.0) * 0.06, 1.0, osg_gnoise(p * 140.0 + 7.0) * 0.06));
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), pud));
	ALBEDO = col;
	ROUGHNESS = rough;
	NORMAL = osg_view_normal(VIEW_MATRIX, n);
}
