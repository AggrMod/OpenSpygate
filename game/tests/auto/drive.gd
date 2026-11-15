extends Node
## Self-playing test: get into the car, drive down the street, steer, brake, get out. Then measure it like a
## road test: rest stability, 0-100 km/h, the gears it reaches, braking distance from 100 km/h, a handbrake turn
## that is caught and ends upright, reverse, and the cameras (orbit, pull-back, ground, driver's view).
## Passes by writing result.json. The process exit code is not trusted.

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
const START_X: float = -150.0             # the west end of the void's 320 m road
const LANE_Z: float = 24.2
const KMH_100: float = 100.0 / 3.6

var _result: Dictionary = {"test": "drive", "pass": false, "notes": []}
var _car: Vehicle
var _cam_low: float = 99.0                # lowest the chase camera came to the ground, metres


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
	_car = car
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
		_note("interact key did not seat the player; entered directly")
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
	# Stop: the handbrake now only locks the rear wheels, so the foot brake (the back key) does most of the
	# work, released as the car stops so that it does not go on into reverse.
	Input.action_press("handbrake")
	Input.action_press("move_back")
	var stop_t := 0.0
	while stop_t < 3.5:
		await get_tree().physics_frame
		stop_t += get_physics_process_delta_time()
		if car.linear_velocity.length() < 0.8:
			Input.action_release("move_back")
	Input.action_release("move_back")
	Input.action_release("handbrake")
	_result["metres_driven"] = snappedf(start.distance_to(car.global_position), 0.1)
	_result["stopped_speed"] = snappedf(car.speed, 0.01)
	_result["upright"] = snappedf(car.global_basis.y.y, 0.001)
	_result["fps"] = Engine.get_frames_per_second()
	await _shot("03_stopped", null, car)
	car.leave()
	await get_tree().create_timer(0.3).timeout
	_result["player_out"] = not player.seated

	# The road test. The driver gets back in and the car is put at the west end of the road each time.
	car.enter(player)
	await _rest_stability()
	await _sprint()
	await _handbrake_turn()
	await _reverse()
	await _rolling_back()
	await _cameras()
	await _limiter()
	await _lamp_materials()
	_release_all()
	_result["camera_lowest_m"] = snappedf(_cam_low, 0.01)
	_judge()
	_finish()


func _judge() -> void:
	var ok := true
	if float(_result["metres_driven"]) < 40.0:
		ok = false; _note("drove too little")
	if float(_result["upright"]) < 0.95:
		ok = false; _note("car is not upright")
	if absf(float(_result["stopped_speed"])) > 0.5:
		ok = false; _note("car did not stop")
	if absf(float(_result["rest_height"])) > 0.08:
		ok = false; _note("car does not sit at ride height")
	var t100 := float(_result.get("zero_to_100_s", 99.0))
	if t100 < 6.5 or t100 > 8.6:
		ok = false; _note("0-100 km/h took %.2f s, wanted about 7 to 8" % t100)
	if int(_result.get("highest_gear", 0)) < 3:
		ok = false; _note("the gearbox did not reach third")
	var stop := float(_result.get("braking_100_m", 99.0))
	if stop < 30.0 or stop > 48.0:
		ok = false; _note("braking from 100 km/h took %.1f m, wanted 30 to 48" % stop)
	if float(_result.get("straight_line_max_yaw_rate", 1.0)) > 0.05:
		ok = false; _note("the car wanders off a straight line under full throttle")
	if float(_result.get("rest_drift_m", 1.0)) > 0.01 or float(_result.get("rest_max_speed", 1.0)) > 0.03:
		ok = false; _note("the car creeps or jitters at rest")
	if float(_result.get("handbrake_yaw_deg", 0.0)) < 45.0:
		ok = false; _note("the handbrake did not swing the tail out")
	if float(_result.get("handbrake_min_upright", 0.0)) < 0.9:
		ok = false; _note("the car leaned too far in the handbrake turn")
	if float(_result.get("handbrake_caught_yaw_rate", 9.0)) > 0.6:
		ok = false; _note("the slide was not caught after the handbrake")
	if float(_result.get("handbrake_yaw_deg", 0.0)) > 150.0 or float(_result.get("handbrake_end_kmh", 0.0)) < 12.0:
		ok = false; _note("the handbrake turn became a spin")
	if int(_result.get("reverse_gear", 0)) != -1 or float(_result.get("reverse_metres", 0.0)) < 3.0:
		ok = false; _note("the car did not reverse")
	if not bool(_result.get("forward_again", false)):
		ok = false; _note("the car did not go back into first after reversing")
	if float(_result.get("rolling_back_top_rpm", 9999.0)) > 1500.0 or int(_result.get("rolling_back_top_gear", 9)) != 1:
		ok = false; _note("rolling backwards in first wound the engine up or changed gear")
	if float(_result.get("rolling_back_decel_ms2", -1.0)) < 0.05:
		ok = false; _note("rolling backwards in first, the car did not slow down")
	if float(_result.get("limiter_top_rpm", 0.0)) < Vehicle.LIMITER_RPM - 100.0 or float(_result.get("limiter_top_rpm", 9999.0)) > Vehicle.LIMITER_RPM + 150.0 or int(_result.get("limiter_cuts", 0)) < 2:
		ok = false; _note("the rev limiter did not hold the engine")
	if float(_result.get("landing_min_upright", 0.0)) < 0.9:
		ok = false; _note("the car tipped on landing")
	if float(_result.get("engine_braking_ms2", 0.0)) < 0.1:
		ok = false; _note("no engine braking when lifting off")
	if float(_result.get("lamp_brake_lit", 0.0)) < 2.9 or not bool(_result.get("lamp_shared_untouched", false)):
		ok = false; _note("a lamp_brake material was not lit for this car alone")
	if _cam_low < 0.3:
		ok = false; _note("the chase camera came within %.2f m of the ground" % _cam_low)
	if float(_result.get("camera_pull_back_m", 0.0)) < 0.8:
		ok = false; _note("the chase camera did not pull back with speed")
	if absf(float(_result.get("camera_orbit_deg", 0.0))) < 60.0 or absf(float(_result.get("camera_returned_deg", 99.0))) > 15.0:
		ok = false; _note("the camera did not orbit and come back behind the car")
	_result["pass"] = ok


func _place(x: float) -> void:
	_release_all()
	_car.place(Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), Vector3(x, 0.05, LANE_Z)))
	_car.camera.activate()
	await get_tree().create_timer(0.5).timeout


func _rest_stability() -> void:
	await _place(START_X)
	await get_tree().create_timer(0.5).timeout
	var origin := _car.global_position
	var max_drift := 0.0
	var max_speed := 0.0
	var max_tilt := 0.0
	var t := 0.0
	while t < 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		max_drift = maxf(max_drift, _car.global_position.distance_to(origin))
		max_speed = maxf(max_speed, _car.linear_velocity.length())
		max_tilt = maxf(max_tilt, _car.angular_velocity.length())
	_result["rest_drift_m"] = snappedf(max_drift, 0.0001)
	_result["rest_max_speed"] = snappedf(max_speed, 0.0001)
	_result["rest_max_turn_rate"] = snappedf(max_tilt, 0.0001)
	_result["idle_rpm"] = snappedf(_car.rpm, 1.0)


func _sprint() -> void:
	# Still at rest from the stability check. Full throttle to 120 km/h, then the brakes.
	var t := 0.0
	var t100 := -1.0
	var top_gear := _car.gear
	var shifts: Array = []
	var last_gear := _car.gear
	var max_rpm := 0.0
	var max_slip := 0.0
	var max_yaw := 0.0
	var trace: Array = []
	var shot_taken := false
	var cam := _car.camera
	var rest_distance := cam.global_position.distance_to(_car.global_position)
	Input.action_press("move_forward")
	while _car.speed < 120.0 / 3.6 and t < 16.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if _car.gear != last_gear:
			shifts.append({"t": snappedf(t, 0.01), "to": _car.gear, "kmh": snappedf(_car.speed * 3.6, 0.1), "rpm": snappedf(_car.rpm, 1.0)})
			last_gear = _car.gear
		top_gear = maxi(top_gear, _car.gear)
		max_rpm = maxf(max_rpm, _car.rpm)
		max_slip = maxf(max_slip, _car.slip)
		max_yaw = maxf(max_yaw, absf(_car.angular_velocity.y))
		if t100 < 0.0 and _car.speed >= KMH_100:
			t100 = t
			_result["camera_pull_back_m"] = snappedf(cam.global_position.distance_to(_car.global_position) - rest_distance, 0.01)
		if int(t * 60.0) % 6 == 0:
			trace.append([snappedf(t, 0.01), snappedf(_car.speed * 3.6, 0.1), _car.gear, snappedf(_car.rpm, 1.0), snappedf(_car.slip, 0.01)])
		if not shot_taken and _car.speed > 22.0:
			shot_taken = true
			await _shot("04_accelerating", null, _car)
		_track_camera()
	Input.action_release("move_forward")
	_result["zero_to_100_s"] = snappedf(t100, 0.01) if t100 > 0.0 else 99.0
	_result["zero_to_120_s"] = snappedf(t, 0.01)
	_result["highest_gear"] = top_gear
	_result["shifts"] = shifts
	_result["max_rpm"] = snappedf(max_rpm, 1.0)
	_result["launch_max_slip"] = snappedf(max_slip, 0.01)
	_result["straight_line_max_yaw_rate"] = snappedf(max_yaw, 0.0001)
	_save_json("sprint_trace.json", trace)
	# Off the throttle for half a second: engine braking and air, no brakes.
	var lift_speed := _car.speed
	var tl := 0.0
	while tl < 0.5:
		await get_tree().physics_frame
		tl += get_physics_process_delta_time()
		_track_camera()
	_result["lift_off_decel_ms2"] = snappedf((lift_speed - _car.speed) / tl, 0.01)
	# What air and rolling alone would take off; the rest is the engine holding the car back.
	var mean_v := (lift_speed + _car.speed) * 0.5
	var passive := Vehicle.AIR_DRAG * mean_v * mean_v / _car.mass + Vehicle.ROLLING * 9.81
	_result["engine_braking_ms2"] = snappedf((lift_speed - _car.speed) / tl - passive, 0.01)
	_result["lift_off_gear"] = _car.gear
	# Full brakes. The distance is measured from the moment the car passes 100 km/h, the brakes already on.
	Input.action_press("move_back")
	var from := Vector3.INF
	var from_speed := 0.0
	var dive := -1.0
	var tb := 0.0
	var lamp_shot := false
	while _car.speed > 0.3 and tb < 8.0:
		await get_tree().physics_frame
		if from == Vector3.INF and _car.speed <= KMH_100:
			from = _car.global_position
			from_speed = _car.speed
		if from != Vector3.INF:
			tb += get_physics_process_delta_time()
		dive = maxf(dive, _car.global_basis.z.y)       # the nose dives: the rear rises
		if not lamp_shot and _car.speed < 20.0:
			lamp_shot = true
			_result["brake_lamps_on_while_braking"] = _car.braking
			await _shot("05_braking", null, _car)
		_track_camera()
	Input.action_release("move_back")
	# Corrected to exactly 100 km/h: distance scales with the square of the starting speed.
	var metres := from.distance_to(_car.global_position) * pow(KMH_100 / maxf(from_speed, 1.0), 2.0)
	_result["braking_100_m"] = snappedf(metres, 0.1)
	_result["braking_100_s"] = snappedf(tb, 0.01)
	_result["braking_nose_dive_deg"] = snappedf(rad_to_deg(asin(clampf(dive, -1.0, 1.0))), 0.01)


func _handbrake_turn() -> void:
	await _place(START_X)
	Input.action_press("move_forward")
	var t := 0.0
	while _car.speed < 60.0 / 3.6 and t < 10.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	var heading := _car.global_basis.z
	var min_up := 1.0
	var max_slip := 0.0
	# Turn right, toward the open side, and pull the handbrake for half a second.
	Input.action_press("move_right")
	Input.action_press("handbrake")
	t = 0.0
	var shot := false
	while t < 0.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		min_up = minf(min_up, _car.global_basis.y.y)
		max_slip = maxf(max_slip, _car.slip)
		if not shot and t > 0.35:
			shot = true
			await _shot("06_handbrake_slide", null, _car)
		_track_camera()
	Input.action_release("handbrake")
	Input.action_release("move_right")
	_result["handbrake_yaw_at_release_deg"] = snappedf(absf(rad_to_deg(heading.signed_angle_to(_car.global_basis.z, Vector3.UP))), 0.1)
	# Catch it: steer into the slide and feed in some throttle, as a driver would.
	Input.action_press("move_left")
	Input.action_press("move_forward")
	t = 0.0
	while t < 0.6:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		min_up = minf(min_up, _car.global_basis.y.y)
		_track_camera()
	Input.action_release("move_left")
	t = 0.0
	var rate := 9.0
	while t < 1.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		min_up = minf(min_up, _car.global_basis.y.y)
		rate = absf(_car.angular_velocity.y)
		_track_camera()
	Input.action_release("move_forward")
	_result["handbrake_yaw_deg"] = snappedf(absf(rad_to_deg(heading.signed_angle_to(_car.global_basis.z, Vector3.UP))), 0.1)
	_result["handbrake_min_upright"] = snappedf(min_up, 0.001)
	_result["handbrake_max_slip"] = snappedf(max_slip, 0.01)
	_result["handbrake_caught_yaw_rate"] = snappedf(rate, 0.01)
	_result["handbrake_end_upright"] = snappedf(_car.global_basis.y.y, 0.001)
	_result["handbrake_end_kmh"] = snappedf(_car.speed * 3.6, 0.1)
	Input.action_press("move_back")
	t = 0.0
	while absf(_car.speed) > 0.5 and t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_back")


func _reverse() -> void:
	await _place(START_X + 40.0)
	var from := _car.global_position
	Input.action_press("move_back")
	var t := 0.0
	var shot := false
	while t < 3.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not shot and t > 2.5:
			shot = true
			await _shot("07_reversing", null, _car)
	Input.action_release("move_back")
	_result["reverse_gear"] = _car.gear
	_result["reverse_kmh"] = snappedf(_car.speed * 3.6, 0.1)
	_result["reverse_metres"] = snappedf((_car.global_position - from).dot(_car.global_basis.z), 0.01)
	# Forward pedal: brakes the backward roll, then first gear.
	Input.action_press("move_forward")
	t = 0.0
	while t < 2.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	_result["forward_again"] = _car.gear == 1 and _car.speed > 1.0


## Rolling tail first in a forward gear with no pedal (as after a spin): the wheels must not wind the engine up,
## the gearbox stays in first, and the engine must not push the car on backwards.
func _rolling_back() -> void:
	await _place(START_X + 120.0)
	_car.linear_velocity = _car.global_basis.z * 10.0
	var v0 := _car.linear_velocity.length()     # (the car's own speed field lags a step behind)
	var top_rpm := 0.0
	var top_gear := 0
	var t := 0.0
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		top_rpm = maxf(top_rpm, _car.rpm)
		top_gear = maxi(top_gear, _car.gear)
	var v1 := _car.linear_velocity.length()
	_result["rolling_back_top_rpm"] = snappedf(top_rpm, 1.0)
	_result["rolling_back_top_gear"] = top_gear
	_result["rolling_back_decel_ms2"] = snappedf((v0 - v1) / t, 0.01)
	await _place(START_X)


func _cameras() -> void:
	await _place(START_X)
	var cam := _car.camera
	# Swing the view round the car with the mouse, and look down from high and up from low.
	for i: int in 30:
		cam.orbit(0.06, 0.0)
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_result["camera_orbit_deg"] = snappedf(_camera_angle(), 0.1)
	await _shot("08_orbit", null, _car)
	for i: int in 20:
		cam.orbit(0.0, -0.05)
		await get_tree().process_frame
		_track_camera()
	await get_tree().create_timer(0.3).timeout
	_track_camera()
	await _shot("09_orbit_low", null, _car)
	await get_tree().create_timer(3.0).timeout
	_result["camera_returned_deg"] = snappedf(_camera_angle(), 0.1)
	# The driver's view, through the action a player presses, under the lamps that cast shadows.
	await _place(-40.0)
	var press := InputEventAction.new()
	press.action = VehicleCamera.ACTION
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = VehicleCamera.ACTION
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().create_timer(0.3).timeout
	_result["driver_view"] = cam.view == VehicleCamera.View.DRIVER
	await _shot("10_driver_view", null, _car)
	Input.action_press("move_forward")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("move_forward")
	await _shot("11_driver_view_moving", null, _car)
	cam.set_view(VehicleCamera.View.CHASE)


## Throttle with the wheels off the ground: the engine must rise to the limiter and be held there.
func _limiter() -> void:
	_release_all()
	_car.place(Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), Vector3(START_X + 60.0, 4.5, 24.2)))
	Input.action_press("move_forward")
	var top := 0.0
	var cuts := 0
	var was_cut := false
	var t := 0.0
	var min_up := 1.0
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		top = maxf(top, _car.rpm)
		var cut := _car.engine_load == 0.0 and _car.rpm > Vehicle.LIMITER_RPM - 300.0
		if cut and not was_cut:
			cuts += 1
		was_cut = cut
		min_up = minf(min_up, _car.global_basis.y.y)
	Input.action_release("move_forward")
	_result["limiter_top_rpm"] = snappedf(top, 1.0)
	_result["limiter_cuts"] = cuts
	_result["landing_min_upright"] = snappedf(min_up, 0.001)
	Input.action_press("move_back")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("move_back")


## The lamp lenses the model may name. A hidden lens called lamp_brake is put on the car: braking must
## light this car's copy of it and leave the shared material alone.
func _lamp_materials() -> void:
	var lens := MeshInstance3D.new()
	lens.mesh = BoxMesh.new()
	lens.visible = false
	var shared := StandardMaterial3D.new()
	shared.resource_name = "lamp_brake"
	shared.emission_enabled = true
	shared.emission = Color(1.0, 0.05, 0.02)
	shared.emission_energy_multiplier = 3.0
	lens.mesh.surface_set_material(0, shared)
	var holder := Node3D.new()
	holder.add_child(lens)
	_car.add_child(holder)
	_car._find_lamp_materials(holder)
	await _place(START_X)
	Input.action_press("move_back")                     # at rest in first: the pedal brakes
	await get_tree().create_timer(0.2).timeout
	var own := lens.get_surface_override_material(0) as StandardMaterial3D
	var lit := own.emission_energy_multiplier if own != null else -1.0
	Input.action_release("move_back")
	_car.handbrake = false
	await get_tree().physics_frame
	await get_tree().process_frame
	_result["lamp_brake_lit"] = snappedf(lit, 0.01)
	_result["lamp_shared_untouched"] = shared.emission_energy_multiplier == 3.0
	holder.queue_free()


## Angle of the camera round the car, from straight behind, in degrees.
func _camera_angle() -> float:
	var behind := _car.global_basis.z
	behind.y = 0.0
	var to_cam := _car.camera.global_position - _car.global_position
	to_cam.y = 0.0
	return rad_to_deg(behind.signed_angle_to(to_cam, Vector3.UP))


func _track_camera() -> void:
	var cam := _car.camera
	if cam.view == VehicleCamera.View.CHASE and cam.current:
		_cam_low = minf(_cam_low, cam.global_position.y)        # the void's floor is at y = 0


func _release_all() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "handbrake"]:
		Input.action_release(action)


func _note(text: String) -> void:
	(_result["notes"] as Array).append(text)


func _save_json(file: String, data: Variant) -> void:
	if Game.out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(Game.out_dir)
	var f := FileAccess.open(Game.out_dir.path_join(file), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _shot(label: String, _cam: Camera3D, _car_unused: Vehicle) -> void:
	await RenderingServer.frame_post_draw
	if Game.out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(Game.out_dir)
	get_viewport().get_texture().get_image().save_png(Game.out_dir.path_join(label + ".png"))


func _fail(why: String) -> void:
	_note(why)
	_finish()


func _finish() -> void:
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var f := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(_result, "  "))
		f.close()
	print("AUTO ", JSON.stringify(_result))
	get_tree().quit(0)
