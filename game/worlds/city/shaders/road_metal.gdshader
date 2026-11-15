// Painted or galvanised street metal: base colour with slight mottling, road grime and splash low down,
// rain darkening and gloss. Used for poles, bins, bollards, hydrants and signal housings.
shader_type spatial;

#include "res://worlds/city/shaders/road_common.gdshaderinc"

uniform vec3 paint : source_color = vec3(0.03, 0.032, 0.035);
uniform float rough = 0.5;
uniform float metal = 0.3;
uniform float grime = 1.0;
uniform vec3 emit_colour : source_color = vec3(0.0);
uniform float emit_energy = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float mott = osg_fbm(wpos.xz * 3.0 + wpos.y * 5.0, 3);
	vec3 col = paint * (0.88 + 0.24 * mott);
	float low = 1.0 - smoothstep(0.05, 0.55, wpos.y);
	float splash = low * smoothstep(0.35, 0.7, osg_fbm(vec2(wpos.x + wpos.z, wpos.y) * 9.0, 3));
	col = mix(col, vec3(0.16, 0.14, 0.11), splash * 0.6 * grime);
	float r = rough + 0.15 * splash * grime + (mott - 0.5) * 0.1;
	col *= mix(1.0, 0.75, wetness);
	r = mix(r, 0.18, wetness);
	ALBEDO = col;
	ROUGHNESS = clamp(r, 0.05, 1.0);
	METALLIC = metal;
	EMISSION = emit_colour * emit_energy;
}
