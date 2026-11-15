class_name FurnitureProps
extends RefCounted
## The street furniture of Calder, modelled in code. Every mesh has its origin on the pavement at the foot of
## the object, +Y up and local +Z pointing toward the carriageway. Dimensions are real ones in metres.
## Each builder returns an ArrayMesh with one surface per material, in the order given by its doc comment.

const K := preload("res://worlds/city/furniture_kit.gd")

## Height of the lamp's light-emitting lens, and how far out over the road it reaches from the pole.
const LAMP_LENS: Vector3 = Vector3(0.0, 8.72, 2.12)


## A street lamp: cast base shroud, tapered round pole bending into a davit arm, flat LED luminaire.
## Surfaces: 0 painted metal, 1 luminaire housing, 2 lens.
static func lamp() -> ArrayMesh:
	var metal := _st()
	# cast base shroud with a plinth and a collar
	K.lathe(metal, _v2([
		[0.0, 0.0], [0.24, 0.0], [0.24, 0.05], [0.24, 0.05], [0.215, 0.075], [0.20, 0.11], [0.20, 0.11],
		[0.185, 0.13], [0.15, 0.52], [0.15, 0.52], [0.168, 0.54], [0.168, 0.60], [0.168, 0.60], [0.15, 0.62],
		[0.115, 0.64], [0.115, 0.64], [0.0, 0.64],
	]), 24)
	# tapered pole
	K.lathe(metal, _v2([[0.106, 0.62], [0.066, 8.22]]), 18)
	# the davit: the pole bends over in a sweep and reaches out over the road
	var arm: Array[Vector3] = []
	arm.append(Vector3(0.0, 8.1, 0.0))
	arm.append_array(K.bezier(Vector3(0.0, 8.22, 0.0), Vector3(0.0, 8.86, 0.0), Vector3(0.0, 8.86, 0.62), 10))
	arm.append(Vector3(0.0, 8.83, 1.72))
	var radii: Array[float] = []
	for k: int in arm.size():
		radii.append(lerpf(0.066, 0.042, float(k) / (arm.size() - 1)))
	K.tube(metal, arm, radii, 14)
	# luminaire: a flat, rounded LED head
	var housing := _st()
	K.loft(housing, [
		[1.66, 0.045, 0.04, 8.83], [1.74, 0.10, 0.055, 8.82], [1.86, 0.16, 0.066, 8.805],
		[2.10, 0.175, 0.068, 8.80], [2.32, 0.165, 0.06, 8.80], [2.44, 0.12, 0.045, 8.805], [2.48, 0.05, 0.025, 8.81],
	], 28, 3.2)
	# cooling fins on top
	for f: int in 5:
		var z := 1.96 + f * 0.075
		K.box(housing, Vector3(0.0, 8.875, z), Vector3(0.22, 0.018, 0.012))
	var lens := _st()
	var xf := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 8.728, 2.13))
	K.plate(lens, K.rounded_rect(0.125, 0.2, 0.05), 0.004, xf)
	return _commit([metal, housing, lens])


## A dry-barrel fire hydrant with two hose outlets and a pumper outlet facing the street.
## Surfaces: 0 body paint, 1 caps and nuts.
static func hydrant() -> ArrayMesh:
	var body := _st()
	K.lathe(body, _v2([
		[0.0, 0.0], [0.165, 0.0], [0.165, 0.035], [0.165, 0.035], [0.13, 0.05], [0.112, 0.07], [0.105, 0.09],
		[0.10, 0.50], [0.10, 0.50], [0.128, 0.515], [0.128, 0.555], [0.128, 0.555], [0.112, 0.57], [0.117, 0.61],
		[0.10, 0.69], [0.07, 0.75], [0.04, 0.78], [0.04, 0.78], [0.0, 0.78],
	]), 24)
	# outlets
	K.tube(body, [Vector3(0.0, 0.40, 0.05), Vector3(0.0, 0.40, 0.17)], [0.068, 0.068], 16)
	for s: float in [-1.0, 1.0]:
		K.tube(body, [Vector3(s * 0.05, 0.44, 0.0), Vector3(s * 0.165, 0.44, 0.0)], [0.046, 0.046], 14)
	var caps := _st()
	K.tube(caps, [Vector3(0.0, 0.40, 0.165), Vector3(0.0, 0.40, 0.215)], [0.08, 0.08], 6)
	for s: float in [-1.0, 1.0]:
		K.tube(caps, [Vector3(s * 0.16, 0.44, 0.0), Vector3(s * 0.20, 0.44, 0.0)], [0.056, 0.056], 6)
	# pentagon operating nut and bonnet bolts
	K.lathe(caps, _v2([[0.0, 0.775], [0.032, 0.775], [0.032, 0.83], [0.032, 0.83], [0.0, 0.83]]), 5)
	for b: int in 8:
		var a := float(b) / 8.0 * TAU
		K.box(caps, Vector3(cos(a) * 0.12, 0.565, sin(a) * 0.12), Vector3(0.022, 0.03, 0.022))
	return _commit([body, caps])


## A cast steel bollard with a domed top and a raised band.
## Surfaces: 0 painted metal.
static func bollard() -> ArrayMesh:
	var m := _st()
	K.lathe(m, _v2([
		[0.0, 0.0], [0.118, 0.0], [0.118, 0.03], [0.118, 0.03], [0.108, 0.05], [0.10, 0.08], [0.10, 0.80],
		[0.10, 0.80], [0.114, 0.815], [0.114, 0.855], [0.114, 0.855], [0.10, 0.87], [0.093, 0.93],
		[0.07, 0.975], [0.035, 0.995], [0.0, 1.0],
	]), 22)
	return _commit([m])


## A litter bin: steel slats round a dark liner, a ring at the top and a domed lid on four short posts.
## Surfaces: 0 painted metal, 1 liner.
static func bin() -> ArrayMesh:
	var m := _st()
	K.lathe(m, _v2([[0.0, 0.0], [0.27, 0.0], [0.27, 0.07], [0.27, 0.07], [0.24, 0.07]]), 24)
	var slats := 30
	for s: int in slats:
		var a := float(s) / slats * TAU
		var xf := Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.268, 0.0, sin(a) * 0.268))
		K.box(m, Vector3(0.0, 0.46, 0.0), Vector3(0.012, 0.78, 0.034), xf)
	for y: float in [0.30, 0.62]:
		K.lathe(m, _v2([[0.274, y], [0.282, y], [0.282, y + 0.025], [0.274, y + 0.025]]), 24)
	K.lathe(m, _v2([[0.25, 0.84], [0.288, 0.84], [0.288, 0.88], [0.288, 0.88], [0.25, 0.88]]), 24)
	for p: int in 4:
		var a2 := float(p) / 4.0 * TAU + 0.4
		K.box(m, Vector3(cos(a2) * 0.26, 0.92, sin(a2) * 0.26), Vector3(0.025, 0.08, 0.025))
	K.lathe(m, _v2([[0.0, 0.955], [0.30, 0.955], [0.30, 0.975], [0.30, 0.975], [0.25, 1.02], [0.15, 1.055], [0.0, 1.065]]), 24)
	var liner := _st()
	K.lathe(liner, _v2([[0.245, 0.07], [0.245, 0.70], [0.245, 0.70], [0.0, 0.70]]), 20)
	return _commit([m, liner])


## A pay-and-display parking station: plinth, cabinet, sloping head with a screen, solar panel on top.
## Surfaces: 0 cabinet paint, 1 screen and keypad glass, 2 solar panel.
static func pay_station() -> ArrayMesh:
	var m := _st()
	K.box(m, Vector3(0.0, 0.04, 0.0), Vector3(0.42, 0.08, 0.30))
	K.box(m, Vector3(0.0, 0.66, 0.0), Vector3(0.34, 1.16, 0.24))
	var head_xf := Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.0, 1.38, 0.02))
	K.box(m, Vector3(0.0, 0.0, 0.0), Vector3(0.37, 0.34, 0.27), head_xf)
	K.box(m, Vector3(0.0, 1.58, -0.02), Vector3(0.36, 0.04, 0.30))
	var glass := _st()
	K.box(glass, Vector3(0.0, 0.05, 0.137), Vector3(0.24, 0.14, 0.004), head_xf)
	K.box(glass, Vector3(0.0, -0.09, 0.137), Vector3(0.16, 0.08, 0.004), head_xf)
	K.box(glass, Vector3(0.0, 0.92, 0.121), Vector3(0.12, 0.05, 0.004))
	var solar := _st()
	var sol_xf := Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.0, 1.66, -0.02))
	K.box(solar, Vector3.ZERO, Vector3(0.34, 0.012, 0.30), sol_xf)
	return _commit([m, glass, solar])


## A stop sign on a square steel post, face toward +Z: white border, red face (text added separately).
## Surfaces: 0 galvanised post and sign back, 1 white, 2 red.
static func stop_sign() -> ArrayMesh:
	var post := _st()
	K.box(post, Vector3(0.0, 1.45, -0.03), Vector3(0.05, 2.9, 0.05))
	var back_xf := Transform3D(Basis.IDENTITY, Vector3(0.0, 2.45, 0.0))
	K.plate(post, K.ngon(8, 0.41, PI / 8.0), 0.004, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.45, -0.001)))
	var white := _st()
	K.plate(white, K.ngon(8, 0.405, PI / 8.0), 0.001, back_xf.translated_local(Vector3(0, 0, 0.002)))
	var red := _st()
	K.plate(red, K.ngon(8, 0.375, PI / 8.0), 0.001, back_xf.translated_local(Vector3(0, 0, 0.004)))
	return _commit([post, white, red])


## Two street-name blades crossed at right angles, for the top of a sign post (no post).
## Surfaces: 0 green face, 1 white border.
static func name_blades(height: float) -> ArrayMesh:
	var green := _st()
	var white := _st()
	for k: int in 2:
		var xf := Transform3D(Basis(Vector3.UP, k * PI / 2.0), Vector3(0.0, height + k * 0.26, 0.0))
		K.box(white, Vector3(0.0, 0.0, 0.0), Vector3(1.16, 0.23, 0.006), xf)
		K.box(green, Vector3(0.0, 0.0, 0.0), Vector3(1.12, 0.19, 0.012), xf)
	return _commit([green, white])


static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(tools: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in tools:
		st.generate_tangents()
		st.commit(mesh)
	return mesh


static func _v2(points: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Array in points:
		out.append(Vector2(p[0], p[1]))
	return out
