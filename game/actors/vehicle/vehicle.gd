class_name Vehicle
extends RigidBody3D
## A car you can drive. Our own arcade model on a plain rigid body: four suspension rays, tyre grip limited
## by load, rear-wheel drive through a six-speed automatic gearbox. The engine's vehicle node is not used
## (see docs/TECH-DESIGN.md, 4.9). Sound lives in VehicleAudio, the chase and driver views in VehicleCamera.

const MODEL: String = "res://assets/shared/vehicle/sedan_a/sedan_a.glb"
const WHEEL_RADIUS: float = 0.335
const MOUNT_HEIGHT: float = 0.60          # top of each suspension ray, above the car's origin
const REST_LENGTH: float = 0.345
const SPRING: float = 46000.0             # newtons per metre
const DAMPER: float = 4200.0
const ANTI_ROLL: float = 18000.0          # newtons per metre of difference between the two sides of an axle
const GRIP: float = 1.15                  # friction coefficient, dry asphalt and a road tyre
const SLIDE_GRIP: float = 0.85            # share of grip a tyre keeps once it slides
const LOCKED_GRIP: float = 0.70           # share a locked, skidding tyre keeps
const LATERAL_GAIN: float = 0.32          # at a crawl: how much of a tyre's sideways slip it removes in one step
const CORNERING_STIFFNESS: float = 16.0   # sideways force per unit load per radian of slip angle (peak near 4 degrees)
const BRAKE_FORCE: float = 17000.0        # newtons at full pedal, all four wheels; ABS keeps each below its grip
const BRAKE_FRONT: float = 0.64           # front share of the braking
const ROLLING: float = 0.012              # rolling resistance coefficient
const AIR_DRAG: float = 0.37              # half of air density times drag coefficient times frontal area
const MAX_STEER: float = 0.56             # radians at walking pace
const MIN_STEER: float = 0.015            # never less than this, however fast
const WHEELBASE: float = 2.78
const CORNERING: float = 9.0              # metres per second squared that full steering asks for
const STEER_SLIP: float = 0.015           # radians added so the tyres can be taken just past their limit
const HANDBRAKE_STEER: float = 0.32       # least lock available while the handbrake is up
const STEER_RATE: float = 4.5             # lock-widths per second toward the lock
const STEER_RETURN: float = 6.5           # and back toward centre

# The engine and gearbox: a two-litre petrol four, six-speed automatic with a torque converter.
const IDLE_RPM: float = 850.0
const SHIFT_RPM: float = 6350.0           # full-throttle upshift
const LIMITER_RPM: float = 6800.0
const STALL_RPM: float = 2300.0           # the converter lets the engine rise this far before the car moves
const TORQUE_RPM: PackedFloat32Array = [0.0, 800.0, 1000.0, 1500.0, 2000.0, 2500.0, 3000.0, 4000.0, 5000.0, 5500.0, 6000.0, 6500.0, 7000.0]
const TORQUE_NM: PackedFloat32Array = [0.0, 130.0, 150.0, 190.0, 220.0, 235.0, 240.0, 240.0, 232.0, 224.0, 210.0, 192.0, 165.0]
const GEARS: PackedFloat32Array = [3.82, 2.20, 1.52, 1.16, 0.92, 0.74]
const REVERSE_RATIO: float = 3.45
const FINAL_DRIVE: float = 3.31
const EFFICIENCY: float = 0.88
const SHIFT_TIME: float = 0.22            # torque is cut for this long while the gearbox changes
const ENGINE_INERTIA: float = 0.22        # kg m2, crank and flywheel
const WHEEL_INERTIA: float = 1.1          # kg m2, each driven wheel with its disc
const TOP_SPEED: float = 55.6             # metres per second, 200 km/h, held by the engine computer
const REVERSE_SPEED: float = 8.5

var driver: Player = null
var throttle: float = 0.0                 # the pedal keys, -1 (back) to 1 (forward)
var steer_input: float = 0.0
var braking: bool = false                 # any brake on: the pedal, the hold at rest, or the handbrake
var handbrake: bool = false
var speed: float = 0.0                    # forward speed, metres per second

## Engine speed, revolutions per minute.
var rpm: float:
	get: return _rpm
## -1 reverse, 0 neutral (nobody driving), 1 to 6 forward.
var gear: int:
	get: return _gear
## True for the short moment the gearbox is changing gear.
var shifting: bool:
	get: return _shift_timer > 0.0
## How hard the engine is working: 1 at full throttle, below 0 when it is braking the car. The sound follows it.
var engine_load: float:
	get: return _load
## Sliding speed at each tyre's contact patch, metres per second (front left, front right, rear left, rear right).
var wheel_slip: PackedFloat32Array:
	get: return _slip.duplicate()
## The largest of the four.
var slip: float:
	get: return maxf(maxf(_slip[0], _slip[1]), maxf(_slip[2], _slip[3]))
## True when at least one wheel touches the ground.
var grounded: bool:
	get: return _grounded_count > 0

var engine_on: bool = false
var camera: VehicleCamera
var audio: VehicleAudio
var cabin: VehicleCabin

var _wheels: Array[Dictionary] = []
var _steer: float = 0.0
var _rpm: float = 0.0
var _gear: int = 0
var _load: float = 0.0
var _shift_timer: float = 0.0
var _shift_hold: float = 0.0
var _cut_timer: float = 0.0
var _flare: float = 0.0
var _axle_speed: float = 0.0              # surface speed of the driven rear tyres, metres per second
var _spinning: bool = false
var _accel: float = 0.0                   # accelerator pedal, 0 to 1
var _foot: float = 0.0                    # brake pedal, 0 to 1
var _reverse_timer: float = 0.0
var _slip: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0]
var _grounded_count: int = 0
var _last_velocity: Vector3 = Vector3.ZERO
var _lamps: Array[SpotLight3D] = []
var _lamp_materials: Dictionary = {}      # lamp kind -> [[material, base energy], ...]
var _tail_glow: OmniLight3D
var _reverse_glow: OmniLight3D


func _ready() -> void:
	mass = 1480.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.36, 0.05)
	# Replace the project's default damping: air drag and rolling resistance are modelled below.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.15
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.78, 0.62, 4.66)          # the body runs from 2.28 m ahead of the origin to 2.42 m behind
	shape.shape = box
	shape.position = Vector3(0.0, 0.70, 0.07)
	add_child(shape)
	var roof := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.50, 0.42, 2.30)
	roof.shape = cbox
	roof.position = Vector3(0.0, 1.21, 0.35)
	add_child(roof)

	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	_finish_paint(model)
	_find_lamp_materials(model)
	cabin = VehicleCabin.new()
	cabin.name = "Cabin"
	add_child(cabin)
	cabin.build(model)
	for wheel_name: String in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		var node := model.find_child(wheel_name, true, false) as Node3D
		var at := node.position
		_wheels.append({
			"node": node, "x": at.x, "z": at.z, "front": at.z < 0.0,
			"length": REST_LENGTH - 0.08, "spin": 0.0, "grounded": false, "sliding": false,
			"load": 0.0, "point": Vector3.ZERO, "normal": Vector3.UP,
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
	# The red and white the rear lamps throw on the road behind.
	_tail_glow = _rear_glow(Color(1.0, 0.08, 0.04), 3.5)
	_reverse_glow = _rear_glow(Color(1.0, 0.97, 0.92), 6.0)
	camera = VehicleCamera.new()
	camera.car = self
	add_child(camera)
	audio = VehicleAudio.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(self)
	body_entered.connect(_on_body_entered)


func _rear_glow(colour: Color, reach: float) -> OmniLight3D:
	var glow := OmniLight3D.new()
	glow.position = Vector3(0.0, 0.80, 3.0)       # behind the bumper, so it lights the road rather than the plate
	glow.light_color = colour
	glow.light_energy = 0.0
	glow.omni_range = reach
	glow.omni_attenuation = 1.6
	glow.shadow_enabled = false
	glow.light_specular = 0.0          # a point has no lamp's shape; the lamp lenses themselves show in reflections
	glow.visible = false
	add_child(glow)
	return glow


## Things the model file cannot carry: the clear lacquer over the paint.
func _finish_paint(model: Node3D) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i: int in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and mat.resource_name == "car_paint":
				mat.clearcoat_enabled = true
				mat.clearcoat = 1.0
				mat.clearcoat_roughness = 0.06


## Lamp lenses the model may name: lamp_head, lamp_tail, lamp_brake, lamp_reverse, lamp_indicator.
## Each is copied for this car alone so that one car braking does not light every other.
func _find_lamp_materials(model: Node3D) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i: int in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null or not mat.resource_name.begins_with("lamp_"):
				continue
			var kind := mat.resource_name.trim_prefix("lamp_")
			if not kind in ["head", "tail", "brake", "reverse", "indicator"]:
				continue                                   # lamp_lens and the like are glass, not a light
			var own := mat.duplicate() as BaseMaterial3D
			own.emission_enabled = true
			var base := mat.emission_energy_multiplier if mat.emission_enabled else 4.0
			if not mat.emission_enabled:
				own.emission = mat.albedo_color
			mesh.set_surface_override_material(i, own)
			if not _lamp_materials.has(kind):
				_lamp_materials[kind] = []
			(_lamp_materials[kind] as Array).append([own, base])


func enter(player: Player) -> void:
	driver = player
	player.set_seated(true)
	handbrake = false
	engine_on = true
	_gear = 1
	_flare = 1.0 if _rpm < IDLE_RPM * 0.5 else 0.0          # a cold start catches and flares before it settles
	camera.activate()
	for lamp: SpotLight3D in _lamps:
		lamp.visible = true
	audio.door(true)


func leave() -> void:
	if driver == null:
		return
	var player := driver
	driver = null
	throttle = 0.0
	steer_input = 0.0
	handbrake = true
	engine_on = false
	_gear = 0
	camera.set_view(VehicleCamera.View.CHASE)
	for lamp: SpotLight3D in _lamps:
		lamp.visible = false
	var beside := global_position - global_basis.x * 1.75      # the driver's side
	player.global_position = Vector3(beside.x, maxf(beside.y, 0.0) + 0.05, beside.z)
	player.set_seated(false)
	audio.door(false)


## Puts the car somewhere at rest, for tests and for spawning: no speed, wheels at ride height, first gear.
func place(xform: Transform3D) -> void:
	global_transform = xform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_velocity = Vector3.ZERO
	_axle_speed = 0.0
	_spinning = false
	_shift_timer = 0.0
	_shift_hold = 0.0
	_steer = 0.0
	_reverse_timer = 0.0
	if engine_on:
		_gear = 1
		_rpm = IDLE_RPM
	for w: Dictionary in _wheels:
		w.length = REST_LENGTH - 0.08
		w.sliding = false
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if driver != null:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_input = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("handbrake")
	var forward := -global_basis.z
	speed = linear_velocity.dot(forward)
	_pedals(delta)
	_steering(delta, forward)

	var space := get_world_3d().direct_space_state
	var down := -global_basis.y
	var reach := REST_LENGTH + WHEEL_RADIUS
	_grounded_count = 0
	# Pass one: the springs.
	for w: Dictionary in _wheels:
		var mount := global_transform * Vector3(w.x, MOUNT_HEIGHT, w.z)
		var query := PhysicsRayQueryParameters3D.create(mount, mount + down * reach)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		w.grounded = not hit.is_empty()
		if not w.grounded:
			w.length = move_toward(w.length, REST_LENGTH, 2.0 * delta)
			w.load = 0.0
			continue
		_grounded_count += 1
		var length := mount.distance_to(hit.position) - WHEEL_RADIUS
		var rate := (length - float(w.length)) / delta
		w.length = length
		w.load = maxf(SPRING * (REST_LENGTH - length) - DAMPER * rate, 0.0)
		w.point = hit.position
		w.normal = hit.normal
	# The anti-roll bars share load across each axle.
	for pair: Array in [[0, 1], [2, 3]]:
		var l: Dictionary = _wheels[pair[0]]
		var r: Dictionary = _wheels[pair[1]]
		if l.grounded and r.grounded:
			var transfer := ANTI_ROLL * (float(r.length) - float(l.length))
			l.load = maxf(float(l.load) + transfer, 0.0)
			r.load = maxf(float(r.load) - transfer, 0.0)
	for w: Dictionary in _wheels:
		if w.grounded:
			apply_force((w.normal as Vector3) * float(w.load), (w.point as Vector3) - global_position)

	var rear_roll := _rear_roll_speed(forward)
	var drive_force := _drivetrain(delta, rear_roll)
	_tyres(delta, drive_force, rear_roll)
	apply_central_force(-linear_velocity * linear_velocity.length() * AIR_DRAG)


## The pedals mean different things in a forward gear and in reverse; holding brake at rest selects reverse.
func _pedals(delta: float) -> void:
	_accel = 0.0
	_foot = 0.0
	if not engine_on:
		_foot = 1.0 if absf(speed) < 0.5 else 0.0
		braking = handbrake or _foot > 0.0
		return
	var stopped := absf(speed) < 0.6
	if _gear >= 1:
		_accel = maxf(throttle, 0.0)
		_foot = maxf(-throttle, 0.0)
		_reverse_timer = _reverse_timer + delta if (throttle < -0.1 and stopped) else 0.0
		if _reverse_timer > 0.35:
			_gear = -1
			_reverse_timer = 0.0
	else:
		_accel = maxf(-throttle, 0.0)
		_foot = maxf(throttle, 0.0)
		_reverse_timer = _reverse_timer + delta if (throttle > 0.1 and stopped) else 0.0
		if _reverse_timer > 0.2:
			_gear = 1
			_reverse_timer = 0.0
	# Wrong way for the gear (for instance still rolling back in first): the pedal brakes.
	if _gear >= 1 and _accel > 0.0 and speed < -0.6:
		_foot = maxf(_foot, _accel)
	if _gear == -1 and _accel > 0.0 and speed > 0.6:
		_foot = maxf(_foot, _accel)
	# Hold at rest: an automatic keeps its brakes on when stopped with no pedal.
	if _accel < 0.05 and absf(speed) < 0.4:
		_foot = maxf(_foot, 1.0)
	braking = handbrake or _foot > 0.05


func _steering(delta: float, forward: Vector3) -> void:
	# A key is all or nothing, so full lock is scaled to what the tyres can use at this speed: the steady
	# turn for about 0.9 g of cornering, plus a little more. At walking pace that is full lock.
	var v := absf(speed)
	var limit := clampf(WHEELBASE * CORNERING / maxf(v * v, 0.01) + STEER_SLIP, MIN_STEER, MAX_STEER)
	# With the handbrake up the driver throws the wheel further, to swing the tail.
	if handbrake:
		limit = maxf(limit, HANDBRAKE_STEER)
	# In a slide, steering toward where the car is really going (opposite lock) may follow that direction,
	# so a slide can be caught. Steering further into the slide gets no extra lock.
	var flat_velocity := linear_velocity.slide(global_basis.y)
	if flat_velocity.length() > 3.0 and speed > 0.0:
		var drift := forward.signed_angle_to(flat_velocity, global_basis.y)     # positive: going left of the nose
		if absf(drift) > 0.08 and signf(steer_input) == signf(drift):
			limit = clampf(maxf(limit, absf(drift) + 0.06), 0.0, MAX_STEER)
	var target := steer_input * limit
	var steering_in := absf(target) > absf(_steer) and (signf(target) == signf(_steer) or _steer == 0.0)
	# The wheel takes about a fifth of a second to reach the lock, and comes back a little quicker.
	var rate := maxf(limit, 0.05) * (STEER_RATE if steering_in else STEER_RETURN)
	_steer = move_toward(_steer, target, rate * delta)


func _rear_roll_speed(forward: Vector3) -> float:
	var total := 0.0
	var count := 0
	for i: int in [2, 3]:
		var w: Dictionary = _wheels[i]
		if w.grounded:
			var at: Vector3 = w.point
			var v := linear_velocity + angular_velocity.cross(at - (global_transform * center_of_mass))
			total += v.dot(forward)
			count += 1
	return total / count if count > 0 else speed


func _ratio() -> float:
	if _gear >= 1:
		return GEARS[_gear - 1] * FINAL_DRIVE
	if _gear == -1:
		return -REVERSE_RATIO * FINAL_DRIVE
	return 0.0


func _engine_torque(at_rpm: float) -> float:
	var i := TORQUE_RPM.bsearch(at_rpm)
	if i <= 0:
		return TORQUE_NM[0]
	if i >= TORQUE_RPM.size():
		return TORQUE_NM[TORQUE_NM.size() - 1]
	var t := (at_rpm - TORQUE_RPM[i - 1]) / (TORQUE_RPM[i] - TORQUE_RPM[i - 1])
	return lerpf(TORQUE_NM[i - 1], TORQUE_NM[i], t)


## Engine speed, the gearbox, and the force the rear tyres are asked to put down (newtons, along the car).
func _drivetrain(delta: float, rear_roll: float) -> float:
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	_shift_hold = maxf(_shift_hold - delta, 0.0)
	_cut_timer = maxf(_cut_timer - delta, 0.0)
	if not engine_on:
		_rpm = move_toward(_rpm, 0.0, 2500.0 * delta)
		_load = 0.0
		_axle_speed = rear_roll
		return 0.0
	if _gear >= 1:
		_auto_shift(rear_roll)
	var ratio := _ratio()
	# Only wheels turning the gear's own way drive the engine round. Rolling against the gear (sliding tail first
	# after a spin, or forwards in reverse) the converter just slips and the engine stays at its own speed;
	# taking the size alone wound the engine up and let its braking push the car further the wrong way.
	var coupled := maxf(_axle_speed / WHEEL_RADIUS * ratio, 0.0) * 60.0 / TAU
	_flare = maxf(_flare - delta * 1.4, 0.0)
	var free := lerpf(IDLE_RPM, STALL_RPM, _accel) + 550.0 * _flare * _flare
	var target := maxf(coupled, free)
	# The engine follows the wheels closely once the converter is coupled, and swings faster when it is not.
	var rate := 14000.0 if _shift_timer > 0.0 or coupled < free else 40000.0
	_rpm = move_toward(_rpm, target, rate * delta)
	if _rpm >= LIMITER_RPM:
		_cut_timer = 0.08
	var torque := _accel * _engine_torque(_rpm)
	if _cut_timer > 0.0:
		torque = 0.0
	# Engine braking: the engine's own friction and pumping, felt when the throttle closes or the fuel is cut.
	var closed := 1.0 if _cut_timer > 0.0 else 1.0 - _accel
	torque -= closed * (12.0 + _rpm * 0.0065) * (1.0 if _rpm > IDLE_RPM + 150.0 else 0.0)
	if _shift_timer > 0.0 and torque > 0.0:
		torque *= 0.2
	# A converter that slips multiplies torque, most at stall.
	var converter := 1.0 + 0.6 * clampf(1.0 - coupled / maxf(_rpm, 1.0), 0.0, 1.0)
	var force := torque * converter * ratio * EFFICIENCY / WHEEL_RADIUS
	if force > 0.0 and _gear >= 1:
		force *= clampf((TOP_SPEED + 0.3 - speed) / 0.6, 0.0, 1.0)
	elif force < 0.0 and _gear == -1:
		force *= clampf((REVERSE_SPEED + speed) / 1.5, 0.0, 1.0)
	var torque_max := _engine_torque(_rpm)
	_load = clampf(torque / maxf(torque_max, 1.0), -1.0, 1.0) if _cut_timer <= 0.0 else 0.0
	return force


func _auto_shift(rear_roll: float) -> void:
	# Coming to a stop, or rolling backwards, the box is back in first whatever it was doing.
	if _gear > 1 and speed < 1.5:
		_gear = 1
		return
	if _shift_timer > 0.0 or _shift_hold > 0.0:
		return
	var up_at := lerpf(2300.0, SHIFT_RPM, clampf(_accel * 1.15, 0.0, 1.0))
	var down_at := lerpf(1250.0, 3400.0, _accel)
	var road_rpm := maxf(rear_roll, 0.0) / WHEEL_RADIUS * GEARS[_gear - 1] * FINAL_DRIVE * 60.0 / TAU
	var limited := speed > TOP_SPEED - 0.8
	if _gear < GEARS.size() and (road_rpm > up_at or (limited and road_rpm > 2600.0)):
		_shift(1)
	elif _gear > 1 and road_rpm < down_at and not limited:
		var lower_rpm := road_rpm * GEARS[_gear - 2] / GEARS[_gear - 1]
		if lower_rpm < up_at * 0.92:
			_shift(-1)


func _shift(direction: int) -> void:
	_gear += direction
	_shift_timer = SHIFT_TIME
	_shift_hold = 0.9


## The four tyres: brakes, drive, rolling resistance and sideways grip, inside each tyre's friction circle.
func _tyres(delta: float, drive_force: float, rear_roll: float) -> void:
	var com := global_transform * center_of_mass
	var quarter := mass * 0.25
	var hold := _foot >= 1.0 and absf(speed) < 0.4 and _accel < 0.05
	var drive_req := drive_force * 0.5
	var drive_put := 0.0
	var drive_grip := 0.0
	var locked := handbrake
	for i: int in _wheels.size():
		var w: Dictionary = _wheels[i]
		_slip[i] = 0.0
		if not w.grounded:
			continue
		var normal: Vector3 = w.normal
		var at: Vector3 = w.point
		var arm := at - global_position
		var yaw := _steer if w.front else 0.0
		var wheel_basis := global_basis.rotated(global_basis.y, yaw)
		var fwd := (-wheel_basis.z).slide(normal).normalized()
		var side := fwd.cross(normal).normalized()
		var v := linear_velocity + angular_velocity.cross(at - com)
		var slip_side := v.dot(side)
		var roll := v.dot(fwd)
		var limit := float(w.load) * GRIP
		# Sideways: a real tyre pushes back in proportion to its slip angle, up to its grip. At a crawl the
		# slip angle means little, so there the force is capped at what stops the sideways slide in a few steps.
		var gain := 1.0 if hold else LATERAL_GAIN
		var cancel := -slip_side * quarter / delta * gain
		var slip_angle := atan2(slip_side, maxf(absf(roll), 0.5))
		var f_side := -slip_angle * float(w.load) * CORNERING_STIFFNESS
		if absf(f_side) > absf(cancel):
			f_side = cancel
		var stop_force := absf(roll) * quarter / delta          # what would stop this wheel's rolling in one step
		var f_fwd := 0.0
		if not w.front and locked:
			# The handbrake locks the rear wheels: they skid along their own direction of travel.
			var ground_v := v.slide(normal)
			if ground_v.length() > 0.4:
				var skid := -ground_v.normalized() * limit * LOCKED_GRIP
				apply_force(skid, arm)
				_slip[i] = ground_v.length()
				w.sliding = true
				w.spin = float(w.spin)
				continue
			f_fwd = -signf(roll) * minf(limit, stop_force)
		else:
			var share := BRAKE_FRONT if w.front else 1.0 - BRAKE_FRONT
			var brake := _foot * BRAKE_FORCE * share * 0.5
			var grip_left := sqrt(maxf(limit * limit - f_side * f_side, limit * limit * 0.09))
			f_fwd = -signf(roll) * minf(minf(brake, grip_left), stop_force)        # ABS: never more than the tyre holds
			f_fwd -= signf(roll) * minf(float(w.load) * ROLLING, stop_force)
			if not w.front:
				f_fwd += drive_req
				drive_grip += grip_left
		var grip := limit * (SLIDE_GRIP if w.sliding else 1.0)
		var want := Vector2(f_fwd, f_side)
		var asked := want.length()
		if asked > grip and grip > 0.0:
			want = want * (grip / asked)
		w.sliding = asked > limit if not w.sliding else asked > limit * 0.8
		if w.sliding:
			_slip[i] = absf(slip_side)
		if not w.front and not locked:
			drive_put += want.x - (f_fwd - drive_req)
		apply_force(fwd * want.x + side * want.y, arm)
		if w.front:
			w.spin = float(w.spin) + roll / WHEEL_RADIUS * delta
	# The driven axle: wheelspin when the engine asks for more than the tyres can put down.
	if locked:
		_axle_speed = 0.0
		_spinning = false
	else:
		var asked_total := drive_req * 2.0
		_spinning = _spinning or absf(asked_total) > drive_grip * 1.02
		if _spinning:
			var inertia := WHEEL_INERTIA * 2.0 + ENGINE_INERTIA * pow(_ratio(), 2.0)
			_axle_speed += (asked_total - drive_put) * WHEEL_RADIUS * WHEEL_RADIUS / inertia * delta
			if _wheels[2].grounded or _wheels[3].grounded:
				_axle_speed = move_toward(_axle_speed, rear_roll, 6.0 * delta)      # the road drags a spinning tyre back
			if absf(asked_total) <= drive_grip and absf(_axle_speed - rear_roll) < 0.5:
				_spinning = false
		if not _spinning:
			_axle_speed = rear_roll
		var spin_slip := absf(_axle_speed - rear_roll)
		_slip[2] = maxf(_slip[2], spin_slip)
		_slip[3] = maxf(_slip[3], spin_slip)
	for i: int in [2, 3]:
		var w: Dictionary = _wheels[i]
		w.spin = float(w.spin) + _axle_speed / WHEEL_RADIUS * delta


func _on_body_entered(_body: Node) -> void:
	# The change in velocity across the step tells how hard the hit was.
	var hit := (linear_velocity - _last_velocity).length()
	audio.impact(hit)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Hits that happen while already touching something (scraping along a wall) do not fire body_entered.
	var change := (state.linear_velocity - _last_velocity).length()
	if change > 2.5 and state.get_contact_count() > 0:
		audio.impact(change)
	_last_velocity = state.linear_velocity


func _process(delta: float) -> void:
	for w: Dictionary in _wheels:
		var node: Node3D = w.node
		node.position.y = MOUNT_HEIGHT - float(w.length)
		node.rotation = Vector3(-float(w.spin), _steer if w.front else 0.0, 0.0)
	if cabin.visible:
		cabin.set_steer(_steer)
		cabin.set_rpm(_rpm)
	_update_lamps()
	audio.update(delta)


func _update_lamps() -> void:
	var lit := driver != null
	var brake_on := lit and (_foot > 0.05 or handbrake)
	var reversing := lit and _gear == -1
	_set_lamp("head", 1.0 if lit else 0.0)
	_set_lamp("tail", 1.0 if lit else 0.0)
	_set_lamp("brake", 1.0 if brake_on else 0.0)
	_set_lamp("reverse", 1.0 if reversing else 0.0)
	_set_lamp("indicator", 0.0)
	_tail_glow.visible = lit
	_tail_glow.light_energy = 0.9 if brake_on else 0.2
	_reverse_glow.visible = reversing
	_reverse_glow.light_energy = 0.9


func _set_lamp(kind: String, level: float) -> void:
	if not _lamp_materials.has(kind):
		return
	for pair: Array in _lamp_materials[kind]:
		(pair[0] as BaseMaterial3D).emission_energy_multiplier = float(pair[1]) * level
