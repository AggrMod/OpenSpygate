extends Node
## Session-wide state. Also sets up input actions in code (so the project file stays readable)
## and starts a self-playing test when the game is run with `-- --auto=<name> --out=<dir>`.

const ACTIONS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"walk_fast": [KEY_SHIFT],
	"interact": [KEY_E],
	"handbrake": [KEY_SPACE],
	"release_mouse": [KEY_ESCAPE],
}

var auto_name: String = ""
var out_dir: String = ""


func _enter_tree() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--auto="):
			auto_name = arg.trim_prefix("--auto=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")


func _ready() -> void:
	if auto_name != "":
		var path := "res://tests/auto/%s.gd" % auto_name
		if not ResourceLoader.exists(path):
			push_error("No such self-playing test: " + auto_name)
			get_tree().quit(1)
			return
		var test: Node = (load(path) as GDScript).new()
		test.name = "AutoTest"
		add_child(test)


func is_auto() -> bool:
	return auto_name != ""
