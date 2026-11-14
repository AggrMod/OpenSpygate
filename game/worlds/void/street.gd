class_name Street
extends Node3D
## The first stretch of road in the void: wet asphalt, lane markings, a pavement on the far side, street lamps.
## It exists only where it has been built. Past its ends there is void.

const LENGTH: float = 320.0
const WIDTH: float = 9.0
const PAVEMENT: float = 3.0
const KERB: float = 0.14
const LAMP_SPACING: float = 32.0

const ASPHALT_SHADER: String = """
shader_type spatial;
render_mode cull_back;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; } return s; }

void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = world_pos.xz;
	float patches = fbm(p * 0.22);
	float grit = fbm(p * 14.0);
	float wet = smoothstep(0.44, 0.62, patches);                      // standing water in the low spots
	float worn = fbm(vec2(p.x * 0.6, p.y * 9.0));                     // tyre tracks polish the surface
	vec3 base = mix(vec3(0.045), vec3(0.018), wet) * (0.90 + 0.20 * grit);
	// markings: UV.x runs across the road 0..1, UV.y is metres along it
	float across = UV.x;
	float along = UV.y;
	float edge = step(abs(across - 0.035), 0.008) + step(abs(across - 0.965), 0.008);
	float centre = step(abs(across - 0.5), 0.008) * step(fract(along / 9.0), 0.33);
	float paint = clamp(edge + centre, 0.0, 1.0) * smoothstep(0.25, 0.55, fbm(p * 6.0) + 0.25);   // worn away in places
	ALBEDO = mix(base, vec3(0.50, 0.50, 0.47), paint * 0.85);
	ROUGHNESS = mix(mix(0.86, 0.62, worn * 0.5), 0.07, wet * (1.0 - paint * 0.4));
	SPECULAR = 0.5;
	float h = grit * (1.0 - wet);
	NORMAL_MAP = vec3(0.5 + dFdx(h) * 2.0, 0.5 + dFdy(h) * 2.0, 1.0);
	NORMAL_MAP_DEPTH = 0.35;
}
"""

var centre_z: float = 0.0


func build() -> void:
	_build_road()
	_build_pavement()
	var x := -LENGTH / 2.0 + LAMP_SPACING / 2.0
	var i := 0
	while x < LENGTH / 2.0:
		_build_lamp(x, absf(x) < 70.0)
		x += LAMP_SPACING
		i += 1


func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 8.0
	var x := -LENGTH / 2.0
	while x < LENGTH / 2.0:
		var x2 := x + step
		var a := Vector3(x, 0.012, -WIDTH / 2.0)
		var b := Vector3(x2, 0.012, -WIDTH / 2.0)
		var c := Vector3(x2, 0.012, WIDTH / 2.0)
		var d := Vector3(x, 0.012, WIDTH / 2.0)
		for corner: Array in [[a, Vector2(0, x)], [b, Vector2(0, x2)], [c, Vector2(1, x2)], [a, Vector2(0, x)], [c, Vector2(1, x2)], [d, Vector2(1, x)]]:
			st.set_normal(Vector3.UP)
			st.set_tangent(Plane(Vector3.RIGHT, 1.0))
			st.set_uv(corner[1])
			st.add_vertex(corner[0])
		x = x2
	var mesh := MeshInstance3D.new()
	mesh.name = "Road"
	mesh.mesh = st.commit()
	var shader := Shader.new()
	shader.code = ASPHALT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mesh.material_override = mat
	add_child(mesh)


func _build_pavement() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.20, 0.20, 0.19)
	concrete.roughness = 0.82
	var body := StaticBody3D.new()
	body.name = "Pavement"
	var size := Vector3(LENGTH, KERB, PAVEMENT)
	var at := Vector3(0.0, KERB / 2.0, -WIDTH / 2.0 - PAVEMENT / 2.0)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = at
	mesh.material_override = concrete
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	add_child(body)


func _build_lamp(x: float, shadows: bool) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.17, 0.18)
	steel.metallic = 0.9
	steel.roughness = 0.45
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(x, KERB, -WIDTH / 2.0 - 0.6)
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.095
	cyl.height = 8.2
	cyl.radial_segments = 16
	pole.mesh = cyl
	pole.position.y = 4.1
	pole.material_override = steel
	lamp.add_child(pole)
	var arm := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(0.07, 0.07, 2.1)
	arm.mesh = ab
	arm.position = Vector3(0.0, 8.15, 1.0)
	arm.material_override = steel
	lamp.add_child(arm)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.26, 0.07, 0.72)
	head.mesh = hb
	head.position = Vector3(0.0, 8.10, 2.2)
	head.material_override = steel
	lamp.add_child(head)
	var glow := MeshInstance3D.new()
	var gq := BoxMesh.new()
	gq.size = Vector3(0.20, 0.01, 0.60)
	glow.mesh = gq
	glow.position = Vector3(0.0, 8.06, 2.2)
	var led := StandardMaterial3D.new()
	led.albedo_color = Color.BLACK
	led.emission_enabled = true
	led.emission = Color(1.0, 0.90, 0.74)
	led.emission_energy_multiplier = 9.0
	glow.material_override = led
	lamp.add_child(glow)
	var light := SpotLight3D.new()
	light.position = Vector3(0.0, 8.0, 2.2)
	light.rotation.x = deg_to_rad(-90.0)
	light.light_color = Color(1.0, 0.90, 0.74)
	light.light_energy = 70.0
	light.spot_range = 30.0
	light.spot_angle = 68.0
	light.spot_attenuation = 1.0
	light.shadow_enabled = shadows
	lamp.add_child(light)
	var base := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.1
	shape.height = 8.2
	cs.shape = shape
	cs.position.y = 4.1
	base.add_child(cs)
	lamp.add_child(base)
	add_child(lamp)
