extends Node
## Self-playing test: drive a lap round the block south-west of the centre junction, four right turns, keeping
## to the right-hand lane, by pressing the same keys a player would (steering and throttle as analogue strength).
## Checks the car never touches anything, stays upright and stays on the carriageway. Passes by writing result.json.

const WORLD: String = "city"
const LOOKAHEAD: float = 7.0
const STRAIGHT_SPEED: float = 12.0       # metres per second (43 km/h), a town speed
const CORNER_SPEED: float = 5.5
const TIME_LIMIT: float = 75.0

var _result: Dictionary = {"test": "city_drive", "pass": false, "notes": []}
var _path: PackedVector2Array = PackedVector2Array()
var _corners: Array[Vector2] = []


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
	car.enter(player)
	car.contact_monitor = true            # test-only: report anything the body touches
	car.max_contacts_reported = 8
	_build_path(car.global_position)
	var hits: Array[String] = []
	var min_up := 1.0
	var min_kerb_gap := 99.0
	var max_y := -9.0
	var t := 0.0
	var idx := 0
	var shots := 0
	var corner_hit := 0
	while t < TIME_LIMIT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var p := Vector2(car.global_position.x, car.global_position.z)
		# advance along the path
		while idx < _path.size() - 1 and _path[idx].distance_to(p) < LOOKAHEAD:
			idx += 1
		if idx >= _path.size() - 1 and p.distance_to(_path[_path.size() - 1]) < 3.0:
			break
		var target := _path[idx]
		var fwd := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
		var to := (target - p).normalized()
		var err := fwd.angle_to(to)           # positive: target is to the right in x/z (clockwise)
		var steer := clampf(-err * 2.2, -1.0, 1.0)
		var near_corner := false
		for c: Vector2 in _corners:
			if p.distance_to(c) < 22.0:
				near_corner = true
		var want := CORNER_SPEED if near_corner else STRAIGHT_SPEED
		var throttle := clampf((want - car.speed) * 0.35, -1.0, 1.0)
		_press("move_left", maxf(steer, 0.0))
		_press("move_right", maxf(-steer, 0.0))
		_press("move_forward", maxf(throttle, 0.0))
		_press("move_back", maxf(-throttle, 0.0) if car.speed > 0.5 else 0.0)
		for body: Node in car.get_colliding_bodies():
			if not hits.has(body.name):
				hits.append(body.name)
		min_up = minf(min_up, car.global_basis.y.y)
		max_y = maxf(max_y, car.global_position.y)
		min_kerb_gap = minf(min_kerb_gap, _kerb_gap(car))
		if corner_hit < _corners.size() and p.distance_to(_corners[corner_hit]) < 9.0:
			corner_hit += 1
			if shots < 2:
				shots += 1
				await _shot("0%d_corner" % shots)
	for a: String in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	Input.action_press("handbrake")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("handbrake")
	await _shot("03_back_at_start")
	var end := Vector2(car.global_position.x, car.global_position.z)
	_result["seconds"] = snappedf(t, 0.1)
	_result["corners_passed"] = corner_hit
	_result["touched"] = hits
	_result["min_upright"] = snappedf(min_up, 0.001)
	_result["max_body_y"] = snappedf(max_y, 0.001)
	_result["min_gap_to_kerb_m"] = snappedf(min_kerb_gap, 0.01)
	_result["end_distance_to_finish"] = snappedf(end.distance_to(_path[_path.size() - 1]), 0.1)
	_result["fps"] = Engine.get_frames_per_second()
	var ok := true
	if corner_hit < 4:
		ok = false; (_result["notes"] as Array).append("did not get round all four corners")
	if not hits.is_empty():
		ok = false; (_result["notes"] as Array).append("the car touched something: " + ", ".join(hits))
	if min_up < 0.95:
		ok = false; (_result["notes"] as Array).append("the car tipped")
	if min_kerb_gap < 0.2:
		ok = false; (_result["notes"] as Array).append("a wheel ran onto the kerb or pavement")
	if max_y > 0.12:
		ok = false; (_result["notes"] as Array).append("the car rose off the carriageway")
	if t >= TIME_LIMIT:
		ok = false; (_result["notes"] as Array).append("ran out of time")
	_result["pass"] = ok
	_finish()


## The lap: out of the parking bay into the eastbound lane of Corder St, right into Tanner Ave, right into
## Lisle St, right into Halloway Ave, right into Corder St again and back past the start.
func _build_path(start3: Vector3) -> void:
	var lane := CityRoads.LANE / 2.0
	var west := CityRoads.ns_x(0)
	var east := CityRoads.ns_x(1)
	var north := CityRoads.ew_z(1)
	var south := CityRoads.ew_z(2)
	var start := Vector2(start3.x, start3.z)
	# centre lines of the lap's lanes, driven clockwise (as seen from above, with -Z north)
	var pts: Array[Vector2] = [start, Vector2(start.x + 12.0, north + lane)]
	var radius := CityRoads.CORNER_R + CityRoads.HALF_ROAD - lane
	var corner_specs: Array = [
		[Vector2(east - lane, north + lane), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(east - lane, south - lane), Vector2(0, 1), Vector2(-1, 0)],
		[Vector2(west + lane, south - lane), Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(west + lane, north + lane), Vector2(0, -1), Vector2(1, 0)],
	]
	for spec: Array in corner_specs:
		var k: Vector2 = spec[0]
		var din: Vector2 = spec[1]
		var dout: Vector2 = spec[2]
		_corners.append(k)
		# the arc's centre sits inside the corner, 'radius' back from both lanes
		var c := k - din * radius + dout * radius
		var a0 := (k - din * radius - c).angle()
		for s: int in 9:
			var a := a0 + float(s) / 8.0 * (PI / 2.0)
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
	pts.append(Vector2(start.x + 30.0, north + lane))
	# densify into points every metre
	for k: int in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := maxi(1, int(a.distance_to(b)))
		for s: int in n:
			_path.append(a.lerp(b, float(s) / n))
	_path.append(pts[pts.size() - 1])


## Distance from the nearest wheel to the nearest kerb face (negative if over it).
func _kerb_gap(car: Vehicle) -> float:
	var best := 99.0
	for corner: Vector3 in [Vector3(-0.8, 0, -1.4), Vector3(0.8, 0, -1.4), Vector3(-0.8, 0, 1.4), Vector3(0.8, 0, 1.4)]:
		var w := car.global_transform * corner
		var ox := absf(w.x - roundf(w.x / CityRoads.PITCH_X) * CityRoads.PITCH_X)
		var oz := absf(w.z - roundf(w.z / CityRoads.PITCH_Z) * CityRoads.PITCH_Z)
		var gap := 99.0
		if ox > CityRoads.HALF_ROAD + CityRoads.CORNER_R:
			gap = CityRoads.HALF_ROAD - oz
		elif oz > CityRoads.HALF_ROAD + CityRoads.CORNER_R:
			gap = CityRoads.HALF_ROAD - ox
		else:
			# in a junction: distance to the corner kerb arc
			var c := Vector2(CityRoads.HALF_ROAD + CityRoads.CORNER_R, CityRoads.HALF_ROAD + CityRoads.CORNER_R)
			var d := Vector2(ox, oz).distance_to(c) - CityRoads.CORNER_R
			if ox > CityRoads.HALF_ROAD and oz > CityRoads.HALF_ROAD:
				gap = d
		best = minf(best, gap)
	return best


func _press(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _shot(label: String) -> void:
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
