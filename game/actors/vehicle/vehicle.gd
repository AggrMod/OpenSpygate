class_name Vehicle
extends RigidBody3D
## A car you can drive. Our own arcade model: four suspension rays, tyre grip limited by load, rear-wheel drive.
## The body is a plain rigid body; the engine's vehicle node is not used (see docs/TECH-DESIGN.md, 4.9).

const MODEL: String = "res://assets/shared/vehicle/sedan_a/sedan_a.glb"
const WHEEL_RADIUS: float = 0.335
const MOUNT_HEIGHT: float = 0.60          # top of each suspension ray, above the car's origin
const REST_LENGTH: float = 0.345
const SPRING: float = 46000.0             # newtons per metre
const DAMPER: float = 4200.0
const GRIP: float = 1.15                  # friction coefficient
const ENGINE_FORCE: float = 8200.0        # newtons, shared by the rear wheels
const BRAKE_FORCE: float = 15000.0
const TOP_SPEED: float = 56.0             # metres per second, about 200 km/h
const REVERSE_SPEED: float = 9.0
const MAX_STEER: float = 0.56             # radians at walking pace
const MIN_STEER: float = 0.10             # at top speed

var driver: Player = null
var throttle: float = 0.0
var steer_input: float = 0.0
var braking: bool = false
var speed: float = 0.0                    # forward speed, metres per second

var _wheels: Array[Dictionary] = []
var _steer: float = 0.0
var _camera: Camera3D
var _lamps: Array[SpotLight3D] = []


func _ready() -> void:
	mass = 1480.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.36, 0.05)
	linear_damp = 0.02
	angular_damp = 0.35
	can_sleep = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.78, 0.62, 4.50)
	shape.shape = box
	shape.position = Vector3(0.0, 0.70, 0.0)
	add_child(shape)
	var cabin := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.50, 0.42, 2.30)
	cabin.shape = cbox
	cabin.position = Vector3(0.0, 1.21, 0.35)
	add_child(cabin)

	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	_finish_paint(model)
	for wheel_name: String in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		var node := model.find_child(wheel_name, true, false) as Node3D
		var at := node.position
		_wheels.append({
			"node": node, "x": at.x, "z": at.z, "front": at.z < 0.0,
			"length": REST_LENGTH - 0.08, "spin": 0.0, "grounded": false,
		})
	for side: float in [-0.62, 0.62]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(side, 0.64, -2.20)
		lamp.rotation.x = deg_to_rad(-4.0)
		lamp.light_color = Color(1.0, 0.96, 0.88)
		lamp.light_energy = 60.0
		lamp.spot_range = 70.0
		lamp.spot_angle = 38.0
		lamp.spot_attenuation = 0.8
		lamp.shadow_enabled = side < 0.0
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)
	_camera = Camera3D.new()
	_camera.top_level = true
	_camera.fov = 62.0
	_camera.near = 0.05
	_camera.far = 400.0
	add_child(_camera)


## Things the model file cannot carry: the clear lacquer over the paint.
func _finish_paint(model: Node3D) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i: int in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null and mat.resource_name == "car_paint":
				mat.clearcoat_enabled = true
				mat.clearcoat = 1.0
				mat.clearcoat_roughness = 0.06


func enter(player: Player) -> void:
	driver = player
	player.set_seated(true)
	_camera.global_position = global_position + global_basis.z * 6.5 + Vector3.UP * 2.2
	_camera.make_current()
	for lamp: SpotLight3D in _lamps:
		lamp.visible = true


func leave() -> void:
	if driver == null:
		return
	var player := driver
	driver = null
	throttle = 0.0
	steer_input = 0.0
	braking = true
	var beside := global_position - global_basis.x * 1.75      # the driver's side
	player.global_position = Vector3(beside.x, maxf(beside.y, 0.0) + 0.05, beside.z)
	player.set_seated(false)


func _physics_process(delta: float) -> void:
	if driver != null:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_input = Input.get_axis("move_right", "move_left")
		braking = Input.is_action_pressed("handbrake")
	var forward := -global_basis.z
	speed = linear_velocity.dot(forward)
	var limit := lerpf(MAX_STEER, MIN_STEER, clampf(absf(speed) / TOP_SPEED, 0.0, 1.0))
	_steer = move_toward(_steer, steer_input * limit, 2.2 * delta)

	var space := get_world_3d().direct_space_state
	for w: Dictionary in _wheels:
		var mount := global_transform * Vector3(w.x, MOUNT_HEIGHT, w.z)
		var down := -global_basis.y
		var reach := REST_LENGTH + WHEEL_RADIUS
		var query := PhysicsRayQueryParameters3D.create(mount, mount + down * reach)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		w.grounded = not hit.is_empty()
		if not w.grounded:
			w.length = move_toward(w.length, REST_LENGTH, 2.0 * delta)
			continue
		var length := mount.distance_to(hit.position) - WHEEL_RADIUS
		var rate := (length - float(w.length)) / delta
		w.length = length
		var load := maxf(SPRING * (REST_LENGTH - length) - DAMPER * rate, 0.0)
		var normal: Vector3 = hit.normal
		var at: Vector3 = hit.position
		var arm := at - global_position
		apply_force(normal * load, arm)

		# the tyre: forward and sideways directions on the ground
		var yaw := _steer if w.front else 0.0
		var wheel_basis := global_basis.rotated(global_basis.y, yaw)
		var fwd := (-wheel_basis.z).slide(normal).normalized()
		var side := fwd.cross(normal).normalized()
		var point_velocity := linear_velocity + angular_velocity.cross(at - (global_transform * center_of_mass))
		var slip_side := point_velocity.dot(side)
		var roll := point_velocity.dot(fwd)
		var grip_limit := load * GRIP
		var f_side := -slip_side * (mass * 0.25) / delta * 0.32
		var f_fwd := 0.0
		if braking:
			f_fwd = -signf(roll) * minf(BRAKE_FORCE * 0.25, absf(roll) * mass * 0.25 / delta)
		elif not w.front:
			if throttle > 0.0 and speed < TOP_SPEED:
				f_fwd = throttle * ENGINE_FORCE * 0.5 * (1.0 - clampf(speed / TOP_SPEED, 0.0, 1.0) * 0.85)
			elif throttle < 0.0 and speed > 1.0:
				f_fwd = throttle * BRAKE_FORCE * 0.25
			elif throttle < 0.0 and speed > -REVERSE_SPEED:
				f_fwd = throttle * ENGINE_FORCE * 0.3
		elif throttle < 0.0 and speed > 1.0:
			f_fwd = throttle * BRAKE_FORCE * 0.25
		if throttle == 0.0 and not braking:
			f_fwd -= signf(roll) * minf(260.0, absf(roll) * 300.0)      # rolling resistance and engine braking
		var want := Vector2(f_fwd, f_side)
		if want.length() > grip_limit and grip_limit > 0.0:
			want = want.normalized() * grip_limit
		apply_force(fwd * want.x + side * want.y, arm)
		w.spin = float(w.spin) + roll / WHEEL_RADIUS * delta

	apply_central_force(-linear_velocity * linear_velocity.length() * 0.42)   # air


func _process(delta: float) -> void:
	for w: Dictionary in _wheels:
		var node: Node3D = w.node
		node.position.y = MOUNT_HEIGHT - float(w.length)
		node.rotation = Vector3(-float(w.spin), _steer if w.front else 0.0, 0.0)
	if driver != null:
		var behind := global_basis.z
		behind.y = 0.0
		behind = behind.normalized()
		var want := global_position + behind * (6.2 + absf(speed) * 0.04) + Vector3.UP * 2.1
		_camera.global_position = _camera.global_position.lerp(want, clampf(delta * 5.0, 0.0, 1.0))
		_camera.look_at(global_position + Vector3.UP * 1.05 - behind * 1.5, Vector3.UP)
