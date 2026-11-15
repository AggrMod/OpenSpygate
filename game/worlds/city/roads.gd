class_name CityRoads
extends Node3D
## The streets of the first downtown blocks of Calder: a 3 x 3 grid of junctions around 2 x 2 blocks.
## Carriageways, kerbs with dropped kerbs at the crossings, pavements, road markings, manholes and drains,
## and the building lots behind the pavements. Built in code; the grid stops where the built world stops.
##
## Axes: +X is east, -Z is north, Y is up. The carriageway is at y = 0, the pavement top at y = KERB_H.

const JUNCTIONS: int = 3
const BLOCK_X: float = 90.0             # building line to building line, east-west
const BLOCK_Z: float = 60.0             # north-south
const LANE: float = 3.3
const PARKING: float = 2.2
const HALF_ROAD: float = LANE + PARKING  # 5.5: centre line to kerb face
const PAVEMENT: float = 3.5
const KERB_H: float = 0.15
const KERB_W: float = 0.15              # width of the kerb stone's top
const GUTTER_W: float = 0.45            # concrete gutter pan in front of the kerb
const CORNER_R: float = 4.5             # kerb radius at the street corners
const PITCH_X: float = BLOCK_X + 2.0 * (HALF_ROAD + PAVEMENT)   # 108 m between north-south streets
const PITCH_Z: float = BLOCK_Z + 2.0 * (HALF_ROAD + PAVEMENT)   # 78 m between east-west streets
const X_KERB: float = PITCH_X + HALF_ROAD   # outer kerb line of the grid
const Z_KERB: float = PITCH_Z + HALF_ROAD
const X_EDGE: float = X_KERB + PAVEMENT     # the built world ends here
const Z_EDGE: float = Z_KERB + PAVEMENT
const CROSSING_W: float = 3.0
## Centre of a crossing from the junction centre: far enough out that the whole dropped kerb, flares
## included, lies on the straight kerb beyond the corner radius.
const CROSSING_AT: float = HALF_ROAD + CORNER_R + 1.4 + CROSSING_W / 2.0
const STOP_LINE_W: float = 0.45
const STOP_LINE_AT: float = CROSSING_AT + CROSSING_W / 2.0 + 1.2 + STOP_LINE_W / 2.0
const RAMP_DEPTH: float = 1.7           # a dropped kerb ramps back over this distance (8 %)
const RAMP_FACE: float = 0.012          # what is left of the kerb face at a dropped kerb
const PAINT_Y: float = 0.004
const LOT_DEPTH: float = 30.0
const LOT_MIN: float = 15.0
const LOT_MAX: float = 30.0
const SEED: int = 1873
## The bus stop: centre of its kerbside zone on the south side of Corder St. No parking bays are painted there.
const BUS_STOP: Vector2 = Vector2(-50.0, HALF_ROAD)
const BUS_ZONE: float = 22.0

## Invented street names. North-south avenues from west to east, east-west streets from north to south.
const NS_NAMES: Array[String] = ["Halloway Ave", "Tanner Ave", "Pellam Ave"]
const EW_NAMES: Array[String] = ["Wick St", "Corder St", "Lisle St"]

const SHADER_DIR: String = "res://worlds/city/shaders/"
const WHITE: Color = Color(0.80, 0.80, 0.76)
const YELLOW: Color = Color(0.82, 0.58, 0.10)

var wetness: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _ramps: Array[Vector2] = []
var _lots: Array[Dictionary] = []
var _collision_faces: PackedVector3Array = PackedVector3Array()


func build() -> void:
	_collect_ramps()
	_build_road()
	_build_pavements()
	_build_markings()
	_build_ironwork()
	_build_collision()
	_build_world_edge()
	_make_lots()


# --- the grid ---------------------------------------------------------------------------

## Centre line of north-south street i (0..2, west to east).
static func ns_x(i: int) -> float:
	return (i - 1) * PITCH_X


## Centre line of east-west street j (0..2, north to south).
static func ew_z(j: int) -> float:
	return (j - 1) * PITCH_Z


static func junction(i: int, j: int) -> Vector2:
	return Vector2(ns_x(i), ew_z(j))


## Directions (in x, z) of the street legs leaving junction (i, j). At the edge of the built world some are missing.
static func legs(i: int, j: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if j > 0:
		out.append(Vector2(0.0, -1.0))
	if j < JUNCTIONS - 1:
		out.append(Vector2(0.0, 1.0))
	if i > 0:
		out.append(Vector2(-1.0, 0.0))
	if i < JUNCTIONS - 1:
		out.append(Vector2(1.0, 0.0))
	return out


## The kerbside to the right of traffic moving in direction f (drive on the right).
static func right_of(f: Vector2) -> Vector2:
	return Vector2(-f.y, f.x)


static func block_centres() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for bj: int in JUNCTIONS - 1:
		for bi: int in JUNCTIONS - 1:
			out.append(Vector2((ns_x(bi) + ns_x(bi + 1)) * 0.5, (ew_z(bj) + ew_z(bj + 1)) * 0.5))
	return out


## Building lots: two back-to-back rows of lots along the long sides of each block, covering it completely.
## Each entry: transform (origin at the centre of the lot's front edge, pavement-top level, +Z toward the street),
## width, depth, open_neg_x / open_pos_x (that side faces a street), seed.
func lots() -> Array[Dictionary]:
	if _lots.is_empty():
		_make_lots()
	return _lots


func set_wetness(value: float) -> void:
	wetness = clampf(value, 0.0, 1.0)
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("wetness", wetness)


## A barrier that keeps people and cars out of an empty lot (the lot is void until a building stands on it).
func lot_barrier(lot: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "LotBarrier"
	var w: float = lot["width"]
	var d: float = lot["depth"]
	var walls: Array = [[Vector3(0.0, 1.5, -0.25), Vector3(w, 3.0, 0.5)]]
	if lot["open_neg_x"]:
		walls.append([Vector3(-w / 2.0 + 0.25, 1.5, -d / 2.0), Vector3(0.5, 3.0, d)])
	if lot["open_pos_x"]:
		walls.append([Vector3(w / 2.0 - 0.25, 1.5, -d / 2.0), Vector3(0.5, 3.0, d)])
	for wall: Array in walls:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		cs.shape = box
		cs.position = wall[0]
		body.add_child(cs)
	body.transform = lot["transform"]
	return body


# --- lots -------------------------------------------------------------------------------

func _make_lots() -> void:
	_lots.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var bi := 0
	for c: Vector2 in block_centres():
		for row: int in 2:
			# row 0 faces the street to the south (+Z), row 1 the street to the north (-Z)
			var facing := 1.0 if row == 0 else -1.0
			var widths := _split(BLOCK_X, rng)
			var x := c.x - BLOCK_X / 2.0
			for k: int in widths.size():
				var w: float = widths[k]
				var mid := x + w / 2.0
				var origin := Vector3(mid, KERB_H, c.y + facing * BLOCK_Z / 2.0)
				var basis := Basis.IDENTITY if row == 0 else Basis(Vector3.UP, PI)
				var west_end := k == 0
				var east_end := k == widths.size() - 1
				_lots.append({
					"transform": Transform3D(basis, origin),
					"width": w,
					"depth": LOT_DEPTH,
					# local -X is west for the south-facing row and east for the north-facing row
					"open_neg_x": west_end if row == 0 else east_end,
					"open_pos_x": east_end if row == 0 else west_end,
					"seed": rng.randi(),
					"block": bi,
				})
				x += w
		bi += 1


## Split a frontage into lot widths between LOT_MIN and LOT_MAX that add up exactly.
func _split(total: float, rng: RandomNumberGenerator) -> Array[float]:
	var out: Array[float] = []
	var left := total
	while left > 0.001:
		if left <= LOT_MAX:
			out.append(left)
			break
		var lo := LOT_MIN
		var hi := minf(LOT_MAX, left - LOT_MIN)
		var w := snappedf(rng.randf_range(lo, hi), 0.5)
		w = clampf(w, lo, hi)
		out.append(w)
		left -= w
	return out


# --- road surface -----------------------------------------------------------------------

func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array[float] = [-X_KERB, -PITCH_X + HALF_ROAD, -HALF_ROAD, HALF_ROAD, PITCH_X - HALF_ROAD, X_KERB]
	var zs: Array[float] = [-Z_KERB, -PITCH_Z + HALF_ROAD, -HALF_ROAD, HALF_ROAD, PITCH_Z - HALF_ROAD, Z_KERB]
	for a: int in 5:
		for b: int in 5:
			var x0 := xs[a]
			var x1 := xs[a + 1]
			var z0 := zs[b]
			var z1 := zs[b + 1]
			if a % 2 == 0 or b % 2 == 0:
				var poly: Array[Vector2] = []
				var corners: Array[Vector2] = [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
				for p: Vector2 in corners:
					var outer := absf(p.x) > X_KERB - 0.01 and absf(p.y) > Z_KERB - 0.01
					if outer:
						# The outer corners of the grid are rounded like every other kerb.
						var sx := signf(p.x)
						var sz := signf(p.y)
						var c := Vector2(sx * (X_KERB - CORNER_R), sz * (Z_KERB - CORNER_R))
						poly.append_array(_arc(c, CORNER_R, sx, sz, 10))
					else:
						poly.append(p)
				_fan(st, _sorted_convex(poly), 0.0)
			else:
				# Block: the road fills the rounded corners in front of the kerb.
				for sx: float in [-1.0, 1.0]:
					for sz: float in [-1.0, 1.0]:
						var p := Vector2(x1 if sx > 0.0 else x0, z1 if sz > 0.0 else z0)
						var c := p - Vector2(sx * CORNER_R, sz * CORNER_R)
						var arc := _arc(c, CORNER_R, sx, sz, 10)
						for k: int in arc.size() - 1:
							_tri(st, _v3(p, 0.0), _v3(arc[k], 0.0), _v3(arc[k + 1], 0.0), Vector3.UP)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh
	mi.material_override = _material("road_asphalt.gdshader")
	add_child(mi)
	_add_collision_from(mesh)


## Points on the quarter circle of radius r around c that bulges toward (sx, sz).
func _arc(c: Vector2, r: float, sx: float, sz: float, steps: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k: int in steps + 1:
		var a := float(k) / steps * PI * 0.5
		out.append(c + Vector2(sx * cos(a), sz * sin(a)) * r)
	return out


## The points of a convex polygon, in order round its centre.
func _sorted_convex(poly: Array[Vector2]) -> Array[Vector2]:
	var centre := Vector2.ZERO
	for p: Vector2 in poly:
		centre += p
	centre /= poly.size()
	var out := poly.duplicate()
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - centre).angle() < (b - centre).angle())
	var typed: Array[Vector2] = []
	typed.assign(out)
	return typed


func _fan(st: SurfaceTool, poly: Array[Vector2], y: float) -> void:
	var centre := Vector2.ZERO
	for p: Vector2 in poly:
		centre += p
	centre /= poly.size()
	for k: int in poly.size():
		_tri(st, _v3(centre, y), _v3(poly[k], y), _v3(poly[(k + 1) % poly.size()], y), Vector3.UP)


# --- pavements and kerbs ----------------------------------------------------------------

func _collect_ramps() -> void:
	_ramps.clear()
	for i: int in JUNCTIONS:
		for j: int in JUNCTIONS:
			var c := junction(i, j)
			for d: Vector2 in legs(i, j):
				var at := c + d * CROSSING_AT
				var across := Vector2(-d.y, d.x)
				_ramps.append(at + across * HALF_ROAD)
				_ramps.append(at - across * HALF_ROAD)


## Crossings: centre point, direction along the street, and whether it gets the ladder pattern.
func crossings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in JUNCTIONS:
		for j: int in JUNCTIONS:
			var c := junction(i, j)
			for d: Vector2 in legs(i, j):
				out.append({"centre": c + d * CROSSING_AT, "dir": d, "ladder": i == 1 and j == 1, "junction": Vector2i(i, j)})
	return out


func _ramp_factor(k: Vector2) -> float:
	var f := 0.0
	for r: Vector2 in _ramps:
		var a := k.distance_to(r)
		if a < 3.0:
			f = maxf(f, 1.0 if a <= CROSSING_W / 2.0 else 1.0 - smoothstep(CROSSING_W / 2.0, CROSSING_W / 2.0 + 1.1, a))
	return f


func _build_pavements() -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerb := SurfaceTool.new()
	kerb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2 in block_centres():
		_ring(top, kerb, edge, c, BLOCK_X / 2.0 + PAVEMENT, BLOCK_Z / 2.0 + PAVEMENT, true)
	_ring(top, kerb, edge, Vector2.ZERO, X_KERB, Z_KERB, false)
	var mesh := ArrayMesh.new()
	top.commit(mesh)
	kerb.commit(mesh)
	edge.commit(mesh)
	mesh.surface_set_material(0, _material("road_pavement.gdshader"))
	var kerb_mat := _material("road_pavement.gdshader")
	kerb_mat.set_shader_parameter("is_kerb", true)
	mesh.surface_set_material(1, kerb_mat)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.0, 0.0, 0.0)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(2, black)
	var mi := MeshInstance3D.new()
	mi.name = "Pavements"
	mi.mesh = mesh
	add_child(mi)


## Samples round a rounded-rectangle kerb line. Each: k = point on the kerb face, n = unit direction into the
## pavement, b = the matching point on the back of the pavement.
func _ring_samples(centre: Vector2, hx: float, hz: float, inside: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var back_off := -PAVEMENT if inside else PAVEMENT
	for ci: int in 4:
		var s := corners[ci]
		var ac := centre + Vector2(s.x * (hx - CORNER_R), s.y * (hz - CORNER_R))
		var back_corner := centre + Vector2(s.x * (hx + back_off), s.y * (hz + back_off))
		var a0 := float(ci) * PI * 0.5
		for k: int in 13:
			var a := a0 + float(k) / 12.0 * PI * 0.5
			var radial := Vector2(cos(a), sin(a))
			out.append({"k": ac + radial * CORNER_R, "n": -radial if inside else radial, "b": back_corner})
		# straight edge from the end of this arc to the start of the next
		var a_end := a0 + PI * 0.5
		var p0 := ac + Vector2(cos(a_end), sin(a_end)) * CORNER_R
		var s2 := corners[(ci + 1) % 4]
		var ac2 := centre + Vector2(s2.x * (hx - CORNER_R), s2.y * (hz - CORNER_R))
		var p1 := ac2 + Vector2(cos(a_end), sin(a_end)) * CORNER_R
		var outward := Vector2(cos(a_end), sin(a_end))
		var n := -outward if inside else outward
		var length := p0.distance_to(p1)
		var dir := (p1 - p0) / length
		var ts: Array[float] = []
		var t := 0.0
		while t < length:
			ts.append(t)
			t += 1.5
		ts.append(length)
		for r: Vector2 in _ramps:
			var rel := r - p0
			if absf(rel.dot(n)) < 0.3:
				var along := rel.dot(dir)
				var o := -3.0
				while o <= 3.0:
					if along + o > 0.0 and along + o < length:
						ts.append(along + o)
					o += 0.25
		ts.sort()
		var last := -1.0
		for tt: float in ts:
			if tt - last < 0.05:
				continue
			last = tt
			var kp := p0 + dir * tt
			out.append({"k": kp, "n": n, "b": kp + n * PAVEMENT})
	return out


func _ring(top: SurfaceTool, kerb: SurfaceTool, edge: SurfaceTool, centre: Vector2, hx: float, hz: float, inside: bool) -> void:
	var samples := _ring_samples(centre, hx, hz, inside)
	var count := samples.size()
	# Heights and cross-sections for every sample.
	var rows: Array = []
	for s: Dictionary in samples:
		var k: Vector2 = s["k"]
		var b: Vector2 = s["b"]
		var f := _ramp_factor(k)
		var face := lerpf(KERB_H, RAMP_FACE, f)
		var length := k.distance_to(b)
		var dirb := (b - k) / length
		var arris := 0.012 * (1.0 - f)
		var ds: Array[float] = [0.0, 0.025, KERB_W, RAMP_DEPTH, length]
		var pts: Array[Vector3] = []
		for d: float in ds:
			var h := lerpf(face, KERB_H, clampf(d / RAMP_DEPTH, 0.0, 1.0))
			if d == 0.0:
				h -= arris
			pts.append(_v3(k + dirb * d, h))
		rows.append({"pts": pts, "ds": ds, "f": f, "k": k, "n": s["n"], "b": b, "face": face - arris})
	for idx: int in count:
		var r0: Dictionary = rows[idx]
		var r1: Dictionary = rows[(idx + 1) % count]
		var p0: Array[Vector3] = r0["pts"]
		var p1: Array[Vector3] = r1["pts"]
		var d0: Array[float] = r0["ds"]
		var d1: Array[float] = r1["ds"]
		for lvl: int in 4:
			var st := kerb if lvl < 2 else top
			_quad_attr(st, p0[lvl], p1[lvl], p1[lvl + 1], p0[lvl + 1], Vector3.UP,
				[r0["f"], r1["f"], r1["f"], r0["f"]], [d0[lvl], d1[lvl], d1[lvl + 1], d0[lvl + 1]])
			_collision_quad(p0[lvl], p1[lvl], p1[lvl + 1], p0[lvl + 1])
		# kerb face, with a slight batter, and the gutter pan in front of it
		var k0: Vector2 = r0["k"]
		var k1: Vector2 = r1["k"]
		var n0: Vector2 = r0["n"]
		var n1: Vector2 = r1["n"]
		if k0.distance_to(k1) > 0.001:
			var out_n := -_v3(n0 + n1, 0.0).normalized()
			var fb0 := _v3(k0 - n0 * 0.018, 0.0)
			var fb1 := _v3(k1 - n1 * 0.018, 0.0)
			_quad_attr(kerb, fb0, fb1, p1[0], p0[0], out_n, [0.0, 0.0, 0.0, 0.0], [-0.02, -0.02, 0.0, 0.0])
			var g0 := _v3(k0 - n0 * GUTTER_W, 0.003)
			var g1 := _v3(k1 - n1 * GUTTER_W, 0.003)
			_quad_attr(kerb, g0, g1, fb1 + Vector3(0, 0.003, 0), fb0 + Vector3(0, 0.003, 0), Vector3.UP,
				[0.0, 0.0, 0.0, 0.0], [-GUTTER_W, -GUTTER_W, -0.02, -0.02])
			# collision: a chamfer instead of the vertical face, so a walker steps up and a tyre rolls up
			var c0 := _v3(k0 - n0 * 0.24, 0.0)
			var c1 := _v3(k1 - n1 * 0.24, 0.0)
			_collision_quad(c0, c1, p1[0], p0[0])
		# back of the pavement where the world is not yet built: a dark cut edge going down
		var b0: Vector3 = p0[4]
		var b1: Vector3 = p1[4]
		if b0.distance_to(b1) > 0.001:
			var back_n := _v3(n0 + n1, 0.0).normalized()
			_quad_attr(edge, b0, b1, b1 - Vector3(0, 0.6, 0), b0 - Vector3(0, 0.6, 0), back_n,
				[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0])


# --- road markings ----------------------------------------------------------------------

func _build_markings() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stop := STOP_LINE_AT + STOP_LINE_W / 2.0
	# Along each street between junctions: double yellow centre line, lane-edge lines, parking bays.
	for j: int in JUNCTIONS:
		for i: int in JUNCTIONS - 1:
			_street_lines(st, Vector2(ns_x(i) + stop, ew_z(j)), Vector2(ns_x(i + 1) - stop, ew_z(j)))
	for i: int in JUNCTIONS:
		for j: int in JUNCTIONS - 1:
			_street_lines(st, Vector2(ns_x(i), ew_z(j) + stop), Vector2(ns_x(i), ew_z(j + 1) - stop))
	# At every junction leg: a stop line across the approach and a marked crossing.
	for cr: Dictionary in crossings():
		var d: Vector2 = cr["dir"]
		var jc: Vector2 = junction(cr["junction"].x, cr["junction"].y)
		var r := right_of(-d)
		var sc := jc + d * STOP_LINE_AT
		_stripe(st, sc + r * 0.25, sc + r * (HALF_ROAD - GUTTER_W), STOP_LINE_W, WHITE)
		var cc: Vector2 = cr["centre"]
		var across := Vector2(-d.y, d.x)
		var reach := HALF_ROAD - GUTTER_W
		if cr["ladder"]:
			for side: float in [-1.0, 1.0]:
				var lc := cc + d * side * (CROSSING_W / 2.0 - 0.15)
				_stripe(st, lc - across * reach, lc + across * reach, 0.3, WHITE)
			var o := -4.2
			while o <= 4.21:
				var bc := cc + across * o
				_stripe(st, bc - d * (CROSSING_W / 2.0 - 0.35), bc + d * (CROSSING_W / 2.0 - 0.35), 0.6, WHITE)
				o += 1.2
		else:
			var o2 := -4.5
			while o2 <= 4.51:
				var bc2 := cc + across * o2
				_stripe(st, bc2 - d * CROSSING_W / 2.0, bc2 + d * CROSSING_W / 2.0, 0.6, WHITE)
				o2 += 1.2
	var mi := MeshInstance3D.new()
	mi.name = "Markings"
	mi.mesh = st.commit()
	mi.material_override = _material("road_paint.gdshader")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _street_lines(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var across := Vector2(-dir.y, dir.x)
	for s: float in [-1.0, 1.0]:
		_stripe(st, a + across * s * 0.1, b + across * s * 0.1, 0.1, YELLOW)
		_stripe(st, a + across * s * LANE, b + across * s * LANE, 0.1, WHITE)
	# Parking bays, 6.5 m long, kept clear of the junctions.
	var length := a.distance_to(b)
	var t := 7.0
	while t <= length - 7.0:
		var at := a + dir * t
		for s: float in [-1.0, 1.0]:
			var bay := at + across * s * (LANE + PARKING / 2.0)
			if absf(bay.x - BUS_STOP.x) < BUS_ZONE / 2.0 and absf(bay.y - (BUS_STOP.y - PARKING / 2.0)) < 1.0:
				continue      # the bus stop: no parking
			_stripe(st, at + across * s * (LANE + 0.05), at + across * s * (HALF_ROAD - GUTTER_W), 0.1, WHITE)
		t += 6.5


## A painted stripe of the given width centred on the segment a-b.
func _stripe(st: SurfaceTool, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * width * 0.5
	var length := a.distance_to(b)
	var corners: Array[Vector3] = [_v3(a - side, PAINT_Y), _v3(b - side, PAINT_Y), _v3(b + side, PAINT_Y), _v3(a + side, PAINT_Y)]
	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(0, length), Vector2(1, length), Vector2(1, 0)]
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var verts: Array[int] = []
		verts.assign(tri)
		var n := (corners[verts[1]] - corners[verts[0]]).cross(corners[verts[2]] - corners[verts[0]])
		if n.y > 0.0:
			verts = [verts[0], verts[2], verts[1]]
		for v: int in verts:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[v])
			st.add_vertex(corners[v])


# --- manholes and drains ----------------------------------------------------------------

func _build_ironwork() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	var manholes: Array[Transform3D] = []
	var stop := STOP_LINE_AT + 2.0
	for j: int in JUNCTIONS:
		for i: int in JUNCTIONS - 1:
			for n: int in 2:
				var x := rng.randf_range(ns_x(i) + stop + 4.0, ns_x(i + 1) - stop - 4.0)
				var z := ew_z(j) + (LANE / 2.0) * (1.0 if rng.randf() < 0.5 else -1.0) + rng.randf_range(-0.4, 0.4)
				manholes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, 0.0, z)))
	for i: int in JUNCTIONS:
		for j: int in JUNCTIONS - 1:
			var z2 := rng.randf_range(ew_z(j) + stop + 4.0, ew_z(j + 1) - stop - 4.0)
			var x2 := ns_x(i) + (LANE / 2.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			manholes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x2, 0.0, z2)))
	# a manhole in the middle of each junction, as utilities cross there
	for i: int in JUNCTIONS:
		for j: int in JUNCTIONS:
			var c := junction(i, j)
			manholes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(c.x + 1.2, 0.0, c.y - 0.8)))
	var drains: Array[Transform3D] = []
	for cr: Dictionary in crossings():
		var d: Vector2 = cr["dir"]
		var jc: Vector2 = junction(cr["junction"].x, cr["junction"].y)
		for side: float in [-1.0, 1.0]:
			var across := Vector2(-d.y, d.x) * side
			var at := jc + d * (STOP_LINE_AT + 1.6) + across * (HALF_ROAD - 0.26)
			# local +Z points at the kerb, local X runs along it
			var z_axis := _v3(across, 0.0)
			var x_axis := Vector3.UP.cross(z_axis)
			drains.append(Transform3D(Basis(x_axis, Vector3.UP, z_axis), _v3(at, 0.0)))
	_multimesh("Manholes", CityRoads.manhole_mesh(), manholes, _iron_material(0))
	_multimesh("Drains", CityRoads.drain_mesh(), drains, _iron_material(1))


func _iron_material(kind: int) -> ShaderMaterial:
	var mat := _material("road_iron.gdshader")
	mat.set_shader_parameter("kind", kind)
	return mat


func _multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k: int in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## A cast-iron manhole cover, 0.66 m across, sitting a few millimetres proud in its frame.
static func manhole_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	var r_cover := 0.33
	var r_frame := 0.40
	for k: int in seg:
		var a0 := float(k) / seg * TAU
		var a1 := float(k + 1) / seg * TAU
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var c := Vector3(0.0, 0.006, 0.0)
		_tri_uv(st, c, c + d1 * r_cover, c + d0 * r_cover, Vector3.UP, 0.5)
		# frame ring, slightly lower
		var f0 := d0 * r_cover + Vector3(0, 0.004, 0)
		var f1 := d1 * r_cover + Vector3(0, 0.004, 0)
		var o0 := d0 * r_frame + Vector3(0, 0.001, 0)
		var o1 := d1 * r_frame + Vector3(0, 0.001, 0)
		_tri_uv(st, f0, f1, o1, Vector3.UP, 0.5)
		_tri_uv(st, f0, o1, o0, Vector3.UP, 0.5)
	st.generate_normals()
	return st.commit()


## A kerbside drain grate (0.9 m along the kerb, 0.5 m out) with the kerb inlet opening above it.
static func drain_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.45
	var y := 0.006
	_tri_uv(st, Vector3(-hw, y, -0.25), Vector3(hw, y, -0.25), Vector3(hw, y, 0.25), Vector3.UP, 0.5)
	_tri_uv(st, Vector3(-hw, y, -0.25), Vector3(hw, y, 0.25), Vector3(-hw, y, 0.25), Vector3.UP, 0.5)
	# inlet opening in the kerb face: a dark slot (UV.y > 1 tells the shader it is the slot)
	var z := 0.26 - 0.016
	var a := Vector3(-0.6, 0.012, z)
	var b := Vector3(0.6, 0.012, z)
	var c := Vector3(0.6, 0.11, z - 0.01)
	var d := Vector3(-0.6, 0.11, z - 0.01)
	_tri_uv(st, a, b, c, Vector3.BACK * -1.0, 2.0)
	_tri_uv(st, a, c, d, Vector3.BACK * -1.0, 2.0)
	st.generate_normals()
	return st.commit()


static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3, uv_y: float) -> void:
	var n := (b - a).cross(c - a)
	var verts: Array[Vector3] = [a, b, c]
	if n.dot(want) > 0.0:
		verts = [a, c, b]
	for v: Vector3 in verts:
		st.set_uv(Vector2(v.x, v.z) if uv_y < 1.5 else Vector2(v.x, 2.0))
		st.add_vertex(v)


# --- collision and the edge of the world ------------------------------------------------

func _add_collision_from(mesh: ArrayMesh) -> void:
	_collision_faces.append_array(mesh.get_faces())


func _collision_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_collision_faces.append_array(PackedVector3Array([a, b, c, a, c, d]))


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_collision_faces)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


## Invisible walls at the outer back of the pavement: past them the world has not been built.
func _build_world_edge() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldEdge"
	for wall: Array in [
		[Vector3(0.0, 2.0, -Z_EDGE - 0.25), Vector3(X_EDGE * 2.0 + 1.0, 4.0, 0.5)],
		[Vector3(0.0, 2.0, Z_EDGE + 0.25), Vector3(X_EDGE * 2.0 + 1.0, 4.0, 0.5)],
		[Vector3(-X_EDGE - 0.25, 2.0, 0.0), Vector3(0.5, 4.0, Z_EDGE * 2.0 + 1.0)],
		[Vector3(X_EDGE + 0.25, 2.0, 0.0), Vector3(0.5, 4.0, Z_EDGE * 2.0 + 1.0)],
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		cs.shape = box
		cs.position = wall[0]
		body.add_child(cs)
	add_child(body)


# --- helpers ----------------------------------------------------------------------------

func _material(file: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + file) as Shader
	mat.set_shader_parameter("pitch_x", PITCH_X)
	mat.set_shader_parameter("pitch_z", PITCH_Z)
	mat.set_shader_parameter("wetness", wetness)
	_materials.append(mat)
	return mat


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## One triangle, wound so that its face points toward 'want'.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var verts: Array[Vector3] = [a, b, c]
	if n.dot(want) > 0.0:
		verts = [a, c, b]       # the engine treats clockwise as the front
	for v: Vector3 in verts:
		st.set_normal(want)
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)


## A quad with per-corner dropped-kerb factor (COLOR.r) and distance from the kerb (UV2.y).
func _quad_attr(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3, f: Array, dist: Array) -> void:
	var pts: Array[Vector3] = [a, b, c, d]
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var ids: Array[int] = []
		ids.assign(tri)
		var n := (pts[ids[1]] - pts[ids[0]]).cross(pts[ids[2]] - pts[ids[0]])
		if n.length_squared() < 1e-12:
			continue
		var face_n := n.normalized()
		if n.dot(want) > 0.0:
			ids = [ids[0], ids[2], ids[1]]
		else:
			face_n = -face_n
		for id: int in ids:
			st.set_color(Color(float(f[id]), 0.0, 0.0))
			st.set_normal(face_n)
			st.set_uv(Vector2(pts[id].x, pts[id].z))
			st.set_uv2(Vector2(0.0, float(dist[id])))
			st.add_vertex(pts[id])
