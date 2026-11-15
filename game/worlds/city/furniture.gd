class_name CityFurniture
extends Node3D
## The street furniture of the first blocks, placed along the kerbs: lamps (lit at dusk, the nearest few
## casting shadows), street trees in iron tree grates, hydrants, pay stations, litter bins, bollards, all-way
## stop signs and street-name blades at the plain junctions, signals at the centre junction, and a bus shelter.
## Repeated pieces are MultiMeshes; everything a car could hit has collision.

const PROPS := preload("res://worlds/city/furniture_props.gd")
const TREES := preload("res://worlds/city/furniture_tree.gd")
const SIGNALS := preload("res://worlds/city/furniture_signals.gd")
const K := preload("res://worlds/city/furniture_kit.gd")

const LAMP_SPACING: float = 30.0
const LAMP_FROM_KERB: float = 0.6
const TREE_SPACING: float = 9.0
const TREE_FROM_KERB: float = 1.2
## A street tree stands at least this far from a lamp pole, so its crown stays out of the luminaire's light
## (crowns that reached the lamp head glowed white at night).
const TREE_FROM_LAMP: float = 5.5
const TREE_FROM_SPAWN: float = 6.0
const SHADOW_LAMPS: int = 4
const BUS_STOP_X: float = CityRoads.BUS_STOP.x      # on Corder St, south side, between the parked car and the junction

var lamps: Array[SpotLight3D] = []
var signals: FurnitureSignals
var night: float = 0.0
var counts: Dictionary = {}
## Points on the pavement (x, z) to keep clear of furniture, such as where the player starts. Set before build().
var keep_clear: Array = []

var _roads: CityRoads
var _body: StaticBody3D
var _reserved: Array[Vector3] = []      # x, z, radius
var _xf: Dictionary = {}                # kind -> Array[Transform3D]
var _lamp_trips: Array[float] = []
var _lamp_spots: Array[Vector2] = []
var _lamp_mat: ShaderMaterial
var _glow_mats: Array[ShaderMaterial] = []
var _map_mats: Array[ShaderMaterial] = []
var _shadow_clock: float = 0.0
var _mats: Dictionary = {}


func build(roads: CityRoads) -> void:
	_roads = roads
	_body = StaticBody3D.new()
	_body.name = "FurnitureBody"
	add_child(_body)
	_make_materials()
	for p: Vector2 in keep_clear:
		_reserve(p, 1.2)
	for cr: Dictionary in roads.crossings():
		var c: Vector2 = cr["centre"]
		var d: Vector2 = cr["dir"]
		var across := Vector2(-d.y, d.x)
		for s: float in [-1.0, 1.0]:
			_reserve(c + across * s * CityRoads.HALF_ROAD, 3.3)
	_build_signals()
	_build_stop_signs()
	_build_bus_stop()
	for e: Dictionary in _edges():
		_place_lamps(e)
	for e: Dictionary in _edges():
		if e["inner"]:
			_place_edge_extras(e)
	_place_corners()
	_build_instances()
	set_night(night)


# --- where things go --------------------------------------------------------------------

## The straight runs of kerb: p0, direction, length, n (into the pavement), inner (a block's own pavement).
func _edges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rings: Array = []
	for c: Vector2 in CityRoads.block_centres():
		rings.append([c, CityRoads.BLOCK_X / 2.0 + CityRoads.PAVEMENT, CityRoads.BLOCK_Z / 2.0 + CityRoads.PAVEMENT, true])
	rings.append([Vector2.ZERO, CityRoads.X_KERB, CityRoads.Z_KERB, false])
	var r := CityRoads.CORNER_R
	for ring: Array in rings:
		var c: Vector2 = ring[0]
		var hx: float = ring[1]
		var hz: float = ring[2]
		var inner: bool = ring[3]
		var sides: Array = [
			[Vector2(c.x - hx + r, c.y - hz), Vector2(1, 0), 2.0 * (hx - r), Vector2(0, 1)],
			[Vector2(c.x - hx + r, c.y + hz), Vector2(1, 0), 2.0 * (hx - r), Vector2(0, -1)],
			[Vector2(c.x - hx, c.y - hz + r), Vector2(0, 1), 2.0 * (hz - r), Vector2(1, 0)],
			[Vector2(c.x + hx, c.y - hz + r), Vector2(0, 1), 2.0 * (hz - r), Vector2(-1, 0)],
		]
		for sd: Array in sides:
			var n: Vector2 = sd[3] if inner else -(sd[3] as Vector2)
			out.append({"p0": sd[0], "dir": sd[1], "length": sd[2], "n": n, "inner": inner, "along_x": absf((sd[1] as Vector2).x) > 0.5})
	return out


func _at(e: Dictionary, s: float, d: float) -> Vector2:
	return (e["p0"] as Vector2) + (e["dir"] as Vector2) * s + (e["n"] as Vector2) * d


## Transform on the pavement at p, with local +Z pointing out toward the road (opposite n).
static func _facing(p: Vector2, n: Vector2, y: float = CityRoads.KERB_H) -> Transform3D:
	var z := Vector3(-n.x, 0.0, -n.y)
	var x := Vector3.UP.cross(z)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(p.x, y, p.y))


func _free(p: Vector2, radius: float) -> bool:
	for r: Vector3 in _reserved:
		if p.distance_to(Vector2(r.x, r.y)) < radius + r.z:
			return false
	return true


func _clear_of_lamps(p: Vector2) -> bool:
	for l: Vector2 in _lamp_spots:
		if p.distance_to(l) < TREE_FROM_LAMP:
			return false
	return true


## No tree trunk within a few steps of a keep-clear point, so the view from there is the street.
func _clear_of_spawn(p: Vector2) -> bool:
	for c: Vector2 in keep_clear:
		if p.distance_to(c) < TREE_FROM_SPAWN:
			return false
	return true


func _reserve(p: Vector2, radius: float) -> void:
	_reserved.append(Vector3(p.x, p.y, radius))


func _add(kind: String, xf: Transform3D) -> void:
	if not _xf.has(kind):
		_xf[kind] = []
	(_xf[kind] as Array).append(xf)


func _place_lamps(e: Dictionary) -> void:
	var length: float = e["length"]
	var n := maxi(1, roundi(length / LAMP_SPACING))
	for k: int in n:
		var s0 := (k + 0.5) * length / n
		for nudge: float in [0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0]:
			var s := s0 + nudge
			if s < 0.5 or s > length - 0.5:
				continue
			var p := _at(e, s, LAMP_FROM_KERB)
			if _free(p, 0.9):
				_reserve(p, 0.9)
				_add_lamp(_facing(p, e["n"]))
				break


func _add_lamp(xf: Transform3D) -> void:
	_add("lamp", xf)
	_lamp_spots.append(Vector2(xf.origin.x, xf.origin.z))
	_cylinder(xf.origin, 0.13, 8.4)
	var light := SpotLight3D.new()
	light.name = "LampLight"
	var lens := xf * PROPS.LAMP_LENS
	var aim := xf.basis * Vector3(0.0, -1.0, 0.2).normalized()
	light.transform = Transform3D(Basis.looking_at(aim, xf.basis.x), lens - Vector3(0.0, 0.03, 0.0))
	light.light_color = Color(1.0, 0.86, 0.70)
	light.light_energy = 24.0
	light.light_indirect_energy = 0.6
	light.light_volumetric_fog_energy = 1.0
	light.spot_range = 24.0
	light.spot_angle = 62.0
	light.spot_angle_attenuation = 0.85
	light.spot_attenuation = 1.25
	light.light_size = 0.25
	light.shadow_enabled = false
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 140.0
	light.distance_fade_length = 40.0
	light.visible = false
	add_child(light)
	lamps.append(light)
	# each photocell trips at its own level of darkness
	var h := absf(sin(xf.origin.x * 12.9898 + xf.origin.z * 78.233) * 43758.5453)
	_lamp_trips.append(0.18 + 0.14 * (h - floorf(h)))


func _place_edge_extras(e: Dictionary) -> void:
	var length: float = e["length"]
	# street trees in tree grates
	var s := 4.5
	while s < length - 4.0:
		# a tree that would stand too near a lamp or other furniture is nudged along the kerb, or left out
		var p := Vector2.INF
		for nudge: float in [0.0, 1.5, -1.5, 3.0, -3.0]:
			var q := _at(e, s + nudge, TREE_FROM_KERB)
			if s + nudge > 3.0 and s + nudge < length - 3.0 and _free(q, 2.4) and _clear_of_lamps(q) and _clear_of_spawn(q):
				p = q
				break
		if p != Vector2.INF:
			_reserve(p, 1.0)
			var xf := _facing(p, e["n"])
			var seed_value := absi(int(p.x * 13.0 + p.y * 7.0)) % 3
			_add("tree_%d" % seed_value, xf.rotated_local(Vector3.UP, float(absi(int(p.x * 3.1 + p.y))) * 0.9))
			_add("tree_grate", xf)
			_cylinder(xf.origin, 0.16, 2.6)
		s += TREE_SPACING
	# one hydrant near the start of each run, a little way back from the corner
	for s2: float in [6.5, 8.5, 10.5, 12.5]:
		var p2 := _at(e, s2, 0.55)
		if _free(p2, 0.7):
			_reserve(p2, 0.7)
			_add("hydrant", _facing(p2, e["n"]))
			_cylinder(Vector3(p2.x, CityRoads.KERB_H, p2.y), 0.17, 0.85)
			break
	# a pay station on the long runs, where there is parking
	if e["along_x"]:
		for s3: float in [length * 0.5 + 3.0, length * 0.5 - 3.0, length * 0.5 + 6.0]:
			var p3 := _at(e, s3, 0.55)
			if _free(p3, 0.7):
				_reserve(p3, 0.7)
				var xf3 := _facing(p3, e["n"])
				_add("pay", xf3)
				_box(xf3, Vector3(0.0, 0.8, 0.0), Vector3(0.42, 1.6, 0.32))
				break


## Bins and bollards at the street corners.
func _place_corners() -> void:
	var r := CityRoads.CORNER_R
	for c: Vector2 in CityRoads.block_centres():
		var hx := CityRoads.BLOCK_X / 2.0 + CityRoads.PAVEMENT
		var hz := CityRoads.BLOCK_Z / 2.0 + CityRoads.PAVEMENT
		for s: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			var ac := c + Vector2(s.x * (hx - r), s.y * (hz - r))
			var corner_to_centre := (c + Vector2(s.x * hx, s.y * hz)).length() < 20.0
			# a bin near every corner, set back from the kerb
			var a := deg_to_rad(28.0)
			var radial := Vector2(s.x * cos(a), s.y * sin(a))
			var pb := ac + radial * (r - 1.5)
			if _free(pb, 0.5):
				_reserve(pb, 0.5)
				var xfb := _facing(pb, -radial)
				_add("bin", xfb)
				_cylinder(xfb.origin, 0.3, 1.05)
			if corner_to_centre:
				# bollards guard the corners of the signalled junction
				for deg: float in [12.0, 78.0]:
					var ra := deg_to_rad(deg)
					var rad2 := Vector2(s.x * cos(ra), s.y * sin(ra))
					var pp := ac + rad2 * (r - 0.45)
					_add("bollard", _facing(pp, -rad2))
					_cylinder(Vector3(pp.x, CityRoads.KERB_H, pp.y), 0.12, 1.0)


# --- signs, signals, the bus stop ---------------------------------------------------------

func _build_signals() -> void:
	signals = SIGNALS.new() as FurnitureSignals
	add_child(signals)
	var centre := CityRoads.junction(1, 1)
	signals.build(centre, _mats["black"], _body, {"ns": CityRoads.NS_NAMES[1], "ew": CityRoads.EW_NAMES[1]})
	for p: Vector2 in signals.pole_positions:
		_reserve(p, 1.2)
		# the corner poles carry a street lamp too, reaching in over the junction
		var to_centre := (centre - p).normalized()
		_add_lamp(_facing(p, -to_centre))


## All-way stops at every junction without signals, and the street names on the first post of each.
func _build_stop_signs() -> void:
	for i: int in CityRoads.JUNCTIONS:
		for j: int in CityRoads.JUNCTIONS:
			if i == 1 and j == 1:
				continue
			var jc := CityRoads.junction(i, j)
			var first := true
			for d: Vector2 in CityRoads.legs(i, j):
				var r := CityRoads.right_of(-d)
				var p := jc + d * (CityRoads.STOP_LINE_AT - 0.2) + r * (CityRoads.HALF_ROAD + 0.5)
				_reserve(p, 0.8)
				var face := Vector3(d.x, 0.0, d.y)
				var xf := Transform3D(Basis.looking_at(-face, Vector3.UP), Vector3(p.x, CityRoads.KERB_H, p.y))
				_add("stop", xf)
				_box(xf, Vector3(0.0, 1.45, -0.03), Vector3(0.06, 2.9, 0.06))
				_label("STOP", xf.translated_local(Vector3(0.0, 2.45, 0.008)), 96, 0.0032, Color(0.95, 0.95, 0.93))
				_label("ALL-WAY", xf.translated_local(Vector3(0.0, 1.93, 0.008)), 40, 0.0032, Color(0.95, 0.95, 0.93))
				_add("allway", xf)
				if first:
					first = false
					_add("blades", xf)
					var along_ns := absf(d.y) > 0.5
					# blade 0 runs along local X, blade 1 along local Z (the leg's own street)
					var name0: String = CityRoads.EW_NAMES[j] if along_ns else CityRoads.NS_NAMES[i]
					var name1: String = CityRoads.NS_NAMES[i] if along_ns else CityRoads.EW_NAMES[j]
					for side: float in [1.0, -1.0]:
						var b0 := xf.translated_local(Vector3(0.0, 3.05, 0.008 * side))
						if side < 0.0:
							b0 = b0.rotated_local(Vector3.UP, PI)
						_label(name0, b0, 40, 0.0036, Color(0.93, 0.95, 0.93))
						var b1 := xf.translated_local(Vector3(0.008 * side, 3.31, 0.0)).rotated_local(Vector3.UP, PI / 2.0 * side)
						_label(name1, b1, 40, 0.0036, Color(0.93, 0.95, 0.93))


func _build_bus_stop() -> void:
	# On the south pavement of Corder St: shelter set back to leave the kerb clear, sign at the kerb.
	var kerb_z := CityRoads.HALF_ROAD
	var n := Vector2(0, 1)
	var centre := Vector2(BUS_STOP_X, kerb_z + 2.45)
	_reserve(centre, 3.2)
	_reserve(Vector2(BUS_STOP_X - 3.5, kerb_z + 0.5), 1.0)
	var xf := _facing(centre, n)
	var shelter := _shelter_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "BusShelter"
	mi.mesh = shelter
	mi.transform = xf
	add_child(mi)
	for px: float in [-1.6, 1.6]:
		_box(xf, Vector3(px, 1.25, -0.6), Vector3(0.08, 2.5, 0.08))
	_box(xf, Vector3(0.0, 1.2, -0.66), Vector3(3.3, 2.3, 0.05))
	_box(xf, Vector3(-1.62, 1.2, -0.05), Vector3(0.05, 2.3, 1.2))
	_box(xf, Vector3(0.0, 0.45, -0.4), Vector3(2.4, 0.45, 0.4))
	# bus stop sign at the kerb
	var sp := Vector2(BUS_STOP_X - 3.5, kerb_z + 0.5)
	var sxf := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(sp.x, CityRoads.KERB_H, sp.y))
	_add("bus_sign", sxf)
	_box(sxf, Vector3(0.0, 1.4, 0.0), Vector3(0.06, 2.8, 0.06))
	for side: float in [1.0, -1.0]:
		var lx := sxf.translated_local(Vector3(0.0, 2.55, 0.012 * side))
		if side < 0.0:
			lx = lx.rotated_local(Vector3.UP, PI)
		_label("BUS", lx, 72, 0.003, Color(0.95, 0.95, 0.95))
		_label("CALDER TRANSIT", lx.translated_local(Vector3(0.0, 0.17, 0.0)), 22, 0.003, Color(0.95, 0.95, 0.95))
		_label("12   40   41", lx.translated_local(Vector3(0.0, -0.17, 0.0)), 34, 0.003, Color(0.1, 0.1, 0.1))


## The shelter: four steel posts, a cantilevered roof with a fascia, a toughened-glass back and end panel,
## a perforated bench, and a lit route map in the end panel.
func _shelter_mesh() -> ArrayMesh:
	var frame := PROPS._st()
	for px: float in [-1.6, 1.6]:
		for pz: float in [-0.62, 0.55]:
			K.box(frame, Vector3(px, 1.24, pz), Vector3(0.07, 2.48, 0.07))
	K.box(frame, Vector3(0.0, 2.52, -0.05), Vector3(3.6, 0.07, 1.65))
	K.box(frame, Vector3(0.0, 2.47, 0.78), Vector3(3.6, 0.17, 0.04))
	K.box(frame, Vector3(0.0, 2.36, -0.62), Vector3(3.2, 0.05, 0.05))
	K.box(frame, Vector3(0.0, 0.12, -0.62), Vector3(3.2, 0.05, 0.05))
	# bench: seat on two legs
	K.box(frame, Vector3(0.0, 0.46, -0.38), Vector3(2.3, 0.04, 0.38))
	K.box(frame, Vector3(0.0, 0.48, -0.56), Vector3(2.3, 0.02, 0.02))
	for bx: float in [-0.9, 0.9]:
		K.box(frame, Vector3(bx, 0.23, -0.38), Vector3(0.05, 0.46, 0.3))
	var glass := PROPS._st()
	K.box(glass, Vector3(0.0, 1.24, -0.64), Vector3(3.13, 2.18, 0.012))
	K.box(glass, Vector3(-1.62, 1.24, -0.03), Vector3(0.012, 2.18, 1.1))
	var panel := PROPS._st()
	K.box(panel, Vector3(1.6, 1.35, -0.03), Vector3(0.1, 1.6, 1.0))
	var mesh := PROPS._commit([frame, glass, panel])
	mesh.surface_set_material(0, _mats["black"])
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.75, 0.82, 0.82, 0.18)
	gm.roughness = 0.05
	gm.metallic_specular = 0.8
	mesh.surface_set_material(1, gm)
	mesh.surface_set_material(2, _map_material())
	return mesh


# --- making the instances ------------------------------------------------------------------

func _make_materials() -> void:
	_mats["black"] = _metal(Color(0.025, 0.027, 0.03), 0.48, 0.35)
	_mats["housing"] = _metal(Color(0.07, 0.075, 0.08), 0.38, 0.55)
	_mats["galv"] = _metal(Color(0.50, 0.51, 0.52), 0.42, 0.85)
	_mats["hydrant"] = _metal(Color(0.80, 0.55, 0.04), 0.5, 0.1)
	_mats["dark"] = _metal(Color(0.03, 0.03, 0.03), 0.6, 0.2)
	_mats["cabinet"] = _metal(Color(0.12, 0.16, 0.15), 0.45, 0.4)
	_mats["liner"] = _metal(Color(0.012, 0.012, 0.012), 0.8, 0.0)
	_lamp_mat = ShaderMaterial.new()
	_lamp_mat.shader = load("res://worlds/city/shaders/road_lamp.gdshader") as Shader
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.85, 0.85, 0.83)
	white.roughness = 0.35
	_mats["white"] = white
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.55, 0.03, 0.03)
	red.roughness = 0.35
	_mats["red"] = red
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.02, 0.2, 0.08)
	green.roughness = 0.4
	_mats["green"] = green
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.02, 0.03, 0.06)
	blue.roughness = 0.1
	blue.metallic = 0.3
	_mats["solar"] = blue
	var bark := ShaderMaterial.new()
	bark.shader = load("res://worlds/city/shaders/road_bark.gdshader") as Shader
	_mats["bark"] = bark
	var leaves := ShaderMaterial.new()
	leaves.shader = load("res://worlds/city/shaders/road_leaves.gdshader") as Shader
	_mats["leaves"] = leaves
	var grate := ShaderMaterial.new()
	grate.shader = load("res://worlds/city/shaders/road_iron.gdshader") as Shader
	grate.set_shader_parameter("kind", 2)
	_mats["grate"] = grate


func _metal(col: Color, rough: float, metal: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://worlds/city/shaders/road_metal.gdshader") as Shader
	m.set_shader_parameter("paint", Color(col.r, col.g, col.b))
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("metal", metal)
	_roads._materials.append(m)          # so rain darkens it too
	return m


func _glow_material(base: Color, light: Color, energy: float) -> ShaderMaterial:
	var m := _metal(base, 0.3, 0.0)
	m.set_shader_parameter("emit_colour", Color(light.r, light.g, light.b))
	m.set_shader_parameter("emit_energy", 0.0)
	m.set_meta("energy", energy)
	_glow_mats.append(m)
	return m


## The route map in the shelter's end panel, backlit after dark.
func _map_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://worlds/city/shaders/road_map.gdshader") as Shader
	_map_mats.append(m)
	return m


func _build_instances() -> void:
	var lamp := PROPS.lamp()
	lamp.surface_set_material(0, _mats["black"])
	lamp.surface_set_material(1, _mats["housing"])
	lamp.surface_set_material(2, _lamp_mat)
	var mmi := _multimesh("Lamps", lamp, _xf.get("lamp", []), true)
	mmi.multimesh = _with_custom(mmi.multimesh, _lamp_trips)
	var hyd := PROPS.hydrant()
	hyd.surface_set_material(0, _mats["hydrant"])
	hyd.surface_set_material(1, _mats["dark"])
	_multimesh("Hydrants", hyd, _xf.get("hydrant", []), true)
	var bol := PROPS.bollard()
	bol.surface_set_material(0, _mats["black"])
	_multimesh("Bollards", bol, _xf.get("bollard", []), true)
	var bin_mesh := PROPS.bin()
	bin_mesh.surface_set_material(0, _mats["black"])
	bin_mesh.surface_set_material(1, _mats["liner"])
	_multimesh("Bins", bin_mesh, _xf.get("bin", []), true)
	var pay := PROPS.pay_station()
	pay.surface_set_material(0, _mats["cabinet"])
	pay.surface_set_material(1, _glow_material(Color(0.02, 0.03, 0.03), Color(0.5, 0.75, 0.9), 1.2))
	pay.surface_set_material(2, _mats["solar"])
	_multimesh("PayStations", pay, _xf.get("pay", []), true)
	var stop := PROPS.stop_sign()
	stop.surface_set_material(0, _mats["galv"])
	stop.surface_set_material(1, _mats["white"])
	stop.surface_set_material(2, _mats["red"])
	_multimesh("StopSigns", stop, _xf.get("stop", []), true)
	var allway := PROPS._st()
	K.box(allway, Vector3(0.0, 1.93, 0.0), Vector3(0.46, 0.15, 0.004))
	var allway_white := PROPS._st()
	K.box(allway_white, Vector3(0.0, 1.93, 0.003), Vector3(0.43, 0.12, 0.004))
	var allway_mesh := PROPS._commit([allway, allway_white])
	allway_mesh.surface_set_material(0, _mats["white"])
	allway_mesh.surface_set_material(1, _mats["red"])
	_multimesh("AllWayPlaques", allway_mesh, _xf.get("allway", []), false)
	var blades := PROPS.name_blades(3.05)
	blades.surface_set_material(0, _mats["green"])
	blades.surface_set_material(1, _mats["white"])
	_multimesh("NameBlades", blades, _xf.get("blades", []), false)
	var bus := PROPS._st()
	K.box(bus, Vector3(0.0, 2.55, 0.0), Vector3(0.46, 0.6, 0.02))
	var bus_mesh := PROPS._commit([bus])
	bus_mesh.surface_set_material(0, _mats["green"])
	_multimesh("BusSign", bus_mesh, _xf.get("bus_sign", []), false)
	for k: int in 3:
		var tree := TREES.build(31 + k * 17)
		tree.surface_set_material(0, _mats["bark"])
		tree.surface_set_material(1, _mats["leaves"])
		_multimesh("Trees%d" % k, tree, _xf.get("tree_%d" % k, []), true)
	var grate := PROPS._st()
	K.box(grate, Vector3(0.0, 0.0035, 0.0), Vector3(1.2, 0.007, 1.2))
	var grate_mesh := PROPS._commit([grate])
	grate_mesh.surface_set_material(0, _mats["grate"])
	_multimesh("TreeGrates", grate_mesh, _xf.get("tree_grate", []), false)
	counts = {}
	for kind: String in _xf:
		counts[kind] = (_xf[kind] as Array).size()
	counts["lamp_lights"] = lamps.size()


func _multimesh(node_name: String, mesh: Mesh, xforms: Array, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k: int in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _with_custom(mm: MultiMesh, values: Array[float]) -> MultiMesh:
	var xfs: Array[Transform3D] = []
	for k: int in mm.instance_count:
		xfs.append(mm.get_instance_transform(k))
	var out := MultiMesh.new()
	out.transform_format = MultiMesh.TRANSFORM_3D
	out.use_custom_data = true
	out.mesh = mm.mesh
	out.instance_count = xfs.size()
	for k: int in xfs.size():
		out.set_instance_transform(k, xfs[k])
		out.set_instance_custom_data(k, Color(values[k], 0.0, 0.0, 0.0))
	return out


func _cylinder(foot: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = foot + Vector3(0.0, height / 2.0, 0.0)
	_body.add_child(cs)


func _box(xf: Transform3D, centre: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf * Transform3D(Basis.IDENTITY, centre)
	_body.add_child(cs)


func _label(text: String, xf: Transform3D, size: int, pixel: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = col
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.transform = xf
	add_child(l)


# --- night and shadows ---------------------------------------------------------------------

## 0 by day, 1 at night: lamps switch on one by one as it gets dark.
func set_night(amount: float) -> void:
	night = amount
	if _lamp_mat != null:
		_lamp_mat.set_shader_parameter("night", amount)
	for k: int in lamps.size():
		lamps[k].visible = amount >= _lamp_trips[k]
	for m: ShaderMaterial in _map_mats:
		m.set_shader_parameter("backlight", clampf(amount * 2.0, 0.0, 1.0))
	for m: ShaderMaterial in _glow_mats:
		m.set_shader_parameter("emit_energy", float(m.get_meta("energy")) * clampf(amount * 2.0, 0.0, 1.0))
	_update_shadows()


func _process(delta: float) -> void:
	_shadow_clock -= delta
	if _shadow_clock <= 0.0:
		_shadow_clock = 0.25
		_update_shadows()


## Only the lamps nearest the camera cast shadows; the rest light without them.
func _update_shadows() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or lamps.is_empty():
		return
	var at := cam.global_position
	var order: Array[int] = []
	for k: int in lamps.size():
		if lamps[k].visible:
			order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool: return lamps[a].global_position.distance_squared_to(at) < lamps[b].global_position.distance_squared_to(at))
	var lit := {}
	for k: int in mini(SHADOW_LAMPS, order.size()):
		lit[order[k]] = true
	for k: int in lamps.size():
		var want: bool = lit.has(k)
		if lamps[k].shadow_enabled != want:
			lamps[k].shadow_enabled = want
