// A lamp's lens. Off by day (pale frosted acrylic), on at night. Each lamp's photocell trips at its own
// darkness (INSTANCE_CUSTOM.r), so a street does not switch on all at once.
shader_type spatial;

uniform float night = 0.0;
uniform vec3 light_colour : source_color = vec3(1.0, 0.86, 0.68);
uniform float energy = 40.0;

varying float trip;

void vertex() {
	trip = INSTANCE_CUSTOM.r;
}

void fragment() {
	float on = smoothstep(trip, trip + 0.02, night);
	ALBEDO = vec3(0.55, 0.55, 0.52) * (1.0 - on);
	ROUGHNESS = 0.3;
	EMISSION = light_colour * energy * on;
}
