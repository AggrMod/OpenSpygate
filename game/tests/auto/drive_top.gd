extends Node
## Self-playing test: full throttle from rest until the car stops gaining speed. It must top out at about
## 200 km/h, in a high gear, under the rev limiter, running straight. Then a lane change by key at that speed
## must stay upright and not spin. The run is on the void's floor, west of the 320 m road.
## Passes by writing result.json. The process exit code is not trusted.

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
var _result: Dictionary = {"test": "drive_top", "pass": false, "notes": []}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var scene := get_tree().current_scene
	var player := scene.get("player") as Player
	var car := scene.get("car") as Vehicle
	if player == null or car == null:
		_fail("no player or no car in the scene")
		return
	car.enter(player)
	# The void's floor is a world boundary, which Jolt makes 2 km across: start near its west edge.
	car.place(Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), Vector3(-950.0, 0.05, 24.2)))
	car.camera.activate()
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_forward")
	var t := 0.0
	var top := 0.0
	var gained_at := 0.0
	var max_rpm := 0.0
	var max_yaw := 0.0
	var trace: Array = []
	while t < 45.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if car.speed > top + 0.05:
			top = car.speed
			gained_at = t
		max_rpm = maxf(max_rpm, car.rpm)
		max_yaw = maxf(max_yaw, absf(car.angular_velocity.y))
		if int(t * 60.0) % 30 == 0:
			trace.append([snappedf(t, 0.1), snappedf(car.speed * 3.6, 0.1), car.gear, snappedf(car.rpm, 1.0), snappedf(car.global_position.x, 0.1)])
		if t - gained_at > 3.0 and t > 15.0:
			break                                          # no more speed for three seconds: this is the top
	_result["top_speed_kmh"] = snappedf(top * 3.6, 0.1)
	_result["seconds_to_top"] = snappedf(gained_at, 0.1)
	_result["gear_at_top"] = car.gear
	_result["rpm_at_top"] = snappedf(car.rpm, 1.0)
	_result["max_rpm"] = snappedf(max_rpm, 1.0)
	_result["max_yaw_rate"] = snappedf(max_yaw, 0.0001)
	_result["trace"] = trace
	await _shot("01_top_speed")
	# A lane change at speed: a quarter of a second each way.
	var min_up := 1.0
	var heading := car.global_basis.z
	var lane: Array = []
	for step: Array in [["move_left", 0.25], ["move_right", 0.25], ["", 1.5]]:
		if step[0] != "":
			Input.action_press(step[0])
		var s := 0.0
		while s < float(step[1]):
			await get_tree().physics_frame
			s += get_physics_process_delta_time()
			min_up = minf(min_up, car.global_basis.y.y)
			lane.append([snappedf(rad_to_deg(heading.signed_angle_to(car.global_basis.z, Vector3.UP)), 0.01), snappedf(car._steer, 0.0001), snappedf(car.angular_velocity.y, 0.001), snappedf(car.slip, 0.01), snappedf(car.steer_input, 0.1)])
		if step[0] != "":
			Input.action_release(step[0])
	Input.action_release("move_forward")
	_result["lane_change_min_upright"] = snappedf(min_up, 0.001)
	_result["lane_trace"] = lane
	_result["lane_change_heading_deg"] = snappedf(absf(rad_to_deg(heading.signed_angle_to(car.global_basis.z, Vector3.UP))), 0.1)
	_result["lane_change_end_kmh"] = snappedf(car.speed * 3.6, 0.1)
	Input.action_press("move_back")
	await get_tree().create_timer(4.0).timeout
	Input.action_release("move_back")
	_result["fps"] = Engine.get_frames_per_second()

	var ok := true
	var kmh := float(_result["top_speed_kmh"])
	if kmh < 190.0 or kmh > 206.0:
		ok = false; _note("top speed %.1f km/h, wanted about 200" % kmh)
	if int(_result["gear_at_top"]) < 4:
		ok = false; _note("top speed reached in gear %d" % int(_result["gear_at_top"]))
	if float(_result["max_rpm"]) > Vehicle.LIMITER_RPM + 150.0:
		ok = false; _note("the engine went past the limiter")
	if float(_result["max_yaw_rate"]) > 0.05:
		ok = false; _note("the car wandered on the straight")
	if float(_result["lane_change_min_upright"]) < 0.9:
		ok = false; _note("the car leaned too far in the lane change")
	if float(_result["lane_change_heading_deg"]) > 15.0:
		ok = false; _note("the lane change ended %.1f degrees off the original heading" % float(_result["lane_change_heading_deg"]))
	_result["pass"] = ok
	_finish()


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
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "handbrake"]:
		Input.action_release(action)
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var f := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(_result, "  "))
		f.close()
	print("AUTO ", JSON.stringify(_result))
	get_tree().quit(0)
