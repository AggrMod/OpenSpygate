extends Node
## Self-playing test of the car's sound. Nobody listens: it is measured.
## The car's sounds are sent to a bus of their own, recorded there (before the fader, so at the level they would
## reach Master at unity gain) while a scripted drive runs: door, idle, full throttle through the gears, a lift
## off, then from the driver's seat (the loudest place to listen) a handbrake slide, braking, a hit on a lamp
## post, getting out. Then the recording is checked:
## not silent, no clipping, the engine's firing frequency follows the rev counter, the skid is heard only while
## a tyre slides, levels are sane, and there are no clicks (in the mix and at the seams of the loop files).
## Writes drive_audio.wav and timeline.json next to result.json for a closer look (tools/audio/analyse_drive_audio.py).

const WORLD: String = "void"        # read by Game: this test runs in the void (see autoload/game.gd)
const BUS: StringName = &"CarUnderTest"
const KMH_100: float = 100.0 / 3.6

var _result: Dictionary = {"test": "drive_audio", "pass": false, "notes": []}
var _car: Vehicle
var _record: AudioEffectRecord
var _t0: int = 0
var _timeline: Array = []                 # [t, rpm, gear, speed, slip, load, shifting]
var _events: Array = []                   # [t, name]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var scene := get_tree().current_scene
	var player := scene.get("player") as Player
	_car = scene.get("car") as Vehicle
	if player == null or _car == null:
		_fail("no player or no car in the scene")
		return
	_result["audio_driver"] = str(ProjectSettings.get_setting("audio/driver/driver", "?"))
	_result["output_device"] = AudioServer.get_output_device()
	_result["mix_rate"] = AudioServer.get_mix_rate()
	_make_bus()
	_car.audio.set_bus(BUS)
	_place(-150.0)
	await get_tree().create_timer(0.5).timeout
	_record.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	_sample_timeline()

	_event("enter")
	_car.enter(player)
	await _wait(2.6)                                      # door, then idle
	_event("throttle")
	Input.action_press("move_forward")
	await _wait_until(func() -> bool: return _car.speed >= KMH_100, 12.0)
	Input.action_release("move_forward")
	_event("lift")
	await _wait(1.6)                                      # overrun
	# From here on the listener sits in the driver's seat, where every sound is closest: the loudest case.
	_car.camera.set_view(VehicleCamera.View.DRIVER)
	_event("handbrake")
	Input.action_press("handbrake")
	Input.action_press("move_right")
	await _wait(1.0)
	Input.action_release("move_right")
	await _wait(0.6)
	Input.action_release("handbrake")
	_event("brake")
	Input.action_press("move_back")
	await _wait_until(func() -> bool: return absf(_car.speed) < 0.5, 6.0)
	Input.action_release("move_back")
	await _wait(1.0)
	# Into the lamp post at x = 48 on the pavement side, at town speed.
	_place_at(Vector3(30.0, 0.2, 16.9))
	_car.camera.set_view(VehicleCamera.View.DRIVER)
	await _wait(0.8)
	_event("towards_post")
	Input.action_press("move_forward")
	var hit_speed := 0.0
	var t := 0.0
	while t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_sample_timeline()
		if _car.global_position.x > 44.0:
			Input.action_release("move_forward")
		if _car.speed > hit_speed:
			hit_speed = _car.speed
		if _car.global_position.x > 44.0 and absf(_car.speed) < 1.0:
			break
	Input.action_release("move_forward")
	_result["impact_speed_kmh"] = snappedf(hit_speed * 3.6, 0.1)
	await _wait(1.2)
	_event("leave")
	_car.leave()
	await _wait(1.6)
	_record.set_recording_active(false)
	_car.audio.set_bus(&"Master")

	var wav := _record.get_recording()
	if wav == null:
		_fail("nothing was recorded")
		return
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		wav.save_to_wav(Game.out_dir.path_join("drive_audio.wav"))
		var f := FileAccess.open(Game.out_dir.path_join("timeline.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"columns": ["t", "rpm", "gear", "speed", "slip", "load", "shifting"], "rows": _timeline, "events": _events}))
		f.close()
	_analyse(wav)
	_finish()


# --- the drive ---------------------------------------------------------------------------------

func _make_bus() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_db(index, -30.0)          # quiet in the room; the recording is taken before the fader
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(index, _record)


func _place(x: float) -> void:
	_place_at(Vector3(x, 0.05, 24.2))


func _place_at(at: Vector3) -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "handbrake"]:
		Input.action_release(action)
	_car.place(Transform3D(Basis.looking_at(Vector3(1.0, 0.0, 0.0)), at))
	if _car.driver != null:
		_car.camera.activate()


func _now() -> float:
	return float(Time.get_ticks_usec() - _t0) / 1000000.0


func _event(label: String) -> void:
	_events.append([snappedf(_now(), 0.001), label])


func _sample_timeline() -> void:
	_timeline.append([snappedf(_now(), 0.001), snappedf(_car.rpm, 1.0), _car.gear, snappedf(_car.speed, 0.01),
		snappedf(_car.slip, 0.01), snappedf(_car.engine_load, 0.01), 1 if _car.shifting else 0])


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_sample_timeline()


func _wait_until(done: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not done.call():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_sample_timeline()


# --- the measurements --------------------------------------------------------------------------

func _analyse(wav: AudioStreamWAV) -> void:
	var rate := float(wav.mix_rate)
	var mono := _to_mono(wav)
	var n := mono.size()
	_result["recorded_seconds"] = snappedf(n / rate, 0.01)
	_result["timeline_seconds"] = snappedf(_now(), 0.01)
	var ok := true
	if n < int(rate * 10.0):
		_note("recording too short: %d samples" % n)
		_result["pass"] = false
		return

	# Level and clipping.
	var peak := 0.0
	var sum := 0.0
	for s: float in mono:
		peak = maxf(peak, absf(s))
		sum += s * s
	var rms := sqrt(sum / n)
	_result["peak_dbfs"] = snappedf(linear_to_db(maxf(peak, 1e-9)), 0.01)
	_result["rms_dbfs"] = snappedf(linear_to_db(maxf(rms, 1e-9)), 0.01)
	if rms < 0.001:
		ok = false; _note("the recording is silent (RMS %.1f dBFS)" % float(_result["rms_dbfs"]))
	if peak > db_to_linear(-1.0):
		ok = false; _note("peak %.2f dBFS: less than 1 dB of headroom" % float(_result["peak_dbfs"]))
	if float(_result["rms_dbfs"]) > -12.0 or float(_result["rms_dbfs"]) < -45.0:
		ok = false; _note("overall level %.1f dBFS is outside -45 to -12" % float(_result["rms_dbfs"]))

	# Idle: audible but not loud.
	var idle := _window_rms(mono, rate, _event_time("enter") + 1.6, 0.8)
	_result["idle_rms_dbfs"] = snappedf(linear_to_db(maxf(idle, 1e-9)), 0.01)
	if float(_result["idle_rms_dbfs"]) < -50.0 or float(_result["idle_rms_dbfs"]) > -18.0:
		ok = false; _note("idle level %.1f dBFS is outside -50 to -18" % float(_result["idle_rms_dbfs"]))

	# Pulling hard near the top of the rev range is clearly louder than idling.
	var pull_t := _steady_moment(5200.0, 6500.0, true)
	if pull_t > 0.0:
		var pull := _window_rms(mono, rate, pull_t - 0.1, 0.2)
		_result["full_throttle_rms_dbfs"] = snappedf(linear_to_db(maxf(pull, 1e-9)), 0.01)
		var span := float(_result["full_throttle_rms_dbfs"]) - float(_result["idle_rms_dbfs"])
		_result["idle_to_full_throttle_db"] = snappedf(span, 0.1)
		if span < 8.0:
			ok = false; _note("full throttle is only %.1f dB louder than idle" % span)

	# No hole in the level between two engine layers: at each midpoint the level is within 3 dB of the
	# quieter of the two layers' own speeds (in first gear, pulling hard, before any skid).
	var crossings: Array = []
	for trio: Array in [[2400.0, 3000.0, 3600.0], [3600.0, 4300.0, 5000.0]]:
		var levels: Array = []
		for target: float in trio:
			var at := _first_crossing(target)
			levels.append(linear_to_db(maxf(_window_rms(mono, rate, at - 0.05, 0.1), 1e-9)) if at > 0.0 else -200.0)
		var dip := minf(float(levels[0]), float(levels[2])) - float(levels[1])
		crossings.append({"layers": [trio[0], trio[2]], "levels_db": [snappedf(levels[0], 0.1), snappedf(levels[1], 0.1), snappedf(levels[2], 0.1)], "dip_db": snappedf(dip, 0.1)})
		if float(levels[1]) < -150.0 or dip > 3.0:
			ok = false; _note("the level dips %.1f dB between the %d and %d rpm layers" % [dip, int(trio[0]), int(trio[2])])
	_result["layer_crossfades"] = crossings

	# The engine's firing frequency against the rev counter, in steady stretches under load.
	var checks: Array = []
	for band: Array in [[1800.0, 2900.0], [3300.0, 4500.0], [5200.0, 6500.0]]:
		var at := _steady_moment(band[0], band[1], true)
		if at < 0.0:
			continue
		var rpm := _rpm_at(at)
		var expected := rpm / 30.0                       # four cylinders, four strokes: two firings per turn
		var found := _pitch(mono, rate, at, expected)
		checks.append({"t": snappedf(at, 0.01), "rpm": snappedf(rpm, 1.0), "expected_hz": snappedf(expected, 0.1), "measured_hz": snappedf(found, 0.1)})
	var lift := _steady_moment(1800.0, 6500.0, false)
	if lift >= 0.0:
		var rpm := _rpm_at(lift)
		var found := _pitch(mono, rate, lift, rpm / 30.0)
		checks.append({"t": snappedf(lift, 0.01), "rpm": snappedf(rpm, 1.0), "expected_hz": snappedf(rpm / 30.0, 0.1), "measured_hz": snappedf(found, 0.1), "overrun": true})
	_result["engine_pitch"] = checks
	var tracked := 0
	for c: Dictionary in checks:
		var err := absf(float(c["measured_hz"]) / float(c["expected_hz"]) - 1.0)
		if err < 0.08:
			tracked += 1
		else:
			_note("engine at %d rpm: measured %.1f Hz, expected %.1f Hz" % [int(c["rpm"]), float(c["measured_hz"]), float(c["expected_hz"])])
	if checks.size() < 3 or tracked < checks.size():
		ok = false; _note("the engine note does not follow the rev counter (%d of %d windows)" % [tracked, checks.size()])
	if checks.size() >= 2:
		var lo: Dictionary = checks[0]
		var hi: Dictionary = checks[mini(2, checks.size() - 1)]
		_result["pitch_rise_ratio"] = snappedf(float(hi["measured_hz"]) / maxf(float(lo["measured_hz"]), 1.0), 0.01)
		_result["rpm_rise_ratio"] = snappedf(float(hi["rpm"]) / maxf(float(lo["rpm"]), 1.0), 0.01)

	# The skid: the squeal's band (about 1.1 to 1.25 kHz) while sliding, against driving without sliding.
	var sliding: Array = []
	var gripping: Array = []
	for row: Array in _timeline:
		var t: float = row[0]
		if t < 0.2 or t > n / rate - 0.2:
			continue
		if float(row[4]) > 4.0 and absf(float(row[3])) > 3.0:
			sliding.append(t)
		elif float(row[4]) < 0.3 and absf(float(row[3])) > 5.0 and int(row[6]) == 0:
			gripping.append(t)
	var slide_db := _band_db(mono, rate, _spread(sliding, 16))
	var grip_db := _band_db(mono, rate, _spread(gripping, 16))
	_result["skid_band_sliding_db"] = snappedf(slide_db, 0.1)
	_result["skid_band_gripping_db"] = snappedf(grip_db, 0.1)
	_result["skid_moments"] = [sliding.size(), gripping.size()]
	if sliding.size() < 5 or gripping.size() < 5:
		ok = false; _note("not enough sliding or gripping moments to compare")
	elif slide_db - grip_db < 10.0:
		ok = false; _note("the skid band is only %.1f dB louder while sliding" % (slide_db - grip_db))

	# One-shots: the hit and the doors stand out from what was playing just before.
	var hit_t := _impact_time()
	_result["impact_t"] = snappedf(hit_t, 0.01)
	if hit_t > 0.0:
		var rise := _transient_rise(mono, rate, hit_t)
		_result["impact_rise_db"] = snappedf(rise, 0.1)
		if rise < 6.0:
			ok = false; _note("the hit is not heard (%.1f dB rise)" % rise)
	else:
		ok = false; _note("the car never hit the post")
	var door_rise := _transient_rise(mono, rate, _event_time("leave") + 0.03)
	_result["door_rise_db"] = snappedf(door_rise, 0.1)
	if door_rise < 6.0:
		ok = false; _note("the door is not heard (%.1f dB rise)" % door_rise)

	# Clicks: a sample step far above the steps around it, away from the hits and doors.
	var clicks := _clicks(mono, rate)
	_result["clicks"] = clicks
	if clicks.size() > 0:
		ok = false; _note("%d click(s) in the mix" % clicks.size())
	var caught := _click_self_check(mono, rate)
	_result["click_check_found_injected"] = "%d of 5" % caught
	if caught < 4:
		ok = false; _note("the click check found only %d of 5 clicks put in on purpose" % caught)
	var seams := _loop_seams()
	_result["loop_seams"] = seams
	for file: String in seams:
		if float(seams[file]) > 1.0:
			ok = false; _note("loop %s jumps at its seam" % file)
	_result["pass"] = ok


func _to_mono(wav: AudioStreamWAV) -> PackedFloat32Array:
	var data := wav.data
	var stereo := wav.stereo
	var frames := data.size() / (4 if stereo else 2)
	var out := PackedFloat32Array()
	out.resize(frames)
	for i: int in frames:
		if stereo:
			out[i] = (data.decode_s16(i * 4) + data.decode_s16(i * 4 + 2)) / 65536.0
		else:
			out[i] = data.decode_s16(i * 2) / 32768.0
	return out


func _event_time(label: String) -> float:
	for e: Array in _events:
		if e[1] == label:
			return float(e[0])
	return -1.0


## When the engine first passes this speed pulling hard in first gear.
func _first_crossing(target: float) -> float:
	for row: Array in _timeline:
		if int(row[2]) == 1 and float(row[5]) >= 0.9 and int(row[6]) == 0 and float(row[1]) >= target and float(row[3]) > 1.0:
			return float(row[0])
	return -1.0


func _rpm_at(t: float) -> float:
	for row: Array in _timeline:
		if float(row[0]) >= t:
			return float(row[1])
	return 0.0


## A moment in the middle of 0.25 s where the gear is held, nothing slides, and the load is on (or off).
func _steady_moment(lo: float, hi: float, pulling: bool) -> float:
	for i: int in range(8, _timeline.size() - 8):
		var row: Array = _timeline[i]
		var rpm := float(row[1])
		if rpm < lo or rpm > hi:
			continue
		var good := true
		for j: int in range(i - 7, i + 8):
			var r: Array = _timeline[j]
			if int(r[6]) != 0 or float(r[4]) > 0.3 or int(r[2]) != int(row[2]) or absf(float(r[3])) < 2.0:
				good = false
				break
			if pulling and float(r[5]) < 0.9:
				good = false
				break
			if not pulling and float(r[5]) > -0.05:
				good = false
				break
		if good:
			return float(row[0])
	return -1.0


func _window_rms(x: PackedFloat32Array, rate: float, t: float, seconds: float) -> float:
	var a := clampi(int(t * rate), 0, x.size() - 1)
	var b := clampi(int((t + seconds) * rate), a + 1, x.size())
	var sum := 0.0
	for i: int in range(a, b):
		sum += x[i] * x[i]
	return sqrt(sum / (b - a))


## Fundamental frequency near t by normalised autocorrelation, on a copy taken down to about 11 kHz.
func _pitch(x: PackedFloat32Array, rate: float, t: float, expected: float) -> float:
	var step := maxi(1, int(rate / 11025.0))
	var r := rate / step
	var size := 2048
	var centre := int(t * rate)
	var start := centre - size * step / 2
	if start < 0 or start + size * step >= x.size():
		return 0.0
	var y := PackedFloat32Array()
	y.resize(size)
	for i: int in size:
		var acc := 0.0
		for k: int in step:
			acc += x[start + i * step + k]
		y[i] = acc / step
	# Search from a little below half the expected frequency to well above it, so a wrong octave would show.
	var min_lag := int(r / (expected * 1.9))
	var max_lag := mini(int(r / (expected * 0.55)), size / 2)
	var best_lag := 0
	var values := PackedFloat32Array()
	values.resize(max_lag + 1)
	var best := -1.0
	for lag: int in range(min_lag, max_lag + 1):
		var num := 0.0
		var den := 0.0
		for i: int in size - lag:
			num += y[i] * y[i + lag]
			den += y[i] * y[i] + y[i + lag] * y[i + lag]
		var nsdf := 2.0 * num / maxf(den, 1e-12)
		values[lag] = nsdf
		best = maxf(best, nsdf)
	# The first peak that reaches 85 % of the best is the period (McLeod's rule against octave errors).
	for lag: int in range(min_lag + 1, max_lag):
		if values[lag] >= best * 0.85 and values[lag] >= values[lag - 1] and values[lag] >= values[lag + 1]:
			best_lag = lag
			break
	if best_lag == 0:
		return 0.0
	# Parabolic interpolation between lags.
	var a := values[best_lag - 1]
	var b := values[best_lag]
	var c := values[best_lag + 1]
	var shift := 0.5 * (a - c) / maxf(a - 2.0 * b + c, -1e9) if absf(a - 2.0 * b + c) > 1e-9 else 0.0
	return r / (best_lag + shift)


func _spread(times: Array, count: int) -> Array:
	if times.size() <= count:
		return times
	var out: Array = []
	for i: int in count:
		out.append(times[int(float(i) * times.size() / count)])
	return out


## Energy in the squeal's band (Goertzel at several frequencies across it), averaged over 40 ms windows.
func _band_db(x: PackedFloat32Array, rate: float, times: Array) -> float:
	if times.is_empty():
		return -200.0
	var size := int(rate * 0.04)
	var total := 0.0
	for t: float in times:
		var start := int(t * rate) - size / 2
		if start < 0 or start + size >= x.size():
			continue
		var strongest := 0.0
		var f := 1060.0
		while f <= 1300.0:
			var w := TAU * f / rate
			var coeff := 2.0 * cos(w)
			var s1 := 0.0
			var s2 := 0.0
			for i: int in size:
				var s0 := x[start + i] + coeff * s1 - s2
				s2 = s1
				s1 = s0
			strongest = maxf(strongest, s1 * s1 + s2 * s2 - coeff * s1 * s2)
			f += 20.0
		total += strongest
	return 10.0 * log(maxf(total / times.size(), 1e-20)) / log(10.0)


func _impact_time() -> float:
	var after := _event_time("towards_post")
	var last_speed := 0.0
	for row: Array in _timeline:
		var t := float(row[0])
		if t < after:
			continue
		var v := float(row[3])
		if last_speed > 3.0 and v < last_speed - 1.0:
			return t
		last_speed = v
	return -1.0


## How much louder the 60 ms after t is than the 300 ms before it, in dB (peak against RMS).
func _transient_rise(x: PackedFloat32Array, rate: float, t: float) -> float:
	var before := _window_rms(x, rate, t - 0.35, 0.3)
	var a := clampi(int((t - 0.03) * rate), 0, x.size() - 1)
	var b := clampi(int((t + 0.12) * rate), a + 1, x.size())
	var peak := 0.0
	for i: int in range(a, b):
		peak = maxf(peak, absf(x[i]))
	return linear_to_db(maxf(peak, 1e-9)) - linear_to_db(maxf(before * sqrt(2.0), 1e-9))


func _clicks(x: PackedFloat32Array, rate: float) -> Array:
	var quiet_zones: Array = []
	for label: String in ["enter", "leave"]:
		var t := _event_time(label)
		quiet_zones.append([t - 0.05, t + 1.4])
	var hit := _impact_time()
	if hit > 0.0:
		quiet_zones.append([hit - 0.2, hit + 1.0])
	var found: Array = []
	for t: float in _click_times(x, rate):
		var excused := false
		for z: Array in quiet_zones:
			if t >= float(z[0]) and t <= float(z[1]):
				excused = true
		if not excused:
			found.append(snappedf(t, 0.001))
	return found


## A click is a sudden bend in the waveform: the largest second difference in a 256-sample block is more
## than twice the largest in the 32 blocks either side (about 170 ms each way at 48 kHz). Engine pulses
## repeat within that span, so they set their own reference; a glitch does not repeat.
func _click_times(x: PackedFloat32Array, rate: float) -> Array:
	var block := 256
	var near := 32
	var count := (x.size() - 2) / block
	var peaks := PackedFloat32Array()
	peaks.resize(count)
	for b: int in count:
		var m := 0.0
		var base := b * block
		for k: int in range(base + 1, base + block + 1):
			m = maxf(m, absf(x[k + 1] - 2.0 * x[k] + x[k - 1]))
		peaks[b] = m
	var out: Array = []
	for b: int in range(near, count - near):
		if peaks[b] < 0.01:
			continue
		var around := 0.0
		for k: int in range(b - near, b + near + 1):
			if k != b:
				around = maxf(around, peaks[k])
		if peaks[b] > around * 2.0:
			out.append(b * block / rate)
	return out


## Proves the click check can find a click: a short step of -16 dBFS is put into copies of the recording.
func _click_self_check(x: PackedFloat32Array, rate: float) -> int:
	var found := 0
	var times := [2.0, 6.0, 10.5, 15.0, 18.5]
	for t: float in times:
		var a := int((t - 0.6) * rate)
		var b := int((t + 0.6) * rate)
		if a < 0 or b >= x.size():
			continue
		var piece := x.slice(a, b)
		var at := int(0.6 * rate)
		for k: int in range(at, mini(at + int(rate * 0.01), piece.size())):
			piece[k] += 0.15 * exp(-float(k - at) / (rate * 0.002))
		for c: float in _click_times(piece, rate):
			if absf(c - 0.6) < 0.02:
				found += 1
				break
	return found


## Each loop file's jump from its last sample back to its first, as a share of its largest ordinary steps.
func _loop_seams() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(VehicleAudio.DIR)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if not file.ends_with(".wav") or file.begins_with("door") or file.begins_with("impact"):
			continue
		var bytes := FileAccess.get_file_as_bytes(VehicleAudio.DIR + file)
		if bytes.size() < 100:
			continue
		var pos := 12
		var data_at := -1
		var data_size := 0
		while pos + 8 <= bytes.size():
			var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
			var size := bytes.decode_u32(pos + 4)
			if id == "data":
				data_at = pos + 8
				data_size = size
				break
			pos += 8 + size + (size % 2)
		if data_at < 0:
			continue
		var frames := data_size / 2 - VehicleAudio.LOOP_GUARD      # the loop's own length, without the guard copy
		var steps := PackedFloat32Array()
		steps.resize(frames - 1)
		for k: int in frames - 1:
			steps[k] = absf(bytes.decode_s16(data_at + (k + 1) * 2) - bytes.decode_s16(data_at + k * 2))
		steps.sort()
		var p999 := maxf(steps[int(steps.size() * 0.999)], 1.0)
		var seam := absf(bytes.decode_s16(data_at) - bytes.decode_s16(data_at + (frames - 1) * 2))
		out[file] = snappedf(seam / p999, 0.001)
	return out


func _note(text: String) -> void:
	(_result["notes"] as Array).append(text)


func _fail(why: String) -> void:
	_note(why)
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "handbrake"]:
		Input.action_release(action)
	if Game.out_dir != "":
		DirAccess.make_dir_recursive_absolute(Game.out_dir)
		var f := FileAccess.open(Game.out_dir.path_join("result.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(_result, "  "))
		f.close()
	print("AUTO ", JSON.stringify(_result))
	get_tree().quit(0)
