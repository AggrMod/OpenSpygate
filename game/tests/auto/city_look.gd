extends Node
## Self-playing test: set pictures of the city for judging by eye. Eye-level street views at noon, golden hour,
## dusk and night, dry and wet; the signalled junction; a close-up of the road and kerb; views from 50 m and
## from high above. Records frames per second and draw calls for each. Passes by writing result.json.
## Run a single picture with --shot=<name> (several: --shot=a,b).

const WORLD: String = "city"
const SETTLE: float = 1.1              # seconds per picture: the sky's reflections and the frame rate settle
const MEASURE: float = 1.0             # then frames are counted over this many seconds

## name, camera position, look-at point, hour, wetness
const SHOTS: Array = [
	["street_noon", Vector3(-75.0, 1.65, 7.4), Vector3(0.0, 1.4, 2.0), 12.5, 0.0],
	["street_golden", Vector3(-15.0, 1.65, 7.4), Vector3(-100.0, 1.0, 1.0), 18.8, 0.0],
	["street_dusk", Vector3(-75.0, 1.65, 7.4), Vector3(0.0, 1.4, 2.0), 19.6, 0.0],
	["street_dusk_wet", Vector3(-75.0, 1.65, 7.4), Vector3(0.0, 1.4, 2.0), 19.6, 1.0],
	["street_night", Vector3(-75.0, 1.65, 7.4), Vector3(0.0, 1.4, 2.0), 23.0, 0.0],
	["street_night_wet", Vector3(-75.0, 1.65, 7.4), Vector3(0.0, 1.4, 2.0), 23.0, 1.0],
	["street_noon_wet", Vector3(-15.0, 1.65, 7.4), Vector3(-100.0, 1.0, 1.0), 12.5, 0.8],
	["junction_noon", Vector3(-22.0, 1.65, 8.0), Vector3(0.0, 3.2, 0.0), 12.5, 0.0],
	["junction_dusk", Vector3(-22.0, 1.65, 8.0), Vector3(0.0, 3.2, 0.0), 19.6, 0.0],
	["kerb_closeup", Vector3(-35.0, 1.0, 7.0), Vector3(-33.2, 0.0, 4.6), 12.5, 0.0],
	["signal_driver", Vector3(-24.0, 1.3, 1.65), Vector3(7.45, 5.6, 1.0), 19.6, 0.0],
	["signal_closeup", Vector3(-14.0, 1.65, 3.0), Vector3(7.45, 5.9, 3.6), 17.0, 0.0],
	["crossing_1m", Vector3(-9.0, 1.0, 14.9), Vector3(-2.0, 0.0, 11.4), 16.0, 0.0],
	["ramp_corner", Vector3(8.6, 1.0, -6.2), Vector3(5.6, 0.0, -12.4), 16.0, 0.0],
	["corner_above", Vector3(-15.0, 7.0, 17.0), Vector3(-8.0, 0.0, 9.0), 15.0, 0.0],
	["view_50m", Vector3(-95.0, 28.0, 45.0), Vector3(-40.0, 0.0, 0.0), 16.0, 0.0],
	["view_50m_night", Vector3(-95.0, 28.0, 45.0), Vector3(-40.0, 0.0, 0.0), 23.0, 0.0],
	["overview", Vector3(-190.0, 120.0, 170.0), Vector3(0.0, 0.0, 0.0), 12.5, 0.0],
]

var _result: Dictionary = {"test": "city_look", "pass": false, "notes": [], "shots": {}}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var scene := get_tree().current_scene
	var sky := scene.get("sky") as CitySky
	var roads := scene.get("roads") as CityRoads
	if sky == null or roads == null:
		_fail("no sky or roads in the scene")
		return
	# The hour and wetness come from --hour and --wet, and the time key moves it on by one hour, smoothly.
	_result["start_hour"] = snappedf(sky.hour, 0.001)
	_result["start_wet"] = snappedf(roads.wetness, 0.001)
	if absf(roads.wetness - Game.start_wet) > 0.001:
		_fail("the streets did not start at the --wet given")
		return
	if absf(sky.hour - Game.start_hour) > 0.01:
		_fail("the sky did not start at the --hour given (%.2f, wanted %.2f)" % [sky.hour, Game.start_hour])
		return
	var signals := [0]
	sky.night_changed.connect(func(_amount: float) -> void: signals[0] += 1)
	var before := sky.hour
	await get_tree().process_frame      # press at the start of a frame, as a real key press arrives
	Input.action_press("time_forward")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("time_forward")
	await get_tree().create_timer(0.5).timeout
	var mid := sky.hour
	await get_tree().create_timer(1.5).timeout
	var moved := fposmod(sky.hour - before, 24.0)
	_result["time_key"] = {"before": snappedf(before, 0.001), "half_way": snappedf(mid, 0.001), "after": snappedf(sky.hour, 0.001)}
	if absf(moved - 1.0) > 0.02 or absf(mid - before) < 0.05 or absf(mid - before) > 0.95:
		_fail("the time key did not move the clock on smoothly by one hour")
		return
	var only: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			only = arg.trim_prefix("--shot=").split(",")
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 420.0
	scene.add_child(cam)
	cam.make_current()
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var nights: Dictionary = {}
	var worst_fps := 1000.0
	for shot: Array in SHOTS:
		var shot_name: String = shot[0]
		if not only.is_empty() and not only.has(shot_name):
			continue
		sky.hour = shot[3]
		roads.set_wetness(shot[4])
		cam.global_position = shot[1]
		cam.look_at(shot[2], Vector3.UP)
		await get_tree().create_timer(SETTLE).timeout
		# Count frames over a measuring window after the view has settled (the engine's own figure averages in
		# the hitch of changing hour and wetness, which re-renders the sky's reflections).
		var frames := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < int(MEASURE * 1000000.0):
			await get_tree().process_frame
			frames += 1
		var fps := snappedf(frames / ((Time.get_ticks_usec() - t0) / 1000000.0), 0.1)
		var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		await RenderingServer.frame_post_draw
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_save(shot_name)
		var furn := scene.get("furniture") as CityFurniture
		var lamps_on := 0
		if furn != null:
			for l: SpotLight3D in furn.lamps:
				lamps_on += int(l.visible)
		(_result["shots"] as Dictionary)[shot_name] = {"lamps_on": "%d/%d" % [lamps_on, furn.lamps.size() if furn != null else 0], "fps": fps, "gpu_ms": snappedf(gpu_ms, 0.01), "render_cpu_ms": snappedf(cpu_ms, 0.01), "draw_calls": draws, "primitives": prims, "hour": shot[3], "wet": shot[4], "night": snappedf(sky.night, 0.001)}
		nights[shot[3]] = sky.night
		worst_fps = minf(worst_fps, fps)
	_result["worst_fps"] = worst_fps
	var furniture := scene.get("furniture") as CityFurniture
	if furniture != null:
		_result["furniture_counts"] = furniture.counts
	_result["night_changed_signals"] = signals[0]
	var ok := true
	if nights.has(12.5) and float(nights[12.5]) > 0.01:
		ok = false; (_result["notes"] as Array).append("it is not day at noon")
	if nights.has(18.8) and float(nights[18.8]) > 0.05:
		ok = false; (_result["notes"] as Array).append("night has started at golden hour")
	if nights.has(19.6) and float(nights[19.6]) < 0.3:
		ok = false; (_result["notes"] as Array).append("the lamps would not be on at dusk")
	if nights.has(23.0) and float(nights[23.0]) < 0.99:
		ok = false; (_result["notes"] as Array).append("it is not night at 23:00")
	if (_result["shots"] as Dictionary).size() > 2 and int(signals[0]) < 2:
		ok = false; (_result["notes"] as Array).append("night_changed was not emitted as the hour changed")
	if worst_fps < 60.0:
		(_result["notes"] as Array).append("below 60 fps in at least one view (the machine is shared; see each shot)")
	_result["pass"] = ok and (_result["shots"] as Dictionary).size() > 0
	_finish()


func _save(label: String) -> void:
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
