class_name FurnitureSignals
extends Node3D
## Traffic signals at a junction, US practice: one mast-arm pole on the far right-hand corner for each
## approach, the arm reaching out over the junction with two three-section heads facing the drivers, a
## street-name blade on the arm, and pedestrian heads with push buttons on the poles at every crossing.
## A fixed-time cycle: east-west green, amber, all red, then north-south. Pedestrians walk with the traffic
## that runs parallel to them, then a flashing hand clears the crossing before the amber.

const K := preload("res://worlds/city/furniture_kit.gd")

const GREEN: float = 16.0
const AMBER: float = 3.5
const ALL_RED: float = 1.5
const WALK: float = 7.0
const POLE_AT: float = 7.45          # corner pole, metres from the junction centre along both streets
const ARM_HEIGHT: float = 6.4
const HEAD_DROP: float = 0.62        # from the arm down to the middle of a head

var cycle_time: float = 0.0
var state: Dictionary = {}            ## current aspect per group: {"ew": "green", "ns": "red", "ew_ped": "walk", ...}
var pole_positions: Array[Vector2] = []

var _lens: Dictionary = {}            # "ew_red" -> StandardMaterial3D
var _ped: Dictionary = {}             # "ew" -> ShaderMaterial
var _labels: Array[Label3D] = []


## Build the signals for the junction at 'centre'. 'names' gives the street names: {"ns": ..., "ew": ...}.
func build(centre: Vector2, metal: Material, body: StaticBody3D, names: Dictionary) -> void:
	name = "Signals"
	var poles := _st()
	var housing := _st()
	var border := _st()
	var lens_tools: Dictionary = {}
	for g: String in ["ew", "ns"]:
		for c: String in ["red", "amber", "green"]:
			lens_tools[g + "_" + c] = _st()
	var ped_tools: Dictionary = {"ew": _st(), "ns": _st()}
	var white := _st()
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.02, 0.20, 0.08)
	green.roughness = 0.4
	for d: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		# traffic approaching from leg d moves along -d; its right-hand side is r
		var r := CityRoads.right_of(-d)
		var group := "ns" if absf(d.y) > 0.5 else "ew"
		var pole2 := centre - d * POLE_AT + r * POLE_AT
		pole_positions.append(pole2)
		var pole := Vector3(pole2.x, CityRoads.KERB_H, pole2.y)
		var face := Vector3(d.x, 0.0, d.y)                 # heads look back at the drivers
		var arm_dir := Vector3(-r.x, 0.0, -r.y)            # the arm reaches back over the lanes
		# pole: anchor-bolt base plate, tapered shaft, cap
		var base_xf := Transform3D(Basis.IDENTITY, pole)
		K.box(poles, Vector3(0.0, 0.02, 0.0), Vector3(0.5, 0.04, 0.5), base_xf)
		for bolt: int in 4:
			var a := float(bolt) / 4.0 * TAU + PI / 4.0
			K.lathe(poles, _v2([[0.0, 0.04], [0.025, 0.04], [0.025, 0.11], [0.025, 0.11], [0.0, 0.12]]), 6, base_xf.translated_local(Vector3(cos(a) * 0.19, 0.0, sin(a) * 0.19)))
		K.lathe(poles, _v2([[0.21, 0.04], [0.21, 0.04], [0.20, 0.10], [0.145, 7.0], [0.145, 7.0], [0.16, 7.02], [0.16, 7.08], [0.0, 7.12]]), 20, base_xf)
		# mast arm with a slight rise, clamped to the pole by a collar and braced by a tie
		var arm_len := POLE_AT + 1.65
		var a0 := pole + Vector3(0.0, ARM_HEIGHT, 0.0) + arm_dir * 0.14
		var a1 := pole + Vector3(0.0, ARM_HEIGHT + 0.35, 0.0) + arm_dir * arm_len
		var arm_pts: Array[Vector3] = K.bezier(a0, a0.lerp(a1, 0.5) + Vector3(0.0, 0.08, 0.0), a1, 8)
		var arm_r: Array[float] = []
		for k: int in arm_pts.size():
			arm_r.append(lerpf(0.13, 0.065, float(k) / (arm_pts.size() - 1)))
		K.tube(poles, arm_pts, arm_r, 14)
		K.lathe(poles, _v2([[0.0, ARM_HEIGHT - 0.25], [0.175, ARM_HEIGHT - 0.25], [0.175, ARM_HEIGHT + 0.25], [0.0, ARM_HEIGHT + 0.25]]), 16, base_xf)
		var tie_from := pole + Vector3(0.0, ARM_HEIGHT + 1.15, 0.0) + arm_dir * 0.15
		var tie_to := pole + Vector3(0.0, ARM_HEIGHT + 0.2, 0.0) + arm_dir * 3.2
		K.tube(poles, [tie_from, tie_to], [0.03, 0.025], 8)
		# two heads: over the approach lane and over the middle of the road
		for lateral: float in [CityRoads.LANE / 2.0, -1.4]:
			var t := (POLE_AT - lateral) / arm_len
			var on_arm := a0.lerp(a1, t)
			var head_c := on_arm - Vector3(0.0, HEAD_DROP, 0.0)
			K.tube(poles, [on_arm, head_c + Vector3(0.0, 0.52, 0.0)], [0.03, 0.03], 8, Transform3D.IDENTITY, false)
			_head(housing, border, lens_tools, group, Transform3D(Basis.looking_at(-face, Vector3.UP), head_c))
		# a third head on the pole, at eye level for the driver at the front of the queue
		var side_c := pole + Vector3(0.0, 3.4, 0.0) + face * 0.46
		_head(housing, border, lens_tools, group, Transform3D(Basis.looking_at(-face, Vector3.UP), side_c))
		K.box(poles, Vector3.ZERO, Vector3(0.08, 0.08, 0.2), Transform3D(Basis.looking_at(-face, Vector3.UP), pole + Vector3(0.0, 3.4, 0.0) + face * 0.17))
		# street-name blade on the arm: the name of the street the driver is about to cross
		var blade_at := a0.lerp(a1, 0.42) - Vector3(0.0, 0.42, 0.0)
		var blade_xf := Transform3D(Basis.looking_at(-face, Vector3.UP), blade_at)
		K.box(white, Vector3.ZERO, Vector3(1.62, 0.34, 0.01), blade_xf)
		K.box(housing, Vector3(0.0, 0.0, -0.008), Vector3(1.64, 0.36, 0.006), blade_xf)
		K.tube(poles, [blade_at + Vector3(-0.5 * arm_dir.x, 0.18, -0.5 * arm_dir.z), a0.lerp(a1, 0.42 - 0.5 / arm_len)], [0.012, 0.012], 5, Transform3D.IDENTITY, false)
		K.tube(poles, [blade_at + Vector3(0.5 * arm_dir.x, 0.18, 0.5 * arm_dir.z), a0.lerp(a1, 0.42 + 0.5 / arm_len)], [0.012, 0.012], 5, Transform3D.IDENTITY, false)
		var green_face := _blade_face(blade_xf, green)
		add_child(green_face)
		var street := str(names["ew"]) if group == "ns" else str(names["ns"])
		_label(street, blade_xf.translated_local(Vector3(0.0, -0.005, 0.012)), 46)
		var back_face := _blade_face(blade_xf.rotated_local(Vector3.UP, PI).translated_local(Vector3(0.0, 0.0, 0.004)), green)
		add_child(back_face)
		_label(street, blade_xf.rotated_local(Vector3.UP, PI).translated_local(Vector3(0.0, -0.005, 0.02)), 46)
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.21
		cyl.height = 7.0
		col.shape = cyl
		col.position = pole + Vector3(0.0, 3.5, 0.0)
		body.add_child(col)
	# pedestrian heads and push buttons: two per corner pole, each looking across its crossing
	for p2: Vector2 in pole_positions:
		var q := (p2 - centre).sign()
		var pole := Vector3(p2.x, CityRoads.KERB_H, p2.y)
		for k: int in 2:
			# k = 0: the crossing over the north-south street (people walk east-west), k = 1: the other one
			var look := Vector3(-q.x, 0.0, 0.0) if k == 0 else Vector3(0.0, 0.0, -q.y)
			var toward := Vector3(0.0, 0.0, q.y) if k == 0 else Vector3(q.x, 0.0, 0.0)
			var group := "ew" if k == 0 else "ns"
			var at := pole + Vector3(0.0, 2.75, 0.0) + toward * 0.22 + look * 0.05
			_ped_head(housing, ped_tools[group], Transform3D(Basis.looking_at(-look, Vector3.UP), at))
			var button := pole + Vector3(0.0, 1.05, 0.0) + toward * 0.18
			K.box(housing, Vector3.ZERO, Vector3(0.12, 0.17, 0.06), Transform3D(Basis.looking_at(-look, Vector3.UP), button))
			K.lathe(border, _v2([[0.0, 0.0], [0.025, 0.0], [0.025, 0.012], [0.0, 0.014]]), 12, Transform3D(Basis.looking_at(-look, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0), button + look * 0.03 + Vector3(0.0, -0.02, 0.0)))
	# materials and meshes
	var black := metal
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.78, 0.62, 0.06)
	yellow.roughness = 0.45
	_mesh("Poles", poles, black, true)
	_mesh("Housings", housing, black, true)
	_mesh("Borders", border, yellow, false)
	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.85, 0.86, 0.84)
	white_mat.roughness = 0.4
	_mesh("BladeBorders", white, white_mat, false)
	for key: String in lens_tools:
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.15
		mat.emission_enabled = true
		_lens[key] = mat
		_mesh("Lens_" + key, lens_tools[key], mat, false)
	var ped_shader := load("res://worlds/city/shaders/road_ped.gdshader") as Shader
	for g: String in ped_tools:
		var pm := ShaderMaterial.new()
		pm.shader = ped_shader
		_ped[g] = pm
		_mesh("Ped_" + g, ped_tools[g], pm, false)
	_apply(0.0)


func _process(delta: float) -> void:
	cycle_time = fposmod(cycle_time + delta, 2.0 * (GREEN + AMBER + ALL_RED))
	_apply(cycle_time)


## Aspect of every group at time t into the cycle.
static func aspects(t: float) -> Dictionary:
	var half := GREEN + AMBER + ALL_RED
	var out := {}
	for g: String in ["ew", "ns"]:
		var local := t if g == "ew" else t - half
		if local < 0.0:
			local += 2.0 * half
		var car := "red"
		if local < GREEN:
			car = "green"
		elif local < GREEN + AMBER:
			car = "amber"
		out[g] = car
		var ped := "hand"
		if local < WALK:
			ped = "walk"
		elif local < GREEN:
			ped = "flash" if fmod(local, 1.0) < 0.5 else "flash_off"
		out[g + "_ped"] = ped
	return out


func _apply(t: float) -> void:
	state = aspects(t)
	var colours := {"red": Color(1.0, 0.08, 0.03), "amber": Color(1.0, 0.45, 0.02), "green": Color(0.1, 1.0, 0.55)}
	for g: String in ["ew", "ns"]:
		for c: String in ["red", "amber", "green"]:
			var mat: StandardMaterial3D = _lens.get(g + "_" + c)
			if mat == null:
				continue
			var on: bool = state[g] == c
			var col: Color = colours[c]
			mat.albedo_color = col * (0.35 if on else 0.06)
			mat.emission = col
			mat.emission_energy_multiplier = 9.0 if on else 0.0
		var pm: ShaderMaterial = _ped.get(g)
		if pm != null:
			var p: String = state[g + "_ped"]
			pm.set_shader_parameter("walk", 1.0 if p == "walk" else 0.0)
			pm.set_shader_parameter("hand", 1.0 if p == "hand" or p == "flash" else 0.0)


## A three-section head: housing, tunnel visors, lenses, black backplate with a yellow reflective border.
## In the transform, +Z points at the driver.
func _head(housing: SurfaceTool, border: SurfaceTool, lenses: Dictionary, group: String, xf: Transform3D) -> void:
	K.box(housing, Vector3(0.0, 0.0, -0.13), Vector3(0.34, 1.02, 0.25), xf)
	K.box(housing, Vector3(0.0, 0.0, -0.265), Vector3(0.66, 1.34, 0.012), xf)
	# the yellow retroreflective border is a 5 cm frame on the front of the backplate only
	for s: float in [-1.0, 1.0]:
		K.box(border, Vector3(s * 0.305, 0.0, -0.257), Vector3(0.05, 1.34, 0.004), xf)
		K.box(border, Vector3(0.0, s * 0.645, -0.257), Vector3(0.56, 0.05, 0.004), xf)
	var colours := ["red", "amber", "green"]
	for k: int in 3:
		var y := 0.335 - k * 0.335
		var c := xf * Vector3(0.0, y, 0.0)
		var fwd := xf.basis * Vector3(0.0, 0.0, 1.0)
		# cap visor over each lens, open underneath so the light can be seen from the pavement
		var vis_xf := Transform3D(xf.basis, c)
		_visor(housing, vis_xf, 0.16, 0.2)
		var lens_xf := Transform3D(xf.basis * Basis(Vector3.RIGHT, PI / 2.0), c + fwd * 0.006)
		K.lathe(lenses[group + "_" + colours[k]], _v2([[0.145, 0.0], [0.11, 0.006], [0.0, 0.012]]), 20, lens_xf)


## A cap visor: three quarters of a thin tube along +Z, open at the bottom, inside and outside faces.
func _visor(st: SurfaceTool, xf: Transform3D, r: float, length: float) -> void:
	var seg := 12
	var a0 := deg_to_rad(-40.0)
	var a1 := deg_to_rad(220.0)
	for k: int in seg:
		var t0 := lerpf(a0, a1, float(k) / seg)
		var t1 := lerpf(a0, a1, float(k + 1) / seg)
		var d0 := Vector3(cos(t0), sin(t0), 0.0)
		var d1 := Vector3(cos(t1), sin(t1), 0.0)
		for side: float in [1.0, -1.0]:
			var rr := r if side > 0.0 else r - 0.006
			var p00 := xf * (d0 * rr)
			var p01 := xf * (d1 * rr)
			var p10 := xf * (d0 * rr + Vector3(0, 0, length))
			var p11 := xf * (d1 * rr + Vector3(0, 0, length))
			var n := (xf.basis * ((d0 + d1) * 0.5 * side)).normalized()
			for tri: Array in [[p00, p10, p11], [p00, p11, p01]]:
				var v: Array[Vector3] = [tri[0], tri[1], tri[2]]
				if (v[1] - v[0]).cross(v[2] - v[0]).dot(n) > 0.0:
					v = [v[0], v[2], v[1]]
				for q: Vector3 in v:
					st.set_normal(n)
					st.set_uv(Vector2.ZERO)
					st.add_vertex(q)


## A pedestrian head: housing with a hood and one lens showing the hand (left) and the walking person (right).
func _ped_head(housing: SurfaceTool, lens: SurfaceTool, xf: Transform3D) -> void:
	K.box(housing, Vector3(0.0, 0.0, -0.11), Vector3(0.46, 0.46, 0.2), xf)
	K.box(housing, Vector3(0.0, 0.235, 0.07), Vector3(0.46, 0.012, 0.16), xf)
	for s: float in [-1.0, 1.0]:
		K.box(housing, Vector3(s * 0.225, 0.12, 0.06), Vector3(0.012, 0.24, 0.14), xf)
	var a := xf * Vector3(-0.2, 0.2, 0.005)
	var b := xf * Vector3(0.2, 0.2, 0.005)
	var c := xf * Vector3(0.2, -0.2, 0.005)
	var d := xf * Vector3(-0.2, -0.2, 0.005)
	var n := xf.basis * Vector3(0.0, 0.0, 1.0)
	for tri: Array in [[a, Vector2(0, 0)], [c, Vector2(1, 1)], [b, Vector2(1, 0)], [a, Vector2(0, 0)], [d, Vector2(0, 1)], [c, Vector2(1, 1)]]:
		lens.set_normal(n)
		lens.set_uv(tri[1])
		lens.add_vertex(tri[0])


## The green face of a street-name blade. The material is set here: the faces share one name, so the engine
## renames all but the first as they are added, and a later lookup by name missed them (blades showed blank).
func _blade_face(xf: Transform3D, mat: Material) -> MeshInstance3D:
	var st := _st()
	K.box(st, Vector3(0.0, 0.0, 0.004), Vector3(1.56, 0.28, 0.006), xf)
	var mi := MeshInstance3D.new()
	mi.name = "BladeFace"
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


func _label(text: String, xf: Transform3D, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 0
	l.modulate = Color(0.92, 0.94, 0.92)
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.transform = xf
	add_child(l)
	_labels.append(l)


func _mesh(node_name: String, st: SurfaceTool, mat: Material, shadows: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _v2(points: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Array in points:
		out.append(Vector2(p[0], p[1]))
	return out
