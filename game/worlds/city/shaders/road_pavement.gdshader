// Concrete pavement and kerb. Pavement: 1.675 m panels laid from the kerb, tooled joints, broom finish,
// panel-to-panel tint, gum spots, grime and rust stains, yellow warning domes at the dropped kerbs.
// Kerb: precast concrete sections 1.8 m long with an arris, a gutter pan, and dirt where water runs.
// Vertex COLOR.r is the dropped-kerb factor; UV2.y is the distance from the kerb face in metres.
shader_type spatial;
render_mode cull_back;

#include "res://worlds/city/shaders/road_common.gdshaderinc"

uniform bool is_kerb = false;
uniform float half_road = 5.5;
uniform float kerb_width = 0.15;
uniform float panel = 1.675;

varying vec3 wpos;
varying vec3 wnorm;
varying float ramp;
varying float from_kerb;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ramp = COLOR.r;
	from_kerb = UV2.y;
}

float joint(float v, float w) {
	float d = abs(v - round(v));
	float aa = max(fwidth(v), 1e-4);
	return clamp((w - d) / aa + 0.5, 0.0, 1.0) * clamp(w * 2.0 / aa, 0.0, 1.0);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 off = osg_street_offsets(p);
	float px = max(length(fwidth(p)), 1e-4);
	float fine_fade = 1.0 - smoothstep(0.006, 0.03, px);
	vec3 n = wnorm;
	vec3 col;
	float rough;
	float low = 0.0;

	if (is_kerb) {
		// Which way does this kerb run? Along x when we are nearer an east-west street.
		float along = off.y < off.x ? p.x : p.y;
		float section = floor(along / 1.8);
		float tint = osg_hash1(vec2(section, 3.0));
		col = mix(vec3(0.30, 0.295, 0.28), vec3(0.38, 0.37, 0.35), tint);
		col *= 0.85 + 0.25 * osg_fbm(p * 4.0, 3);
		float sj = joint(along / 1.8, 0.006 / 1.8);
		col = mix(col, vec3(0.12), sj * 0.8);
		// Dirt and tyre scuffs low on the face and in the gutter pan.
		float hgt = wpos.y;
		float dirt = 1.0 - smoothstep(0.0, 0.09, hgt);
		col = mix(col, vec3(0.20, 0.185, 0.16) * (0.7 + 0.6 * osg_fbm(p * 6.0, 2)), dirt * 0.6);
		float scuff = smoothstep(0.6, 0.8, osg_fbm(vec2(along * 0.8, hgt * 30.0), 3)) * smoothstep(0.02, 0.06, hgt) * (1.0 - smoothstep(0.1, 0.15, hgt));
		col = mix(col, vec3(0.06), scuff * 0.7 * step(0.3, abs(n.x) + abs(n.z)));
		rough = 0.86;
		low = dirt;
	} else {
		float d_ew = (off.y - (half_road + kerb_width)) / panel;
		float d_ns = (off.x - (half_road + kerb_width)) / panel;
		float jw = 0.007 / panel;
		float joints = max(joint(d_ew, jw), joint(d_ns, jw));
		vec2 panel_id = vec2(floor(d_ew + 0.0001), floor(d_ns + 0.0001)) + round(p / vec2(pitch_x, pitch_z)) * 97.0;
		vec2 ph = osg_hash2(panel_id + vec2(19.0, 7.0));
		// Each panel was poured on its own day: a slightly different tint and age.
		col = mix(vec3(0.26, 0.255, 0.24), vec3(0.36, 0.35, 0.33), ph.x);
		col *= 0.88 + 0.22 * osg_fbm(p * 1.7 + ph * 13.0, 3);
		// Tooled margin beside each joint is smoother and a touch lighter.
		float fd_ew = abs(d_ew - round(d_ew)) * panel;
		float fd_ns = abs(d_ns - round(d_ns)) * panel;
		float margin = 1.0 - smoothstep(0.03, 0.05, min(fd_ew, fd_ns));
		col *= 1.0 + 0.06 * margin;
		// Grime builds up along the joints and at the building line.
		float grime = (1.0 - smoothstep(0.0, 0.12, min(fd_ew, fd_ns))) * 0.35;
		grime += smoothstep(0.55, 0.8, osg_fbm(p * 0.5 + 33.0, 4)) * 0.35;
		col = mix(col, vec3(0.17, 0.16, 0.14), grime);
		col = mix(col, vec3(0.08), joints * 0.85);
		// Old chewing gum: flattened dark spots, thickest near the kerb.
		vec2 g = p * 4.5;
		vec2 gc = floor(g);
		vec2 gh = osg_hash2(gc + vec2(5.0, 91.0));
		float gum_density = mix(0.015, 0.06, 1.0 - smoothstep(0.3, 2.5, from_kerb));
		float gum = 0.0;
		if (gh.x < gum_density) {
			vec2 gp = gc + 0.2 + 0.6 * osg_hash2(gc + vec2(77.0, 3.0));
			float r = (0.008 + 0.014 * gh.y) * 4.5;
			vec2 gd = (g - gp) * vec2(1.0, 1.0 + 0.6 * gh.x * 10.0);
			float wob = osg_gnoise(g * 9.0) * r * 0.5;
			gum = (1.0 - smoothstep(r * 0.6, r, length(gd) + wob)) * (0.5 + 0.5 * gh.y);
		}
		col = mix(col, vec3(0.09, 0.088, 0.085), gum * 0.75);
		// Rust and leaf stains.
		float rust = smoothstep(0.7, 0.82, osg_fbm(p * 0.8 + 140.0, 3));
		col = mix(col, vec3(0.30, 0.20, 0.12), rust * 0.35);
		// Broom finish: fine ridges across the pavement.
		if (fine_fade > 0.0) {
			float across = off.y < off.x ? p.x : p.y;
			float bro = osg_gnoise(vec2(across * 3.0, (off.y < off.x ? p.y : p.x) * 140.0));
			float e = 0.003;
			float bx = osg_gnoise(p * 55.0);
			float bxx = osg_gnoise((p + vec2(e, 0.0)) * 55.0);
			float bzz = osg_gnoise((p + vec2(0.0, e)) * 55.0);
			float k = 0.0012 * fine_fade;
			n = normalize(n + vec3(-(bxx - bx) / e * k, 0.0, -(bzz - bx) / e * k) + vec3(0.0, 0.0, bro * 0.04 * fine_fade));
			col *= 1.0 + 0.04 * bro * fine_fade;
		}
		rough = 0.9 - 0.08 * margin;
		// Detectable warning surface at the bottom of a dropped kerb: yellow truncated domes.
		float warn = step(0.97, ramp) * step(kerb_width + 0.05, from_kerb) * (1.0 - step(kerb_width + 0.66, from_kerb));
		if (warn > 0.0) {
			vec2 dp = p / 0.06;
			vec2 dc = fract(dp) - 0.5;
			float dome = 1.0 - smoothstep(0.26, 0.36, length(dc));
			col = mix(vec3(0.62, 0.48, 0.07), vec3(0.75, 0.6, 0.12), dome) * (0.8 + 0.2 * osg_fbm(p * 3.0, 2));
			col *= 0.85;
			rough = 0.6;
			n = normalize(n + vec3(dc.x, 0.0, dc.y) * dome * 1.2);
		}
		low = joints * 0.4 + (1.0 - smoothstep(0.0, 0.25, from_kerb - kerb_width)) * 0.3 + ramp * 0.5;
	}

	float pud = osg_puddles(p * 1.3 + 50.0, low) * 0.8;
	col *= mix(1.0, 0.62, wetness);
	rough = mix(rough, 0.42, wetness);
	col *= mix(1.0, 0.8, pud);
	rough = mix(rough, 0.04, pud);
	n = normalize(mix(n, wnorm, pud));

	ALBEDO = col;
	ROUGHNESS = rough;
	NORMAL = osg_view_normal(VIEW_MATRIX, n);
}
