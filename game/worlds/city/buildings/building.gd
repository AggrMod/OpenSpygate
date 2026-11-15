class_name CityBuilding
extends Node3D
## One generated building on a lot of the city of Calder, built entirely in code.
##
## The building occupies local x in [-width/2, width/2], z in [-depth, 0], y from 0 (top of the
## pavement) upwards. Its street facade stands on the z = 0 plane facing +Z. The main wall face
## is set back WALL_D behind the lot line so that piers, risers and door surrounds can stand
## proud of it without crossing the line. Below CLEAR_HEIGHT nothing crosses z = 0. Above it,
## cornices, sills, awnings, signs and fire escapes may overhang the pavement by up to
## OVERHANG metres, as they do on real streets; the same holds past a side or the rear when
## that side faces a street (opts open_neg_x, open_pos_x, open_back). A party side never
## crosses x = +-width/2. A closed rear wall stands REAR_IN in front of z = -depth.
##
## A building is three meshes: the body (one surface: masonry, trim, metal, roof), the glass
## (one surface: every pane with its interior-mapped room), and the details (one surface:
## fire escapes, roof plant, lettering), which drop out beyond DETAIL_RANGE. Collision is a
## StaticBody3D of boxes. set_lit() turns the night on through an instance uniform, so no
## material is duplicated and no light node is used.

const STYLES: Array[String] = ["brick", "terracotta", "midcentury", "brutalist", "glass", "parking"]
const WALL_D: float = -0.15
const CLEAR_HEIGHT: float = 2.4
const OVERHANG: float = 1.5
const DETAIL_RANGE: float = 170.0
const REAR_IN: float = 0.2
const TRI_BUDGET: int = 38000
const MAX_FLOORS: int = 10

# Material ids, matching building_surface.gdshader.
const M_BRICK: float = 0.0
const M_STONE: float = 1.0
const M_TERRACOTTA: float = 2.0
const M_BOARD_CONCRETE: float = 3.0
const M_CONCRETE: float = 4.0
const M_METAL_PANEL: float = 5.0
const M_PAINTED_METAL: float = 6.0
const M_ROOF: float = 7.0
const M_FABRIC: float = 8.0
const M_GRANITE: float = 9.0
const M_GALVANISED: float = 10.0
const M_LAMP: float = 11.0
const M_SMOOTH_STONE: float = 12.0
const M_TILE: float = 13.0
const M_TIMBER: float = 14.0
const M_FASCIA: float = 15.0
const M_LETTER: float = 16.0
const M_LIT_LETTER: float = 17.0
const M_GRATING: float = 18.0
const M_PAVING: float = 19.0
const M_COMMON_BRICK: float = 20.0

# Room kinds, matching building_glass.gdshader.
const K_OFFICE: float = 0.0
const K_HOME: float = 1.0
const K_SHOP: float = 2.0
const K_PARKING: float = 3.0
const K_SPANDREL: float = 4.0
const K_LOBBY: float = 5.0

const SURFACE_SHADER: Shader = preload("res://worlds/city/buildings/building_surface.gdshader")
const GLASS_SHADER: Shader = preload("res://worlds/city/buildings/building_glass.gdshader")

static var _surface_mat: ShaderMaterial
static var _glass_mat: ShaderMaterial

## What was built, for tests and the streets engineer.
var style: String = ""
var floors: int = 0
var roof_height: float = 0.0       ## top of the main roof slab
var top_height: float = 0.0        ## highest point including parapet and plant
var lot_width: float = 0.0
var lot_depth: float = 0.0
var open_neg_x: bool = false       ## the -x side faces a street (full facade, may overhang)
var open_pos_x: bool = false
var open_back: bool = false        ## the rear faces a street or alley (full rear facade)
var stats: Dictionary = {}

var body_mesh: MeshInstance3D
var glass_mesh: MeshInstance3D
var detail_mesh: MeshInstance3D

# Build state.
var _rng: RandomNumberGenerator
var _body: CityMeshKit
var _glass: CityMeshKit
var _detail: CityMeshKit
var _solids: Array[AABB] = []
var _sp: Dictionary = {}
var _fy: Array[float] = []
var _opts: Dictionary = {}
var _seed: int = 0
var _window_count: int = 0
var _lean: bool = false            # rebuilt with less small detail to stay inside the triangle budget
var _gf_front: float = -0.6        # front of the ground-floor collision box (deeper behind a colonnade)
var _shop_kind: int = 0            # interior kind of the shop being built (CitySignNames.KIND_*)


## A facade plane in building space: s runs along it, y up, d out of the wall (0 = lot line).
class Face:
	var o: Vector3
	var r: Vector3
	var n: Vector3
	var length: float
	var primary: bool
	var open_start: bool
	var open_end: bool

	func _init(origin: Vector3, right: Vector3, normal: Vector3, len: float, is_primary: bool, o_start: bool, o_end: bool) -> void:
		o = origin
		r = right
		n = normal
		length = len
		primary = is_primary
		open_start = o_start
		open_end = o_end

	func p(s: float, y: float, d: float) -> Vector3:
		return o + r * s + Vector3.UP * y + n * d


static func create(width: float, depth: float, seed: int, opts: Dictionary = {}) -> CityBuilding:
	var b := CityBuilding.new()
	b.name = "Building%d" % seed
	b._generate(width, depth, seed, opts)
	return b


## 0 by day, 1 at night: lights rooms (a share of them), shop signs and shopfront lamps.
func set_lit(amount: float) -> void:
	for mi: MeshInstance3D in [body_mesh, glass_mesh, detail_mesh]:
		if mi != null:
			mi.set_instance_shader_parameter("lit", clampf(amount, 0.0, 1.0))


# --- generation -------------------------------------------------------------------------

func _generate(width: float, depth: float, seed: int, opts: Dictionary) -> void:
	lot_width = width
	lot_depth = depth
	open_neg_x = bool(opts.get("open_neg_x", false))
	open_pos_x = bool(opts.get("open_pos_x", false))
	open_back = bool(opts.get("open_back", false))
	_opts = opts
	_seed = seed
	_rng = RandomNumberGenerator.new()
	_build(false)
	if _body.triangle_count() + _glass.triangle_count() + _detail.triangle_count() > TRI_BUDGET:
		_build(true)
	_finish()


## One full build from the seed. Called a second time, lean, if the first one is over budget,
## so the same arguments still always give the same building.
func _build(lean: bool) -> void:
	var width := lot_width
	var depth := lot_depth
	var opts := _opts
	var seed := _seed
	_lean = lean
	_solids.clear()
	_window_count = 0
	_gf_front = -0.6
	var key := "%d|%.2f|%.2f|%s|%s|%s|%s|%s" % [seed, width, depth, opts.get("open_neg_x", false), opts.get("open_pos_x", false), opts.get("open_back", false), opts.get("floors", 0), opts.get("style", "")]
	_rng.seed = key.hash()          # setting the seed restarts the sequence
	_body = CityMeshKit.new()
	_glass = CityMeshKit.new(true)
	_detail = CityMeshKit.new()
	style = String(opts.get("style", ""))
	if not STYLES.has(style):
		style = _pick_style()
	_sp = _make_spec(style)
	floors = int(opts.get("floors", 0))
	if floors <= 0:
		floors = _rng.randi_range(int(_sp["min_floors"]), int(_sp["max_floors"]))
	floors = clampi(floors, 1, MAX_FLOORS)
	_fy.clear()
	_fy.append(0.0)
	for k: int in floors:
		_fy.append(_fy[k] + (float(_sp["gf_h"]) if k == 0 else float(_sp["up_h"])))
	roof_height = _fy[floors]
	top_height = roof_height + float(_sp["parapet"])

	var w := width
	var d := depth
	var open_neg: bool = opts.get("open_neg_x", false)
	var open_pos: bool = opts.get("open_pos_x", false)
	var faces: Array[Face] = [Face.new(Vector3(-w / 2.0, 0, 0), Vector3.RIGHT, Vector3.BACK, w, true, open_neg, open_pos)]
	if open_pos:
		faces.append(Face.new(Vector3(w / 2.0, 0, 0), Vector3.FORWARD, Vector3.RIGHT, d, false, true, open_back))
	if open_neg:
		faces.append(Face.new(Vector3(-w / 2.0, 0, -d), Vector3.BACK, Vector3.LEFT, d, false, open_back, true))
	if open_back:
		faces.append(Face.new(Vector3(w / 2.0, 0, -d), Vector3.LEFT, Vector3.FORWARD, w, false, open_pos, open_neg))
	for f: Face in faces:
		_build_face(f)
	_build_shell(open_neg, open_pos)
	_build_roof(open_neg, open_pos)
	_build_fire_escape(faces[0])


func _pick_style() -> String:
	var roll := _rng.randf()
	var s := "brick"
	if roll < 0.34:
		s = "brick"
	elif roll < 0.48:
		s = "terracotta"
	elif roll < 0.64:
		s = "midcentury"
	elif roll < 0.76:
		s = "brutalist"
	elif roll < 0.90:
		s = "glass"
	else:
		s = "parking"
	if s == "parking" and lot_width < 22.0:
		s = "midcentury"
	if s == "terracotta" and lot_width < 16.0:
		s = "brick"
	return s


static func _c(r: float, g: float, b: float) -> Color:
	return Color(r, g, b).srgb_to_linear()


func _vary(c: Color, amount: float) -> Color:
	var k := 1.0 + _rng.randf_range(-amount, amount)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func _choose(list: Array) -> Variant:
	return list[_rng.randi() % list.size()]


## Everything that makes one style differ from another, with this building's seeded choices.
func _make_spec(st: String) -> Dictionary:
	var sp: Dictionary = {}
	var frames: Array = [_c(0.10, 0.17, 0.13), _c(0.06, 0.06, 0.06), _c(0.74, 0.73, 0.69), _c(0.32, 0.09, 0.08), _c(0.12, 0.15, 0.22)]
	var fascias: Array = [_c(0.08, 0.20, 0.14), _c(0.05, 0.05, 0.05), _c(0.36, 0.08, 0.07), _c(0.08, 0.12, 0.26), _c(0.80, 0.76, 0.66), _c(0.55, 0.38, 0.12)]
	sp["fascia_cols"] = fascias
	sp["fire_escape"] = false
	sp["old_glass"] = false
	sp["room"] = K_OFFICE
	sp["share"] = _rng.randf_range(0.32, 0.58)
	match st:
		"brick":
			var bricks: Array = [_c(0.52, 0.24, 0.17), _c(0.58, 0.30, 0.20), _c(0.44, 0.20, 0.15), _c(0.62, 0.38, 0.26), _c(0.40, 0.22, 0.17), _c(0.56, 0.27, 0.19)]
			var wall: Color = _vary(_choose(bricks), 0.06)
			var painted := _rng.randf() < 0.18
			if painted:
				wall = _choose([_c(0.78, 0.74, 0.64), _c(0.25, 0.32, 0.27), _c(0.60, 0.56, 0.50), _c(0.30, 0.30, 0.33)])
			sp["min_floors"] = 2; sp["max_floors"] = 5
			sp["gf_h"] = _rng.randf_range(4.3, 4.8); sp["up_h"] = _rng.randf_range(3.5, 3.9)
			sp["wall_mat"] = M_BRICK; sp["wall_col"] = wall
			sp["trim_mat"] = M_STONE if _rng.randf() < 0.7 else M_SMOOTH_STONE
			sp["trim_col"] = _vary(_choose([_c(0.72, 0.68, 0.58), _c(0.66, 0.62, 0.54), _c(0.58, 0.52, 0.44)]), 0.04)
			if painted:
				sp["trim_col"] = wall.lightened(0.15)
			sp["pier_mat"] = M_BRICK; sp["pier_col"] = wall
			sp["gf_pier_mat"] = _choose([M_STONE, M_PAINTED_METAL, M_BRICK])
			sp["gf_pier_col"] = sp["trim_col"] if int(sp["gf_pier_mat"]) == int(M_STONE) else (_choose(frames) if int(sp["gf_pier_mat"]) == int(M_PAINTED_METAL) else wall)
			sp["end_pier"] = _rng.randf_range(0.45, 0.7)
			sp["bay"] = _rng.randf_range(2.3, 3.1)
			sp["layout"] = "punched"
			sp["per_bay"] = 1 if _rng.randf() < 0.6 else 2
			sp["win_w"] = _rng.randf_range(0.9, 1.1)
			sp["win_h"] = _rng.randf_range(1.9, 2.15)
			sp["sill_h"] = _rng.randf_range(0.7, 0.85)
			sp["reveal"] = 0.2
			sp["frame"] = _choose(["sash", "sash", "sash22"])
			sp["frame_col"] = _choose(frames)
			sp["sill"] = "stone"
			sp["lintel"] = _choose(["stone", "keystone", "soldier"])
			sp["cornice"] = _choose(["bracketed", "bracketed", "corbel"])
			sp["cornice_col"] = _choose([_c(0.30, 0.32, 0.30), _c(0.70, 0.68, 0.62), _choose(frames), sp["trim_col"]])
			sp["parapet"] = _rng.randf_range(1.1, 1.5)
			sp["gf"] = "traditional"
			sp["fire_escape"] = _rng.randf() < 0.45
			sp["old_glass"] = true
			sp["room"] = K_HOME if _rng.randf() < 0.7 else K_OFFICE
			sp["string_courses"] = true
			sp["date"] = str(_rng.randi_range(1889, 1926))
		"terracotta":
			var tc: Color = _vary(_choose([_c(0.84, 0.78, 0.66), _c(0.78, 0.70, 0.56), _c(0.72, 0.71, 0.68), _c(0.86, 0.82, 0.74), _c(0.70, 0.60, 0.50)]), 0.03)
			var use_brick := _rng.randf() < 0.45
			sp["min_floors"] = 6; sp["max_floors"] = 8
			sp["gf_h"] = _rng.randf_range(4.8, 5.4); sp["up_h"] = _rng.randf_range(3.6, 3.8)
			sp["wall_mat"] = M_BRICK if use_brick else M_TERRACOTTA
			sp["wall_col"] = _vary(_choose([_c(0.62, 0.50, 0.36), _c(0.50, 0.30, 0.22), _c(0.42, 0.30, 0.24), _c(0.70, 0.62, 0.48)]), 0.05) if use_brick else tc
			sp["trim_mat"] = M_TERRACOTTA; sp["trim_col"] = tc
			sp["pier_mat"] = M_TERRACOTTA; sp["pier_col"] = tc
			sp["gf_pier_mat"] = M_STONE; sp["gf_pier_col"] = _vary(_c(0.62, 0.60, 0.56), 0.04)
			sp["end_pier"] = _rng.randf_range(0.9, 1.3)
			sp["bay"] = _rng.randf_range(3.2, 3.8)
			sp["layout"] = "pilaster"
			sp["per_bay"] = 2
			sp["win_w"] = _rng.randf_range(1.0, 1.15)
			sp["win_h"] = _rng.randf_range(2.0, 2.2)
			sp["sill_h"] = 0.8
			sp["reveal"] = 0.22
			sp["frame"] = "sash"
			sp["frame_col"] = _choose([_c(0.20, 0.15, 0.10), _c(0.06, 0.06, 0.06), _c(0.74, 0.73, 0.69)])
			sp["sill"] = "stone"
			sp["lintel"] = "none"
			sp["cornice"] = "heavy"
			sp["cornice_col"] = tc
			sp["parapet"] = 1.6
			sp["gf"] = "lobby"
			sp["room"] = K_OFFICE
			sp["string_courses"] = true
			sp["name"] = CitySignNames.building(_rng)
			sp["date"] = str(_rng.randi_range(1921, 1931))
		"midcentury":
			var buff: Color = _vary(_choose([_c(0.72, 0.62, 0.45), _c(0.76, 0.67, 0.50), _c(0.66, 0.57, 0.44), _c(0.80, 0.74, 0.62)]), 0.04)
			sp["min_floors"] = 3; sp["max_floors"] = 5
			sp["gf_h"] = _rng.randf_range(4.2, 4.5); sp["up_h"] = _rng.randf_range(3.35, 3.5)
			sp["wall_mat"] = M_BRICK; sp["wall_col"] = buff
			sp["trim_mat"] = M_CONCRETE; sp["trim_col"] = _vary(_c(0.70, 0.69, 0.65), 0.03)
			sp["pier_mat"] = M_CONCRETE; sp["pier_col"] = sp["trim_col"]
			sp["gf_pier_mat"] = M_GRANITE; sp["gf_pier_col"] = _choose([_c(0.20, 0.20, 0.22), _c(0.45, 0.30, 0.28)])
			sp["end_pier"] = _rng.randf_range(0.4, 0.6)
			sp["bay"] = _rng.randf_range(3.0, 4.2)
			sp["layout"] = "strip"
			sp["win_h"] = _rng.randf_range(1.5, 1.75)
			sp["sill_h"] = _rng.randf_range(0.9, 1.0)
			sp["reveal"] = 0.12
			sp["frame"] = "steel"
			sp["frame_col"] = _choose([_c(0.62, 0.64, 0.65), _c(0.15, 0.15, 0.16), _c(0.40, 0.42, 0.40)])
			sp["sill"] = "metal"
			sp["lintel"] = "none"
			sp["enamel"] = _rng.randf() < 0.5
			sp["enamel_col"] = _choose([_c(0.20, 0.48, 0.52), _c(0.18, 0.30, 0.50), _c(0.78, 0.62, 0.24), _c(0.70, 0.30, 0.22), _c(0.30, 0.45, 0.35)])
			sp["cornice"] = "coping"
			sp["cornice_col"] = sp["frame_col"]
			sp["parapet"] = _rng.randf_range(0.6, 0.9)
			sp["gf"] = "modern"
			sp["room"] = K_OFFICE
			sp["string_courses"] = false
		"brutalist":
			sp["min_floors"] = 4; sp["max_floors"] = 8
			sp["gf_h"] = _rng.randf_range(4.6, 5.2); sp["up_h"] = _rng.randf_range(3.6, 3.8)
			sp["wall_mat"] = M_BOARD_CONCRETE; sp["wall_col"] = _vary(_choose([_c(0.60, 0.59, 0.55), _c(0.55, 0.53, 0.49), _c(0.64, 0.62, 0.57)]), 0.03)
			sp["trim_mat"] = M_CONCRETE; sp["trim_col"] = sp["wall_col"]
			sp["pier_mat"] = M_BOARD_CONCRETE; sp["pier_col"] = sp["wall_col"]
			sp["gf_pier_mat"] = M_BOARD_CONCRETE; sp["gf_pier_col"] = sp["wall_col"]
			sp["end_pier"] = _rng.randf_range(0.8, 1.2)
			sp["bay"] = _rng.randf_range(1.5, 1.8)
			sp["layout"] = "ribbon"
			sp["coated"] = _rng.randf_range(0.2, 0.5)
			sp["win_h"] = _rng.randf_range(1.55, 1.8)
			sp["sill_h"] = 1.05
			sp["reveal"] = 0.35
			sp["frame"] = "alum"
			sp["frame_col"] = _choose([_c(0.20, 0.15, 0.10), _c(0.12, 0.12, 0.12), _c(0.55, 0.56, 0.56)])
			sp["sill"] = "none"
			sp["lintel"] = "none"
			sp["cornice"] = "slab"
			sp["cornice_col"] = sp["wall_col"]
			sp["parapet"] = 1.3
			sp["gf"] = "colonnade"
			sp["room"] = K_OFFICE
			sp["string_courses"] = false
			sp["name"] = CitySignNames.building(_rng)
		"glass":
			sp["min_floors"] = 4; sp["max_floors"] = 8
			sp["gf_h"] = _rng.randf_range(4.5, 5.0); sp["up_h"] = _rng.randf_range(3.3, 3.6)
			sp["wall_mat"] = M_METAL_PANEL; sp["wall_col"] = _choose([_c(0.22, 0.23, 0.24), _c(0.52, 0.48, 0.40), _c(0.42, 0.44, 0.45), _c(0.70, 0.70, 0.68)])
			sp["trim_mat"] = M_METAL_PANEL; sp["trim_col"] = sp["wall_col"]
			sp["pier_mat"] = M_METAL_PANEL; sp["pier_col"] = sp["wall_col"]
			sp["gf_pier_mat"] = M_METAL_PANEL; sp["gf_pier_col"] = sp["wall_col"]
			sp["end_pier"] = _rng.randf_range(0.6, 1.4)
			sp["bay"] = _rng.randf_range(1.4, 1.7)
			sp["layout"] = "curtain"
			sp["coated"] = _rng.randf_range(0.35, 0.8)
			sp["frame"] = "alum"
			sp["frame_col"] = _choose([_c(0.10, 0.10, 0.11), _c(0.60, 0.61, 0.62), sp["wall_col"]])
			sp["reveal"] = 0.08
			sp["cornice"] = "metal"
			sp["cornice_col"] = sp["wall_col"]
			sp["parapet"] = 1.1
			sp["gf"] = "modern"
			sp["room"] = K_HOME if _rng.randf() < 0.5 else K_OFFICE
			sp["string_courses"] = false
		"parking":
			sp["min_floors"] = 4; sp["max_floors"] = 6
			sp["gf_h"] = 4.2; sp["up_h"] = _rng.randf_range(3.05, 3.2)
			sp["wall_mat"] = M_CONCRETE; sp["wall_col"] = _vary(_c(0.64, 0.63, 0.59), 0.04)
			sp["trim_mat"] = M_CONCRETE; sp["trim_col"] = sp["wall_col"]
			sp["pier_mat"] = M_CONCRETE; sp["pier_col"] = _vary(sp["wall_col"], 0.04)
			sp["gf_pier_mat"] = M_CONCRETE; sp["gf_pier_col"] = sp["pier_col"]
			sp["end_pier"] = 0.6
			sp["bay"] = _rng.randf_range(7.6, 8.6)
			sp["layout"] = "deck"
			sp["frame_col"] = _c(0.15, 0.15, 0.15)
			sp["reveal"] = 0.25
			sp["cornice"] = "deck"
			sp["cornice_col"] = sp["wall_col"]
			sp["parapet"] = 1.1
			sp["gf"] = "garage"
			sp["room"] = K_PARKING
			sp["string_courses"] = false
	return sp


# --- facade -----------------------------------------------------------------------------

func _build_face(f: Face) -> void:
	var ep: float = _sp["end_pier"]
	var gf_h: float = _fy[1]
	var top := roof_height + float(_sp["parapet"])
	# end piers, full height, standing proud of the wall to the lot line
	for s0: float in [0.0, f.length - ep]:
		_fbox(f, s0, s0 + ep, gf_h, top, WALL_D, 0.0, _sp["pier_col"], _sp["pier_mat"])
	match String(_sp["gf"]):
		"traditional":
			_gf_traditional(f)
		"lobby":
			_gf_traditional(f, true)
		"modern":
			_gf_modern(f)
		"colonnade":
			_gf_colonnade(f)
		"garage":
			_gf_garage(f)
	# a strip of paving between the shopfronts and the lot line, so no void shows at the foot
	_body.quad(f.p(0.0, 0.003, -0.8), f.r * f.length, f.n * 0.8, _c(0.46, 0.45, 0.43), M_PAVING)
	if floors > 1:
		match String(_sp["layout"]):
			"punched", "pilaster":
				_upper_punched(f)
			"strip":
				_upper_strip(f)
			"ribbon":
				_upper_ribbon(f)
			"curtain":
				_upper_curtain(f)
			"deck":
				_upper_deck(f)
	_top(f)


## A box given in face coordinates.
func _fbox(f: Face, s0: float, s1: float, y0: float, y1: float, d0: float, d1: float, col: Color, mat: float, kit: CityMeshKit = null) -> void:
	var a := f.p(s0, y0, d0)
	var b := f.p(s1, y1, d1)
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	(kit if kit != null else _body).box(lo, hi, col, mat)


## The same box without its back face (the side against the wall or the glass, never seen).
func _fbox_nb(f: Face, s0: float, s1: float, y0: float, y1: float, d0: float, d1: float, col: Color, mat: float) -> void:
	var a := f.p(s0, y0, d0)
	var b := f.p(s1, y1, d1)
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var back := CityMeshKit.F_BACK
	if f.n == Vector3.FORWARD:
		back = CityMeshKit.F_FRONT
	elif f.n == Vector3.RIGHT:
		back = CityMeshKit.F_LEFT
	elif f.n == Vector3.LEFT:
		back = CityMeshKit.F_RIGHT
	_body.box(lo, hi, col, mat, CityMeshKit.F_ALL & ~back)


## A flat wall piece facing out of the face at depth d.
func _fquad(f: Face, s0: float, s1: float, y0: float, y1: float, d: float, col: Color, mat: float, g0: float = 0.0, g1: float = 0.0) -> void:
	if s1 - s0 <= 0.001 or y1 - y0 <= 0.001:
		return
	_body.quad(f.p(s0, y0, d), f.r * (s1 - s0), Vector3.UP * (y1 - y0), col, mat, g0, g1)


func _solid(f: Face, s0: float, s1: float, y0: float, y1: float, d0: float, d1: float) -> void:
	var a := f.p(s0, y0, d0)
	var b := f.p(s1, y1, d1)
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	_solids.append(AABB(lo, hi - lo))


## Lays bays out between the end piers. Returns [first_s, bay_width, count].
func _bays(f: Face, target: float) -> Array:
	var ep: float = _sp["end_pier"]
	var inner := f.length - 2.0 * ep
	var n := maxi(1, roundi(inner / target))
	return [ep, inner / float(n), n]


## The wall of one storey, with openings cut in it. Openings all share y0..y1.
func _wall_band(f: Face, a: float, b: float, yb: float, yt: float, openings: Array[Vector2], y0: float, y1: float, col: Color, mat: float) -> void:
	var x := a
	for o: Vector2 in openings:
		_fquad(f, x, o.x, yb, yt, WALL_D, col, mat)                      # pier between openings
		_fquad(f, o.x, o.y, yb, y0, WALL_D, col, mat, 0.0, 1.0)          # under the sill, streaked
		_fquad(f, o.x, o.y, y1, yt, WALL_D, col, mat)                    # over the head
		x = o.y
	_fquad(f, x, b, yb, yt, WALL_D, col, mat)


## Room data for one pane.
func _room(kind: float, depth: float, sill: float, storey: float, ml: float, mr: float, group: int) -> Array:
	_window_count += 1
	var seed := float((_seed * 7919 + _window_count * 104729) % 9973)
	var grp := float((_seed * 31 + group * 6151) % 9967)
	return [Vector4(seed, depth, kind, sill), Vector4(storey, ml, mr, grp)]


func _pane(f: Face, s0: float, s1: float, y0: float, y1: float, d: float, room: Array) -> void:
	var col := Color(float(_sp["share"]), float(_sp.get("coated", 0.0)), float(_shop_kind) * 0.25, 1.0 if bool(_sp["old_glass"]) else 0.0)
	_glass.pane(f.p(s0, y0, d), f.r * (s1 - s0), Vector3.UP * (y1 - y0), room[0], room[1], col)


## A window opening: reveals, glass, frame and glazing bars, sill and head.
func _window(f: Face, s0: float, s1: float, y0: float, y1: float, frame: String, room: Array, reveal: float = -1.0) -> void:
	var rv: float = reveal if reveal > 0.0 else float(_sp["reveal"])
	var d0 := WALL_D
	var d1 := WALL_D - rv
	var w := s1 - s0
	var h := y1 - y0
	var wall_col: Color = _sp["wall_col"]
	var wall_mat: float = _sp["wall_mat"]
	# reveals
	_body.quad(f.p(s0, y0, d0), -f.n * rv, Vector3.UP * h, wall_col, wall_mat)
	_body.quad(f.p(s1, y0, d1), f.n * rv, Vector3.UP * h, wall_col, wall_mat)
	_body.quad(f.p(s0, y1, d1), f.r * w, f.n * rv, wall_col, wall_mat)
	_body.quad(f.p(s0, y0, d0), f.r * w, -f.n * rv, wall_col, wall_mat)
	_pane(f, s0, s1, y0, y1, d1, room)
	var fc: Color = _sp["frame_col"]
	var fd0 := d1
	var fd1 := d1 + 0.05
	var fw := 0.055
	match frame:
		"sash", "sash22":
			fw = 0.07
			_frame_rect(f, s0, s1, y0, y1, fd0, fd1, fw, fc)
			var mid := y0 + h * 0.52
			if _lean:
				_fquad(f, s0 + fw, s1 - fw, mid - 0.03, mid + 0.03, fd1 + 0.02, fc, M_PAINTED_METAL)
			else:
				_fbox_nb(f, s0 + fw, s1 - fw, mid - 0.03, mid + 0.03, fd0, fd1 + 0.02, fc, M_PAINTED_METAL)    # meeting rail
			if not _lean:
				_fbox_nb(f, s0 + fw, s1 - fw, y0 + fw, y0 + fw + 0.05, fd0, fd1, fc, M_PAINTED_METAL)      # bottom rail
			if frame == "sash22" and not _lean:
				_fbox_nb(f, s0 + w * 0.5 - 0.015, s0 + w * 0.5 + 0.015, y0 + fw, y1 - fw, fd0, fd1 - 0.015, fc, M_PAINTED_METAL)
		"steel":
			fw = 0.045
			_frame_rect(f, s0, s1, y0, y1, fd0, fd1, fw, fc)
			var nv := maxi(2, roundi(w / (0.9 if not _lean else 1.6)))
			for i: int in range(1, nv):
				var s := s0 + w * float(i) / float(nv)
				_fbox_nb(f, s - 0.02, s + 0.02, y0 + fw, y1 - fw, fd0, fd1, fc, M_PAINTED_METAL)
			var hy := y0 + h * 0.32       # hopper light at the bottom
			_fbox_nb(f, s0 + fw, s1 - fw, hy - 0.02, hy + 0.02, fd0, fd1, fc, M_PAINTED_METAL)
		"alum":
			fw = 0.05
			_frame_rect(f, s0, s1, y0, y1, fd0, fd1, fw, fc)
	# sill and head
	var trim_col: Color = _sp["trim_col"]
	var trim_mat: float = _sp["trim_mat"]
	match String(_sp.get("sill", "none")):
		"stone":
			_fbox_nb(f, s0 - 0.07, s1 + 0.07, y0 - 0.09, y0, d1 + 0.02, d0 + 0.07, trim_col, trim_mat)
		"metal":
			_fbox_nb(f, s0 - 0.02, s1 + 0.02, y0 - 0.04, y0, d1 + 0.02, d0 + 0.05, fc, M_PAINTED_METAL)
	var lintel := String(_sp.get("lintel", "none"))
	if _lean and lintel != "none":
		# flat heads only: the stone or brick head drawn on the wall plane
		var lc: Color = wall_col.darkened(0.12) if lintel == "soldier" else trim_col
		_fquad(f, s0 - 0.1, s1 + 0.1, y1, y1 + 0.24, d0 + 0.003, lc, wall_mat if lintel == "soldier" else trim_mat)
		lintel = "none"
	match lintel:
		"stone":
			_fbox_nb(f, s0 - 0.12, s1 + 0.12, y1, y1 + 0.26, d0, d0 + 0.025, trim_col, trim_mat)
		"keystone":
			_fbox_nb(f, s0 - 0.12, s1 + 0.12, y1, y1 + 0.26, d0, d0 + 0.025, trim_col, trim_mat)
			_fbox_nb(f, s0 + w * 0.5 - 0.1, s0 + w * 0.5 + 0.1, y1 - 0.04, y1 + 0.32, d0, d0 + 0.05, trim_col, trim_mat)
		"soldier":
			_fbox_nb(f, s0 - 0.05, s1 + 0.05, y1, y1 + 0.22, d0, d0 + 0.012, wall_col.darkened(0.12), wall_mat)


## A window air-conditioner sitting on the sill under a raised lower sash, as old flats have.
func _window_unit(f: Face, s0: float, s1: float, y0: float) -> void:
	var c := (s0 + s1) * 0.5
	var w := minf(0.62, s1 - s0 - 0.16)
	var d1 := WALL_D - float(_sp["reveal"])
	var body := _c(0.80, 0.79, 0.75)
	_fbox(f, c - w * 0.5, c + w * 0.5, y0 + 0.02, y0 + 0.42, d1 + 0.06, WALL_D + 0.34, body, M_PAINTED_METAL, _detail)
	_fbox(f, c - w * 0.5 + 0.03, c + w * 0.5 - 0.03, y0 + 0.06, y0 + 0.38, WALL_D + 0.34, WALL_D + 0.345, _c(0.35, 0.35, 0.34), M_GRATING, _detail)
	_fbox(f, c - w * 0.5 - 0.02, c - w * 0.5 + 0.02, y0 - 0.12, y0 + 0.02, WALL_D, WALL_D + 0.3, _c(0.2, 0.2, 0.2), M_PAINTED_METAL, _detail)
	_fbox(f, c + w * 0.5 - 0.02, c + w * 0.5 + 0.02, y0 - 0.12, y0 + 0.02, WALL_D, WALL_D + 0.3, _c(0.2, 0.2, 0.2), M_PAINTED_METAL, _detail)


## A window frame: four members seen from the front with their inner edges, 16 triangles
## (the faces against the reveal and the glass are never seen, so they are not built).
func _frame_rect(f: Face, s0: float, s1: float, y0: float, y1: float, d0: float, d1: float, fw: float, c: Color) -> void:
	var m := M_PAINTED_METAL
	var dd := d1 - d0
	_fquad(f, s0, s1, y0, y0 + fw, d1, c, m)
	_fquad(f, s0, s1, y1 - fw, y1, d1, c, m)
	_fquad(f, s0, s0 + fw, y0 + fw, y1 - fw, d1, c, m)
	_fquad(f, s1 - fw, s1, y0 + fw, y1 - fw, d1, c, m)
	var ia := s0 + fw
	var ib := s1 - fw
	var ja := y0 + fw
	var jb := y1 - fw
	_body.quad(f.p(ia, ja, d1), -f.n * dd, Vector3.UP * (jb - ja), c, m)          # inner left edge, faces +r
	_body.quad(f.p(ib, ja, d0), f.n * dd, Vector3.UP * (jb - ja), c, m)           # inner right edge, faces -r
	_body.quad(f.p(ia, jb, d0), f.r * (ib - ia), f.n * dd, c, m)                  # head edge, faces down
	_body.quad(f.p(ia, ja, d1), f.r * (ib - ia), -f.n * dd, c, m)                 # sill edge, faces up


func _room_kind() -> float:
	return float(_sp["room"])


func _upper_punched(f: Face) -> void:
	var lay := _bays(f, _sp["bay"])
	var a: float = lay[0]
	var bw: float = lay[1]
	var n: int = lay[2]
	var per: int = _sp["per_bay"]
	var ww: float = minf(float(_sp["win_w"]), (bw - 0.5) / float(per) - (0.12 if per == 2 else 0.0))
	var pilaster := String(_sp["layout"]) == "pilaster"
	var wall_col: Color = _sp["wall_col"]
	var wall_mat: float = _sp["wall_mat"]
	var b := f.length - a
	for k: int in range(1, floors):
		var yb := _fy[k]
		var yt := _fy[k + 1]
		var y0 := yb + float(_sp["sill_h"])
		var y1 := minf(y0 + float(_sp["win_h"]), yt - 0.45)
		var opens: Array[Vector2] = []
		for i: int in n:
			var c := a + bw * (float(i) + 0.5)
			if per == 1:
				opens.append(Vector2(c - ww * 0.5, c + ww * 0.5))
			else:
				var gap := 0.28 if not pilaster else 0.22
				opens.append(Vector2(c - gap * 0.5 - ww, c - gap * 0.5))
				opens.append(Vector2(c + gap * 0.5, c + gap * 0.5 + ww))
		if pilaster and k == 1 and floors > 2:
			# the base: the second storey faced in stone like the ground floor
			_wall_band(f, a, b, yb, yt, opens, y0, y1, _sp["gf_pier_col"], M_STONE)
		else:
			_wall_band(f, a, b, yb, yt, opens, y0, y1, wall_col, wall_mat)
		for i: int in opens.size():
			var o := opens[i]
			var group := k * 100 + (i / 2 if _room_kind() == K_HOME else 0)
			var room := _room(_room_kind(), _rng.randf_range(4.0, 6.5), float(_sp["sill_h"]), yt - yb, 0.9, 0.9, group)
			_window(f, o.x, o.y, y0, y1, _sp["frame"], room)
			if _room_kind() == K_HOME and style == "brick" and _rng.randf() < 0.12 and not _lean:
				_window_unit(f, o.x, o.y, y0)
		if pilaster:
			# terracotta spandrel panels between the storeys, sunk between the piers
			for i: int in n:
				var c := a + bw * (float(i) + 0.5)
				var half := ww + 0.25
				_fbox(f, c - half, c + half, yb + 0.12, y0 - 0.12, WALL_D, WALL_D + 0.03, (_sp["trim_col"] as Color).darkened(0.08), M_TERRACOTTA)
	if pilaster:
		var pc: Color = _sp["trim_col"]
		var top_y := _fy[floors - 1]
		for i: int in range(1, n):
			var s := a + bw * float(i)
			_fbox(f, s - 0.3, s + 0.3, _fy[2] if floors > 2 else _fy[1], top_y, WALL_D, WALL_D + 0.2, pc, M_TERRACOTTA)
			# capital block where the pier meets the top storey
			_fbox(f, s - 0.38, s + 0.38, top_y - 0.05, top_y + 0.35, WALL_D, WALL_D + 0.26, pc.lightened(0.04), M_TERRACOTTA)
		# ornament in the top storey's spandrels: a sunk panel with a raised boss in each bay
		for i: int in n:
			var c := a + bw * (float(i) + 0.5)
			var y := _fy[floors] - 0.55
			_fbox(f, c - bw * 0.36, c + bw * 0.36, y - 0.22, y + 0.22, WALL_D, WALL_D + 0.03, pc.darkened(0.12), M_TERRACOTTA)
			_fbox(f, c - 0.16, c + 0.16, y - 0.16, y + 0.16, WALL_D, WALL_D + 0.08, pc.lightened(0.05), M_TERRACOTTA)
	if bool(_sp.get("string_courses", false)):
		# belt course over the shopfronts and a sill course under the top storey
		_fbox(f, 0.0, f.length, _fy[1] - 0.05, _fy[1] + 0.22, WALL_D, 0.12, _sp["trim_col"], _sp["trim_mat"])
		if floors > 2:
			var ys := _fy[floors - 1] + float(_sp["sill_h"]) - 0.09
			_fbox(f, a, b, ys, ys + 0.1, WALL_D, WALL_D + 0.08, _sp["trim_col"], _sp["trim_mat"])
		if style == "terracotta" and floors > 3:
			_fbox(f, 0.0, f.length, _fy[2] - 0.08, _fy[2] + 0.18, WALL_D, 0.1, _sp["trim_col"], _sp["trim_mat"])


func _upper_strip(f: Face) -> void:
	var lay := _bays(f, _sp["bay"])
	var a: float = lay[0]
	var bw: float = lay[1]
	var n: int = lay[2]
	var b := f.length - a
	var wall_col: Color = _sp["wall_col"]
	for k: int in range(1, floors):
		var yb := _fy[k]
		var yt := _fy[k + 1]
		var y0 := yb + float(_sp["sill_h"])
		var y1 := minf(y0 + float(_sp["win_h"]), yt - 0.35)
		var opens: Array[Vector2] = []
		for i: int in n:
			var s0 := a + bw * float(i) + 0.18
			opens.append(Vector2(s0, s0 + bw - 0.36))
		_wall_band(f, a, b, yb, yt, opens, y0, y1, wall_col, M_BRICK)
		for o: Vector2 in opens:
			var room := _room(K_OFFICE, _rng.randf_range(5.0, 7.5), float(_sp["sill_h"]), yt - yb, 0.4, 0.4, k)
			_window(f, o.x, o.y, y0, y1, "steel", room)
			if bool(_sp["enamel"]):
				_fbox(f, o.x, o.y, yb + 0.25, y0 - 0.04, WALL_D, WALL_D + 0.02, _sp["enamel_col"], M_METAL_PANEL)
		# exposed slab edge at each floor
		_fbox(f, a, b, yb - 0.1, yb + 0.22, WALL_D, WALL_D + 0.06, _sp["trim_col"], M_CONCRETE)


func _upper_ribbon(f: Face) -> void:
	var a: float = _sp["end_pier"]
	var b := f.length - a
	var seg := float(_sp["bay"]) * 2.0
	var nseg := maxi(1, roundi((b - a) / seg))
	seg = (b - a) / float(nseg)
	var wc: Color = _sp["wall_col"]
	var fc: Color = _sp["frame_col"]
	for k: int in range(1, floors):
		var yb := _fy[k]
		var yt := _fy[k + 1]
		var y0 := yb + float(_sp["sill_h"])
		var y1 := minf(y0 + float(_sp["win_h"]), yt - 0.5)
		# deep spandrel band standing proud of the recessed glass, with a drip at its foot
		_fbox(f, a, b, yb - 0.25, y0, WALL_D, 0.0 if yb > CLEAR_HEIGHT else WALL_D, wc, M_BOARD_CONCRETE)
		_fbox(f, a, b, y1, yt - 0.25, WALL_D, 0.0, wc, M_BOARD_CONCRETE)
		_fbox(f, a, b, y0 - 0.06, y0, -0.02, 0.02, wc.darkened(0.1), M_CONCRETE)
		var rv: float = _sp["reveal"]
		var d1 := WALL_D - rv
		_body.quad(f.p(a, y1, d1), f.r * (b - a), f.n * (rv + 0.15), wc, M_CONCRETE)     # soffit
		_body.quad(f.p(a, y0, 0.0), f.r * (b - a), -f.n * (rv + 0.15), wc, M_CONCRETE)   # sill top
		_fquad(f, a, b, y0, y1, d1 - 0.0005, wc, M_CONCRETE)   # wall behind the glass where it ends
		for i: int in nseg:
			var s0 := a + seg * float(i)
			var room := _room(K_OFFICE, _rng.randf_range(5.0, 8.0), float(_sp["sill_h"]), yt - yb, 0.3, 0.3, k)
			_pane(f, s0, s0 + seg, y0, y1, d1, room)
			var nm := maxi(1, roundi(seg / 1.5))
			for m: int in range(0, nm + 1):
				var s := s0 + seg * float(m) / float(nm)
				_fbox(f, s - 0.035, s + 0.035, y0, y1, d1, d1 + 0.07, fc, M_PAINTED_METAL)
			_fbox(f, s0, s0 + seg, y0, y0 + 0.06, d1, d1 + 0.07, fc, M_PAINTED_METAL)
			_fbox(f, s0, s0 + seg, y1 - 0.06, y1, d1, d1 + 0.07, fc, M_PAINTED_METAL)
		# the ends of the band meet the end piers
		_body.quad(f.p(a, y0, WALL_D), -f.n * rv, Vector3.UP * (y1 - y0), wc, M_CONCRETE)
		_body.quad(f.p(b, y0, d1), f.n * rv, Vector3.UP * (y1 - y0), wc, M_CONCRETE)


func _upper_curtain(f: Face) -> void:
	var a: float = _sp["end_pier"]
	var b := f.length - a
	var bw := float(_sp["bay"])
	var n := maxi(1, roundi((b - a) / bw))
	bw = (b - a) / float(n)
	var fc: Color = _sp["frame_col"]
	var d1 := WALL_D - float(_sp["reveal"])
	for k: int in range(1, floors):
		var yb := _fy[k]
		var yt := _fy[k + 1]
		var y_vis0 := yb + 0.15
		var y_vis1 := yt - 0.75
		for i: int in n:
			var s0 := a + bw * float(i)
			var group := k * 100 + (i / 3 if _room_kind() == K_HOME else 0)
			var room := _room(_room_kind(), _rng.randf_range(5.0, 8.0), 0.15, yt - yb, 0.6, 0.6, group)
			_pane(f, s0, s0 + bw, y_vis0, y_vis1, d1, room)
			var spandrel := _room(K_SPANDREL, 1.0, 0.0, yt - yb, 0.0, 0.0, 0)
			_pane(f, s0, s0 + bw, y_vis1, yt + 0.15, d1, spandrel)
		# transoms at the slab and the vision head
		_fbox(f, a, b, yb + 0.1, yb + 0.17, d1, d1 + 0.08, fc, M_PAINTED_METAL)
		_fbox(f, a, b, y_vis1 - 0.04, y_vis1 + 0.03, d1, d1 + 0.08, fc, M_PAINTED_METAL)
	# vertical mullion caps, running the height of the curtain wall
	for i: int in range(0, n + 1):
		var s := a + bw * float(i)
		_fbox(f, s - 0.03, s + 0.03, _fy[1], roof_height, d1, d1 + 0.16, fc, M_PAINTED_METAL)
	_fquad(f, a, b, _fy[1], roof_height, d1 - 0.3, _c(0.1, 0.1, 0.1), M_PAINTED_METAL)
	# side returns of the glass box against the end piers
	_body.quad(f.p(a, _fy[1], WALL_D), -f.n * (WALL_D - d1), Vector3.UP * (roof_height - _fy[1]), _sp["pier_col"], _sp["pier_mat"])
	_body.quad(f.p(b, _fy[1], d1), f.n * (WALL_D - d1), Vector3.UP * (roof_height - _fy[1]), _sp["pier_col"], _sp["pier_mat"])
	_fbox(f, a, b, roof_height - 0.05, roof_height + 0.05, d1, WALL_D, fc, M_PAINTED_METAL)


func _upper_deck(f: Face) -> void:
	var lay := _bays(f, _sp["bay"])
	var a: float = lay[0]
	var bw: float = lay[1]
	var n: int = lay[2]
	var b := f.length - a
	var wc: Color = _sp["wall_col"]
	var pc: Color = _sp["pier_col"]
	var rv: float = _sp["reveal"]
	for k: int in range(1, floors):
		var yb := _fy[k]
		var yt := _fy[k + 1]
		var y0 := yb + 1.05
		var y1 := yt - 0.38
		# precast spandrel barrier hung on the slab edge
		_fbox(f, a, b, yb - 0.38, y0, WALL_D, WALL_D + 0.14, wc, M_CONCRETE, null)
		_fbox(f, a, b, y0, y0 + 0.04, WALL_D - 0.02, WALL_D + 0.16, wc.lightened(0.05), M_CONCRETE)
		for i: int in n:
			var s0 := a + bw * float(i) + 0.3
			var s1 := s0 + bw - 0.6
			var room := _room(K_PARKING, 16.0, 1.05, yt - yb, s0 - a, b - s1, k)     # one open deck behind every bay
			_pane(f, s0, s1, y0, y1, WALL_D - rv, room)
			_body.quad(f.p(s0, y1, WALL_D - rv), f.r * (s1 - s0), f.n * rv, wc, M_CONCRETE)
		# the slab soffit band between storeys is the next barrier's top; columns frame the bays
	for i: int in range(1, n):
		var s := a + bw * float(i)
		_fbox(f, s - 0.3, s + 0.3, _fy[1], roof_height + 1.1, WALL_D, 0.0, pc, M_CONCRETE)
	# reveals of each opening against the columns
	for i: int in n:
		var s0 := a + bw * float(i) + 0.3
		var s1 := s0 + bw - 0.6
		for k: int in range(1, floors):
			var y0 := _fy[k] + 1.05
			var oh := _fy[k + 1] - 0.38 - y0
			_body.quad(f.p(s0, y0, WALL_D), -f.n * rv, Vector3.UP * oh, wc, M_CONCRETE)
			_body.quad(f.p(s1, y0, WALL_D - rv), f.n * rv, Vector3.UP * oh, wc, M_CONCRETE)


## The parapet and cornice over the face.
func _top(f: Face) -> void:
	var L := f.length
	var H := roof_height
	var ph: float = _sp["parapet"]
	var cc: Color = _sp["cornice_col"]
	var tm: float = _sp["trim_mat"]
	var tc: Color = _sp["trim_col"]
	var wall_col: Color = _sp["wall_col"]
	var wall_mat: float = _sp["wall_mat"]
	var ep: float = _sp["end_pier"]
	# the parapet wall itself, thick enough to read from the roof
	_fbox(f, 0.0, L, H, H + ph, WALL_D - 0.3, WALL_D, wall_col, wall_mat)
	match String(_sp["cornice"]):
		"bracketed", "heavy":
			var heavy := String(_sp["cornice"]) == "heavy"
			var proj := 0.85 if heavy else 0.62
			var y_c := H + ph - (0.75 if heavy else 0.6)
			var mat := M_PAINTED_METAL if not heavy and cc != tc else tm
			# frieze panel and moulded crown in three steps
			_fbox(f, 0.0, L, y_c - 0.55, y_c - 0.05, WALL_D, WALL_D + 0.05, cc.darkened(0.06), mat)
			_fbox(f, 0.0, L, y_c, y_c + 0.12, WALL_D, proj * 0.55, cc, mat)
			_fbox(f, 0.0, L, y_c + 0.12, y_c + 0.3, WALL_D, proj, cc, mat)
			_fbox(f, 0.0, L, y_c + 0.3, y_c + 0.4, WALL_D, proj - 0.06, cc.darkened(0.05), mat)
			_fbox(f, 0.0, L, y_c - 0.05, y_c, WALL_D, proj * 0.35, cc, mat)
			# brackets (modillions) carrying the crown
			var nb := maxi(2, roundi(L / ((0.55 if heavy else 0.75) * (2.0 if _lean else 1.0))))
			for i: int in nb + 1:
				var s := clampf(L * float(i) / float(nb), 0.08, L - 0.08)
				_fbox(f, s - 0.06, s + 0.06, y_c - 0.42, y_c + 0.12, WALL_D, proj * 0.75, cc, mat)
			if heavy and not _lean:
				for i: int in roundi(L / 0.16):
					var s := 0.08 + float(i) * 0.16
					if s > L - 0.08:
						break
					_fbox(f, s - 0.04, s + 0.04, y_c - 0.1, y_c - 0.02, WALL_D, proj * 0.42, cc, mat)
			_fbox(f, 0.0, L, H + ph - 0.06, H + ph, WALL_D - 0.34, WALL_D + 0.04, tc, tm)
			if _sp.has("date") and style == "brick" and L > 10.0:
				# a date tablet in the parapet, centred over the facade
				if ph > 1.3:
					_fbox(f, L * 0.5 - 0.6, L * 0.5 + 0.6, y_c - 0.52, y_c - 0.08, WALL_D, WALL_D + 0.07, tc, tm)
					_detail.text(String(_sp["date"]), f.p(L * 0.5, y_c - 0.3, WALL_D + 0.07), f.r, f.n, 0.95, 0.3, 0.012, tc.darkened(0.15), M_LETTER)
		"corbel":
			var y := H + ph - 0.62
			for i: int in 4:
				_fbox(f, 0.0, L, y + float(i) * 0.135, y + float(i + 1) * 0.135, WALL_D, WALL_D + 0.045 * float(i + 1), wall_col, wall_mat)
			# dentil course of headers
			for i: int in roundi(L / 0.2):
				var s := 0.1 + float(i) * 0.2
				if s > L - 0.1:
					break
				_fbox(f, s - 0.05, s + 0.05, y - 0.135, y, WALL_D, WALL_D + 0.07, wall_col.darkened(0.08), wall_mat)
			_fbox(f, 0.0, L, H + ph - 0.08, H + ph, WALL_D - 0.34, WALL_D + 0.24, tc, tm)
		"coping":
			_fbox(f, 0.0, L, H + ph - 0.08, H + ph, WALL_D - 0.34, WALL_D + 0.04, cc, M_PAINTED_METAL)
			_fbox(f, ep, L - ep, H - 0.05, H + 0.25, WALL_D, WALL_D + 0.06, tc, M_CONCRETE)
		"slab":
			# a deep board-marked fascia closing the top, with a shadow slot under it
			_fbox(f, 0.0, L, H - 0.3, H + ph, WALL_D, 0.25, wall_col, M_BOARD_CONCRETE)
			_fbox(f, 0.0, L, H + ph - 0.05, H + ph, WALL_D - 0.34, 0.27, wall_col.darkened(0.05), M_CONCRETE)
			if _sp.has("name"):
				_detail.text(String(_sp["name"]), f.p(L * 0.5, H + ph * 0.45, 0.25), f.r, f.n, L * 0.55, ph * 0.32, 0.015, _c(0.45, 0.33, 0.20), M_LIT_LETTER)
		"metal":
			_fbox(f, 0.0, L, H, H + ph, WALL_D - 0.3, WALL_D + 0.02, _sp["pier_col"], M_METAL_PANEL)
			_fbox(f, 0.0, L, H + ph - 0.05, H + ph, WALL_D - 0.34, WALL_D + 0.06, (_sp["pier_col"] as Color).lightened(0.1), M_PAINTED_METAL)
		"deck":
			_fbox(f, 0.0, L, H - 0.38, H + 1.05, WALL_D, WALL_D + 0.14, wall_col, M_CONCRETE)
	if String(_sp["cornice"]) != "deck":
		_fbox(f, 0.0, L, H + ph - 0.06, H + ph, WALL_D - 0.34, WALL_D + 0.04, tc if String(_sp["cornice"]) != "metal" else _sp["pier_col"], tm)


# --- ground floors ----------------------------------------------------------------------

## Older shopfronts between stone or iron piers, with a street door to the floors above.
func _gf_traditional(f: Face, lobby: bool = false) -> void:
	var ep: float = _sp["end_pier"]
	var gf_h := _fy[1]
	var a := ep
	var b := f.length - ep
	var pier_col: Color = _sp["gf_pier_col"]
	var pier_mat: float = _sp["gf_pier_mat"]
	for s0: float in [0.0, f.length - ep]:
		_fbox(f, s0, s0 + ep, 0.0, gf_h, WALL_D, 0.0, pier_col, pier_mat)
		_fbox(f, s0 - 0.03 if s0 > 0.0 else s0, s0 + ep + (0.03 if s0 == 0.0 else 0.0), 0.0, 0.35, WALL_D, 0.0, pier_col.darkened(0.15), M_GRANITE if pier_mat != M_PAINTED_METAL else M_STONE)
		_solid(f, s0, s0 + ep, 0.0, gf_h, WALL_D - 0.3, 0.0)
	var units: Array[Vector2] = []
	var door: Vector2 = Vector2.ZERO
	var has_door := floors > 1 and f.primary
	if lobby and f.primary:
		var mid := f.length * 0.5
		door = Vector2(mid - 1.8, mid + 1.8)
		units.append(Vector2(a, door.x - 0.5))
		units.append(Vector2(door.y + 0.5, b))
	elif has_door and b - a > 7.0:
		if _rng.randf() < 0.5:
			door = Vector2(a, a + 1.5)
			a = door.y + 0.45
		else:
			door = Vector2(b - 1.5, b)
			b = door.x - 0.45
		_fbox(f, (door.y if door.x < a else door.x - 0.45), (door.y + 0.45 if door.x < a else door.x), 0.0, gf_h, WALL_D, 0.0, pier_col, pier_mat)
		units.append(Vector2(a, b))
	else:
		units.append(Vector2(a, b))
	if not f.primary:
		# along the side street: one shop at the corner, then a plain wall with windows and a service door
		var corner_len := minf(9.0, f.length * 0.4)
		var at_start := f.open_start
		units.clear()
		var shop_u := Vector2(ep, ep + corner_len) if at_start else Vector2(f.length - ep - corner_len, f.length - ep)
		units.append(shop_u)
		_gf_plain(f, (shop_u.y + 0.45) if at_start else ep, (f.length - ep) if at_start else (shop_u.x - 0.45))
		if at_start:
			_fbox(f, shop_u.y, shop_u.y + 0.45, 0.0, gf_h, WALL_D, 0.0, pier_col, pier_mat)
		else:
			_fbox(f, shop_u.x - 0.45, shop_u.x, 0.0, gf_h, WALL_D, 0.0, pier_col, pier_mat)
	# split long frontages into shops of five to nine metres
	var split: Array[Vector2] = []
	for u: Vector2 in units:
		var n := maxi(1, floori((u.y - u.x) / 6.0))
		var uw := (u.y - u.x - 0.45 * float(n - 1)) / float(n)
		for i: int in n:
			var s0 := u.x + float(i) * (uw + 0.45)
			split.append(Vector2(s0, s0 + uw))
			if i > 0:
				_fbox(f, s0 - 0.45, s0, 0.0, gf_h, WALL_D, -0.02, pier_col, pier_mat)
	for u: Vector2 in split:
		_shopfront(f, u.x, u.y, false)
	if door != Vector2.ZERO:
		if lobby:
			_lobby_entrance(f, door.x, door.y)
		else:
			_street_door(f, door.x, door.y)


## A ground-floor wall with high windows and a steel service door (side and back streets).
func _gf_plain(f: Face, a: float, b: float) -> void:
	if b - a < 0.5:
		return
	var gf_h := _fy[1]
	var col: Color = _sp["gf_pier_col"] if int(_sp["gf_pier_mat"]) != int(M_PAINTED_METAL) else _sp["wall_col"]
	var mat: float = _sp["gf_pier_mat"] if int(_sp["gf_pier_mat"]) != int(M_PAINTED_METAL) else _sp["wall_mat"]
	if int(mat) == int(M_GRANITE):
		mat = _sp["wall_mat"]
		col = _sp["wall_col"]
	var bw := 3.0
	var n := maxi(1, floori((b - a) / bw))
	bw = (b - a) / float(n)
	var opens: Array[Vector2] = []
	var door_i := _rng.randi_range(0, n - 1)
	for i: int in n:
		if i == door_i:
			continue
		var c := a + bw * (float(i) + 0.5)
		opens.append(Vector2(c - 0.6, c + 0.6))
	var y0 := 1.6
	var y1 := gf_h - 0.8
	var dc := a + bw * (float(door_i) + 0.5)
	# wall with the door gap left in it
	var x := a
	var cuts: Array[Vector2] = opens.duplicate()
	cuts.append(Vector2(dc - 0.5, dc + 0.5))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	for o: Vector2 in cuts:
		_fquad(f, x, o.x, 0.0, gf_h, WALL_D, col, mat)
		if o.x == dc - 0.5:
			_fquad(f, o.x, o.y, 2.2, gf_h, WALL_D, col, mat)
		else:
			_fquad(f, o.x, o.y, 0.0, y0, WALL_D, col, mat, 0.0, 1.0)
			_fquad(f, o.x, o.y, y1, gf_h, WALL_D, col, mat)
		x = o.y
	_fquad(f, x, b, 0.0, gf_h, WALL_D, col, mat)
	for o: Vector2 in opens:
		var room := _room(K_OFFICE, 5.0, 1.6, gf_h, 0.6, 0.6, 7)
		_window(f, o.x, o.y, y0, y1, "alum" if style != "brick" else "sash", room, 0.15)
		_fbox(f, o.x - 0.05, o.y + 0.05, y0 - 0.06, y0, WALL_D - 0.15, WALL_D + 0.04, _sp["trim_col"], _sp["trim_mat"])
	_service_door(f, dc - 0.5, dc + 0.5)
	_solid(f, a, b, 0.0, gf_h, WALL_D - 0.3, WALL_D)


func _service_door(f: Face, s0: float, s1: float) -> void:
	var d := WALL_D - 0.12
	var dc := _c(0.22, 0.24, 0.24)
	_body.quad(f.p(s0, 0.0, WALL_D), -f.n * 0.12, Vector3.UP * 2.2, _sp["wall_col"], M_CONCRETE)
	_body.quad(f.p(s1, 0.0, d), f.n * 0.12, Vector3.UP * 2.2, _sp["wall_col"], M_CONCRETE)
	_body.quad(f.p(s0, 2.2, d), f.r * (s1 - s0), f.n * 0.12, _sp["wall_col"], M_CONCRETE)
	_fquad(f, s0, s1, 0.0, 2.2, d, dc, M_METAL_PANEL)
	_fbox(f, s0, s1, 2.12, 2.2, d, d + 0.05, dc.darkened(0.3), M_PAINTED_METAL)
	_fbox(f, s1 - 0.16, s1 - 0.12, 0.95, 1.1, d, d + 0.06, _c(0.6, 0.6, 0.58), M_GALVANISED)
	# a caged bulkhead lamp over the door
	_fbox(f, (s0 + s1) * 0.5 - 0.1, (s0 + s1) * 0.5 + 0.1, 2.45, 2.62, WALL_D, WALL_D + 0.12, _c(0.1, 0.1, 0.1), M_PAINTED_METAL)
	_fquad(f, (s0 + s1) * 0.5 - 0.07, (s0 + s1) * 0.5 + 0.07, 2.48, 2.59, WALL_D + 0.121, _c(1.0, 0.85, 0.6), M_LAMP)


## One shop: stall riser, display glazing with mullions, transom lights, a recessed entrance,
## a fascia board with its name, gooseneck lamps, and on some an awning.
func _shopfront(f: Face, s0: float, s1: float, modern: bool) -> void:
	var gf_h := _fy[1]
	var dg := -0.32                                  # glazing line
	var riser_h := 0.5 if not modern else 0.18
	var fz0 := gf_h - 1.0
	var fz1 := gf_h - 0.3
	var y_tb := 2.85 if not modern else minf(3.25, fz0 - 0.1)    # transom bar
	var w := s1 - s0
	var frame_col: Color = _choose([_c(0.08, 0.16, 0.12), _c(0.05, 0.05, 0.05), _c(0.30, 0.08, 0.07), _c(0.74, 0.72, 0.68), _c(0.13, 0.15, 0.24)]) if not modern else _sp["frame_col"]
	var fascia_col: Color = _choose(_sp["fascia_cols"])
	var riser_col: Color = _choose([_c(0.12, 0.12, 0.13), _c(0.35, 0.18, 0.16), _c(0.42, 0.40, 0.38), _c(0.10, 0.20, 0.16)])
	var riser_mat := M_GRANITE if _rng.randf() < 0.6 else M_TILE
	var shop_seed := _rng.randi()
	var room_depth := _rng.randf_range(8.0, 14.0)
	var named := CitySignNames.shop_with_kind(_rng)
	var shop_name: String = named[0]
	_shop_kind = int(named[1])
	# entrance recess
	var dw := 1.0 if w < 6.0 else 1.8
	var recess := 1.2 if not modern else 0.0
	var e_c := s0 + w * 0.5
	var pos_roll := _rng.randf()
	if pos_roll < 0.3:
		e_c = s0 + 0.35 + dw * 0.5 + 0.15
	elif pos_roll < 0.6:
		e_c = s1 - 0.35 - dw * 0.5 - 0.15
	var e0 := e_c - dw * 0.5 - 0.15
	var e1 := e_c + dw * 0.5 + 0.15
	var group := shop_seed % 9967
	# the shop is one room behind all its panes
	var mk_room := func(p0: float, p1: float, sill: float) -> Array:
		_window_count += 1
		var sd := float(shop_seed % 9973)
		return [Vector4(sd, room_depth, K_SHOP, sill), Vector4(gf_h, p0 - s0, s1 - p1, float(group))]
	# display windows either side of the entrance
	for seg: Vector2 in [Vector2(s0, e0), Vector2(e1, s1)]:
		if seg.y - seg.x < 0.2:
			continue
		_fbox(f, seg.x, seg.y, 0.0, riser_h, dg - 0.1, dg + 0.06, riser_col, riser_mat)
		_fbox(f, seg.x, seg.y, riser_h, riser_h + 0.06, dg - 0.05, dg + 0.08, frame_col, M_PAINTED_METAL)
		var nm := maxi(1, roundi((seg.y - seg.x) / 2.0))
		for i: int in nm:
			var p0 := seg.x + (seg.y - seg.x) * float(i) / float(nm)
			var p1 := seg.x + (seg.y - seg.x) * float(i + 1) / float(nm)
			_pane(f, p0, p1, riser_h + 0.06, y_tb, dg, mk_room.call(p0, p1, riser_h + 0.06))
			if i > 0:
				_fbox(f, p0 - 0.03, p0 + 0.03, riser_h, y_tb, dg - 0.03, dg + 0.05, frame_col, M_PAINTED_METAL)
		_fbox(f, seg.x, seg.x + 0.07, riser_h, y_tb, dg - 0.04, dg + 0.06, frame_col, M_PAINTED_METAL)
		_fbox(f, seg.y - 0.07, seg.y, riser_h, y_tb, dg - 0.04, dg + 0.06, frame_col, M_PAINTED_METAL)
	# transom lights over the whole width, prism-glass high windows on the old fronts
	_fbox(f, s0, s1, y_tb, y_tb + 0.1, dg - 0.05, dg + 0.08, frame_col, M_PAINTED_METAL)
	var nt := maxi(1, roundi(w / 1.0))
	if fz0 - 0.08 - (y_tb + 0.1) > 0.15:
		for i: int in nt:
			var p0 := s0 + w * float(i) / float(nt)
			var p1 := s0 + w * float(i + 1) / float(nt)
			_pane(f, p0, p1, y_tb + 0.1, fz0 - 0.08, dg, mk_room.call(p0, p1, y_tb + 0.1))
			if i > 0:
				_fbox(f, p0 - 0.025, p0 + 0.025, y_tb + 0.1, fz0 - 0.08, dg - 0.03, dg + 0.05, frame_col, M_PAINTED_METAL)
	_fbox(f, s0, s1, fz0 - 0.1, fz0, dg - 0.05, WALL_D + 0.02, frame_col, M_PAINTED_METAL)
	# the wall plane is filled between the glazing line and the face: head and side linings
	_body.quad(f.p(s0, 0.0, WALL_D), -f.n * (WALL_D - dg), Vector3.UP * fz0, frame_col, M_PAINTED_METAL)
	_body.quad(f.p(s1, 0.0, dg), f.n * (WALL_D - dg), Vector3.UP * fz0, frame_col, M_PAINTED_METAL)
	_body.quad(f.p(s0, 0.0, 0.0), f.r * w, -f.n * (0.0 - dg + 0.1), _c(0.4, 0.4, 0.38), M_PAVING)
	# recessed entrance: angled-in display returns, mosaic floor, soffit and the door
	if recess > 0.0:
		var dd := dg - recess
		_fbox(f, e0, e1, 0.0, 0.03, dd, dg, _choose([_c(0.80, 0.78, 0.72), _c(0.55, 0.20, 0.16), _c(0.25, 0.35, 0.30)]), M_TILE)
		for side: int in 2:
			var s := e0 if side == 0 else e1
			# riser and glass return, facing into the recess
			_fbox(f, s - 0.04 if side == 0 else s, s if side == 0 else s + 0.04, 0.0, riser_h, dd, dg, riser_col, riser_mat)
			var o := f.p(s, riser_h, dg) if side == 0 else f.p(s, riser_h, dd)
			var u := -f.n * recess if side == 0 else f.n * recess
			var rm: Array = mk_room.call(s0, s1, riser_h)
			rm[1] = Vector4(gf_h, 0.5, 0.5, float(group))
			_glass.pane(o, u, Vector3.UP * (y_tb - riser_h), rm[0], rm[1], Color(float(_sp["share"]), 0, float(_shop_kind) * 0.25, 0))
			_fbox(f, s - 0.05, s + 0.05, riser_h, y_tb, dd, dd + 0.08, frame_col, M_PAINTED_METAL)
			_fbox(f, s - 0.05, s + 0.05, 0.0, y_tb, dg - 0.06, dg + 0.06, frame_col, M_PAINTED_METAL)
		_body.quad(f.p(e0, y_tb, dd), f.r * (e1 - e0), f.n * recess, frame_col, M_PAINTED_METAL)
		var dr: Array = mk_room.call(e0 + 0.15, e1 - 0.15, 0.0)
		_pane(f, e0 + 0.15, e1 - 0.15, 0.0, y_tb, dd, dr)
		_door_frame(f, e0 + 0.15, e1 - 0.15, y_tb, dd, frame_col, dw > 1.5)
		_fquad(f, e0, e0 + 0.15, 0.0, y_tb, dd, frame_col, M_PAINTED_METAL)
		_fquad(f, e1 - 0.15, e1, 0.0, y_tb, dd, frame_col, M_PAINTED_METAL)
	else:
		_door_frame(f, e0 + 0.15, e1 - 0.15, y_tb, dg + 0.005, frame_col, dw > 1.5)
	# fascia board and its moulded hood
	var fascia_d1 := WALL_D + 0.1
	_fbox(f, s0, s1, fz0, fz1, WALL_D, fascia_d1, fascia_col, M_FASCIA, null)
	_set_last_gradient(_body, 24, fz0, fz1)
	_fbox(f, s0 - 0.02, s1 + 0.02, fz1, fz1 + 0.1, WALL_D, fascia_d1 + 0.08, fascia_col.darkened(0.2), M_PAINTED_METAL)
	_fquad(f, s0, s1, fz1 + 0.1, gf_h, WALL_D, _sp["gf_pier_col"] if int(_sp["gf_pier_mat"]) != int(M_PAINTED_METAL) else _sp["wall_col"], _sp["gf_pier_mat"] if int(_sp["gf_pier_mat"]) != int(M_PAINTED_METAL) else _sp["wall_mat"])
	_shop_kind = CitySignNames.KIND_GOODS
	var lit_letters := modern or _rng.randf() < 0.35
	var letter_col: Color
	if lit_letters:
		letter_col = _choose([_c(1.0, 0.92, 0.8), _c(1.0, 0.45, 0.25), _c(0.5, 0.85, 1.0), _c(1.0, 0.82, 0.4)])
	else:
		letter_col = _choose([_c(0.86, 0.70, 0.36), _c(0.92, 0.90, 0.84), _c(0.08, 0.08, 0.08)])
		if letter_col.get_luminance() < 0.1 and fascia_col.get_luminance() < 0.2:
			letter_col = _c(0.9, 0.88, 0.8)
		if letter_col.get_luminance() > 0.5 and fascia_col.get_luminance() > 0.5:
			letter_col = _c(0.08, 0.08, 0.08)
	_detail.text(shop_name, f.p((s0 + s1) * 0.5, (fz0 + fz1) * 0.5, fascia_d1), f.r, f.n, w * 0.78, (fz1 - fz0) * 0.5, 0.012, letter_col, M_LIT_LETTER if lit_letters else M_LETTER)
	if not lit_letters:
		# gooseneck lamps lighting the board
		var nl := maxi(2, roundi(w / 2.2))
		for i: int in nl:
			var s := s0 + w * (float(i) + 0.5) / float(nl)
			_fbox(f, s - 0.012, s + 0.012, fz1 + 0.1, fz1 + 0.32, WALL_D + 0.08, WALL_D + 0.11, _c(0.08, 0.08, 0.08), M_PAINTED_METAL, _detail)
			_fbox(f, s - 0.012, s + 0.012, fz1 + 0.3, fz1 + 0.33, WALL_D + 0.1, WALL_D + 0.42, _c(0.08, 0.08, 0.08), M_PAINTED_METAL, _detail)
			_fbox(f, s - 0.09, s + 0.09, fz1 + 0.2, fz1 + 0.33, WALL_D + 0.36, WALL_D + 0.5, _c(0.08, 0.08, 0.08), M_PAINTED_METAL, _detail)
			_detail.quad(f.p(s - 0.07, fz1 + 0.199, WALL_D + 0.37), f.r * 0.14, f.n * 0.12, _c(1.0, 0.86, 0.62), M_LAMP)
	# awning
	if not modern and _rng.randf() < 0.45:
		_awning(f, s0 + 0.08, s1 - 0.08, fz0 - 0.12)
	_solid(f, s0, s1, 0.0, gf_h, WALL_D - 0.3, dg)


## Sets the weathering gradient of the last box's vertices from their height (for fascia light pools).
func _set_last_gradient(kit: CityMeshKit, count: int, y0: float, y1: float) -> void:
	var n := kit.verts.size()
	for i: int in range(maxi(0, n - count), n):
		var g := clampf((kit.verts[i].y - y0) / maxf(0.01, y1 - y0), 0.0, 1.0)
		kit.uv2s[i] = Vector2(kit.uv2s[i].x, g)


func _door_frame(f: Face, s0: float, s1: float, y_top: float, d: float, col: Color, pair: bool) -> void:
	var fw := 0.1
	_fbox(f, s0, s0 + fw, 0.0, y_top, d, d + 0.06, col, M_PAINTED_METAL)
	_fbox(f, s1 - fw, s1, 0.0, y_top, d, d + 0.06, col, M_PAINTED_METAL)
	_fbox(f, s0, s1, 2.2, 2.3, d, d + 0.06, col, M_PAINTED_METAL)          # door head, transom above
	_fbox(f, s0 + fw, s1 - fw, 0.0, 0.28, d, d + 0.05, col, M_PAINTED_METAL)   # kick rail
	if pair:
		var m := (s0 + s1) * 0.5
		_fbox(f, m - 0.06, m + 0.06, 0.0, 2.2, d, d + 0.06, col, M_PAINTED_METAL)
		_fbox(f, m - 0.3, m - 0.27, 0.9, 1.3, d + 0.06, d + 0.1, _c(0.7, 0.6, 0.4), M_GALVANISED)
		_fbox(f, m + 0.27, m + 0.3, 0.9, 1.3, d + 0.06, d + 0.1, _c(0.7, 0.6, 0.4), M_GALVANISED)
	else:
		_fbox(f, s1 - fw - 0.08, s1 - fw - 0.05, 0.9, 1.3, d + 0.06, d + 0.1, _c(0.7, 0.6, 0.4), M_GALVANISED)


## The door to the upper floors: a narrow recessed doorway with a transom and a lamp.
func _street_door(f: Face, s0: float, s1: float) -> void:
	var gf_h := _fy[1]
	var dd := WALL_D - 0.45
	var wc: Color = _sp["gf_pier_col"]
	var wm: float = _sp["gf_pier_mat"]
	var top := 3.0
	_fquad(f, s0, s1, top, gf_h, WALL_D, wc, wm)
	_body.quad(f.p(s0, 0.0, WALL_D), -f.n * 0.45, Vector3.UP * top, wc, wm)
	_body.quad(f.p(s1, 0.0, dd), f.n * 0.45, Vector3.UP * top, wc, wm)
	_body.quad(f.p(s0, top, dd), f.r * (s1 - s0), f.n * 0.45, wc, wm)
	_fbox(f, s0, s1, 0.0, 0.17, dd, WALL_D + 0.05, _sp["trim_col"], M_STONE)        # step
	var dc: Color = _choose([_c(0.10, 0.16, 0.12), _c(0.30, 0.10, 0.08), _c(0.05, 0.05, 0.05), _c(0.25, 0.16, 0.10)])
	var room := _room(K_LOBBY, 4.0, 1.2, 3.4, 0.3, 0.3, 9)
	_pane(f, s0 + 0.18, s1 - 0.18, 1.2, 2.2, dd + 0.01, room)
	_fquad(f, s0, s1, 0.17, 1.2, dd, dc, M_TIMBER)
	_fbox(f, s0, s1, 1.15, 1.22, dd, dd + 0.05, dc, M_PAINTED_METAL)
	_fbox(f, s0, s0 + 0.18, 1.2, 2.3, dd, dd + 0.05, dc, M_PAINTED_METAL)
	_fbox(f, s1 - 0.18, s1, 1.2, 2.3, dd, dd + 0.05, dc, M_PAINTED_METAL)
	_fbox(f, s0, s1, 2.2, 2.32, dd, dd + 0.06, dc, M_PAINTED_METAL)
	var troom := _room(K_LOBBY, 4.0, 2.32, 3.4, 0.3, 0.3, 9)
	_pane(f, s0, s1, 2.32, top, dd + 0.01, troom)
	_fbox(f, s1 - 0.32, s1 - 0.28, 1.0, 1.08, dd + 0.05, dd + 0.1, _c(0.7, 0.6, 0.4), M_GALVANISED)
	# number plaque and a lantern over the door
	_fbox(f, s0 - 0.4, s0 - 0.12, 2.5, 2.75, WALL_D, WALL_D + 0.02, _c(0.75, 0.62, 0.32), M_GALVANISED)
	_detail.text(str(_rng.randi_range(100, 990)), f.p(s0 - 0.26, 2.625, WALL_D + 0.02), f.r, f.n, 0.22, 0.12, 0.004, _c(0.1, 0.1, 0.1), M_PAINTED_METAL)
	var lc := (s0 + s1) * 0.5
	_fbox(f, lc - 0.09, lc + 0.09, top + 0.15, top + 0.45, WALL_D, WALL_D + 0.16, _c(0.06, 0.06, 0.06), M_PAINTED_METAL)
	_fquad(f, lc - 0.07, lc + 0.07, top + 0.18, top + 0.42, WALL_D + 0.161, _c(1.0, 0.82, 0.55), M_LAMP)
	_solid(f, s0, s1, 0.0, gf_h, WALL_D - 0.6, dd)


## The office lobby of a 1920s block: a deep stone doorway with bronze doors, a lit transom
## and the building's name cut above.
func _lobby_entrance(f: Face, s0: float, s1: float) -> void:
	var gf_h := _fy[1]
	var dd := WALL_D - 1.4
	var sc: Color = _sp["gf_pier_col"]
	var bronze := _c(0.30, 0.22, 0.12)
	var top := gf_h - 1.1
	_fbox(f, s0 - 0.5, s0, 0.0, gf_h, WALL_D, 0.0, sc, M_STONE)
	_fbox(f, s1, s1 + 0.5, 0.0, gf_h, WALL_D, 0.0, sc, M_STONE)
	_fquad(f, s0, s1, top, gf_h, WALL_D, sc, M_STONE)
	_body.quad(f.p(s0, 0.0, WALL_D), -f.n * 1.4, Vector3.UP * top, sc, M_STONE)
	_body.quad(f.p(s1, 0.0, dd), f.n * 1.4, Vector3.UP * top, sc, M_STONE)
	_body.quad(f.p(s0, top, dd), f.r * (s1 - s0), f.n * 1.4, sc.darkened(0.1), M_SMOOTH_STONE)
	_fbox(f, s0, s1, 0.0, 0.02, dd, WALL_D, _c(0.35, 0.33, 0.30), M_GRANITE)
	# surround moulding
	_fbox(f, s0 - 0.25, s0, 0.0, top + 0.25, WALL_D, 0.0, sc.lightened(0.05), M_SMOOTH_STONE)
	_fbox(f, s1, s1 + 0.25, 0.0, top + 0.25, WALL_D, 0.0, sc.lightened(0.05), M_SMOOTH_STONE)
	_fbox(f, s0 - 0.25, s1 + 0.25, top, top + 0.25, WALL_D, 0.06, sc.lightened(0.05), M_SMOOTH_STONE)
	# doors and transom
	var w := s1 - s0
	var room := _room(K_LOBBY, 9.0, 0.0, gf_h, 1.0, 1.0, 11)
	_pane(f, s0 + 0.2, s1 - 0.2, 0.0, top, dd, room)
	_fquad(f, s0, s0 + 0.2, 0.0, top, dd, bronze, M_GALVANISED)
	_fquad(f, s1 - 0.2, s1, 0.0, top, dd, bronze, M_GALVANISED)
	for i: int in 5:
		var s := s0 + 0.2 + (w - 0.4) * float(i) / 4.0
		_fbox(f, s - 0.05, s + 0.05, 0.0, top, dd, dd + 0.08, bronze, M_GALVANISED)
	_fbox(f, s0 + 0.2, s1 - 0.2, 2.35, 2.5, dd, dd + 0.08, bronze, M_GALVANISED)
	_fbox(f, s0 + 0.2, s1 - 0.2, 0.0, 0.3, dd, dd + 0.06, bronze, M_GALVANISED)
	if _sp.has("name"):
		_fbox(f, s0 - 0.25, s1 + 0.25, top + 0.3, gf_h - 0.1, WALL_D, WALL_D + 0.04, sc.lightened(0.08), M_SMOOTH_STONE)
		_detail.text(String(_sp["name"]), f.p((s0 + s1) * 0.5, (top + 0.3 + gf_h - 0.1) * 0.5, WALL_D + 0.04), f.r, f.n, w - 0.2, 0.32, 0.01, _c(0.40, 0.30, 0.15), M_LETTER)    # between the surround mouldings, which stand in front of it
	# a pair of bronze lanterns
	for s: float in [s0 - 0.38, s1 + 0.38]:
		_fbox(f, s - 0.1, s + 0.1, 2.6, 3.05, 0.06, 0.26, bronze, M_GALVANISED)
		_fquad(f, s - 0.08, s + 0.08, 2.65, 3.0, 0.261, _c(1.0, 0.85, 0.6), M_LAMP)
	_solid(f, s0, s1, 0.0, gf_h, dd - 0.3, dd)


## Postwar and recent shopfronts: slim aluminium frames, glass nearly to the pavement,
## a flat canopy with downlights and a sign band above.
func _gf_modern(f: Face) -> void:
	var ep: float = _sp["end_pier"]
	var gf_h := _fy[1]
	var a := ep
	var b := f.length - ep
	var pc: Color = _sp["gf_pier_col"]
	var pm: float = _sp["gf_pier_mat"]
	for s0: float in [0.0, f.length - ep]:
		_fbox(f, s0, s0 + ep, 0.0, gf_h, WALL_D, 0.0, pc, pm)
		_solid(f, s0, s0 + ep, 0.0, gf_h, WALL_D - 0.3, 0.0)
	var limit := b
	if not f.primary:
		var corner_len := minf(10.0, f.length * 0.4)
		if f.open_start:
			limit = a + corner_len
			_gf_plain(f, limit + 0.45, b)
			_fbox(f, limit, limit + 0.45, 0.0, gf_h, WALL_D, 0.0, pc, pm)
			b = limit
		else:
			_gf_plain(f, a, b - corner_len - 0.45)
			_fbox(f, b - corner_len - 0.45, b - corner_len, 0.0, gf_h, WALL_D, 0.0, pc, pm)
			a = b - corner_len
	var n := maxi(1, floori((b - a) / 7.0))
	var uw := (b - a - 0.4 * float(n - 1)) / float(n)
	var canopy_y := minf(3.25, _fy[1] - 1.1) - 0.22
	var band_c: Color = _sp["frame_col"] if style == "glass" else _sp["trim_col"]
	for i: int in n:
		var s0 := a + float(i) * (uw + 0.4)
		var s1 := s0 + uw
		if i > 0:
			_fbox(f, s0 - 0.4, s0, 0.0, gf_h, WALL_D, -0.02, pc, pm)
		_shopfront(f, s0, s1, true)
	# continuous flat canopy with downlights
	var cd := 1.25
	_fbox(f, a, b, canopy_y, canopy_y + 0.16, WALL_D, cd, band_c.darkened(0.2), M_PAINTED_METAL)
	var nl := maxi(2, roundi((b - a) / 1.8))
	for i: int in nl:
		var s := a + (b - a) * (float(i) + 0.5) / float(nl)
		_body.quad(f.p(s - 0.07, canopy_y - 0.002, cd * 0.55 - 0.07), f.r * 0.14, f.n * 0.14, _c(1.0, 0.9, 0.75), M_LAMP)


## A 1970s base: the ground floor set back behind a colonnade of board-marked columns.
func _gf_colonnade(f: Face) -> void:
	var ep: float = _sp["end_pier"]
	var gf_h := _fy[1]
	var a := ep
	var b := f.length - ep
	var wc: Color = _sp["wall_col"]
	var back := -3.2
	if f.primary:
		_gf_front = back - 0.3
	for s0: float in [0.0, f.length - ep]:
		_fbox(f, s0, s0 + ep, 0.0, gf_h, back, 0.0, wc, M_BOARD_CONCRETE)
		_solid(f, s0, s0 + ep, 0.0, gf_h, back, 0.0)
	var soffit := gf_h - 0.9
	# deep soffit beam across the front, with downlights in the colonnade ceiling
	_fbox(f, 0.0, f.length, soffit, gf_h + 0.25, WALL_D, 0.0, wc, M_BOARD_CONCRETE)
	_body.quad(f.p(a, soffit, back), f.r * (b - a), f.n * (WALL_D - back), wc.darkened(0.1), M_CONCRETE)
	_body.quad(f.p(a, 0.002, 0.0), f.r * (b - a), -f.n * (0.0 - back), _c(0.5, 0.49, 0.46), M_PAVING)
	var cols := maxi(2, roundi((b - a) / 6.0))
	var step := (b - a) / float(cols)
	for i: int in range(1, cols):
		var s := a + step * float(i)
		_fbox(f, s - 0.35, s + 0.35, 0.0, soffit, -1.0, -0.3, wc, M_BOARD_CONCRETE)
		_solid(f, s - 0.35, s + 0.35, 0.0, soffit, -1.0, -0.3)
	for i: int in cols:
		for j: int in 2:
			var s := a + step * (float(i) + 0.5)
			var dz := back + 0.9 + float(j) * 1.3
			_body.quad(f.p(s - 0.12, soffit - 0.003, dz - 0.12), f.r * 0.24, f.n * 0.24, _c(1.0, 0.92, 0.78), M_LAMP)
	# glass wall at the back of the colonnade, with an entrance pair in it
	var fc: Color = _sp["frame_col"]
	var door_i := cols / 2
	var nm := maxi(2, roundi((b - a) / 1.5))
	var gw := (b - a) / float(nm)
	var group := _rng.randi() % 10000
	# the shop named on the soffit occupies the glass behind the colonnade; otherwise a lobby
	var shop_named := f.primary and not (_sp.has("name") and String(_sp["cornice"]) != "slab")
	var nm2 := ""
	if shop_named:
		var named := CitySignNames.shop_with_kind(_rng)
		nm2 = named[0]
		_shop_kind = int(named[1])
	for i: int in nm:
		var s0 := a + gw * float(i)
		var kind := K_SHOP if shop_named else K_LOBBY
		var room := [Vector4(float(group), 10.0, kind, 0.0), Vector4(gf_h, s0 - a, b - s0 - gw, float(group))]
		_pane(f, s0, s0 + gw, 0.0, soffit, back, room)
		_fbox(f, s0 - 0.04, s0 + 0.04, 0.0, soffit, back, back + 0.08, fc, M_PAINTED_METAL)
	_shop_kind = CitySignNames.KIND_GOODS
	_fbox(f, a, b, 0.0, 0.1, back, back + 0.08, fc, M_PAINTED_METAL)
	_fbox(f, a, b, 2.4, 2.48, back, back + 0.08, fc, M_PAINTED_METAL)
	var dcs := a + step * (float(door_i) + 0.5)
	_fbox(f, dcs - 0.92, dcs - 0.88, 0.0, 2.4, back, back + 0.1, fc, M_PAINTED_METAL)
	_fbox(f, dcs + 0.88, dcs + 0.92, 0.0, 2.4, back, back + 0.1, fc, M_PAINTED_METAL)
	_fbox(f, dcs - 0.03, dcs + 0.03, 0.0, 2.4, back, back + 0.1, fc, M_PAINTED_METAL)
	_solid(f, a, b, 0.0, gf_h, back - 0.3, back)
	# name in cast letters on the soffit beam
	if _sp.has("name") and String(_sp["cornice"]) != "slab":
		_detail.text(String(_sp["name"]), f.p(f.length * 0.5, (soffit + gf_h) * 0.5, 0.0), f.r, f.n, f.length * 0.6, 0.45, 0.02, _c(0.3, 0.3, 0.3), M_LETTER)
	elif shop_named:
		_detail.text(nm2, f.p(f.length * 0.5, (soffit + gf_h) * 0.5, 0.0), f.r, f.n, f.length * 0.5, 0.4, 0.02, _c(1.0, 0.95, 0.85), M_LIT_LETTER)


## A parking structure's ground floor: a vehicle entrance, a pay booth window, a shop,
## and a tall lit blade sign.
func _gf_garage(f: Face) -> void:
	var ep: float = _sp["end_pier"]
	var gf_h := _fy[1]
	var a := ep
	var b := f.length - ep
	var wc: Color = _sp["wall_col"]
	for s0: float in [0.0, f.length - ep]:
		_fbox(f, s0, s0 + ep, 0.0, gf_h, WALL_D, 0.0, wc, M_CONCRETE)
		_solid(f, s0, s0 + ep, 0.0, gf_h, WALL_D - 0.3, 0.0)
	if not f.primary:
		_gf_plain(f, a, b)
		return
	var gate_w := 7.0
	var g0 := a + 0.6 if _rng.randf() < 0.5 else b - 0.6 - gate_w
	var g1 := g0 + gate_w
	var top := 3.2
	# the open vehicle entrance
	_fquad(f, g0, g1, top, gf_h, WALL_D, wc, M_CONCRETE)
	var room := _room(K_PARKING, 20.0, 0.0, gf_h, 0.2, 0.2, 13)
	_pane(f, g0, g1, 0.0, top, WALL_D - 0.6, room)
	_body.quad(f.p(g0, 0.0, WALL_D), -f.n * 0.6, Vector3.UP * top, wc, M_CONCRETE)
	_body.quad(f.p(g1, 0.0, WALL_D - 0.6), f.n * 0.6, Vector3.UP * top, wc, M_CONCRETE)
	_body.quad(f.p(g0, top, WALL_D - 0.6), f.r * gate_w, f.n * 0.6, wc.darkened(0.1), M_CONCRETE)
	_body.quad(f.p(g0, 0.004, 0.0), f.r * gate_w, -f.n * 0.6, _c(0.3, 0.3, 0.3), M_CONCRETE)
	# clearance bar with hazard bands, an island and pay station between the lanes
	var yel := _c(0.85, 0.65, 0.1)
	_fbox(f, g0 + 0.2, g1 - 0.2, 2.3, 2.42, WALL_D - 0.45, WALL_D - 0.33, yel, M_PAINTED_METAL)
	var mid := (g0 + g1) * 0.5
	_fbox(f, mid - 0.3, mid + 0.3, 0.0, 0.15, WALL_D - 0.6, WALL_D, _c(0.6, 0.6, 0.57), M_CONCRETE)
	_fbox(f, mid - 0.15, mid + 0.15, 0.15, 1.35, WALL_D - 0.5, WALL_D - 0.2, _c(0.2, 0.25, 0.3), M_PAINTED_METAL)
	_fquad(f, mid - 0.1, mid + 0.1, 0.9, 1.2, WALL_D - 0.199, _c(0.6, 0.9, 1.0), M_LAMP)
	# remaining frontage: a shop
	var other := Vector2(a, g0 - 0.45) if g0 > a + 2.0 else Vector2(g1 + 0.45, b)
	if other.y - other.x > 2.5:
		_shopfront(f, other.x, other.y, true)
		_fbox(f, (g0 - 0.45) if g0 > a + 2.0 else g1, g0 if g0 > a + 2.0 else (g1 + 0.45), 0.0, gf_h, WALL_D, 0.0, wc, M_CONCRETE)
	# tall blade sign, lit, at the corner of the entrance
	var bs := g1 - 0.1 if g0 < f.length * 0.5 else g0 + 0.1
	var y0 := 4.6
	var y1 := minf(roof_height - 0.4, y0 + 5.0)
	var red := _c(0.55, 0.08, 0.06)
	_fbox(f, bs - 0.12, bs + 0.12, y0, y1, 0.0, 1.0, red, M_PAINTED_METAL, _detail)
	_fbox(f, bs - 0.05, bs + 0.05, y0 + 0.4, y0 + 0.5, WALL_D, 0.0, _c(0.1, 0.1, 0.1), M_PAINTED_METAL, _detail)
	_fbox(f, bs - 0.05, bs + 0.05, y1 - 0.5, y1 - 0.4, WALL_D, 0.0, _c(0.1, 0.1, 0.1), M_PAINTED_METAL, _detail)
	var word := "PARK"
	var lh := (y1 - y0 - 0.4) / float(word.length())
	for i: int in word.length():
		var cy := y1 - 0.2 - lh * (float(i) + 0.5)
		for side: int in 2:
			var sn := f.r if side == 0 else -f.r
			var sr := -f.n if side == 0 else f.n
			_detail.text(word[i], f.p(bs, cy, 0.5) + sn * 0.121, sr, sn, 0.7, lh * 0.8, 0.0, _c(1.0, 0.95, 0.85), M_LIT_LETTER)
	# the name over the entrance, in the strip of wall below the first deck's barrier
	var barrier_y := gf_h - 0.38
	_detail.text(CitySignNames.garage(_rng), f.p(mid, (top + barrier_y) * 0.5, WALL_D + 0.01), f.r, f.n, gate_w * 0.85, minf(0.42, (barrier_y - top) * 0.7), 0.02, _c(1.0, 0.95, 0.85), M_LIT_LETTER)


func _awning(f: Face, s0: float, s1: float, y_top: float) -> void:
	var proj := _rng.randf_range(1.1, 1.4)
	var y_low := maxf(CLEAR_HEIGHT + 0.3, y_top - 0.55)
	var col: Color = _choose([_c(0.12, 0.25, 0.16), _c(0.42, 0.08, 0.08), _c(0.10, 0.14, 0.30), _c(0.55, 0.42, 0.14), _c(0.08, 0.08, 0.08), _c(0.62, 0.30, 0.12)])
	col.a = 1.0 if _rng.randf() < 0.4 else 0.0
	var top := f.p(s0, y_top, WALL_D + 0.1)
	var slope := f.p(s0, y_low, proj) - top
	var span := f.r * (s1 - s0)
	_body.quad(top, span, slope, col, M_FABRIC)                       # upper side
	_body.quad(top + slope, span, -slope, col.darkened(0.25), M_FABRIC)   # underside
	_body.quad(top + slope + span, -span, Vector3.UP * -0.001, col, M_FABRIC)
	# valance
	var vt := f.p(s0, y_low, proj)
	_body.quad(vt + Vector3.DOWN * 0.24, span, Vector3.UP * 0.24, col, M_FABRIC)
	_body.quad(vt + span + Vector3.DOWN * 0.24, -span, Vector3.UP * 0.24, col.darkened(0.25), M_FABRIC)
	# arms
	for s: float in [s0 + 0.05, s1 - 0.05]:
		var a := f.p(s, y_top - 0.05, WALL_D + 0.1)
		var bb := f.p(s, y_low + 0.02, proj - 0.03)
		var mid := (a + bb) * 0.5
		var ax := (bb - a) * 0.5
		var az := f.r * 0.015
		var ay := az.cross(ax).normalized() * 0.015
		_body.obox(mid, ax, ay, az, _c(0.1, 0.1, 0.1), M_PAINTED_METAL)


# --- shell, roof, plant -----------------------------------------------------------------

func _build_shell(open_neg: bool, open_pos: bool) -> void:
	var w := lot_width
	var d := lot_depth
	var H := roof_height
	var zb := -d + (REAR_IN if not open_back else -WALL_D)
	var party_col: Color = _vary(_c(0.42, 0.24, 0.18), 0.08) if style == "brick" or style == "terracotta" or style == "midcentury" else _vary(_c(0.55, 0.54, 0.51), 0.04)
	var party_mat := M_COMMON_BRICK if party_col.r > party_col.b * 1.4 else M_CONCRETE
	var side_top := H + 0.5
	var coping := _c(0.5, 0.5, 0.48)
	# party walls on the sides that do not face a street
	if not open_neg:
		_body.quad(Vector3(-w / 2.0, 0, zb), Vector3(0, 0, WALL_D - zb), Vector3(0, H, 0), party_col, party_mat)
		_body.box(Vector3(-w / 2.0, H, zb), Vector3(-w / 2.0 + 0.3, side_top, WALL_D - 0.3), party_col, party_mat)
		_body.box(Vector3(-w / 2.0, side_top, zb), Vector3(-w / 2.0 + 0.32, side_top + 0.06, WALL_D - 0.3), coping, M_CONCRETE)
	if not open_pos:
		_body.quad(Vector3(w / 2.0, 0, WALL_D), Vector3(0, 0, zb - WALL_D), Vector3(0, H, 0), party_col, party_mat)
		_body.box(Vector3(w / 2.0 - 0.3, H, zb), Vector3(w / 2.0, side_top, WALL_D - 0.3), party_col, party_mat)
		_body.box(Vector3(w / 2.0 - 0.32, side_top, zb), Vector3(w / 2.0, side_top + 0.06, WALL_D - 0.3), coping, M_CONCRETE)
	# the rear wall, plain, with a downpipe (unless the back is a street facade of its own)
	var xl := -w / 2.0 + (-WALL_D if open_neg else 0.0)
	var xr := w / 2.0 - (-WALL_D if open_pos else 0.0)
	if not open_back:
		_body.quad(Vector3(xr, 0, zb), Vector3(xl - xr, 0, 0), Vector3(0, H, 0), party_col, party_mat)
		_body.box(Vector3(xl, H, zb), Vector3(xr, side_top, zb + 0.3), party_col, party_mat)
		_body.box(Vector3(xl, side_top, zb - 0.02), Vector3(xr, side_top + 0.06, zb + 0.32), coping, M_CONCRETE)
		_detail.box(Vector3(xr - 1.0, 0.2, zb - 0.12), Vector3(xr - 0.9, H + 0.2, zb - 0.02), _c(0.25, 0.27, 0.27), M_GALVANISED)
	# downpipes on open side faces, from a rainwater head under the parapet to the ground
	var ep: float = _sp["end_pier"]
	for side: int in 2:
		var open := open_pos if side == 0 else open_neg
		if not open:
			continue
		var sx := 1.0 if side == 0 else -1.0
		var x_wall := sx * (w / 2.0 + WALL_D)
		var z := zb + ep + 0.15
		var a := x_wall
		var b := x_wall + sx * 0.1
		_detail.box(Vector3(minf(a, b), 0.15, z - 0.05), Vector3(maxf(a, b), H - 0.45, z + 0.05), _c(0.22, 0.24, 0.24), M_GALVANISED)
		var c := x_wall + sx * 0.14
		_detail.box(Vector3(minf(a, c), H - 0.45, z - 0.15), Vector3(maxf(a, c), H - 0.12, z + 0.15), _c(0.22, 0.24, 0.24), M_GALVANISED)
	# collision for the upper mass and the ground floor behind the shopfronts
	var zc := zb if not open_back else -d + 0.6
	_solids.append(AABB(Vector3(-w / 2.0, _fy[1], zc), Vector3(w, H + float(_sp["parapet"]) - _fy[1], -zc)))
	# behind a colonnade the ground floor stands back on every open face, not only the front
	var inset := -_gf_front if String(_sp["gf"]) == "colonnade" else 0.0
	var gx0 := -w / 2.0 + (inset if open_neg else 0.0)
	var gx1 := w / 2.0 - (inset if open_pos else 0.0)
	var gz0 := (-d + inset) if open_back and inset > 0.0 else zc
	_solids.append(AABB(Vector3(gx0, 0, gz0), Vector3(gx1 - gx0, _fy[1], _gf_front - gz0)))


func _build_roof(open_neg: bool, open_pos: bool) -> void:
	var w := lot_width
	var d := lot_depth
	var H := roof_height
	var x0 := -w / 2.0 + (0.0 if not open_neg else -WALL_D)
	var x1 := w / 2.0 - (0.0 if not open_pos else -WALL_D)
	var z1 := WALL_D
	# roofing: old tar-and-gravel, grey cap sheet, or a white membrane on the newer blocks
	var roof_col: Color = _vary(_choose([_c(0.22, 0.22, 0.22), _c(0.34, 0.33, 0.31), _c(0.27, 0.26, 0.25)]), 0.08)
	if style == "glass" or (style != "brick" and _rng.randf() < 0.35):
		roof_col = _vary(_c(0.72, 0.72, 0.70), 0.04)
	if style == "parking":
		roof_col = _c(0.42, 0.42, 0.40)
	var zr := -d + (REAR_IN if not open_back else -WALL_D)
	_body.quad(Vector3(x0, H, z1), Vector3(x1 - x0, 0, 0), Vector3(0, 0, zr - z1), roof_col, M_ROOF if style != "parking" else M_CONCRETE)
	if style == "parking":
		# top deck: light poles and a stair tower
		for i: int in maxi(1, roundi(w / 12.0)):
			var x := x0 + (x1 - x0) * (float(i) + 0.5) / float(maxi(1, roundi(w / 12.0)))
			var z := -d * 0.5
			_detail.cylinder(Vector3(x, H, z), 0.08, 7.0, 6, _c(0.4, 0.4, 0.4), M_GALVANISED, false)
			_detail.box(Vector3(x - 0.35, H + 7.0, z - 0.15), Vector3(x + 0.35, H + 7.15, z + 0.15), _c(0.2, 0.2, 0.2), M_PAINTED_METAL)
			_detail.quad(Vector3(x - 0.3, H + 6.999, z - 0.12), Vector3(0.6, 0, 0), Vector3(0, 0, 0.24), _c(1.0, 0.95, 0.85), M_LAMP)
		_stair_tower(Vector3(x1 - 4.0, H, -d + 0.5), Vector3(3.5, 3.6, 5.0), _c(0.62, 0.61, 0.58), M_CONCRETE)
		top_height = maxf(top_height, H + 7.15)
		return
	# plant on the roof
	var margin := 1.6
	var rx0 := x0 + margin
	var rx1 := x1 - margin
	var rz0 := -d + margin
	var rz1 := z1 - margin - 0.5
	if rx1 - rx0 < 3.0:
		return
	var placed: Array[Rect2] = []
	if floors >= 3 or _rng.randf() < 0.5:
		var bw := 3.0
		var bd := 4.6
		var bx := _rng.randf_range(rx0, rx1 - bw)
		var bz := _rng.randf_range(rz0, maxf(rz0, rz0 + (rz1 - rz0) * 0.5 - bd))
		var bh := 2.9 if floors < 6 else 4.2
		var bcol: Color = _sp["wall_col"] if style == "brick" else _vary(_c(0.6, 0.59, 0.55), 0.05)
		var bmat: float = M_COMMON_BRICK if style == "brick" else M_CONCRETE
		if style == "brick":
			bcol = _vary(_sp["wall_col"], 0.08)
		_stair_tower(Vector3(bx, H, bz), Vector3(bw, bh, bd), bcol, bmat)
		placed.append(Rect2(bx - 0.5, bz - 0.5, bw + 1.0, bd + 1.0))
		top_height = maxf(top_height, H + bh + 0.1)
	# a roof hatch, and on the older blocks a glazed skylight over the stair
	var hatch := _free_spot(placed, rx0 + 0.6, rx1 - 0.6, rz0 + 0.6, rz1 - 0.6, 1.4)
	if hatch != Vector2.INF:
		var hc := Vector3(hatch.x, H, hatch.y)
		_body.box(hc - Vector3(0.5, 0, 0.5), hc + Vector3(0.5, 0.5, 0.5), _c(0.45, 0.46, 0.45), M_GALVANISED, CityMeshKit.F_ALL & ~CityMeshKit.F_BOTTOM)
		placed.append(Rect2(hatch.x - 0.7, hatch.y - 0.7, 1.4, 1.4))
	if style == "brick" or style == "terracotta":
		var sky := _free_spot(placed, rx0 + 1.2, rx1 - 1.2, rz0 + 1.2, rz1 - 1.2, 2.6)
		if sky != Vector2.INF:
			var sc := Vector3(sky.x, H, sky.y)
			_body.box(sc - Vector3(1.1, 0, 0.8), sc + Vector3(1.1, 0.45, 0.8), _c(0.15, 0.17, 0.16), M_PAINTED_METAL, CityMeshKit.F_ALL & ~CityMeshKit.F_BOTTOM)
			var room := [Vector4(float(_rng.randi() % 997), 3.0, K_SPANDREL, 0.0), Vector4(3.0, 0.0, 0.0, 0.0)]
			_glass.pane(sc + Vector3(-1.0, 0.451, 0.7), Vector3(2.0, 0, 0), Vector3(0, 0, -1.4), room[0], room[1], Color(0, 0, 0, 1))
			placed.append(Rect2(sky.x - 1.4, sky.y - 1.1, 2.8, 2.2))
	# a timber water tank on a steel stand, on some of the older blocks
	if (style == "brick" or style == "terracotta") and _rng.randf() < 0.5:
		var r := _rng.randf_range(1.6, 2.1)
		var spot := _free_spot(placed, rx0 + r, rx1 - r, rz0 + r, rz1 - r, r * 2.4)
		if spot != Vector2.INF:
			_water_tank(Vector3(spot.x, H, spot.y), r)
			placed.append(Rect2(spot.x - r - 0.4, spot.y - r - 0.4, r * 2 + 0.8, r * 2 + 0.8))
			top_height = maxf(top_height, H + 3.4 + r * 1.6 + r * 0.45)
	# condensing units, exhaust fans, vent stacks
	var units := _rng.randi_range(1, 2 + int(w / 9.0))
	for i: int in units:
		var spot := _free_spot(placed, rx0 + 0.7, rx1 - 0.7, rz0 + 0.7, rz1 - 0.7, 1.8)
		if spot == Vector2.INF:
			break
		_condenser(Vector3(spot.x, H, spot.y))
		placed.append(Rect2(spot.x - 0.9, spot.y - 0.9, 1.8, 1.8))
	for i: int in _rng.randi_range(2, 5):
		var spot := _free_spot(placed, rx0, rx1, rz0, rz1, 0.6)
		if spot == Vector2.INF:
			break
		if _rng.randf() < 0.5:
			_detail.cylinder(Vector3(spot.x, H, spot.y), 0.06, _rng.randf_range(0.6, 1.2), 6, _c(0.3, 0.3, 0.3), M_GALVANISED)
		else:
			_detail.cylinder(Vector3(spot.x, H, spot.y), 0.28, 0.5, 8, _c(0.55, 0.56, 0.56), M_GALVANISED, false)
			_detail.cone(Vector3(spot.x, H + 0.62, spot.y), 0.42, 0.18, 8, _c(0.55, 0.56, 0.56), M_GALVANISED)
			_detail.cylinder(Vector3(spot.x, H + 0.5, spot.y), 0.3, 0.12, 8, _c(0.2, 0.2, 0.2), M_PAINTED_METAL, false)
		placed.append(Rect2(spot.x - 0.3, spot.y - 0.3, 0.6, 0.6))
	if style == "glass" or style == "brutalist" or (style == "midcentury" and _rng.randf() < 0.5):
		# a long duct run to a rooftop air handler
		var spot := _free_spot(placed, rx0 + 2.0, rx1 - 2.0, rz0 + 1.5, rz1 - 1.5, 4.0)
		if spot != Vector2.INF:
			_detail.box(Vector3(spot.x - 1.8, H, spot.y - 1.0), Vector3(spot.x + 1.8, H + 1.8, spot.y + 1.0), _c(0.62, 0.63, 0.62), M_GALVANISED)
			_detail.box(Vector3(spot.x - 0.3, H + 0.6, spot.y + 1.0), Vector3(spot.x + 0.3, H + 1.2, minf(rz1, spot.y + 6.0)), _c(0.58, 0.59, 0.58), M_GALVANISED)


func _free_spot(placed: Array[Rect2], x0: float, x1: float, z0: float, z1: float, size: float) -> Vector2:
	if x1 <= x0 or z1 <= z0:
		return Vector2.INF
	for attempt: int in 12:
		var p := Vector2(_rng.randf_range(x0, x1), _rng.randf_range(z0, z1))
		var r := Rect2(p.x - size * 0.5, p.y - size * 0.5, size, size)
		var ok := true
		for q: Rect2 in placed:
			if q.intersects(r):
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


func _stair_tower(at: Vector3, size: Vector3, col: Color, mat: float) -> void:
	_body.box(at, at + size, col, mat, CityMeshKit.F_ALL & ~CityMeshKit.F_BOTTOM)
	_body.box(at + Vector3(-0.05, size.y, -0.05), at + size + Vector3(0.05, 0.1, 0.05), _c(0.45, 0.45, 0.43), M_CONCRETE)
	# a steel door on the front face, toward the street
	var dx := at.x + size.x * 0.5
	_body.quad(Vector3(dx - 0.45, at.y, at.z + size.z + 0.01), Vector3(0.9, 0, 0), Vector3(0, 2.1, 0), _c(0.3, 0.33, 0.33), M_METAL_PANEL)
	_solids.append(AABB(at, size))


func _condenser(at: Vector3) -> void:
	var s := Vector3(_rng.randf_range(1.0, 1.3), _rng.randf_range(0.9, 1.2), _rng.randf_range(0.9, 1.2))
	var lo := at - Vector3(s.x * 0.5, 0, s.z * 0.5)
	_detail.box(lo + Vector3(0.05, 0, 0.05), lo + Vector3(s.x - 0.05, 0.12, s.z - 0.05), _c(0.2, 0.2, 0.2), M_PAINTED_METAL)
	_detail.box(lo + Vector3(0, 0.12, 0), lo + s + Vector3(0, 0.12, 0), _c(0.70, 0.70, 0.66), M_GALVANISED)
	_detail.cylinder(Vector3(at.x, at.y + s.y + 0.12, at.z), minf(s.x, s.z) * 0.38, 0.03, 10, _c(0.08, 0.08, 0.08), M_GRATING)


func _water_tank(at: Vector3, r: float) -> void:
	var leg_h := 3.2
	var steel := _c(0.12, 0.12, 0.12)
	for i: int in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var p := at + Vector3(cos(a) * r * 0.7, 0, sin(a) * r * 0.7)
		_detail.box(p - Vector3(0.08, 0, 0.08), p + Vector3(0.08, leg_h, 0.08), steel, M_PAINTED_METAL)
	_detail.box(at + Vector3(-r * 0.75, leg_h - 0.2, -0.06), at + Vector3(r * 0.75, leg_h, 0.06), steel, M_PAINTED_METAL)
	_detail.box(at + Vector3(-0.06, leg_h - 0.2, -r * 0.75), at + Vector3(0.06, leg_h, r * 0.75), steel, M_PAINTED_METAL)
	var h := r * 1.6
	var wood := _vary(_c(0.38, 0.30, 0.22), 0.1)
	_detail.cylinder(at + Vector3(0, leg_h, 0), r, h, 16, wood, M_TIMBER, false)
	for k: int in 4:
		_detail.cylinder(at + Vector3(0, leg_h + h * (0.12 + 0.25 * float(k)), 0), r + 0.02, 0.05, 16, steel, M_PAINTED_METAL, false)
	_detail.cone(at + Vector3(0, leg_h + h, 0), r + 0.08, r * 0.45, 16, _c(0.26, 0.24, 0.22), M_ROOF)
	_detail.box(at + Vector3(r * 0.9, leg_h, -0.2), at + Vector3(r * 0.95, leg_h + h, 0.2), steel, M_PAINTED_METAL)


## A steel fire escape across two bays of an older facade: a balcony at each storey, stairs
## between them, and a counterweighted drop ladder held up over the pavement.
func _build_fire_escape(f: Face) -> void:
	if not bool(_sp["fire_escape"]) or floors < 3 or _lean:
		return
	var lay := _bays(f, _sp["bay"])
	var a: float = lay[0]
	var bw: float = lay[1]
	var n: int = lay[2]
	if n < 3:
		return
	var b0 := _rng.randi_range(0, n - 2)
	var s0 := a + bw * float(b0) + 0.2
	var s1 := a + bw * float(b0 + 2) - 0.2
	var depth := 1.15
	var dw := WALL_D
	var steel := _c(0.07, 0.07, 0.07)
	for k: int in range(1, floors):
		var y := _fy[k] + float(_sp["sill_h"]) - 0.45
		_fbox(f, s0, s1, y - 0.05, y, dw, dw + depth, steel, M_GRATING, _detail)
		_fbox(f, s0, s1, y - 0.15, y - 0.05, dw + depth - 0.05, dw + depth, steel, M_PAINTED_METAL, _detail)
		# railing: top rail, mid rail, pickets
		var rh := 1.0
		_fbox(f, s0, s1, y + rh - 0.04, y + rh, dw + depth - 0.04, dw + depth, steel, M_PAINTED_METAL, _detail)
		_fbox(f, s0, s1, y + 0.45, y + 0.48, dw + depth - 0.03, dw + depth, steel, M_PAINTED_METAL, _detail)
		for side: float in [s0, s1 - 0.04]:
			_fbox(f, side, side + 0.04, y + rh - 0.04, y + rh, dw, dw + depth, steel, M_PAINTED_METAL, _detail)
		var np := int((s1 - s0) / (0.3 if not _lean else 0.6))
		for i: int in np + 1:
			var s := s0 + (s1 - s0 - 0.02) * float(i) / float(np)
			_fbox(f, s, s + 0.02, y, y + rh, dw + depth - 0.02, dw + depth, steel, M_PAINTED_METAL, _detail)
		for i: int in 4:
			var dd := dw + depth * float(i) / 3.0
			_fbox(f, s0, s0 + 0.02, y, y + rh, dd - 0.02, dd, steel, M_PAINTED_METAL, _detail)
			_fbox(f, s1 - 0.02, s1, y, y + rh, dd - 0.02, dd, steel, M_PAINTED_METAL, _detail)
		# brackets into the wall
		for s: float in [s0 + 0.3, s1 - 0.3]:
			var tip := f.p(s, y - 0.05, dw + depth)
			var foot := f.p(s, y - 0.8, dw)
			var mid := (tip + foot) * 0.5
			var ax := (tip - foot) * 0.5
			var az := f.r * 0.02
			var ay := az.cross(ax).normalized() * 0.02
			_detail.obox(mid, ax, ay, az, steel, M_PAINTED_METAL)
		# stair up to the next balcony
		if k < floors - 1:
			var y2 := _fy[k + 1] + float(_sp["sill_h"]) - 0.45
			var going_right := k % 2 == 1
			var sa := s0 + 0.15 if going_right else s1 - 0.15
			var sb := s0 + (s1 - s0) * 0.6 if going_right else s1 - (s1 - s0) * 0.6
			var da := dw + depth - 0.4
			var p0 := f.p(sa, y, da)
			var p1 := f.p(sb, y2, da)
			var c := (p0 + p1) * 0.5
			var ax := (p1 - p0) * 0.5
			var az := f.n * 0.02
			var ay := az.cross(ax).normalized() * 0.09
			_detail.obox(c + f.n * 0.33, ax, ay, az, steel, M_PAINTED_METAL)
			_detail.obox(c - f.n * 0.33, ax, ay, az, steel, M_PAINTED_METAL)
			var steps := int((y2 - y) / 0.2)
			for i: int in range(1, steps):
				var t := float(i) / float(steps)
				var ts := lerpf(sa, sb, t)
				var ty := lerpf(y, y2, t)
				_fbox(f, ts - 0.12, ts + 0.12, ty - 0.015, ty + 0.015, da - 0.31, da + 0.31, steel, M_GRATING, _detail)
			# handrail
			_detail.obox(c + f.n * 0.34 + Vector3.UP * 0.9, ax, ay * 0.25, az, steel, M_PAINTED_METAL)
	# the drop ladder, raised, hanging under the first balcony
	var y1 := _fy[1] + float(_sp["sill_h"]) - 0.45
	var ls := s1 - 0.6
	var ly0 := maxf(CLEAR_HEIGHT + 0.3, y1 - 2.4)
	var ld := dw + depth - 0.25
	_fbox(f, ls - 0.22, ls - 0.19, ly0, y1 + 1.0, ld, ld + 0.03, steel, M_PAINTED_METAL, _detail)
	_fbox(f, ls + 0.19, ls + 0.22, ly0, y1 + 1.0, ld, ld + 0.03, steel, M_PAINTED_METAL, _detail)
	var rung := ly0 + 0.15
	while rung < y1 + 0.9:
		_fbox(f, ls - 0.19, ls + 0.19, rung, rung + 0.025, ld, ld + 0.025, steel, M_PAINTED_METAL, _detail)
		rung += 0.3


func _finish() -> void:
	if _surface_mat == null:
		_surface_mat = ShaderMaterial.new()
		_surface_mat.shader = SURFACE_SHADER
		_glass_mat = ShaderMaterial.new()
		_glass_mat.shader = GLASS_SHADER
	body_mesh = _make_mesh("Body", _body, _surface_mat, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	# the glass casts shadows too: the shell is hollow, so without it the sun shines in at one
	# window and out of another, printing bright window shapes into the building's shadow
	glass_mesh = _make_mesh("Glass", _glass, _glass_mat, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	detail_mesh = _make_mesh("Detail", _detail, _surface_mat, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	if detail_mesh != null:
		detail_mesh.visibility_range_end = DETAIL_RANGE
		detail_mesh.visibility_range_end_margin = 10.0
	if glass_mesh != null:
		glass_mesh.visibility_range_end = 900.0
	var body := StaticBody3D.new()
	body.name = "Collision"
	for box: AABB in _solids:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size
		cs.shape = bs
		cs.position = box.get_center()
		body.add_child(cs)
	add_child(body)
	var tris := _body.triangle_count() + _glass.triangle_count() + _detail.triangle_count()
	var surfaces := 0
	for mi: MeshInstance3D in [body_mesh, glass_mesh, detail_mesh]:
		if mi != null:
			surfaces += mi.mesh.get_surface_count()
	var fp := _body.fingerprint() + _glass.fingerprint() + _detail.fingerprint()
	stats = {
		"style": style,
		"floors": floors,
		"triangles": tris,
		"surfaces": surfaces,
		"shadow_casters": int(body_mesh != null) + int(glass_mesh != null) + int(detail_mesh != null),
		"vertices": int(fp.w),
		"windows": _window_count,
		"collision_boxes": _solids.size(),
		"lean": _lean,
		"fingerprint": [snappedf(fp.x, 0.001), snappedf(fp.y, 0.001), snappedf(fp.z, 0.001), int(fp.w)],
	}
	# drop build state
	_body = null
	_glass = null
	_detail = null


func _make_mesh(label: String, kit: CityMeshKit, mat: Material, shadows: GeometryInstance3D.ShadowCastingSetting) -> MeshInstance3D:
	if kit.is_empty():
		return null
	var mesh := ArrayMesh.new()
	kit.commit(mesh, mat)
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.cast_shadow = shadows
	add_child(mi)
	return mi
