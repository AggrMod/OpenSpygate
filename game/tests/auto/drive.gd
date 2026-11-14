extends Node
## Self-playing test: get into the car, drive down the street, steer, brake, get out.
## Passes by writing result.json. The process exit code is not trusted.

var _result: Dictionary = {"test": "drive", "pass": false, "notes": []}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	var scene := get_tree().current_scene
	var player := scene.get("player") as Player
	var car := scene.get("car") as Vehicle
	if player == null or car == null:
		_fail("no player or no car in the scene")
		return
	_result["rest_height"] = snappedf(car.global_position.y, 0.001)
	player.global_position = car.global_position - car.global_basis.x * 1.8
	await get_tree().create_timer(0.2).timeout
	await _shot("01_beside_car", player.camera, car)
	await get_tree().process_frame      # press at the start of a frame, as a real key press arrives
	Input.action_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("interact")
	if car.driver == null:
		car.enter(player)
		(_result["notes"] as Array).append("interact key did not seat the player; entered directly")
	var start := car.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(5.0).timeout
	_result["speed_after_5s_kmh"] = snappedf(car.speed * 3.6, 0.1)
	await _shot("02_driving", null, car)
	Input.action_press("move_left")
	await get_tree().create_timer(1.2).timeout
	Input.action_release("move_left")
	_result["turned_degrees"] = snappedf(rad_to_deg(car.global_basis.z.signed_angle_to(Vector3(-1, 0, 0), Vector3.UP)), 0.1)
	Input.action_release("move_forward")
	Input.action_press("handbrake")
	await get_tree().create_timer(3.5).timeout
	Input.action_release("handbrake")
	_result["metres_driven"] = snappedf(start.distance_to(car.global_position), 0.1)
	_result["stopped_speed"] = snappedf(car.speed, 0.01)
	_result["upright"] = snappedf(car.global_basis.y.y, 0.001)
	_result["fps"] = Engine.get_frames_per_second()
	await _shot("03_stopped", null, car)
	car.leave()
	await get_tree().create_timer(0.3).timeout
	_result["player_out"] = not player.seated
	var ok := true
	if float(_result["metres_driven"]) < 40.0:
		ok = false; (_result["notes"] as Array).append("drove too little")
	if float(_result["upright"]) < 0.95:
		ok = false; (_result["notes"] as Array).append("car is not upright")
	if absf(float(_result["stopped_speed"])) > 0.5:
		ok = false; (_result["notes"] as Array).append("car did not stop")
	if absf(float(_result["rest_height"])) > 0.08:
		ok = false; (_result["notes"] as Array).append("car does not sit at ride height")
	_result["pass"] = ok
	_finish()


func _shot(label: String, _cam: Camera3D, _car: Vehicle) -> void:
	await RenderingServer.frame_post_draw
	if Game.out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(Game.out_dir)
	get_viewport().get_texture().get_image().save_png(Game.out_dir.path_join(label + ".png"))


func _fail(why: String) -> void:
	(_result["notes"] as Array).append(why)
	_finish()


func _finish() -> void:
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var f := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(_result, "  "))
		f.close()
	print("AUTO ", JSON.stringify(_result))
	get_tree().quit(0)
