extends Node
## Self-playing test: start in the void, walk toward the door, take pictures on the way.
## Passes by writing result.json. The process exit code is not trusted.

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
const WALK_SECONDS: float = 4.0

var _result: Dictionary = {"test": "void_walk", "pass": false, "notes": []}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var scene := get_tree().current_scene
	var player := scene.get("player") as Player
	if player == null:
		_fail("no player in the scene")
		return
	var start := player.global_position
	_result["door_present"] = scene.get("door") != null
	await _shot("01_start")
	Input.action_press("move_forward")
	await get_tree().create_timer(WALK_SECONDS).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.4).timeout
	await _shot("02_closer")
	var moved := start.distance_to(player.global_position)
	_result["metres_walked"] = snappedf(moved, 0.01)
	_result["fps"] = Engine.get_frames_per_second()
	var expected := Player.WALK_SPEED * WALK_SECONDS
	if absf(moved - expected) > 0.6:
		_fail("walked %.2f m, expected about %.2f m" % [moved, expected])
		return
	if player.global_position.y > 0.05 or player.global_position.y < -0.05:
		_fail("player left the floor: y = %.3f" % player.global_position.y)
		return
	_result["pass"] = true
	_finish()


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
