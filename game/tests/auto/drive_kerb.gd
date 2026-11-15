extends Node
## Self-playing test: the things town driving does to a car. Mounting the pavement's kerb at an angle must not
## tip it or throw it in the air; stopping hard and pulling away at once must start again in first gear;
## and a look from the driver's seat further down the street, where the street lamps cast no shadows,
## with the rev counter's needle following the engine.
## Passes by writing result.json. The process exit code is not trusted.

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
const KERB_TOP: float = 0.14              # the void street's pavement

var _result: Dictionary = {"test": "drive_kerb", "pass": false, "notes": []}
var _car: Vehicle


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var scene := get_tree().current_scene
	var player := scene.get("player") as Player
	_car = scene.get("car") as Vehicle
	if player == null or _car == null:
		_fail("no player or no car in the scene")
		return
	_car.enter(player)
	# Onto the pavement (its kerb runs along z = 17.5) between two lamp posts, at 40 km/h, at two angles.
	await _kerb("kerb_20deg", Vector3(-150.0, 0.05, 23.5), 20.0, true)
	await _kerb("kerb_55deg", Vector3(-96.0, 0.05, 21.5), 55.0, false)
	await _relaunch()
	await _far_driver_view()
	_release_all()

	var ok := true
	for key: String in ["kerb_20deg", "kerb_55deg"]:
		var k: Dictionary = _result[key]
		if float(k["min_upright"]) < 0.9:
			ok = false; _note("%s: the car leaned to %.3f" % [key, float(k["min_upright"])])
		if float(k["max_height_m"]) > KERB_TOP + 0.35:
			ok = false; _note("%s: the car was thrown %.2f m up" % [key, float(k["max_height_m"])])
		if not bool(k["reached_pavement"]):
			ok = false; _note("%s: the car never got onto the pavement" % key)
	var dial: Array = _result.get("dial", [0.0, 999.0, false])
	var expected := 125.0 - 250.0 * clampf(float(dial[0]) / 8000.0, 0.0, 1.0)
	if not bool(_result.get("stand_in_cabin", true)):
		_note("the model has its own interior, so the stand-in rev counter is not shown and was not checked")
	elif not bool(dial[2]) or absf(float(dial[1]) - expected) > 2.0:
		ok = false; _note("the rev counter's needle does not follow the engine")
	if int(_result.get("relaunch_gear", 0)) != 1:
		ok = false; _note("pulled away again in gear %d" % int(_result.get("relaunch_gear", 0)))
	var a := float(_result.get("relaunch_0_50_s", 99.0))
	var b := float(_result.get("fresh_0_50_s", 0.0))
	if absf(a - b) > 0.4:
		ok = false; _note("0-50 km/h after a hard stop took %.2f s, from fresh %.2f s" % [a, b])
	_result["pass"] = ok
	_finish()


func _kerb(label: String, at: Vector3, angle_deg: float, shoot: bool) -> void:
	var dir := Vector3(cos(deg_to_rad(angle_deg)), 0.0, -sin(deg_to_rad(angle_deg)))
	_release_all()
	_car.place(Transform3D(Basis.looking_at(dir), at))
	_car.camera.activate()
	await get_tree().create_timer(0.4).timeout
	_car.linear_velocity = dir * (40.0 / 3.6)
	Input.action_press("move_forward", 0.35)
	var min_up := 1.0
	var max_y := 0.0
	var on_pavement := false
	var t := 0.0
	var shot := false
	while t < 2.6:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		min_up = minf(min_up, _car.global_basis.y.y)
		max_y = maxf(max_y, _car.global_position.y)
		if _car.global_position.z < 16.5 and _car.global_position.z > 14.8:
			on_pavement = true
			if shoot and not shot:
				shot = true
				await _shot("01_over_the_kerb")
		if _car.global_position.z < 13.0:
			break                                          # off the far side of the pavement
	Input.action_release("move_forward")
	_result[label] = {"min_upright": snappedf(min_up, 0.001), "max_height_m": snappedf(max_y, 0.001), "reached_pavement": on_pavement}
	Input.action_press("move_back")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("move_back")


func _relaunch() -> void:
	_release_all()
	_car.place(Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), Vector3(-150.0, 0.05, 24.2)))
	_car.camera.activate()
	await get_tree().create_timer(0.4).timeout
	_result["fresh_0_50_s"] = await _time_to(50.0)
	await _time_to(110.0)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	while absf(_car.speed) > 0.3:
		await get_tree().physics_frame
	Input.action_release("move_back")
	_result["relaunch_gear"] = _car.gear
	_result["relaunch_0_50_s"] = await _time_to(50.0)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	while absf(_car.speed) > 0.3:
		await get_tree().physics_frame
	Input.action_release("move_back")


## Full throttle until the car reaches kmh; returns the seconds it took.
func _time_to(kmh: float) -> float:
	Input.action_press("move_forward")
	var t := 0.0
	while _car.speed < kmh / 3.6 and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return snappedf(t, 0.01)


func _far_driver_view() -> void:
	_release_all()
	_car.place(Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), Vector3(-135.0, 0.05, 24.2)))
	_car.camera.activate()
	_car.camera.set_view(VehicleCamera.View.DRIVER)
	await get_tree().create_timer(0.6).timeout
	await _shot("02_driver_view_unshadowed_lamps")
	Input.action_press("move_forward")
	await get_tree().create_timer(1.5).timeout
	await _shot("03_driver_view_pulling")
	_result["stand_in_cabin"] = _car.cabin.stand_in
	if _car.cabin.stand_in:
		_result["dial"] = [snappedf(_car.rpm, 1.0), snappedf(rad_to_deg(_car.cabin._needle.rotation.y), 0.1), _car.cabin.visible]     # rpm, needle degrees, cabin shown
	Input.action_release("move_forward")
	_car.camera.set_view(VehicleCamera.View.CHASE)


func _release_all() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "handbrake"]:
		Input.action_release(action)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	if Game.out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(Game.out_dir)
	get_viewport().get_texture().get_image().save_png(Game.out_dir.path_join(label + ".png"))


func _note(text: String) -> void:
	(_result["notes"] as Array).append(text)


func _fail(why: String) -> void:
	_note(why)
	_finish()


func _finish() -> void:
	_release_all()
	_result["fps"] = Engine.get_frames_per_second()
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var f := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(_result, "  "))
		f.close()
	print("AUTO ", JSON.stringify(_result))
	get_tree().quit(0)
