// Aged city asphalt: aggregate, repair patches, cracks and sealed joints, tyre polish, oil drips,
// gutter grime, and standing water in the low spots when it has rained. All in world space.
shader_type spatial;
render_mode cull_back;

#include "res://worlds/city/shaders/road_common.gdshaderinc"

uniform float half_road = 5.5;          // kerb line, metres from a street's centre line
uniform float lane = 3.3;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box_sdf(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Repair patches: rectangles cut out and refilled, aligned with the street. x = distance (negative inside), y = age 0..1.
vec2 repair_patch(vec2 p) {
	float cell = 11.0;
	vec2 c = floor(p / cell);
	float best = 100.0;
	float age = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = c + vec2(float(x), float(y));
			vec2 h = osg_hash2(id + vec2(311.0, 71.0));
			if (h.x > 0.30) {
				continue;
			}
			vec2 h2 = osg_hash2(id + vec2(13.0, 977.0));
			vec2 h3 = osg_hash2(id + vec2(541.0, 233.0));
			vec2 centre = (id + 0.15 + 0.7 * h2) * cell;
			vec2 size = vec2(0.45 + 3.2 * h3.x * h3.x, 0.4 + 1.1 * h3.y);
			if (h.y > 0.5) {
				size = size.yx;
			}
			float d = box_sdf(p - centre, size);
			if (d < best) {
				best = d;
				age = h2.y;
			}
		}
	}
	return vec2(best, age);
}

// Thin line of width w (metres) along the zero set of 'd', anti-aliased and faded when smaller than a pixel.
float thin_line(float d, float w) {
	float aa = max(fwidth(d), 1e-4);
	return clamp((w - abs(d)) / aa + 0.5, 0.0, 1.0) * clamp(w * 2.0 / aa, 0.0, 1.0);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 off = osg_street_offsets(p);
	float ax = off.x;
	float az = off.y;
	float px = max(length(fwidth(p)), 1e-4);          // metres per pixel, for fading fine detail

	// Where are we: on an east-west street, a north-south street, or in a junction.
	float on_ew = (1.0 - step(half_road + 0.1, az)) * smoothstep(half_road, half_road + 5.0, ax);
	float on_ns = (1.0 - step(half_road + 0.1, ax)) * smoothstep(half_road, half_road + 5.0, az);
	float lat = on_ew > on_ns ? az : ax;                 // metres from the street's centre line
	float along = on_ew > on_ns ? p.x : p.y;
	float lane_w = max(on_ew, on_ns);
	float kerb_d = 99.0;
	if (ax > half_road) { kerb_d = min(kerb_d, half_road - az); }
	if (az > half_road) { kerb_d = min(kerb_d, half_road - ax); }
	kerb_d = max(kerb_d, 0.0);

	// Base: aged grey binder with large soft tonal drift.
	vec2 warp = vec2(osg_gnoise(p * 0.07), osg_gnoise(p * 0.07 + 9.7)) * 6.0;
	float drift = osg_fbm((p + warp) * 0.045, 4);
	float mottling = osg_fbm(p * 0.6 + 3.3, 3);
	vec3 col = mix(vec3(0.085, 0.084, 0.082), vec3(0.15, 0.148, 0.142), drift);
	col *= 0.9 + 0.2 * mottling;

	// Aggregate: light stones in the dark binder, faded out where a pixel is bigger than a stone.
	float fine_fade = 1.0 - smoothstep(0.012, 0.04, px);
	float stones = 0.0;
	if (fine_fade > 0.0) {
		float s1 = osg_gnoise(p * 38.0);
		float s2 = osg_gnoise(p * 83.0 + 4.1);
		stones = smoothstep(0.18, 0.42, s1 * 0.65 + s2 * 0.45) * fine_fade;
		col = mix(col, col * 2.1 + vec3(0.04), stones * 0.6);
		col *= 1.0 - 0.18 * smoothstep(0.1, 0.4, -s2) * fine_fade;   // pits between stones
	}

	// Tyre polish along the wheel paths, and the oil-drip strip down the middle of each lane.
	float wander = osg_gnoise(vec2(along * 0.035, lat)) * 0.25;
	float l = lat + wander;
	float wheel = exp(-pow((l - 0.78) / 0.32, 2.0)) + exp(-pow((l - 2.52) / 0.32, 2.0));
	wheel *= lane_w;
	float drip = exp(-pow((l - 1.65) / 0.28, 2.0)) * lane_w;
	float drip_spots = smoothstep(0.55, 0.85, osg_fbm(p * vec2(1.6, 1.6) + 21.0, 3));
	col *= 1.0 - 0.16 * wheel;
	col = mix(col, vec3(0.035, 0.033, 0.03), drip * (0.25 + 0.5 * drip_spots));
	// Parking lanes: oil stains where cars stand.
	float park = smoothstep(lane - 0.1, lane + 0.2, lat) * lane_w;
	float stain = smoothstep(0.62, 0.8, osg_fbm(p * 0.9 + 77.0, 3)) * park;
	col = mix(col, vec3(0.03, 0.028, 0.026), stain * 0.6);

	// Gutter grime: grit, leaves and dust washed against the kerb.
	float gutter = (1.0 - smoothstep(0.0, 0.55, kerb_d)) * smoothstep(0.0, 0.05, kerb_d);
	float grit = osg_fbm(p * 2.3 + 5.0, 3);
	col = mix(col, vec3(0.16, 0.145, 0.12) * (0.7 + 0.5 * grit), gutter * 0.55);

	// Repair patches: darker, smoother fill with a sealed edge.
	vec2 rp = repair_patch(p);
	float in_patch = 1.0 - smoothstep(-0.01, 0.01, rp.x);
	vec3 patch_col = mix(vec3(0.045, 0.045, 0.044), vec3(0.11, 0.108, 0.104), rp.y);
	patch_col *= 0.92 + 0.16 * osg_fbm(p * 3.0 + 40.0, 2);
	col = mix(col, patch_col, in_patch);
	float patch_edge = thin_line(rp.x, 0.035);
	col = mix(col, vec3(0.025), patch_edge * 0.85);

	// Cracks: a network in tired zones, a seam along the paving joint, some sealed with glossy tar.
	vec2 q = p * 0.62 + vec2(osg_gnoise(p * 1.1), osg_gnoise(p * 1.1 + 3.1)) * 0.28;
	vec2 v = osg_voronoi(q);
	float tired = smoothstep(0.66, 0.8, osg_fbm(p * 0.04 + 11.0, 3) + wheel * 0.08) * (1.0 - in_patch);
	float crack = thin_line(v.y - v.x, 0.006) * tired;
	float seam_d = (lat - lane) + osg_gnoise(vec2(along * 0.4, 1.7)) * 0.03 + osg_gnoise(vec2(along * 3.0, 4.2)) * 0.006;
	float seam = thin_line(seam_d, 0.006) * lane_w;
	float sealed_zone = smoothstep(0.55, 0.62, osg_fbm(p * 0.03 + 61.0, 2));
	float tar = thin_line(seam_d, 0.035) * lane_w * sealed_zone;
	tar = max(tar, thin_line(v.y - v.x, 0.02) * tired * sealed_zone);
	col = mix(col, col * 0.35, max(crack, seam) * 0.8);
	col = mix(col, vec3(0.022), tar * 0.85);

	float rough = mix(0.88, 0.80, drift);
	rough -= 0.20 * wheel;
	rough = mix(rough, 0.72, in_patch);
	rough = mix(rough, 0.45, tar);
	rough = mix(rough, 0.62, drip * drip_spots);

	// Height for the normal: stones stand proud, cracks are sunk.
	vec3 n = vec3(0.0, 1.0, 0.0);
	if (fine_fade > 0.0) {
		float e = 0.004;
		float h0 = osg_gnoise(p * 38.0) * 0.65 + osg_gnoise(p * 83.0 + 4.1) * 0.45;
		float hx = osg_gnoise((p + vec2(e, 0.0)) * 38.0) * 0.65 + osg_gnoise((p + vec2(e, 0.0)) * 83.0 + 4.1) * 0.45;
		float hz = osg_gnoise((p + vec2(0.0, e)) * 38.0) * 0.65 + osg_gnoise((p + vec2(0.0, e)) * 83.0 + 4.1) * 0.45;
		float k = 0.0018 * fine_fade * (1.0 - 0.6 * in_patch) * (1.0 - 0.5 * wheel);
		n = normalize(vec3(-(hx - h0) / e * k, 1.0, -(hz - h0) / e * k));
	}

	// Rain: the porous surface darkens and turns glossy; water stands in gutters, ruts and patch edges.
	float low = gutter * 0.9 + wheel * 0.25 + patch_edge * 0.3 + (1.0 - drift) * 0.25;
	float pud = osg_puddles(p, low);
	float damp = wetness * (1.0 - 0.25 * stones);
	col *= mix(1.0, 0.58, damp);
	rough = mix(rough, 0.2, damp);
	col *= mix(1.0, 0.72, pud);
	rough = mix(rough, 0.02, pud);
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), max(pud, damp * 0.5)));

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	SPECULAR = mix(0.5, 0.35, pud);
	NORMAL = osg_view_normal(VIEW_MATRIX, n);
}
