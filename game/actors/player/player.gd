class_name Player
extends CharacterBody3D
## The player in the void. First person: you have no face and no cover yet. You get those on the other side of the door.

const EYE_HEIGHT: float = 1.6
const WALK_SPEED: float = 1.5      # an unhurried walk, metres per second
const FAST_SPEED: float = 3.0
const ACCEL: float = 9.0
const LOOK_SENS: float = 0.0022
const BOB_HEIGHT: float = 0.012

var camera: Camera3D
var _pitch: float = 0.0
var _stride: float = 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = 62.0
	camera.near = 0.03
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	if not Game.is_auto():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * LOOK_SENS)
		_pitch = clampf(_pitch - motion.relative.y * LOOK_SENS, -1.35, 1.35)
		camera.rotation.x = _pitch
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.is_auto():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (global_transform.basis * Vector3(input.x, 0.0, input.y))
	wish.y = 0.0
	var speed := FAST_SPEED if Input.is_action_pressed("walk_fast") else WALK_SPEED
	var target := wish.normalized() * speed if wish.length() > 0.01 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# a small head bob that follows the real distance walked
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	_stride += ground_speed * delta
	var bob := sin(_stride * TAU / 1.4) * BOB_HEIGHT * clampf(ground_speed / WALK_SPEED, 0.0, 1.0)
	camera.position.y = EYE_HEIGHT + bob


## Where the player is looking, for interaction checks.
func look_ray(length: float = 1.2) -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * length
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)
