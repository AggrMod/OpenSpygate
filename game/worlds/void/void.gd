extends Node3D
## The opening of the game: an empty black void, one door, light under it.
## Everything is built in code so the scene file stays one readable line.
## Where nothing has been built there is nothing: no sky, no horizon, no placeholder.

const DOOR_SCENE: String = "res://assets/shared/hero/door_tenement_a/door_tenement_a.glb"
const START: Vector3 = Vector3(0.6, 0.0, 7.5)     # the player starts here, facing the door

var player: Player
var door: Node3D


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_door()
	player = Player.new()
	player.position = START
	add_child(player)
	player.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var shape := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	shape.shape = plane
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	mesh.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.021)
	mat.roughness = 0.38
	mat.metallic_specular = 0.5
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _build_door() -> void:
	if not ResourceLoader.exists(DOOR_SCENE):
		# The door has not been exported into the game yet. The void stays empty until it is.
		return
	door = (load(DOOR_SCENE) as PackedScene).instantiate() as Node3D
	door.name = "Door"
	add_child(door)
	# The room beyond: warm light that only gets out under the door and through the glass.
	var spill := SpotLight3D.new()
	spill.name = "LightBeyond"
	spill.position = Vector3(0.0, 0.16, -0.75)       # Blender +Y (behind the door) is Godot -Z
	spill.look_at_from_position(spill.position, Vector3(0.0, 0.02, 0.4), Vector3.UP)
	spill.light_color = Color(1.0, 0.70, 0.38)
	spill.light_energy = 14.0
	spill.spot_range = 6.0
	spill.spot_angle = 75.0
	spill.shadow_enabled = true
	spill.shadow_bias = 0.01
	add_child(spill)
	var lamp := OmniLight3D.new()
	lamp.name = "LampBeyond"
	lamp.position = Vector3(0.15, 1.95, -1.0)
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	lamp.shadow_enabled = true
	add_child(lamp)
	# A faint cool light so the door can be read in the dark.
	var key := SpotLight3D.new()
	key.name = "Key"
	key.position = Vector3(-2.3, 3.1, 3.0)
	key.look_at_from_position(key.position, Vector3(0.0, 1.15, 0.0), Vector3.UP)
	key.light_color = Color(0.80, 0.88, 1.0)
	key.light_energy = 2.2
	key.spot_range = 9.0
	key.spot_angle = 28.0
	key.shadow_enabled = true
	add_child(key)
