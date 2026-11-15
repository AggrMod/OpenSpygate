class_name VehicleAudio
extends Node3D
## The car's sound, all of it rendered by tools/audio/render_vehicle_sounds.py (no recordings).
## The engine is a set of loops, one per engine speed for pulling and for a closed throttle: the two nearest
## to the engine's real speed are crossfaded and pitched so that the firing rate follows the rev counter.
## All engine loops run together from the moment the engine starts, so that they stay in phase.
## Tyres, skid and wind are loops whose level and pitch follow speed and slip. Doors and hits are one-shots.
## Every player is positional, so the car is heard from where it is.

const DIR: String = "res://audio/vehicle/"
const ON_RPMS: PackedFloat32Array = [900.0, 1500.0, 2400.0, 3600.0, 5000.0, 6600.0]
const OFF_RPMS: PackedFloat32Array = [1500.0, 2400.0, 3600.0, 5000.0, 6600.0]
const EXHAUST: Vector3 = Vector3(0.45, 0.30, 2.25)        # the tailpipe, under the rear bumper
const SILENT: float = -80.0
const CABIN_ENGINE: float = 0.50          # about -6 dB: the bulkhead and the exhaust far behind
const CABIN_TYRES: float = 0.56           # about -5 dB
const CABIN_WIND: float = 0.71            # about -3 dB: wind is the loudest thing inside a fast car
const LOOP_GUARD: int = 16                                # each loop file repeats its first 16 frames after its end

var bus: StringName = &"Master"
## True while the listener sits in the car: the body and its insulation take the edge off what is outside.
var interior: bool = false
var _car: Vehicle
var _on: Array[AudioStreamPlayer3D] = []
var _off: Array[AudioStreamPlayer3D] = []
var _roll: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
var _door: AudioStreamPlayer3D
var _thud: AudioStreamPlayer3D
var _door_open: AudioStream
var _door_close: AudioStream
var _load: float = 0.0
var _skid_level: float = 0.0
var _impact_wait: float = 0.0
var _close_in: float = -1.0
var _engine_running: bool = false


func setup(car: Vehicle) -> void:
	_car = car
	if AudioServer.get_bus_index(&"Vehicles") >= 0:
		bus = &"Vehicles"
	for rpm: float in ON_RPMS:
		_on.append(_loop("engine_on_%04d.wav" % int(rpm), EXHAUST, 7.0))
	for rpm: float in OFF_RPMS:
		_off.append(_loop("engine_off_%04d.wav" % int(rpm), EXHAUST, 7.0))
	_roll = _loop("tyre_roll.wav", Vector3(0.0, 0.25, 0.0), 6.0)
	_skid = _loop("tyre_skid.wav", Vector3(0.0, 0.25, 0.8), 9.0)
	_wind = _loop("wind.wav", Vector3(0.0, 1.20, -0.6), 6.0)
	_door = _player(Vector3(-0.90, 0.95, 0.10), 5.0)
	_thud = _player(Vector3(0.0, 0.70, 0.0), 10.0)
	_door_open = load(DIR + "door_open.wav")
	_door_close = load(DIR + "door_close.wav")
	_thud.stream = load(DIR + "impact.wav")


## Sends every sound of this car to another bus (tests use this to record the car alone).
func set_bus(value: StringName) -> void:
	bus = value
	for p: AudioStreamPlayer3D in find_children("*", "AudioStreamPlayer3D", false, false):
		p.bus = value


func _player(at: Vector3, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.position = at
	p.unit_size = unit
	p.max_distance = 160.0
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -12.0
	p.bus = bus
	add_child(p)
	return p


func _loop(file: String, at: Vector3, unit: float) -> AudioStreamPlayer3D:
	var p := _player(at, unit)
	var stream := (load(DIR + file) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate)) - LOOP_GUARD
	p.stream = stream
	p.volume_db = SILENT
	p.play()
	p.stream_paused = true
	return p


## Door open, then shut a moment later: getting in and getting out both sound like this.
func door(_getting_in: bool) -> void:
	_door.stream = _door_open
	_door.volume_db = 0.0
	_door.pitch_scale = randf_range(0.97, 1.03)
	_door.play()
	_close_in = 0.85


## A hit. strength is the change of speed it caused, metres per second.
func impact(strength: float) -> void:
	if strength < 1.0 or _impact_wait > 0.0:
		return
	_impact_wait = 0.18
	var level := clampf(strength / 9.0, 0.06, 1.0)
	_thud.volume_db = linear_to_db(level)
	_thud.pitch_scale = (1.12 - 0.25 * level) * randf_range(0.97, 1.03)
	_thud.play()


func update(delta: float) -> void:
	_impact_wait = maxf(_impact_wait - delta, 0.0)
	if _close_in > 0.0:
		_close_in -= delta
		if _close_in <= 0.0:
			_door.stream = _door_close
			_door.pitch_scale = randf_range(0.97, 1.03)
			_door.play()
	var rpm := _car.rpm
	# Load is smoothed a little: the note swells as the throttle opens rather than switching.
	var target_load := clampf(_car.engine_load, -1.0, 1.0)
	_load = lerpf(_load, target_load, 1.0 - exp(-delta * (14.0 if target_load > _load else 7.0)))
	var on_mix := smoothstep(-0.15, 0.55, _load)
	on_mix = maxf(on_mix, 1.0 - clampf((rpm - 950.0) / 600.0, 0.0, 1.0))     # idle is its own layer
	# An engine at idle is a murmur; near the limiter, pulling, it is some 15 dB louder.
	var running := clampf(rpm / Vehicle.IDLE_RPM, 0.0, 1.0)
	var revs := clampf((rpm - Vehicle.IDLE_RPM) / (Vehicle.LIMITER_RPM - Vehicle.IDLE_RPM), 0.0, 1.0)
	var level := db_to_linear(lerpf(-12.0, 1.5, sqrt(revs))) * running * running * (CABIN_ENGINE if interior else 1.0)
	# Changed under the audio lock, so that no layer gets a new pitch one mix earlier than another.
	# A parked car whose layers are already paused has nothing to change and takes no lock.
	if rpm > 30.0 or _engine_running:
		_engine_update(rpm, level, on_mix)
	_tyres_and_wind(delta)


func _engine_update(rpm: float, level: float, on_mix: float) -> void:
	AudioServer.lock()
	var starting := rpm > 30.0 and not _engine_running
	_engine_running = rpm > 30.0
	if starting:
		for p: AudioStreamPlayer3D in _on + _off:
			p.play(0.0)                      # every layer from its first firing, together
	_set_layers(_on, ON_RPMS, rpm, level * on_mix)
	_set_layers(_off, OFF_RPMS, rpm, level * (1.0 - on_mix) * 1.6)
	AudioServer.unlock()


func _tyres_and_wind(delta: float) -> void:
	var v := absf(_car.speed)
	var on_ground := 1.0 if _car.grounded else 0.0
	var roll := pow(clampf(v / 30.0, 0.0, 1.0), 1.1) * on_ground
	_level(_roll, roll * 0.8 * (CABIN_TYRES if interior else 1.0), 0.75 + 0.5 * clampf(v / 40.0, 0.0, 1.0))
	var wind := pow(clampf(v / Vehicle.TOP_SPEED, 0.0, 1.0), 2.0)
	_level(_wind, wind * 0.9 * (CABIN_WIND if interior else 1.0), 0.85 + 0.35 * clampf(v / Vehicle.TOP_SPEED, 0.0, 1.0))
	var slip := _car.slip * on_ground
	var skid_target := smoothstep(1.2, 5.0, slip) if (v > 1.0 or slip > 2.0) else 0.0
	_skid_level = lerpf(_skid_level, skid_target, 1.0 - exp(-delta * (25.0 if skid_target > _skid_level else 9.0)))
	_level(_skid, _skid_level * 0.85 * (CABIN_TYRES if interior else 1.0), 0.93 + 0.12 * clampf((slip - 1.0) / 10.0, 0.0, 1.0))


func _set_layers(players: Array[AudioStreamPlayer3D], rpms: PackedFloat32Array, rpm: float, level: float) -> void:
	# The layers are rendered from the same firing pattern and every one is kept running and pitched to the
	# same firing rate, so they stay in phase with each other. Signals in phase add as amplitudes, so the
	# crossfade between the two layers either side of the engine speed is linear (equal gain), not equal power.
	var weights := PackedFloat32Array()
	weights.resize(rpms.size())
	weights.fill(0.0)
	if rpm <= rpms[0]:
		weights[0] = 1.0
	elif rpm >= rpms[rpms.size() - 1]:
		weights[rpms.size() - 1] = 1.0
	else:
		for i: int in rpms.size() - 1:
			if rpm < rpms[i + 1]:
				var t := (rpm - rpms[i]) / (rpms[i + 1] - rpms[i])
				weights[i] = 1.0 - t
				weights[i + 1] = t
				break
	var running := rpm > 30.0
	for i: int in players.size():
		var p := players[i]
		var gain := level * weights[i]
		p.volume_db = linear_to_db(gain) if gain > 0.00002 else SILENT
		p.pitch_scale = maxf(rpm, 30.0) / rpms[i]
		p.stream_paused = not running


func _level(p: AudioStreamPlayer3D, level: float, pitch: float) -> void:
	if level < 0.0005:
		p.volume_db = SILENT
		p.stream_paused = true
		return
	p.volume_db = linear_to_db(level)
	p.pitch_scale = pitch
	p.stream_paused = false
