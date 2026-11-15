// Cast iron in the street: manhole covers (kind 0), kerbside drain grates (kind 1) and tree grates (kind 2).
// UV is local metres from the centre of the piece; UV.y = 2 marks the dark kerb inlet slot.
shader_type spatial;
render_mode cull_back;

#include "res://worlds/city/shaders/road_common.gdshaderinc"

uniform int kind = 0;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = wpos.xz;
	vec3 iron = vec3(0.075, 0.07, 0.065) * (0.8 + 0.4 * osg_fbm(p * 7.0, 3));
	// Rust in the recesses, polish on the tops where tyres run.
	vec3 rust = vec3(0.22, 0.11, 0.05) * (0.7 + 0.6 * osg_fbm(p * 11.0 + 3.0, 3));
	vec3 col = iron;
	float rough = 0.55;
	vec3 n = wnorm;
	float raised = 0.0;
	if (kind == 0) {
		float r = length(uv);
		float ang = atan(uv.y, uv.x);
		if (r < 0.33) {
			// raised pattern: rings and a diamond grid, with a plain band for the pick holes
			vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * uv / 0.045;
			vec2 gf = abs(fract(g) - 0.5);
			float diamond = smoothstep(0.30, 0.22, max(gf.x, gf.y));
			float rings = smoothstep(0.012, 0.006, abs(r - 0.30)) + smoothstep(0.012, 0.006, abs(r - 0.16));
			float band = step(0.20, r) * step(r, 0.26);
			raised = mix(diamond, 0.0, band) + rings;
			raised = clamp(raised, 0.0, 1.0);
			// two pick holes
			vec2 hole = vec2(0.23, 0.0);
			float holes = step(length(uv - hole), 0.018) + step(length(uv + hole), 0.018);
			col = mix(mix(rust * 0.6, iron * 0.7, 0.6), iron * 1.6 + vec3(0.03), raised);
			col = mix(col, vec3(0.005), holes);
			rough = mix(0.8, 0.32, raised);
			n = normalize(n + vec3(-dFdx(raised), 0.0, -dFdy(raised)) * 1.5);
		} else {
			col = iron * 1.15;
			rough = 0.5;
			col = mix(col, rust, smoothstep(0.38, 0.40, r) * 0.6);
		}
	} else if (kind == 2) {
		// square tree grate: a frame, rings of radial slots, and the mulch round the trunk in the middle
		vec2 q = lpos.xz;
		float r = length(q);
		float ang = atan(q.y, q.x);
		float frame = step(0.56, max(abs(q.x), abs(q.y)));
		float ring = step(0.30, r) * (1.0 - frame);
		float slots = step(0.5, fract(ang / 6.2831 * 48.0)) * step(0.34, r) * step(r, 0.52);
		slots *= 1.0 - step(abs(r - 0.43), 0.012);
		float corner_slots = step(0.5, fract((q.x + q.y) / 0.06)) * step(0.55, r) * (1.0 - frame);
		float hole = max(slots, corner_slots);
		vec3 mulch = vec3(0.06, 0.045, 0.03) * (0.6 + 0.8 * osg_fbm(p * 18.0, 3));
		col = mix(iron * 1.25, vec3(0.008), hole);
		col = mix(col, rust, (1.0 - hole) * smoothstep(0.5, 0.8, osg_fbm(p * 7.0, 2)) * 0.5);
		col = mix(mulch, col, step(0.30, r));
		rough = mix(0.5, 0.95, max(hole, 1.0 - step(0.30, r)));
		n = normalize(n + vec3(q.x, 0.0, q.y) * 0.0);
	} else {
		if (uv.y > 1.5) {
			col = vec3(0.004);
			rough = 1.0;
		} else {
			vec2 a = abs(uv);
			float frame = step(0.40, a.x) + step(0.20, a.y);
			float slot = step(0.5, fract(uv.x / 0.055)) * (1.0 - clamp(frame, 0.0, 1.0));
			float cross_bar = step(abs(uv.y), 0.015);
			slot *= 1.0 - cross_bar;
			col = mix(iron * 1.3, vec3(0.006), slot);
			col = mix(col, rust, (1.0 - slot) * smoothstep(0.5, 0.8, osg_fbm(p * 9.0, 2)) * 0.6);
			rough = mix(0.45, 1.0, slot);
		}
	}
	// wet iron
	col *= mix(1.0, 0.7, wetness);
	rough = mix(rough, 0.12, wetness);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	NORMAL = osg_view_normal(VIEW_MATRIX, n);
}
