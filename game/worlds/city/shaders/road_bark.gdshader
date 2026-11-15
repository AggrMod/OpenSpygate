// Bark of a young street tree: shallow vertical fissures, grey-brown, darker and greener low down.
// UV.x runs round the stem, UV.y along it.
shader_type spatial;

#include "res://worlds/city/shaders/road_common.gdshaderinc"

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = vec2(UV.x * 14.0, wpos.y * 5.0);
	float fis = osg_fbm(p * vec2(1.0, 0.3) + vec2(MODEL_MATRIX[3].x, 0.0), 5);
	float groove = smoothstep(0.40, 0.58, fis);
	float flake = osg_fbm(vec2(UV.x * 40.0, wpos.y * 30.0), 3);
	vec3 col = mix(vec3(0.07, 0.06, 0.05), vec3(0.24, 0.21, 0.18), groove);
	col *= 0.8 + 0.4 * flake;
	col = mix(col, vec3(0.10, 0.12, 0.06), (1.0 - smoothstep(0.0, 1.2, wpos.y)) * 0.4);
	col *= mix(1.0, 0.6, wetness);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.5, wetness);
	NORMAL_MAP = vec3(0.5 + (dFdx(groove) * 2.0), 0.5 + dFdy(groove) * 2.0, 1.0);
	NORMAL_MAP_DEPTH = 1.2;
}
