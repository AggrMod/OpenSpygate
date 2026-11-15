extends Node
## Self-playing test: walk the city. Along a pavement, down a dropped kerb, over a marked crossing and up the
## far side; step up a kerb from the road; try to walk off the pavement into an unbuilt lot and off the edge of
## the world. Checks the kerb has collision where it stands, the player never falls through, and the
## building lots cover every block exactly. Passes by writing result.json.

const WORLD: String = "city"

var _result: Dictionary = {"test": "city_walk", "pass": false, "notes": []}
var _player: Player
var _lowest: float = 100.0
var _ok: bool = true


func _ready() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _player != null:
		_lowest = minf(_lowest, _player.global_position.y)


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var scene := get_tree().current_scene
	_player = scene.get("player") as Player
	var roads := scene.get("roads") as CityRoads
	if _player == null or roads == null:
		_fail("no player or roads in the scene")
		return
	_check_lots(roads)

	# 1. Standing on the pavement where the game starts.
	await get_tree().create_timer(0.5).timeout
	_result["spawn_y"] = snappedf(_player.global_position.y, 0.001)
	_expect(absf(_player.global_position.y - CityRoads.KERB_H) < 0.03, "player does not stand on the pavement at the start")
	await _shot("01_start")

	# 2. Along the pavement, eastward.
	var p0 := _player.global_position
	await _walk(-PI / 2.0, 4.0, false)
	var moved := p0.distance_to(_player.global_position)
	_result["pavement_metres"] = snappedf(moved, 0.01)
	_expect(absf(moved - Player.WALK_SPEED * 4.0) < 0.8, "walked %.2f m along the pavement, expected about %.1f" % [moved, Player.WALK_SPEED * 4.0])
	_expect(absf(_player.global_position.y - CityRoads.KERB_H) < 0.03, "left the pavement surface while walking along it")

	# 3. Kerb collision: rays find the road, the kerb and the pavement at the right heights.
	var heights := {}
	for probe: Array in [["road", 2.0], ["gutter", 5.2], ["pavement", 7.5]]:
		var hit := _ray_down(Vector3(-40.0, 2.0, probe[1]))
		heights[probe[0]] = snappedf(float(hit.get("position", Vector3(0, -99, 0)).y), 0.001)
	_result["ground_heights"] = heights
	_expect(absf(float(heights["road"])) < 0.02, "road surface is not at y = 0")
	_expect(absf(float(heights["pavement"]) - CityRoads.KERB_H) < 0.02, "pavement surface is not at kerb height")

	# 4. Step up a kerb from the road: stand in the parking lane, walk at the kerb.
	_player.global_position = Vector3(-40.0, 0.05, 3.8)
	_player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.4).timeout
	var on_road_y := _player.global_position.y
	await _walk(PI, 2.5, false)            # facing +Z, toward the south kerb
	_result["kerb_step"] = {"from_y": snappedf(on_road_y, 0.001), "to_y": snappedf(_player.global_position.y, 0.001), "z": snappedf(_player.global_position.z, 0.01)}
	_expect(absf(on_road_y) < 0.03, "player did not stand on the road")
	_expect(_player.global_position.y > CityRoads.KERB_H - 0.03 and _player.global_position.z > CityRoads.HALF_ROAD + 0.2, "could not step up the kerb onto the pavement")
	await _shot("02_up_the_kerb")

	# 5. A marked crossing at the centre junction: down the dropped kerb, across Tanner Ave, up the far side.
	var cz := -CityRoads.CROSSING_AT
	_player.global_position = Vector3(-8.5, CityRoads.KERB_H + 0.05, cz)
	_player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.4).timeout
	var profile: Array = []
	var start_x := _player.global_position.x
	_player.rotation.y = -PI / 2.0
	Input.action_press("move_forward")
	var t := 0.0
	while t < 12.0 and _player.global_position.x < 8.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if profile.is_empty() or _player.global_position.x - float(profile[-1][0]) > 0.5:
			profile.append([snappedf(_player.global_position.x, 0.01), snappedf(_player.global_position.y, 0.001)])
		if absf(_player.global_position.x) < 0.2 and not _result.has("crossing_mid_shot"):
			_result["crossing_mid_shot"] = true
	Input.action_release("move_forward")
	_result["crossing_profile"] = profile
	var min_y := 9.0
	for s: Array in profile:
		min_y = minf(min_y, float(s[1]))
	_expect(_player.global_position.x >= 8.4, "did not get across the crossing (stopped at x = %.2f, from %.2f)" % [_player.global_position.x, start_x])
	_expect(min_y < 0.03, "the crossing did not go down to the road")
	_expect(absf(_player.global_position.y - CityRoads.KERB_H) < 0.04, "did not come back up onto the far pavement")
	await _shot("03_across")

	# 6. Walk into an empty lot: the barrier must hold at the back of the pavement.
	_player.global_position = Vector3(-30.0, CityRoads.KERB_H + 0.05, 7.5)
	await get_tree().create_timer(0.3).timeout
	await _walk(PI, 3.0, true)
	var back := CityRoads.HALF_ROAD + CityRoads.PAVEMENT
	_result["lot_stop_z"] = snappedf(_player.global_position.z, 0.01)
	_expect(_player.global_position.z < back + 0.05, "walked off the pavement into an unbuilt lot")

	# 7. Walk off the edge of the world: the outer pavement ends in a barrier too.
	_player.global_position = Vector3(-40.0, CityRoads.KERB_H + 0.05, -CityRoads.Z_KERB - 1.5)
	await get_tree().create_timer(0.3).timeout
	await _walk(0.0, 3.0, true)
	_result["edge_stop_z"] = snappedf(_player.global_position.z, 0.01)
	_expect(_player.global_position.z > -CityRoads.Z_EDGE - 0.05, "walked off the edge of the built world")

	_result["lowest_y"] = snappedf(_lowest, 0.001)
	_expect(_lowest > -0.1, "the player fell below the ground (lowest y %.3f)" % _lowest)
	_result["pass"] = _ok
	_finish()


func _check_lots(roads: CityRoads) -> void:
	var lots := roads.lots()
	_result["lot_count"] = lots.size()
	var per_row: Dictionary = {}
	var corner_sides := 0
	for lot: Dictionary in lots:
		var w: float = lot["width"]
		if w < CityRoads.LOT_MIN - 0.001 or w > CityRoads.LOT_MAX + 0.001:
			_expect(false, "lot width %.2f out of range" % w)
		if absf(float(lot["depth"]) - CityRoads.LOT_DEPTH) > 0.001:
			_expect(false, "lot depth is not 30 m")
		var xf: Transform3D = lot["transform"]
		_expect(absf(xf.origin.y - CityRoads.KERB_H) < 0.001, "lot origin not at pavement level")
		var key := "%d_%d" % [int(lot["block"]), int(signf(xf.basis.z.z))]
		var acc: Array = per_row.get(key, [0.0, []])
		acc[0] = float(acc[0]) + w
		# the lot's span along x in world space
		var a := (xf * Vector3(-w / 2.0, 0.0, 0.0)).x
		var b := (xf * Vector3(w / 2.0, 0.0, 0.0)).x
		(acc[1] as Array).append([minf(a, b), maxf(a, b)])
		per_row[key] = acc
		corner_sides += int(bool(lot["open_neg_x"])) + int(bool(lot["open_pos_x"]))
		# the street side of the lot must face a street: a point 5 m in front of the lot is on the carriageway
		var front := xf * Vector3(0.0, 0.0, CityRoads.PAVEMENT + 2.0)
		var off_x := absf(front.x - roundf(front.x / CityRoads.PITCH_X) * CityRoads.PITCH_X)
		var off_z := absf(front.z - roundf(front.z / CityRoads.PITCH_Z) * CityRoads.PITCH_Z)
		_expect(minf(off_x, off_z) < CityRoads.HALF_ROAD, "a lot does not face a street")
	_result["lot_rows"] = per_row.size()
	_result["corner_open_sides"] = corner_sides
	_expect(per_row.size() == 8, "expected 8 rows of lots (4 blocks x 2)")
	_expect(corner_sides == 16, "expected 16 street-facing lot sides (4 corners x 4 blocks)")
	for key: String in per_row:
		var acc: Array = per_row[key]
		_expect(absf(float(acc[0]) - CityRoads.BLOCK_X) < 0.01, "row %s widths add up to %.2f, not 90" % [key, float(acc[0])])
		var spans: Array = acc[1]
		spans.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		for k: int in spans.size() - 1:
			_expect(absf(float(spans[k][1]) - float(spans[k + 1][0])) < 0.01, "lots in row %s overlap or leave a gap" % key)


func _walk(yaw: float, seconds: float, fast: bool) -> void:
	_player.rotation.y = yaw
	if fast:
		Input.action_press("walk_fast")
	Input.action_press("move_forward")
	await get_tree().create_timer(seconds).timeout
	Input.action_release("move_forward")
	Input.action_release("walk_fast")
	await get_tree().create_timer(0.4).timeout


func _ray_down(from: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0)
	q.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(q)


func _expect(cond: bool, why: String) -> void:
	if not cond:
		_ok = false
		(_result["notes"] as Array).append(why)


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
