extends Node
## Self-playing test: the saloon in the void, lit by lights of its own (test only), photographed from all sides,
## then the model file checked against the contract the driving code depends on.
## Passes by writing result.json. The process exit code is not trusted.

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
const REQUIRED_MATERIALS: Array[String] = ["car_paint", "glass", "trim_black", "chrome", "rubber", "alloy", "interior",
		"lamp_head", "lamp_tail", "lamp_brake", "lamp_reverse", "lamp_indicator"]
const LAMP_COLOURS: Dictionary = {
	"lamp_head": Color(1.0, 0.97, 0.92), "lamp_tail": Color(1.0, 0.03, 0.01), "lamp_brake": Color(1.0, 0.02, 0.01),
	"lamp_reverse": Color(1.0, 1.0, 1.0), "lamp_indicator": Color(1.0, 0.45, 0.02),
}
const WHEELS: Dictionary = {          # name: expected centre in the model (x, y, z); front wheels at -z
	"wheel_fl": Vector3(-0.80, 0.335, -1.40), "wheel_fr": Vector3(0.80, 0.335, -1.40),
	"wheel_rl": Vector3(-0.80, 0.335, 1.40), "wheel_rr": Vector3(0.80, 0.335, 1.40),
}
const MAX_TRIANGLES: int = 150000
const MAX_BYTES: int = 4 * 1024 * 1024

var _result: Dictionary = {"test": "car_show", "pass": false, "notes": []}
var _ok: bool = true
var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout       # let the car settle on its springs
	var scene := get_tree().current_scene
	var car := scene.get("car") as Vehicle
	var player := scene.get("player") as Player
	if car == null:
		_fail("no car in the scene")
		return
	_check_model()
	car.freeze = true
	if player != null:
		player.visible = false
	var c := car.global_position
	var f := -car.global_basis.z                        # forward
	var r := car.global_basis.x                         # the car's right
	var up := Vector3.UP
	_add_lights(c, f, r)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.03
	scene.add_child(_cam)
	_cam.make_current()
	await _shot("01_front34", c + f * 4.4 - r * 3.6 + up * 1.35, c + up * 0.62 + f * 0.2)
	await _shot("02_side", c - r * 7.6 + up * 0.85, c + up * 0.72)
	await _shot("03_rear34", c - f * 4.6 + r * 3.4 + up * 1.55, c + up * 0.65 - f * 0.2)
	await _shot("04_wheel_lamp", c + f * 3.1 - r * 2.2 + up * 0.55, c + f * 1.75 - r * 0.85 + up * 0.48, 35.0)
	var cabin := _cabin_light(c, r)
	await _shot("05_interior", c - r * 2.9 + up * 1.32 - f * 0.15, c + up * 0.86 + r * 0.25, 38.0)
	cabin.queue_free()
	_set_lamps(car, true)
	await _shot("06_lamps_rear", c - f * 5.2 - r * 2.4 + up * 1.2, c + up * 0.7 - f * 1.6)
	await _shot("07_lamps_front", c + f * 5.4 + r * 2.0 + up * 1.1, c + up * 0.6 + f * 1.6)
	_set_lamps(car, false)
	# full lock each way on the front left wheel at ride height: the fixed calipers must stay behind the spokes.
	# (Clearance over suspension travel is checked numerically against the model, not here.)
	car.process_mode = Node.PROCESS_MODE_DISABLED
	var wheel := car.get_node("Model").find_child("wheel_fl", true, false) as Node3D
	wheel.position.y = Vehicle.WHEEL_RADIUS
	for lock: Array in [["08_full_lock_in", Vehicle.MAX_STEER], ["09_full_lock_out", -Vehicle.MAX_STEER]]:
		wheel.rotation = Vector3(0.0, lock[1], 0.0)
		await _shot(lock[0], c + f * 2.0 - r * 2.7 + up * 0.5, c + f * 1.4 - r * 0.8 + up * 0.3, 30.0)
	_result["fps"] = Engine.get_frames_per_second()
	_result["pass"] = _ok
	_finish()


## The model file itself, on a fresh copy (the live car moves and spins its wheels).
func _check_model() -> void:
	var holder := Node3D.new()
	holder.visible = false
	get_tree().current_scene.add_child(holder)
	var model := (load(Vehicle.MODEL) as PackedScene).instantiate() as Node3D
	holder.add_child(model)
	var wheels := {}
	for wheel_name: String in WHEELS:
		var node := model.find_child(wheel_name, true, false) as Node3D
		if node == null:
			_bad("missing " + wheel_name)
			continue
		var want: Vector3 = WHEELS[wheel_name]
		var at := node.global_position
		var box := _aabb(node, node.global_transform.affine_inverse())
		var radius := maxf(box.size.y, box.size.z) / 2.0
		wheels[wheel_name] = {"at": [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)],
			"radius": snappedf(radius, 0.001), "width": snappedf(box.size.x, 0.001)}
		if at.distance_to(want) > 0.03:
			_bad("%s at %s, expected about %s" % [wheel_name, at, want])
		if absf(radius - Vehicle.WHEEL_RADIUS) > 0.004:
			_bad("%s radius %.3f, expected %.3f" % [wheel_name, radius, Vehicle.WHEEL_RADIUS])
		if not node.basis.is_equal_approx(Basis.IDENTITY):
			_bad(wheel_name + " has a rotation or scale; the driving code overwrites it every frame")
		if absf(box.get_center().y) > 0.003 or absf(box.get_center().z) > 0.003:
			_bad(wheel_name + " origin is not at the wheel centre")
	_result["wheels"] = wheels
	var body := model.find_child("body", true, false) as Node3D
	var all_box := _aabb(model, Transform3D.IDENTITY)
	var body_box := _aabb(body, Transform3D.IDENTITY) if body != null else AABB()
	_result["size_all_m"] = [snappedf(all_box.size.x, 0.001), snappedf(all_box.size.y, 0.001), snappedf(all_box.size.z, 0.001)]
	_result["size_body_m"] = [snappedf(body_box.size.x, 0.001), snappedf(body_box.size.y, 0.001), snappedf(body_box.size.z, 0.001)]
	if absf(body_box.size.z - 4.70) > 0.06 or absf(body_box.size.x - 1.85) > 0.05 or absf(all_box.size.y - 1.45) > 0.04:
		_bad("overall size is off: body %s, all %s" % [body_box.size, all_box.size])
	if absf(all_box.position.y) > 0.005:
		_bad("the car does not stand on its origin: lowest point y = %.3f" % all_box.position.y)
	if all_box.size.x > 2.20:
		_bad("wider than 2.20 m over the mirrors")
	# how far the body reaches past the driving code's collision box (z = -2.26 .. +2.40); a note, not a failure
	var past_front := -body_box.position.z - 2.26
	var past_rear := body_box.end.z - 2.40
	_result["past_collision_m"] = {"front": snappedf(past_front, 0.001), "rear": snappedf(past_rear, 0.001)}
	if maxf(past_front, past_rear) > 0.10:
		(_result["notes"] as Array).append("body reaches %.2f m (front) and %.2f m (rear) past the collision box" % [past_front, past_rear])
	# triangles and materials
	var tris := 0
	var mats := {}
	var glass_transparent := false
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null:
				mats[mat.resource_name] = true
				if mat.resource_name == "glass" and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					glass_transparent = true
	_result["triangles"] = tris
	_result["materials"] = mats.keys()
	_result["glass_transparent"] = glass_transparent
	if tris > MAX_TRIANGLES:
		_bad("%d triangles, budget %d" % [tris, MAX_TRIANGLES])
	for m: String in REQUIRED_MATERIALS:
		if not mats.has(m):
			_bad("material missing: " + m)
	if not glass_transparent:
		_bad("the glass did not import as transparent")
	var bytes := FileAccess.get_file_as_bytes(Vehicle.MODEL).size()
	_result["glb_bytes"] = bytes
	if bytes == 0 or bytes > MAX_BYTES:
		_bad("glb is %d bytes" % bytes)
	holder.queue_free()


func _aabb(node: Node3D, to_space: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var list: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		list.append(node)
	for mi: MeshInstance3D in list:
		var b := (to_space * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _add_lights(c: Vector3, f: Vector3, r: Vector3) -> void:
	var specs := [   # position offset, energy, colour, range
		[f * 5.0 - r * 4.0 + Vector3.UP * 4.5, 5.0, Color(1.0, 0.97, 0.92)],
		[-f * 5.0 + r * 4.5 + Vector3.UP * 3.5, 3.5, Color(0.85, 0.9, 1.0)],
		[-r * 6.0 - f * 1.0 + Vector3.UP * 2.5, 2.5, Color(1.0, 1.0, 1.0)],
		[r * 6.0 + f * 1.0 + Vector3.UP * 2.5, 2.0, Color(1.0, 1.0, 1.0)],
		[Vector3.UP * 6.0, 3.0, Color(1.0, 1.0, 1.0)],
	]
	for s: Array in specs:
		var l := SpotLight3D.new()
		get_tree().current_scene.add_child(l)
		l.global_position = c + (s[0] as Vector3)
		l.look_at(c + Vector3.UP * 0.6, Vector3.UP if absf((s[0] as Vector3).normalized().y) < 0.99 else Vector3.FORWARD)
		l.light_energy = s[1]
		l.light_color = s[2]
		l.spot_range = 16.0
		l.spot_angle = 40.0
		l.spot_attenuation = 0.6
		l.shadow_enabled = true


## A soft light reaching into the cabin through the far side glass, so the interior can be judged.
func _cabin_light(c: Vector3, r: Vector3) -> SpotLight3D:
	var l := SpotLight3D.new()
	get_tree().current_scene.add_child(l)
	l.global_position = c + r * 3.0 + Vector3.UP * 2.2
	l.look_at(c + Vector3.UP * 0.7 - r * 0.3, Vector3.UP)
	l.light_energy = 6.0
	l.spot_range = 8.0
	l.spot_angle = 30.0
	l.shadow_enabled = true
	return l


func _set_lamps(car: Node3D, on: bool) -> void:
	for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		for s: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null and LAMP_COLOURS.has(mat.resource_name):
				mat.emission_enabled = on
				mat.emission = LAMP_COLOURS[mat.resource_name]
				mat.emission_energy_multiplier = 4.0 if mat.resource_name == "lamp_head" else 2.5


func _shot(label: String, from: Vector3, at: Vector3, fov: float = 40.0) -> void:
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if Game.out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(Game.out_dir)
	get_viewport().get_texture().get_image().save_png(Game.out_dir.path_join(label + ".png"))


func _bad(why: String) -> void:
	_ok = false
	(_result["notes"] as Array).append(why)


func _fail(why: String) -> void:
	(_result["notes"] as Array).append(why)
	_finish()


func _finish() -> void:
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var file := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(_result, "  "))
		file.close()
	print("AUTO ", JSON.stringify(_result))
	get_tree().quit(0)
