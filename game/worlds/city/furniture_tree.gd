class_name FurnitureTree
extends RefCounted
## A young street tree grown in code: a straight trunk clear to 2.6 m (people walk under it), a leader,
## scaffold branches set round it on the golden angle, side shoots, and leaf clusters of crossed cards at
## the outer ends. About 8 m tall with a 5 m crown. Surfaces: 0 bark, 1 leaves.
## Leaf cards carry UV 0..1 across the card and UV2.x = a random number for the leaf shader.

const K := preload("res://worlds/city/furniture_kit.gd")
const CLEAR_TRUNK: float = 2.6


static func build(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	# trunk and leader, with a slight wander
	var lean := Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))
	var trunk: Array[Vector3] = []
	var radii: Array[float] = []
	var top := 7.4
	for k: int in 13:
		var t := float(k) / 12.0
		var y := t * top
		var wob := Vector3(sin(t * 7.0 + seed_value) * 0.04, 0.0, cos(t * 5.0 + seed_value) * 0.04)
		trunk.append(Vector3(0.0, y, 0.0) + lean * t * t * 3.0 + wob * t)
		radii.append(lerpf(0.13, 0.025, pow(t, 0.8)) + (0.035 if k == 0 else 0.0))
	K.tube(bark, trunk, radii, 12)
	var tips: Array[Vector3] = [trunk[trunk.size() - 1]]
	var inner: Array[Vector3] = []
	# scaffold branches
	var count := 9
	var golden := 2.39996
	var az0 := rng.randf() * TAU
	for b: int in count:
		var t := float(b) / (count - 1)
		var y := lerpf(CLEAR_TRUNK, 6.2, t) + rng.randf_range(-0.15, 0.15)
		var at := _on_trunk(trunk, y)
		var az := az0 + b * golden + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(az), 0.0, sin(az))
		var rise := deg_to_rad(lerpf(38.0, 62.0, t) + rng.randf_range(-8.0, 8.0))
		var length := lerpf(2.7, 1.5, t) * rng.randf_range(0.85, 1.15)
		var dir := (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
		var tip := at + dir * length + Vector3.UP * 0.25 * length
		var mid := at + dir * length * 0.55
		var path := K.bezier(at, mid, tip, 7)
		var r0 := lerpf(0.065, 0.035, t)
		var rr: Array[float] = []
		for k: int in path.size():
			rr.append(lerpf(r0, 0.012, float(k) / (path.size() - 1)))
		K.tube(bark, path, rr, 7)
		tips.append(tip)
		# foliage along the branch as well as at its end, so the crown is not hollow round a bare fork
		inner.append(path[int(0.55 * (path.size() - 1))] + Vector3.UP * 0.25)
		# side shoots
		for s: int in 3:
			var f := rng.randf_range(0.45, 0.85)
			var base := path[int(f * (path.size() - 1))]
			var side := dir.cross(Vector3.UP).normalized() * (1.0 if s % 2 == 0 else -1.0)
			var sdir := (dir * 0.6 + side * 0.6 + Vector3.UP * rng.randf_range(0.1, 0.5)).normalized()
			var slen := rng.randf_range(0.7, 1.3) * (1.0 - t * 0.3)
			var stip := base + sdir * slen
			K.tube(bark, [base, base.lerp(stip, 0.5) + Vector3.UP * 0.08, stip], [r0 * 0.4, r0 * 0.25, 0.008], 5, Transform3D.IDENTITY, false)
			tips.append(stip)
	# leaf clusters: crossed cards round every tip, and a few along the leader to fill the crown
	for k: int in 6:
		tips.append(_on_trunk(trunk, lerpf(4.6, 7.2, float(k) / 5.0)) + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5)))
	for tip: Vector3 in tips:
		var cards := 5 if tip.y > 4.0 else 3
		for c: int in cards:
			var size := rng.randf_range(0.95, 1.35)
			var centre := tip + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.4), rng.randf_range(-0.5, 0.5))
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(-0.9, 0.9)))
			_card(leaves, centre, basis, size, rng.randf())
	for at: Vector3 in inner:
		for c: int in 3:
			var size := rng.randf_range(0.9, 1.2)
			var centre := at + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.35, 0.35))
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(-0.9, 0.9)))
			_card(leaves, centre, basis, size, rng.randf())
	var mesh := ArrayMesh.new()
	bark.generate_tangents()
	bark.commit(mesh)
	leaves.commit(mesh)
	return mesh


static func _on_trunk(trunk: Array[Vector3], y: float) -> Vector3:
	for k: int in trunk.size() - 1:
		if trunk[k + 1].y >= y:
			var t := (y - trunk[k].y) / maxf(trunk[k + 1].y - trunk[k].y, 1e-4)
			return trunk[k].lerp(trunk[k + 1], t)
	return trunk[trunk.size() - 1]


## A square card of leaves, both sides; the normal leans outward from the crown so it lights like foliage.
static func _card(st: SurfaceTool, centre: Vector3, basis: Basis, size: float, rnd: float) -> void:
	var h := size * 0.5
	var u := basis.x * h
	var v := basis.y * h
	var corners: Array[Vector3] = [centre - u - v, centre + u - v, centre + u + v, centre - u + v]
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var outward := (centre - Vector3(0.0, 5.0, 0.0)).normalized()
	var n := (basis.z * 0.35 + outward * 0.65).normalized()
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		for i: int in tri:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.set_uv2(Vector2(rnd, 0.0))
			st.add_vertex(corners[i])
