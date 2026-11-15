// Window glass with a room behind it (interior mapping). Each pane traces the view ray into a
// box room of its own: back wall, side walls, floor and a ceiling with its light fitting, one
// cut-out of furniture part way in, and blinds or curtains on the glass. Nothing is modelled;
// the room is worked out per pixel from the pane's data:
//   UV       position on the pane in metres (0..w, 0..h)
//   UV2      pane size w, h in metres
//   CUSTOM0  x window seed, y room depth, z kind, w sill (pane bottom above the room floor)
//   CUSTOM1  x storey height, y room margin left of the pane, z room margin right of it,
//            w group seed (shared by the windows of one flat, office floor or shop, so they
//            light together and one shop's panes look into the same room)
//   COLOR.r  share of homes and offices lit at night
//   COLOR.g  strength of a modern solar coating: darker, greener, more mirror-like
//   COLOR.b  shop kind / 4: 0 goods on shelves, 1 food and drink, 2 services, 3 clothing
//   COLOR.a  1 for old drawn glass that ripples slightly
// The glass itself reflects the sky and street through the engine's specular, so the room
// shows strongly when you look straight in and fades at grazing angles, as real glass does.
shader_type spatial;
render_mode cull_back;

instance uniform float lit = 0.0;     // 0 by day, 1 at night

// flat: every corner of a pane carries the same values, and interpolating them would add
// rounding noise that the hashes below turn into speckle
varying flat vec4 room;
varying flat vec4 extra;
varying flat vec2 pane_size;
varying flat float old_glass;
varying flat float coated;
varying flat float lit_share;
varying flat float shop_kind;

const float K_OFFICE = 0.0;
const float K_HOME = 1.0;
const float K_SHOP = 2.0;
const float K_PARKING = 3.0;
const float K_SPANDREL = 4.0;
const float K_LOBBY = 5.0;

float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float box2(vec2 p, vec2 lo, vec2 hi) {
	return step(lo.x, p.x) * step(p.x, hi.x) * step(lo.y, p.y) * step(p.y, hi.y);
}

// Shelving seen from across the shop: boards every 450 mm carrying rows of products of
// varied width, height and colour, with the dark back of the shelf above them.
vec3 shelf_goods(vec2 xy, float salt, vec3 back) {
	float row = floor(xy.y / 0.45);
	float fy = fract(xy.y / 0.45) * 0.45;
	float bay = floor(xy.x / 0.9);
	float pw = 0.05 + 0.11 * hash12(vec2(bay, row + salt));
	float item = floor(xy.x / pw);
	float h = hash12(vec2(item, row + salt * 3.0));
	float ih = 0.45 * (0.45 + 0.4 * hash12(vec2(item + 7.0, row)));
	vec3 c = vec3(h, hash12(vec2(row, item + salt)), hash12(vec2(item * 1.7, row + 5.0)));
	c = mix(vec3(dot(c, vec3(0.33))), c, 0.55) * 0.6 + 0.08;
	float gap = step(fract(xy.x / pw), 0.08);
	vec3 col = fy < 0.035 ? vec3(0.3, 0.29, 0.27) : (fy < ih ? c * (1.0 - 0.5 * gap) : back * 0.45);
	if (fract(xy.x / 0.9) < 0.025) { col = vec3(0.22); }
	return col;
}

// Clothes on a wall rail at 1.7 m: garments of varied width, length and colour hang under it.
vec3 garments(vec2 xy, float salt, vec3 back) {
	float slot = floor(xy.x / 0.07);
	float len = 0.75 + 0.55 * hash12(vec2(floor(xy.x / 0.5), salt));
	vec3 c = vec3(hash12(vec2(slot, salt)), hash12(vec2(slot + 3.0, salt)), hash12(vec2(slot + 9.0, salt)));
	c = mix(vec3(dot(c, vec3(0.33))), c, 0.45) * 0.55 + 0.06;
	float hang = step(1.7 - len, xy.y) * step(xy.y, 1.66);
	vec3 col = back;
	col = mix(col, c * (0.85 + 0.15 * step(0.5, fract(xy.x / 0.07))), hang);
	col = mix(col, vec3(0.55, 0.55, 0.56), box2(xy, vec2(-1e4, 1.66), vec2(1e4, 1.7)));
	return col;
}

// The back of a cafe, diner or takeaway: tiled wall, a lit menu band and a service counter.
vec3 food_wall(vec2 xy, float salt, vec3 back, out float menu) {
	vec2 t = fract(xy / vec2(0.15, 0.075));
	float tile = step(0.06, t.x) * step(0.08, t.y);
	vec3 tc = mix(vec3(0.62, 0.62, 0.6), vec3(0.78, 0.78, 0.76), tile);
	vec3 col = xy.y < 1.5 ? mix(tc, back, step(0.5, hash11(salt * 1.3))) : back;
	// menu boards: dark panels with rows of light lettering
	float board = box2(xy, vec2(-2.4, 1.85), vec2(2.4, 2.45)) * step(0.06, fract(xy.x / 1.6));
	float lines = step(0.55, fract(xy.y / 0.09)) * step(0.3, hash12(vec2(floor(xy.x / 0.35), floor(xy.y / 0.09) + salt)));
	menu = board * lines;
	col = mix(col, vec3(0.06, 0.06, 0.07), board);
	col = mix(col, vec3(0.9, 0.86, 0.75), menu);
	// counter with a steel front and a lighter top
	col = mix(col, vec3(0.32, 0.3, 0.28), step(xy.y, 1.0));
	col = mix(col, vec3(0.7, 0.69, 0.66), box2(xy, vec2(-1e4, 0.96), vec2(1e4, 1.04)));
	return col;
}

// Barber, tailor, travel agent, insurance: framed mirrors or panels in a row on a plain wall.
vec3 service_wall(vec2 xy, float salt, vec3 back) {
	float cell = fract(xy.x / 1.3);
	float frame = box2(vec2(cell, xy.y), vec2(0.18, 0.95), vec2(0.82, 1.95));
	float inner = box2(vec2(cell, xy.y), vec2(0.22, 1.0), vec2(0.78, 1.9));
	vec3 col = mix(back, vec3(0.18, 0.16, 0.14), frame);
	col = mix(col, mix(vec3(0.55, 0.6, 0.62), back * 1.15, step(0.5, hash11(salt))), inner);
	col = mix(col, back * 0.6, step(xy.y, 0.12));     // skirting
	return col;
}

void vertex() {
	room = CUSTOM0;
	extra = CUSTOM1;
	pane_size = UV2;
	old_glass = COLOR.a;
	coated = COLOR.g;
	lit_share = COLOR.r;
	shop_kind = floor(COLOR.b * 4.0 + 0.5);
}

vec3 pick(float h, vec3 a, vec3 b, vec3 c, vec3 d) {
	return h < 0.25 ? a : (h < 0.5 ? b : (h < 0.75 ? c : d));
}

void fragment() {
	float seed = room.x;
	float depth = room.y;
	float kind = floor(room.z + 0.5);
	float sill = room.w;
	float storey = extra.x;
	float ml = extra.y;
	float mr = extra.z;
	float group = extra.w;
	float share = lit_share;
	vec2 sz = pane_size;
	vec2 p = UV;

	float h1 = hash11(seed * 1.7 + 0.3);
	float h2 = hash11(seed * 3.1 + 1.9);
	float h3 = hash11(seed * 5.3 + 7.1);
	float h4 = hash11(seed * 7.9 + 4.4);
	float hg = hash11(group * 2.3 + 0.7);

	// Is this room lit? Offices burn their lights through the working day and a share stay
	// on at night; homes light up after dark; shops are lit while open.
	float night = lit;
	float lamp_on;
	if (kind == K_OFFICE) {
		lamp_on = mix(step(hg, 0.72), step(hg, share * 0.8), night);
	} else if (kind == K_HOME) {
		lamp_on = step(hg, share * night + 0.06 * (1.0 - night));
	} else if (kind == K_PARKING) {
		lamp_on = 1.0;
	} else {
		lamp_on = (night > 0.5 && hg > 0.72) ? 0.25 : 1.0;     // a few shops closed: display light only
	}
	float on = lamp_on;

	// colour of the light: warm homes, neutral offices, a few cool screens
	vec3 warm = vec3(1.0, 0.74, 0.46);
	vec3 neutral = vec3(1.0, 0.9, 0.78);
	vec3 cool = vec3(0.82, 0.92, 1.0);
	vec3 lamp_col = kind == K_HOME ? mix(warm, neutral, step(0.7, h2)) : mix(neutral, cool, step(0.6, hg) * 0.6);
	if (kind == K_HOME && h3 > 0.88) { lamp_col = cool * 0.7; }          // only the television on
	if (kind == K_PARKING) { lamp_col = vec3(0.92, 1.0, 0.95); }

	// view ray in pane space: x along the pane, y up, z into the room
	vec3 vd = -VIEW;
	vec3 dir = vec3(dot(vd, TANGENT), dot(vd, BINORMAL), -dot(vd, NORMAL));
	dir.z = max(dir.z, 1e-4);
	float ceil_drop = kind == K_OFFICE ? 0.7 : (kind == K_PARKING ? 0.45 : 0.35);
	vec3 lo = vec3(-ml, -sill, 0.0);
	vec3 hi = vec3(sz.x + mr, storey - ceil_drop - sill, depth);
	vec3 o = vec3(p, 0.0);
	vec3 tv = vec3(
		dir.x > 0.0 ? (hi.x - o.x) / dir.x : (lo.x - o.x) / min(dir.x, -1e-5),
		dir.y > 0.0 ? (hi.y - o.y) / dir.y : (lo.y - o.y) / min(dir.y, -1e-5),
		(hi.z - o.z) / dir.z);
	float t = min(tv.x, min(tv.y, tv.z));
	vec3 q = o + dir * t;
	// room-space coordinates: floor at y = 0, centre line of the room at x = 0 (the room may
	// run past either side of the pane, so all the panes of one shop see one room)
	float room_c = (sz.x + mr - ml) * 0.5;
	vec3 r = vec3(q.x - room_c, q.y + sill, q.z);
	float ceil_y = hi.y + sill;
	float half_w = (sz.x + ml + mr) * 0.5;

	// surfaces
	vec3 wall_c = pick(h1, vec3(0.62, 0.60, 0.56), vec3(0.55, 0.54, 0.52), vec3(0.64, 0.58, 0.50), vec3(0.48, 0.52, 0.53));
	vec3 floor_c = vec3(0.3, 0.3, 0.32);
	vec3 ceil_c = vec3(0.7, 0.69, 0.66);
	if (kind == K_HOME) {
		wall_c = pick(h1, vec3(0.80, 0.72, 0.60), vec3(0.62, 0.68, 0.70), vec3(0.78, 0.66, 0.58), vec3(0.85, 0.82, 0.74));
		floor_c = vec3(0.42, 0.28, 0.17) * (0.8 + 0.4 * h2);
	} else if (kind == K_SHOP || kind == K_LOBBY) {
		wall_c = pick(h1, vec3(0.70, 0.68, 0.64), vec3(0.26, 0.24, 0.22), vec3(0.62, 0.55, 0.46), vec3(0.45, 0.55, 0.52));
		floor_c = pick(h2, vec3(0.62, 0.60, 0.56), vec3(0.35, 0.24, 0.16), vec3(0.20, 0.20, 0.21), vec3(0.70, 0.68, 0.64));
	} else if (kind == K_PARKING) {
		wall_c = vec3(0.5, 0.5, 0.48);
		floor_c = vec3(0.34, 0.34, 0.33);
		ceil_c = vec3(0.52, 0.52, 0.5);
	}
	vec3 albedo;
	float face_shade = 1.0;
	float emit_fixture = 0.0;
	if (t == tv.z) {
		albedo = wall_c;
		if (kind == K_SHOP) {
			if (shop_kind == 1.0) {
				float menu;
				albedo = food_wall(r.xy, seed, wall_c, menu);
				emit_fixture = menu * 0.35;
			} else if (shop_kind == 2.0) {
				albedo = service_wall(r.xy + vec2(40.0, 0.0), seed, wall_c);
			} else if (shop_kind == 3.0) {
				albedo = garments(vec2(r.x + 50.0, r.y), seed, wall_c);
			} else {
				// shelving along the back wall: bays of goods in rows
				float shelf = step(0.2, r.y) * step(r.y, 2.25);
				albedo = mix(albedo, shelf_goods(vec2(r.x + 50.0, r.y), seed, wall_c), shelf * step(0.3, h3));
			}
		} else if (kind == K_OFFICE) {
			float door = box2(r.xy, vec2(-half_w * 0.6, 0.0), vec2(-half_w * 0.6 + 0.9, 2.1)) * step(0.5, h3);
			albedo = mix(albedo, vec3(0.35, 0.3, 0.26), door);
			float board = box2(r.xy, vec2(0.2, 1.0), vec2(1.4, 1.8)) * step(0.7, h4);
			albedo = mix(albedo, vec3(0.9), board);
		} else if (kind == K_HOME) {
			float pic = box2(r.xy, vec2(-0.4 + h3 * 0.6, 1.35), vec2(0.2 + h3 * 0.6, 1.8)) * step(0.4, h4);
			albedo = mix(albedo, vec3(0.25, 0.22, 0.2) + vec3(h4, h2, h1) * 0.3, pic);
			float shelf = box2(r.xy, vec2(half_w - 1.4, 0.0), vec2(half_w - 0.4, 1.9)) * step(0.55, h2);
			albedo = mix(albedo, vec3(0.3, 0.2, 0.14), shelf);
		} else if (kind == K_PARKING) {
			albedo = mix(albedo, vec3(0.2), step(r.y, 1.0) * 0.3);
		}
		face_shade = 0.9;
	} else if (t == tv.x) {
		albedo = wall_c * 0.92;
		if (kind == K_SHOP) {
			if (shop_kind == 0.0) {
				float shelf = step(0.2, r.y) * step(r.y, 2.0);
				albedo = mix(albedo, shelf_goods(vec2(r.z + 20.0, r.y), seed + sign(dir.x) * 13.0, wall_c * 0.92), shelf * step(0.45, h4));
			} else if (shop_kind == 3.0) {
				albedo = garments(vec2(r.z + 20.0, r.y), seed + sign(dir.x) * 13.0, wall_c * 0.92);
			} else if (shop_kind == 1.0) {
				// banquette seating along the wall
				albedo = mix(albedo, vec3(0.42, 0.14, 0.1) * (0.7 + 0.6 * h1), box2(vec2(r.z, r.y), vec2(1.0, 0.0), vec2(depth - 1.5, 0.95)));
			}
		}
		face_shade = 0.75;
	} else if (dir.y < 0.0) {
		albedo = floor_c;
		if (kind == K_OFFICE) { albedo *= 0.9 + 0.2 * noise(r.xz * 2.0); }
		if (kind == K_HOME) { albedo *= 0.85 + 0.3 * step(0.5, fract(r.x / 0.15)) * 0.4; }
		if (kind == K_PARKING) {
			float stripe = step(abs(fract(r.x / 2.6) - 0.5), 0.02) * step(r.z, 5.0);
			albedo = mix(albedo, vec3(0.8, 0.78, 0.7), stripe);
		}
		face_shade = 0.8;
	} else {
		albedo = ceil_c;
		face_shade = 0.95;
		vec2 cxz = vec2(r.x, r.z - depth * 0.45);
		if (kind == K_OFFICE) {
			// lay-in ceiling grid with recessed panels
			float grid = step(fract(r.x / 0.6), 0.03) + step(fract(r.z / 0.6), 0.03);
			albedo *= 1.0 - 0.15 * clamp(grid, 0.0, 1.0);
			vec2 cell = vec2(fract((r.x + 0.3) / 2.4), fract(r.z / 1.8));
			emit_fixture = box2(cell, vec2(0.37, 0.33), vec2(0.62, 0.66));
		} else if (kind == K_HOME) {
			emit_fixture = 1.0 - smoothstep(0.12, 0.17, length(cxz));
		} else if (kind == K_SHOP || kind == K_LOBBY) {
			float row = step(abs(fract(r.z / 1.8) - 0.5), 0.05);
			emit_fixture = row * step(abs(r.x), half_w - 0.6);
			if (h4 > 0.5) {         // track spots instead
				vec2 c2 = vec2(fract(r.x / 1.2) - 0.5, fract(r.z / 1.5) - 0.5);
				emit_fixture = 1.0 - smoothstep(0.05, 0.08, length(c2));
			}
		} else if (kind == K_PARKING) {
			float beam = step(abs(fract(r.x / 2.4) - 0.5), 0.06);
			albedo *= 1.0 - 0.35 * beam;
			emit_fixture = step(abs(fract(r.x / 4.8) - 0.25), 0.02) * step(abs(fract(r.z / 6.0) - 0.5), 0.15);
		}
	}

	// furniture: one cut-out plane part way into the room
	float fz = depth * (0.35 + 0.25 * h2);
	float tf = (fz - o.z) / dir.z;
	vec3 fq = o + dir * tf;
	vec2 fp = vec2(fq.x - room_c, fq.y + sill);
	float fmask = 0.0;
	vec3 fcol = vec3(0.2);
	if (tf < t && abs(fp.x) < half_w) {
		if (kind == K_OFFICE) {
			float desk = box2(fp, vec2(-half_w, 0.70), vec2(half_w, 0.75));
			float legs = step(fract(fp.x / 1.6 + h1), 0.03) * step(fp.y, 0.72);
			float screen = step(fract(fp.x / 1.6 + h1 + 0.4), 0.3) * box2(fp, vec2(-half_w, 0.8), vec2(half_w, 1.15));
			float part = box2(fp, vec2(-half_w, 0.0), vec2(half_w, 1.25)) * step(0.6, h3) * (1.0 - step(0.72, fp.y) * step(fp.y, 1.15) * 0.0);
			fmask = max(max(desk, legs), max(screen, part * 0.0 + part));
			fcol = mix(vec3(0.22, 0.22, 0.24), vec3(0.08), screen);
			fcol = mix(fcol, vec3(0.42, 0.42, 0.44), part * (1.0 - screen));
			emit_fixture += 0.0;
			if (screen > 0.5 && lamp_on > 0.5) { fcol = vec3(0.35, 0.45, 0.6); }
		} else if (kind == K_HOME) {
			float sx = (h1 - 0.5) * half_w;
			float sofa = box2(fp, vec2(sx - 1.0, 0.0), vec2(sx + 1.0, 0.45)) + box2(fp, vec2(sx - 1.0, 0.0), vec2(sx + 1.0, 0.85)) * step(0.0, fq.z - fz);
			float arm = box2(fp, vec2(sx - 1.05, 0.0), vec2(sx - 0.85, 0.62)) + box2(fp, vec2(sx + 0.85, 0.0), vec2(sx + 1.05, 0.62));
			float lampstand = box2(fp, vec2(sx + 1.3, 0.0), vec2(sx + 1.33, 1.45)) + box2(fp, vec2(sx + 1.15, 1.35), vec2(sx + 1.5, 1.62));
			fmask = clamp(sofa + arm + lampstand, 0.0, 1.0) * step(0.3, h3);
			fcol = mix(vec3(0.25, 0.2, 0.18), vec3(h1, h2, h4) * 0.4 + 0.1, 0.5);
		} else if (kind == K_SHOP && shop_kind == 1.0) {
			// tables and chairs across the room
			float u = fract(fp.x / 1.8 + h1) * 1.8;
			float top = box2(vec2(u, fp.y), vec2(0.35, 0.72), vec2(1.15, 0.77));
			float stem = box2(vec2(u, fp.y), vec2(0.72, 0.0), vec2(0.78, 0.72));
			float chair = box2(vec2(u, fp.y), vec2(0.05, 0.0), vec2(0.09, 0.9)) + box2(vec2(u, fp.y), vec2(0.05, 0.44), vec2(0.3, 0.48))
				+ box2(vec2(u, fp.y), vec2(1.41, 0.0), vec2(1.45, 0.9)) + box2(vec2(u, fp.y), vec2(1.2, 0.44), vec2(1.45, 0.48));
			fmask = clamp(top + stem + chair, 0.0, 1.0) * step(abs(fp.x), half_w - 0.4);
			fcol = mix(vec3(0.16, 0.12, 0.1), vec3(0.5, 0.4, 0.3) * (0.6 + 0.5 * h2), top);
		} else if (kind == K_SHOP && shop_kind == 2.0) {
			// a row of chairs (barber, waiting room) and on some a reception desk
			float u = fract(fp.x / 1.3) * 1.3;
			float chair = box2(vec2(u, fp.y), vec2(0.35, 0.0), vec2(0.95, 0.5)) + box2(vec2(u, fp.y), vec2(0.4, 0.5), vec2(0.9, 1.15));
			float has_desk = step(0.5, h1);
			float desk = box2(fp, vec2(half_w * 0.2, 0.0), vec2(half_w * 0.2 + 1.6, 1.05)) * has_desk;
			chair *= 1.0 - has_desk * step(half_w * 0.2 - 0.2, fp.x);
			fmask = clamp(chair + desk, 0.0, 1.0) * step(abs(fp.x), half_w - 0.4);
			fcol = desk > 0.5 ? vec3(0.32, 0.26, 0.2) : vec3(0.1, 0.1, 0.11) + vec3(h4, h2, h1) * 0.12;
		} else if (kind == K_SHOP) {
			float counter = box2(fp, vec2(-half_w * 0.3, 0.0), vec2(half_w * 0.6, 1.0)) * step(0.4, h1);
			float rack = box2(fp, vec2(-half_w + 0.5, 0.0), vec2(-half_w + 1.7, 1.5)) * step(0.5, h2);
			float rails = step(fract(fp.x * 4.0), 0.5) * box2(fp, vec2(-half_w + 0.5, 0.6), vec2(-half_w + 1.7, 1.4));
			if (shop_kind == 3.0) {     // clothes on a free-standing rail in the middle of the floor
				rack = box2(fp, vec2(-half_w * 0.5, 0.35), vec2(half_w * 0.1, 1.45));
				rails = step(0.35, fract(fp.x / 0.07));
			}
			fmask = clamp(counter + rack, 0.0, 1.0);
			fcol = mix(vec3(0.3, 0.25, 0.2), vec3(0.6, 0.55, 0.5) * vec3(h3, h4, h1), rails * rack);
		} else if (kind == K_PARKING) {
			float col = step(abs(fract(fp.x / 8.0 + h1) - 0.5) * 8.0, 0.3);
			// cars parked nose-in, seen end-on: wheels, a body to 0.9 m, a cabin narrowing to the roof
			float slot = floor((fp.x + 30.0) / 2.6);
			float x = abs(fract((fp.x + 30.0) / 2.6) - 0.5) * 2.6;     // metres from the bay centre
			float hc = hash12(vec2(slot, seed));
			float tall = step(0.75, hash12(vec2(slot, seed + 3.0)));   // some vans and SUVs
			float roof = 1.42 + 0.35 * tall;
			float rise = clamp((fp.y - 0.92) / (roof - 0.92), 0.0, 1.0);
			float body = step(x, 0.9) * step(0.3, fp.y) * step(fp.y, 0.92);
			float cabin = step(x, 0.78 - 0.22 * rise) * step(0.92, fp.y) * step(fp.y, roof);
			float wheel = step(0.62, x) * step(x, 0.86) * step(fp.y, 0.34);
			float car = clamp(body + cabin + wheel, 0.0, 1.0) * step(0.25, hc);
			fmask = clamp(col + car, 0.0, 1.0);
			// paint: mostly white, black, grey and silver, a few colours
			float pc = hash12(vec2(slot, seed + 4.0));
			vec3 paint = pc < 0.25 ? vec3(0.78, 0.78, 0.76) : (pc < 0.45 ? vec3(0.04) : (pc < 0.62 ? vec3(0.3, 0.31, 0.32) : (pc < 0.8 ? vec3(0.55, 0.56, 0.57)
				: (pc < 0.88 ? vec3(0.45, 0.06, 0.05) : (pc < 0.95 ? vec3(0.07, 0.12, 0.3) : vec3(0.25, 0.3, 0.27))))));
			vec3 cc = paint;
			cc = mix(cc, vec3(0.03, 0.035, 0.04), cabin * step(fp.y, roof - 0.07) * step(x, 0.68 - 0.22 * rise));     // rear window
			cc = mix(cc, vec3(0.02), wheel);
			cc = mix(cc, vec3(0.9, 0.2, 0.1), step(0.62, x) * step(x, 0.85) * step(0.72, fp.y) * step(fp.y, 0.82));   // tail lamps
			fcol = col > 0.5 ? vec3(0.5, 0.5, 0.48) : cc;
		}
	}
	vec3 hit = q;
	float hit_z = r.z;
	float hit_y = r.y;
	if (fmask > 0.5) {
		albedo = fcol;
		hit_z = fz;
		hit_y = fp.y;
		face_shade = 0.85;
		emit_fixture = 0.0;
	}

	// lighting: daylight falls off away from the window, the lamp lights the room evenly-ish
	float day = 1.0 - night;
	float daylight = (0.10 + 0.55 * exp(-hit_z * 0.45)) * day;
	if (kind == K_PARKING) { daylight = (0.25 + 0.5 * exp(-hit_z * 0.3)) * day; }
	// lamp strength: shops are bright, offices moderate, homes dimmer and warmer; each room
	// varies a little so a lit floor never reads as one flat sheet
	float strength = kind == K_SHOP || kind == K_LOBBY ? mix(0.42, 0.7, night) : (kind == K_HOME ? 0.42 : mix(0.3, 0.5, night));
	if (kind == K_PARKING) { strength = 0.35; }
	strength *= 0.75 + 0.5 * h2;
	float lamp = (0.45 + 0.55 * smoothstep(0.0, ceil_y, hit_y)) * lamp_on * (1.0 - 0.35 * smoothstep(0.0, depth, hit_z));
	vec3 radiance = albedo * face_shade * (vec3(0.55, 0.6, 0.66) * daylight * 0.28 + lamp_col * lamp * strength);
	radiance += lamp_col * emit_fixture * lamp_on * 2.2;

	// blinds and curtains on the glass
	float blind = 0.0;
	vec3 blind_col = vec3(0.86, 0.84, 0.8);
	float bkind = h4;
	if (kind == K_OFFICE || kind == K_HOME) {
		float drop = sz.y * (h3 < 0.35 ? 0.0 : (h3 < 0.75 ? h1 * 0.6 : (0.6 + 0.4 * h1)));
		float covered = step(sz.y - drop, p.y);
		if (bkind < 0.55) {
			// venetian: 25 mm slats tilted half open, averaged out when smaller than a pixel
			float slat = smoothstep(0.35, 0.5, abs(fract(p.y / 0.025) - 0.5) * 2.0);
			slat = mix(slat, 0.4, smoothstep(0.004, 0.012, fwidth(p.y)));
			blind = covered * (0.65 + 0.35 * slat);
			blind_col = kind == K_OFFICE ? vec3(0.72, 0.73, 0.74) : vec3(0.88, 0.86, 0.8);
		} else {
			blind = covered;
			blind_col = kind == K_HOME ? vec3(0.85, 0.80, 0.70) * (0.8 + 0.3 * h2) : vec3(0.6, 0.62, 0.62);
		}
		if (kind == K_HOME && h2 > 0.5) {
			// curtains drawn back to each side, gathered in folds
			float cw = sz.x * (0.12 + 0.2 * h1);
			float side = 1.0 - step(cw, p.x) * step(p.x, sz.x - cw);
			float fold = 0.75 + 0.25 * sin(p.x * 40.0);
			vec3 cc = vec3(h1, h4, h2) * 0.5 + 0.25;
			blind_col = mix(blind_col, cc * fold, side);
			blind = max(blind, side);
		}
	}
	// a lit room glows through its blinds; a dark one shows them grey
	vec3 through = blind_col * (lamp_col * lamp * strength * 0.8 + vec3(0.03) * day);
	radiance = mix(radiance, through, blind * 0.92);

	if (kind == K_SPANDREL) {
		radiance = vec3(0.0);
	}

	// glass: grazing angles reflect, straight on lets the room through
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - ndv, 5.0);
	float trans = 1.0 - fres;
	vec3 glass_tint = mix(vec3(0.86, 0.9, 0.88), vec3(0.42, 0.52, 0.52), coated);
	if (kind == K_PARKING) {        // open deck: no glass at all
		trans = 1.0;
		glass_tint = vec3(1.0);
	}
	// dust along the bottom of the pane
	float dust = (1.0 - smoothstep(0.0, 0.25, p.y)) * 0.3 * noise(p * 7.0);
	EMISSION = radiance * trans * glass_tint * (1.0 - dust);
	ALBEDO = vec3(0.01) + blind_col * blind * 0.25 * day + vec3(0.25, 0.24, 0.22) * dust;
	METALLIC = 0.0;
	if (kind == K_SPANDREL) { ALBEDO = vec3(0.03, 0.035, 0.04); }
	if (kind == K_PARKING) {
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		ALBEDO = vec3(0.0);
	} else {
		SPECULAR = 0.5 + 0.4 * coated;
		// panes differ: some cleaner, some hazier, some slightly tinted
		ROUGHNESS = 0.02 + 0.06 * h3 * h3 + dust * 0.4;
		if (old_glass > 0.5) {
			// drawn glass of the early panes: a faint ripple bends the reflection
			float rip = noise(vec2(p.x * 3.0, p.y * 0.7) + seed);
			NORMAL = normalize(NORMAL + (rip - 0.5) * 0.05 * TANGENT + (noise(p * 2.0 + 9.0) - 0.5) * 0.03 * BINORMAL);
		}
	}
}
