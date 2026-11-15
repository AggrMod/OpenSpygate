extends Node
## Session-wide state. Also sets up input actions in code (so the project file stays readable),
## picks the world to start in, and starts a self-playing test when the game is run with
## `-- --auto=<name> --out=<dir>`.
##
## User arguments (after `--` on the command line):
##   --world=city|void   which world to start in. The default is the city.
##   --hour=<0..24>      time of day in the city (default 18.5, early evening).
##   --wet=<0..1>        how wet the streets are (0 dry, 1 just after rain).
##   --auto=<name>       run the self-playing test tests/auto/<name>.gd.
##   --out=<dir>         where a test writes result.json and its pictures.
##
## How a test picks its world: a test script may declare `const WORLD: String = "void"` (or "city").
## A --world argument on the command line overrides it; a test without the constant runs in whatever scene was
## started, which is the city (the main scene) when the game is run normally. So `--auto=drive` drives in the city and `--auto=drive --world=void` drives in the void.

const ACTIONS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"walk_fast": [KEY_SHIFT],
	"interact": [KEY_E],
	"handbrake": [KEY_SPACE],
	"release_mouse": [KEY_ESCAPE],
	"time_forward": [KEY_T],
}

const WORLDS: Dictionary = {
	"city": "res://worlds/city/city.tscn",
	"void": "res://worlds/void/void.tscn",
}
const DEFAULT_WORLD: String = "city"

var auto_name: String = ""
var out_dir: String = ""
var world: String = DEFAULT_WORLD
var start_hour: float = 18.5
var start_wet: float = 0.0
var _world_chosen: bool = false     # true when --world or a test's WORLD constant asked for a world


func _enter_tree() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
	var world_arg := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--auto="):
			auto_name = arg.trim_prefix("--auto=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--world="):
			world_arg = arg.trim_prefix("--world=")
		elif arg.begins_with("--hour="):
			start_hour = fposmod(arg.trim_prefix("--hour=").to_float(), 24.0)
		elif arg.begins_with("--wet="):
			start_wet = clampf(arg.trim_prefix("--wet=").to_float(), 0.0, 1.0)
	if world_arg == "" and auto_name != "":
		var path := "res://tests/auto/%s.gd" % auto_name
		if ResourceLoader.exists(path):
			var script := load(path) as GDScript
			world_arg = str(script.get_script_constant_map().get("WORLD", ""))
	if world_arg != "":
		if WORLDS.has(world_arg):
			world = world_arg
			_world_chosen = true
		else:
			push_error("No such world: %s (known: %s)" % [world_arg, ", ".join(WORLDS.keys())])


func _ready() -> void:
	_enter_world.call_deferred()
	if auto_name != "":
		var path := "res://tests/auto/%s.gd" % auto_name
		if not ResourceLoader.exists(path):
			push_error("No such self-playing test: " + auto_name)
			get_tree().quit(1)
			return
		var test: Node = (load(path) as GDScript).new()
		test.name = "AutoTest"
		add_child(test)


## Swap the running scene for the chosen world if a world was asked for and it is not already running.
## When no world was asked for, whatever scene was started stays (the project's main scene is the city, and a
## scene run on its own, such as the void or another area's preview scene, is left alone); Game.world then
## names that scene's world if it is one.
## (World scenes check Game.world before building, so the wrong one never builds itself just to be thrown away.)
func _enter_world() -> void:
	var scene := get_tree().current_scene
	if not _world_chosen:
		if scene != null:
			for w: String in WORLDS:
				if WORLDS[w] == scene.scene_file_path:
					world = w
		return
	var want: String = WORLDS[world]
	if scene == null or scene.scene_file_path != want:
		get_tree().change_scene_to_file(want)


func world_scene() -> String:
	return WORLDS[world]


func is_auto() -> bool:
	return auto_name != ""
