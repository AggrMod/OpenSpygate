class_name VehicleCamera
extends Camera3D
## The views from a car. Chase: behind and above, the mouse swings it round and it drifts back behind the car
## after a moment, it pulls back with speed and never goes through the ground. Driver: from the driver's seat.
## The key for switching (V) is registered here if nothing else has registered it.

enum View { CHASE, DRIVER }

const ACTION: String = "camera_view"
const LOOK_SENS: float = 0.0035
const RETURN_AFTER: float = 1.4           # seconds without the mouse before the view swings back
const CHASE_DISTANCE: float = 6.2
const CHASE_PULL: float = 3.0             # extra metres at top speed
const PIVOT_HEIGHT: float = 1.05
const ELEVATION: float = 0.17             # radians above the car's roof line, at rest
const GROUND_CLEARANCE: float = 0.35
const DRIVER_EYE: Vector3 = Vector3(-0.36, 1.16, 0.24)    # left-hand drive, a seated adult's eye

var car: Vehicle
var view: View = View.CHASE
var _yaw: float = 0.0
var _pitch: float = 0.0
var _idle: float = 99.0
var _boom_yaw: float = 0.0
var _distance: float = CHASE_DISTANCE
var _pivot_y: float = 0.0


static func register_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	InputMap.action_add_event(ACTION, ev)


func _ready() -> void:
	register_action()
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF    # it is moved every frame, after the car's interpolated pose
	fov = 62.0
	near = 0.05
	far = 400.0


## Becomes the view, starting behind the car.
func activate() -> void:
	set_view(View.CHASE)
	make_current()


func set_view(value: View) -> void:
	view = value
	_yaw = 0.0
	_pitch = 0.0
	fov = 66.0 if view == View.DRIVER else 62.0
	near = 0.02 if view == View.DRIVER else 0.05
	car.cabin.show_cabin(view == View.DRIVER)
	car.audio.interior = view == View.DRIVER
	if view == View.CHASE:
		_snap_behind(car.global_transform)


func _unhandled_input(event: InputEvent) -> void:
	if car == null or car.driver == null or not current:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * LOOK_SENS
		_pitch -= motion.relative.y * LOOK_SENS
		_idle = 0.0
	elif event.is_action_pressed(ACTION):
		set_view(View.DRIVER if view == View.CHASE else View.CHASE)


## Turns the view by mouse-like amounts, for tests (radians).
func orbit(yaw: float, pitch: float) -> void:
	_yaw += yaw
	_pitch += pitch
	_idle = 0.0


func _process(delta: float) -> void:
	if car == null or car.driver == null:
		return
	_idle += delta
	if _idle > RETURN_AFTER:
		var k := 1.0 - exp(-delta * 2.5)
		_yaw = lerp_angle(_yaw, 0.0, k)
		_pitch = lerpf(_pitch, 0.0, k)
	var xf := car.get_global_transform_interpolated()
	if view == View.DRIVER:
		var turn := 1.1 if car.cabin.stand_in else 1.9   # the stand-in cabin has no seats, so the head turns only so far
		_yaw = clampf(_yaw, -turn, turn)
		_pitch = clampf(_pitch, -0.30, 0.35)
		global_transform = xf * Transform3D(Basis.from_euler(Vector3(_pitch - 0.07, _yaw, 0.0)), DRIVER_EYE)
		return
	_yaw = wrapf(_yaw, -PI, PI)
	_pitch = clampf(_pitch, -ELEVATION - 0.05, 1.0)
	# The boom swings after the car's heading and lengthens with speed, but rides with the car, so that
	# steady speed never leaves the camera trailing behind.
	_boom_yaw = lerp_angle(_boom_yaw, _heading(xf), 1.0 - exp(-delta * 4.0))
	var pull := clampf(absf(car.speed) / Vehicle.TOP_SPEED, 0.0, 1.0)
	_distance = lerpf(_distance, CHASE_DISTANCE + CHASE_PULL * pull, 1.0 - exp(-delta * 1.5))
	_pivot_y = lerpf(_pivot_y, xf.origin.y, 1.0 - exp(-delta * 10.0))
	var pivot := Vector3(xf.origin.x, _pivot_y + PIVOT_HEIGHT, xf.origin.z)
	global_position = _keep_clear(pivot, pivot + _boom(_boom_yaw + _yaw) * _distance)
	var ahead := -_boom(_boom_yaw) * 1.5 if absf(_yaw) < 0.6 else Vector3.ZERO
	ahead.y = 0.0
	look_at(pivot + ahead, Vector3.UP)


## The direction from the car back along its length, as a yaw angle.
func _heading(xf: Transform3D) -> float:
	var behind := xf.basis.z
	return atan2(behind.x, behind.z) if Vector2(behind.x, behind.z).length() > 0.01 else _boom_yaw


func _boom(yaw: float) -> Vector3:
	var elevation := ELEVATION + _pitch
	return Vector3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation))


func _snap_behind(xf: Transform3D) -> void:
	_boom_yaw = _heading(xf)
	_distance = CHASE_DISTANCE
	_pivot_y = xf.origin.y
	var pivot := xf.origin + Vector3.UP * PIVOT_HEIGHT
	global_position = pivot + _boom(_boom_yaw + _yaw) * _distance
	look_at(pivot - _boom(_boom_yaw) * 1.5 * Vector3(1, 0, 1), Vector3.UP)


## Pulls the camera in front of anything between it and the car, and keeps it above the ground.
func _keep_clear(pivot: Vector3, at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pivot, at)
	query.exclude = [car.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		at = (hit.position as Vector3) + (pivot - at).normalized() * 0.3
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 4.0)
	down.exclude = [car.get_rid()]
	var ground := space.intersect_ray(down)
	if not ground.is_empty():
		at.y = maxf(at.y, (ground.position as Vector3).y + GROUND_CLEARANCE)
	return at
