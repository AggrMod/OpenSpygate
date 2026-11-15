// Every opaque surface of a CityBuilding in one material, so a building costs one draw call
// for all its masonry, trim, metalwork and roof. UV is in metres on the face's own plane,
// UV2.x picks the material, UV2.y is a weathering gradient (1 just under a sill), COLOR is the tint.
// Detail is drawn here rather than modelled: brick bond and mortar, stone joints, concrete
// board marks, panel seams. All of it fades to its average colour with distance so it never
// shimmers or shows a repeat.
shader_type spatial;
render_mode cull_back;

instance uniform float lit = 0.0;   // 0 by day, 1 at night: lamps and lit sign boards

varying vec3 local_pos;
varying vec3 local_nrm;
varying float mat_id;
varying float grad;
varying float bld_offset;     // differs per building, so two equal lots never weather alike

const float M_BRICK = 0.0;
const float M_STONE = 1.0;
const float M_TERRACOTTA = 2.0;
const float M_BOARD_CONCRETE = 3.0;
const float M_CONCRETE = 4.0;
const float M_METAL_PANEL = 5.0;
const float M_PAINTED_METAL = 6.0;
const float M_ROOF = 7.0;
const float M_FABRIC = 8.0;
const float M_GRANITE = 9.0;
const float M_GALVANISED = 10.0;
const float M_LAMP = 11.0;
const float M_SMOOTH_STONE = 12.0;
const float M_TILE = 13.0;
const float M_TIMBER = 14.0;
const float M_FASCIA = 15.0;
const float M_LETTER = 16.0;
const float M_LIT_LETTER = 17.0;
const float M_GRATING = 18.0;
const float M_PAVING = 19.0;
const float M_COMMON_BRICK = 20.0;
const float M_GLASS_BLOCK = 21.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + 17.1; a *= 0.5; }
	return s;
}

// A soft joint line: 1 on the joint, 0 on the face. w is the joint width, aa the pixel footprint.
float joint(float x, float period, float w, float aa) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;   // distance to the nearest joint
	return 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, d);
}

// American common bond, modular brick: 203 x 57 mm faces, 10 mm joints, 67 mm courses.
// A header course every sixth course. Returns mortar mask in .x, brick id in .yz.
vec3 brick_pattern(vec2 uv, vec2 aa) {
	float course_h = 0.0677;
	float row = floor(uv.y / course_h);
	bool header = mod(row, 6.0) == 0.0;
	float len = header ? 0.1016 : 0.2032;
	float off = header ? 0.0 : mod(row, 2.0) * 0.1016;
	float x = uv.x + off;
	float col = floor(x / len);
	float fy = fract(uv.y / course_h) * course_h;
	float fx = fract(x / len) * len;
	float mj = 0.0095;
	float bed = 1.0 - smoothstep(mj * 0.5 - aa.y, mj * 0.5 + aa.y, min(fy, course_h - fy));
	float head = 1.0 - smoothstep(mj * 0.5 - aa.x, mj * 0.5 + aa.x, min(fx, len - fx));
	return vec3(max(bed, head), col + (header ? 0.5 : 0.0), row);
}

struct Surf { vec3 albedo; float rough; float metal; float height; float spec; vec3 emit; };

Surf surf_brick(vec2 uv, vec3 tint, vec2 aa, float detail, float far_detail, bool common) {
	Surf s;
	vec3 b = brick_pattern(uv, aa);
	float id = hash12(b.yz + 3.7);
	float id2 = hash12(b.yz * 1.31 + 9.1);
	// per-brick colour: firing variation, a few dark clinkers and pale ones
	vec3 c = tint * (0.82 + 0.34 * id);
	c = mix(c, c * vec3(0.62, 0.55, 0.52), step(0.93, id2));
	c = mix(c, mix(c, vec3(0.62, 0.52, 0.44), 0.35), step(id2, 0.05));
	if (common) { c = mix(c, c * 0.8, noise(uv * 3.0) * 0.5); }
	float face = fbm(uv * 40.0);                                  // sandy face texture
	c *= 0.9 + 0.2 * face;
	vec3 mortar = mix(vec3(0.42, 0.41, 0.38), tint * 1.2, 0.2);
	float m = b.x * detail;
	// far away the mortar blends into the brick, but the brick-to-brick colour lasts longer
	vec3 avg_m = mortar * 0.17;
	vec3 near = mix(c, mortar, m);
	vec3 mid = c * 0.83 + avg_m;
	vec3 far = tint * 0.98 * 0.83 + avg_m;
	s.albedo = mix(far, mix(mid, near, detail), far_detail);
	s.rough = 0.88;
	s.metal = 0.0;
	s.height = (1.0 - b.x) * 0.6 + face * 0.15;
	s.spec = 0.35;
	s.emit = vec3(0.0);
	return s;
}

Surf surf_stone(vec2 uv, vec3 tint, vec2 aa, float detail, float course, float block, bool joints) {
	Surf s;
	float row = floor(uv.y / course);
	float off = mod(row, 2.0) * block * 0.5;
	vec2 cell = vec2(floor((uv.x + off) / block), row);
	float id = hash12(cell + 1.3);
	float j = 0.0;
	if (joints) {
		j = max(joint(uv.y, course, 0.006, aa.y), joint(uv.x + off, block, 0.006, aa.x)) * detail;
	}
	float grain = fbm(uv * vec2(6.0, 9.0)) * 0.6 + fbm(uv * 30.0) * 0.4;
	vec3 c = tint * (0.93 + 0.1 * id) * (0.92 + 0.14 * grain);
	s.albedo = mix(c, tint * 0.72, j);
	s.rough = 0.8;
	s.metal = 0.0;
	s.height = (1.0 - j) * 0.4 + grain * 0.2;
	s.spec = 0.4;
	s.emit = vec3(0.0);
	return s;
}

Surf surf_concrete(vec2 uv, vec3 tint, vec2 aa, float detail, bool boards) {
	Surf s;
	float n = fbm(uv * 2.2);
	float fine = fbm(uv * 25.0);
	vec3 c = tint * (0.86 + 0.22 * n) * (0.94 + 0.12 * fine);
	float h = fine * 0.3;
	if (boards) {
		// 150 mm softwood boards: each board leaves its own tone and grain; tie holes on a 600 mm grid
		float board = floor(uv.y / 0.15);
		float bid = hash12(vec2(board, floor(uv.x / 2.4 + hash12(vec2(board, 2.0)))));
		c *= 0.92 + 0.14 * bid;
		float grain = noise(vec2(uv.x * 1.5, uv.y * 60.0 + bid * 10.0));
		c *= mix(1.0, 0.9 + 0.2 * grain, detail);
		float seam = joint(uv.y, 0.15, 0.004, aa.y) * detail;
		c *= 1.0 - 0.18 * seam;
		vec2 tie = abs(fract(uv / vec2(0.6, 0.6) + 0.5) - 0.5) * 0.6;
		float hole = 1.0 - smoothstep(0.012, 0.018 + aa.x, length(tie));
		c *= 1.0 - 0.5 * hole * detail;
		h = 0.3 * grain + 0.6 * (1.0 - seam) - 0.6 * hole;
	}
	s.albedo = c;
	s.rough = 0.92;
	s.metal = 0.0;
	s.height = h;
	s.spec = 0.35;
	s.emit = vec3(0.0);
	return s;
}

Surf surf_default(vec3 tint, float rough, float metal, float spec) {
	Surf s;
	s.albedo = tint; s.rough = rough; s.metal = metal; s.height = 0.0; s.spec = spec; s.emit = vec3(0.0);
	return s;
}

void vertex() {
	local_pos = VERTEX;
	local_nrm = NORMAL;
	mat_id = UV2.x;
	grad = UV2.y;
	bld_offset = fract(NODE_POSITION_WORLD.x * 0.0137 + NODE_POSITION_WORLD.z * 0.0291) * 97.0;
}

void fragment() {
	vec2 uv = UV;
	vec2 aa = fwidth(uv) * 0.75;
	float px = max(aa.x, aa.y);
	float detail = 1.0 - smoothstep(0.004, 0.012, px);        // joints fade out by ~15 m
	float far_detail = 1.0 - smoothstep(0.02, 0.05, px);      // unit-to-unit colour by ~50 m
	vec3 tint = COLOR.rgb;
	float id = floor(mat_id + 0.5);
	Surf s;
	bool masonry = false;
	if (id == M_BRICK || id == M_COMMON_BRICK) {
		s = surf_brick(uv, tint, aa, detail, far_detail, id == M_COMMON_BRICK);
		masonry = true;
	} else if (id == M_STONE) {
		s = surf_stone(uv, tint, aa, detail, 0.61, 1.22, true);
		masonry = true;
	} else if (id == M_TERRACOTTA) {
		s = surf_stone(uv, tint, aa, detail, 0.42, 0.61, true);
		s.rough = 0.45; s.spec = 0.5;
		masonry = true;
	} else if (id == M_SMOOTH_STONE) {
		s = surf_stone(uv, tint, aa, detail, 10.0, 10.0, false);
		masonry = true;
	} else if (id == M_BOARD_CONCRETE) {
		s = surf_concrete(uv, tint, aa, detail, true);
		masonry = true;
	} else if (id == M_CONCRETE || id == M_PAVING) {
		s = surf_concrete(uv, tint, aa, detail, false);
		if (id == M_PAVING) {
			float j = max(joint(uv.x, 0.6, 0.006, aa.x), joint(uv.y, 0.6, 0.006, aa.y)) * detail;
			s.albedo *= 1.0 - 0.35 * j;
		}
		masonry = true;
	} else if (id == M_METAL_PANEL) {
		float seam = max(joint(uv.x, 1.2, 0.012, aa.x), joint(uv.y, 0.9, 0.012, aa.y)) * detail;
		vec2 cell = floor(uv / vec2(1.2, 0.9));
		float pv = hash12(cell + 5.0);
		s = surf_default(tint * (0.98 + 0.03 * pv) * (1.0 - 0.6 * seam), 0.36 + 0.06 * pv, 0.75, 0.5);
		s.height = 1.0 - seam;
	} else if (id == M_PAINTED_METAL) {
		float n = fbm(uv * 8.0);
		s = surf_default(tint * (0.92 + 0.12 * n), 0.42 + 0.2 * n, 0.15, 0.5);
	} else if (id == M_GALVANISED) {
		float n = fbm(uv * 5.0);
		float rib = joint(uv.x, 0.08, 0.02, aa.x) * detail;
		s = surf_default(tint * (0.85 + 0.25 * n) * (1.0 - 0.15 * rib), 0.45 + 0.25 * n, 0.85, 0.5);
		s.height = rib;
	} else if (id == M_ROOF) {
		// membrane laid in 1 m rolls with lapped seams, patched here and there, ponding stains
		float n = fbm(uv * 1.5);
		float grav = noise(uv * 90.0);
		float seam = joint(uv.y, 1.0, 0.03, aa.y) * detail;
		float patch = smoothstep(0.62, 0.64, fbm(uv * vec2(0.35, 0.6) + 21.0)) * step(0.3, fract(uv.x / 3.1 + hash12(vec2(floor(uv.y), 1.0))));
		float pond = smoothstep(0.55, 0.7, fbm(uv * 0.25 + 9.0));
		vec3 c = tint * (0.78 + 0.34 * n) * (0.88 + 0.24 * grav * detail);
		c = mix(c, c * 0.82, patch);
		c = mix(c, c * 0.7, pond * 0.6);
		c *= 1.0 - 0.15 * seam;
		s = surf_default(c, mix(0.95, 0.6, pond * 0.5), 0.0, 0.3);
		s.height = grav * 0.5 + seam;
	} else if (id == M_FABRIC) {
		// woven canvas, striped when the tint's alpha asks for it
		float weave = noise(uv * 300.0) * detail;
		float stripe = step(0.5, fract(uv.x / 0.3));
		vec3 c = mix(tint, vec3(0.86, 0.84, 0.78), stripe * step(0.5, COLOR.a));
		s = surf_default(c * (0.92 + 0.12 * weave), 0.9, 0.0, 0.3);
	} else if (id == M_GRANITE) {
		float n = noise(uv * 120.0);
		float m = noise(uv * 31.0);
		vec3 c = tint * (0.7 + 0.6 * n * m);
		c = mix(c, vec3(0.8, 0.78, 0.74), step(0.86, n) * 0.6 * detail);
		s = surf_default(c, 0.12, 0.0, 0.6);
	} else if (id == M_TILE) {
		float j = max(joint(uv.x, 0.1, 0.004, aa.x), joint(uv.y, 0.1, 0.004, aa.y)) * detail;
		vec2 cell = floor(uv / 0.1);
		float h = hash12(cell);
		vec3 c = mix(tint, vec3(0.12, 0.12, 0.13), step(0.8, h) * 0.8);
		s = surf_default(mix(c, vec3(0.5, 0.49, 0.46), j), mix(0.2, 0.8, j), 0.0, 0.5);
		s.height = 1.0 - j;
	} else if (id == M_TIMBER) {
		float stave = joint(uv.x, 0.14, 0.008, aa.x) * detail;
		float g = noise(vec2(uv.x * 7.0, uv.y * 0.8));
		s = surf_default(tint * (0.75 + 0.4 * g) * (1.0 - 0.4 * stave), 0.85, 0.0, 0.3);
		s.height = 1.0 - stave;
	} else if (id == M_FASCIA) {
		float n = fbm(uv * 4.0);
		s = surf_default(tint * (0.95 + 0.07 * n), 0.35, 0.0, 0.5);
		// lit by the gooseneck lamps above it at night: a pool on each board, brighter at the top
		float pool = 0.35 + 0.65 * grad;
		s.emit = s.albedo * lit * pool * 0.9;
	} else if (id == M_LETTER) {
		s = surf_default(tint, 0.35, 0.3, 0.5);
		s.emit = tint * lit * 0.6;
	} else if (id == M_LIT_LETTER) {
		s = surf_default(tint, 0.3, 0.0, 0.5);
		s.emit = tint * (0.15 + lit * 4.5);
	} else if (id == M_LAMP) {
		s = surf_default(vec3(0.85), 0.2, 0.0, 0.5);
		s.emit = tint * lit * 9.0;
	} else if (id == M_GRATING) {
		float slot = joint(uv.x, 0.03, 0.012, aa.x) * detail;
		s = surf_default(tint * (1.0 - 0.7 * slot), 0.5, 0.2, 0.5);
	} else if (id == M_GLASS_BLOCK) {
		float j = max(joint(uv.x, 0.2, 0.012, aa.x), joint(uv.y, 0.2, 0.012, aa.y));
		s = surf_default(mix(tint, vec3(0.55), j), 0.15, 0.0, 0.6);
		s.emit = tint * lit * 0.5 * (1.0 - j);
	} else {
		s = surf_default(tint, 0.6, 0.0, 0.5);
	}

	// Weathering, all in building space so neighbours never share it.
	if (masonry) {
		vec2 wp = vec2(local_pos.x + local_pos.z + bld_offset, local_pos.y);
		float big = fbm(wp * vec2(0.09, 0.05) + bld_offset);
		s.albedo *= 0.8 + 0.34 * big;                                    // uneven soot and wash
		// long rain-wash streaks down the whole face, some darker, some cleaner
		float wash = noise(vec2(wp.x * 1.3, wp.y * 0.06)) - 0.5;
		s.albedo *= 1.0 + 0.16 * wash * far_detail + 0.08 * wash;
		// dirt streaks running down from each sill, stronger under some windows than others
		float which = hash12(vec2(floor(uv.x / 1.1), floor(uv.y / 3.0)));
		float streak = noise(vec2(uv.x * 7.0, uv.y * 0.5)) * noise(vec2(uv.x * 19.0, 3.0 + which * 9.0));
		s.albedo *= 1.0 - clamp(pow(grad, 1.5 + which * 2.0) * streak * (0.4 + 1.1 * which), 0.0, 0.4);
		// grime splashed up at the foot of the wall
		float foot = 1.0 - smoothstep(0.1, 1.3 + 0.5 * noise(uv * 0.8), local_pos.y);
		s.albedo *= 1.0 - 0.4 * foot;
		// lighter repairs: patches of newer brick or repointing
		float patch = smoothstep(0.72, 0.76, fbm(uv * 0.35 + 41.0));
		s.albedo = mix(s.albedo, s.albedo * vec3(1.12, 1.08, 1.04), patch * 0.8);
		s.rough = min(1.0, s.rough + foot * 0.05);
	}

	// Height to normal: one-sided differences through the screen derivatives, in tangent space.
	float hscale = masonry ? 0.012 : 0.006;
	vec2 dh = vec2(dFdx(s.height), dFdy(s.height));
	vec2 duvx = dFdx(uv);
	vec2 duvy = dFdy(uv);
	float det = duvx.x * duvy.y - duvx.y * duvy.x;
	if (abs(det) > 1e-12 && detail > 0.01) {
		vec2 g = vec2(dh.x * duvy.y - dh.y * duvx.y, dh.y * duvx.x - dh.x * duvy.x) / det;   // dh/du, dh/dv
		g = clamp(g * hscale, vec2(-1.0), vec2(1.0)) * detail;
		NORMAL = normalize(NORMAL - g.x * TANGENT - g.y * BINORMAL);
	}
	ALBEDO = s.albedo;
	ROUGHNESS = s.rough;
	METALLIC = s.metal;
	SPECULAR = s.spec;
	EMISSION = s.emit;
}
