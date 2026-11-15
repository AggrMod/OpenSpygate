class_name VehicleCabin
extends Node3D
## What the driver sees from the seat. The exported body is a closed shell with no interior, so for the
## driver's view this car alone gets: its body shell drawn dark from the inside (roof lining, pillars and door
## cards), see-through glass, and a dashboard and steering wheel built here. Outside the driver's view
## none of it is drawn and the body keeps the materials it was exported with.
## Measurements are a mid-size saloon's: wheel 37 cm across, its centre 55 cm in front of the driver's eye.

const WHEEL_CENTRE: Vector3 = Vector3(-0.36, 0.80, -0.30)
const WHEEL_TILT: float = 0.42            # radians the wheel leans back from upright
const WHEEL_RADIUS: float = 0.185
const STEERING_RATIO: float = 15.0        # turns of the wheel for one of the road wheels

## False when the model brings its own interior (a node named "interior"): then nothing here is built or
## swapped, and the driver's view simply looks out from the model's own seat.
var stand_in: bool = true
var _body: MeshInstance3D
var _overrides: Dictionary = {}           # surface index -> material used in the driver's view
var _wheel_pivot: Node3D
var _needle: Node3D
var _plastic: StandardMaterial3D
var _leather: StandardMaterial3D


func build(model: Node3D) -> void:
	visible = false
	if model.find_child("interior", true, false) != null:
		stand_in = false
		return
	_plastic = StandardMaterial3D.new()
	_plastic.albedo_color = Color(0.020, 0.020, 0.021)
	_plastic.roughness = 0.78
	_leather = StandardMaterial3D.new()
	_leather.albedo_color = Color(0.022, 0.020, 0.019)
	_leather.roughness = 0.62
	_body = model.find_child("body", true, false) as MeshInstance3D
	if _body != null:
		_prepare_shell()
	_build_dashboard()
	_build_wheel()


func _prepare_shell() -> void:
	var lining := StandardMaterial3D.new()
	lining.albedo_color = Color(0.045, 0.043, 0.041)
	lining.roughness = 0.9
	lining.cull_mode = BaseMaterial3D.CULL_FRONT          # only the inside faces of the shell
	for i: int in _body.mesh.get_surface_count():
		var mat := _body.mesh.surface_get_material(i) as BaseMaterial3D
		if mat == null:
			continue
		if mat.resource_name == "car_glass":
			var glass := mat.duplicate() as BaseMaterial3D
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(0.06, 0.07, 0.08, 0.14)
			glass.roughness = 0.02
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			_overrides[i] = glass
		elif mat.resource_name == "car_paint" or mat.resource_name == "car_trim":
			var outside := mat.duplicate() as BaseMaterial3D
			outside.cull_mode = BaseMaterial3D.CULL_BACK
			outside.next_pass = lining
			_overrides[i] = outside


## Switches the driver's view on or off.
func show_cabin(on: bool) -> void:
	visible = on and stand_in
	if _body == null:
		return
	for i: int in _overrides:
		_body.set_surface_override_material(i, _overrides[i] if on else null)


func set_steer(road_angle: float) -> void:
	if _wheel_pivot != null:
		_wheel_pivot.rotation.z = road_angle * STEERING_RATIO


func _build_dashboard() -> void:
	# A profile in (z, y), swept across the cabin: windscreen foot, the top, the brow over the dials, the face.
	var profile: Array[Vector2] = [
		Vector2(-1.02, 0.945), Vector2(-0.85, 0.958), Vector2(-0.68, 0.955), Vector2(-0.56, 0.940),
		Vector2(-0.48, 0.912), Vector2(-0.44, 0.870), Vector2(-0.425, 0.790), Vector2(-0.44, 0.660),
		Vector2(-0.50, 0.540),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.80
	# Smooth normals: each profile point takes the average of the two faces that meet there.
	var normals: Array[Vector3] = []
	for j: int in profile.size():
		var a := profile[maxi(j - 1, 0)]
		var b := profile[mini(j + 1, profile.size() - 1)]
		normals.append(Vector3(0.0, b.x - a.x, -(b.y - a.y)).normalized())      # faces up and toward the driver
	for j: int in profile.size() - 1:
		var a := profile[j]
		var b := profile[j + 1]
		var quad := [
			[Vector3(-half, a.y, a.x), j], [Vector3(half, a.y, a.x), j], [Vector3(half, b.y, b.x), j + 1],
			[Vector3(-half, a.y, a.x), j], [Vector3(half, b.y, b.x), j + 1], [Vector3(-half, b.y, b.x), j + 1],
		]
		for corner: Array in quad:
			st.set_normal(normals[corner[1]])
			st.add_vertex(corner[0])
	# The binnacle: a low hood over the instruments in front of the driver.
	var hood_x := WHEEL_CENTRE.x
	var steps := 10
	for k: int in steps:
		var t0 := PI * float(k) / steps
		var t1 := PI * float(k + 1) / steps
		var p0 := Vector3(hood_x - cos(t0) * 0.20, 0.935 + sin(t0) * 0.050, -0.47)
		var p1 := Vector3(hood_x - cos(t1) * 0.20, 0.935 + sin(t1) * 0.050, -0.47)
		var q0 := Vector3(hood_x - cos(t0) * 0.21, 0.948 + sin(t0) * 0.030, -0.66)
		var q1 := Vector3(hood_x - cos(t1) * 0.21, 0.948 + sin(t1) * 0.030, -0.66)
		var n0 := Vector3(-cos(t0), sin(t0), 0.25).normalized()
		for v: Vector3 in [p0, q0, q1, p0, q1, p1]:
			st.set_normal(n0)
			st.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.name = "Dashboard"
	mesh.mesh = st.commit()
	_plastic.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = _plastic
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	# The rev counter glows faintly under the hood: a ring, a mark for every thousand rpm, and a needle.
	# (No speedometer: there is no speed readout yet.)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color.BLACK
	glow.emission_enabled = true
	glow.emission = Color(0.85, 0.92, 1.0)
	glow.emission_energy_multiplier = 0.35
	var dial := Node3D.new()
	dial.name = "RevCounter"
	dial.position = Vector3(hood_x, 0.858, -0.416)       # on the dashboard's face, seen through the top of the wheel
	dial.rotation.x = deg_to_rad(80.0)                   # the face looks back and a little up, at the driver
	add_child(dial)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.046
	torus.outer_radius = 0.049
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = glow
	dial.add_child(ring)
	for k: int in 9:
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.0018, 0.001, 0.007 if k % 2 == 0 else 0.004)
		mark.mesh = box
		mark.material_override = glow
		var phi := _dial_angle(k * 1000.0)
		mark.position = Vector3(sin(phi), 0.0, -cos(phi)) * 0.040
		mark.rotation.y = -phi
		dial.add_child(mark)
	var needle_glow := StandardMaterial3D.new()
	needle_glow.albedo_color = Color.BLACK
	needle_glow.emission_enabled = true
	needle_glow.emission = Color(1.0, 0.55, 0.25)
	needle_glow.emission_energy_multiplier = 0.9
	_needle = Node3D.new()
	dial.add_child(_needle)
	var needle := MeshInstance3D.new()
	var nbox := BoxMesh.new()
	nbox.size = Vector3(0.0022, 0.0012, 0.038)
	needle.mesh = nbox
	needle.position = Vector3(0.0, 0.0012, -0.015)
	needle.material_override = needle_glow
	_needle.add_child(needle)
	set_rpm(0.0)


## Needle angle from straight up, clockwise as the driver sees it: 0 rpm at lower left, 8000 at lower right.
func _dial_angle(at_rpm: float) -> float:
	return deg_to_rad(-125.0 + 250.0 * clampf(at_rpm / 8000.0, 0.0, 1.0))


func set_rpm(at_rpm: float) -> void:
	if _needle != null:
		_needle.rotation.y = -_dial_angle(at_rpm)


func _build_wheel() -> void:
	var mount := Node3D.new()
	mount.name = "SteeringColumn"
	mount.position = WHEEL_CENTRE
	mount.rotation.x = -WHEEL_TILT
	add_child(mount)
	_wheel_pivot = Node3D.new()
	mount.add_child(_wheel_pivot)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = WHEEL_RADIUS - 0.017
	torus.outer_radius = WHEEL_RADIUS + 0.017
	torus.rings = 48
	torus.ring_segments = 12
	rim.mesh = torus
	rim.rotation.x = PI * 0.5                    # the torus lies flat; stand it up facing the driver
	rim.material_override = _leather
	_wheel_pivot.add_child(rim)
	var hub := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.062
	cyl.bottom_radius = 0.070
	cyl.height = 0.05
	cyl.radial_segments = 24
	hub.mesh = cyl
	hub.rotation.x = PI * 0.5
	hub.position.z = -0.02
	hub.material_override = _plastic
	_wheel_pivot.add_child(hub)
	for angle: float in [0.0, PI, -PI * 0.5]:            # spokes at three, nine and six o'clock
		var spoke := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(WHEEL_RADIUS - 0.06, 0.032, 0.014)
		spoke.mesh = box
		var dir := Vector2(cos(angle), sin(angle))
		var mid := (0.06 + WHEEL_RADIUS) * 0.5
		spoke.position = Vector3(dir.x * mid, dir.y * mid, -0.012)
		spoke.rotation.z = angle
		spoke.material_override = _plastic
		_wheel_pivot.add_child(spoke)
	var column := MeshInstance3D.new()
	var col := CylinderMesh.new()
	col.top_radius = 0.032
	col.bottom_radius = 0.045
	col.height = 0.30
	column.mesh = col
	column.rotation.x = PI * 0.5
	column.position.z = -0.18
	column.material_override = _plastic
	mount.add_child(column)
	for node: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
