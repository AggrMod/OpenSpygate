class_name FurnitureKit
extends RefCounted
## Mesh-making tools for the street furniture: lathes, swept tubes, lofts of rounded sections, boxes and
## flat plates, all added to a SurfaceTool through an optional transform. Front faces are wound the way
## the engine expects (clockwise seen from outside) and normals are set explicitly.


## Turn a profile of (radius, height) points round the Y axis. A repeated point makes a hard edge there.
static func lathe(st: SurfaceTool, profile: Array[Vector2], segments: int, xf: Transform3D = Transform3D.IDENTITY, phase: float = 0.0) -> void:
	var nb := xf.basis.inverse().transposed()
	var count := profile.size()
	# normals per segment in the (r, y) plane
	var seg_n: Array[Vector2] = []
	for k: int in count - 1:
		var d := profile[k + 1] - profile[k]
		seg_n.append(Vector2(d.y, -d.x).normalized() if d.length() > 1e-6 else Vector2.ZERO)
	for k: int in count - 1:
		var a := profile[k]
		var b := profile[k + 1]
		if a.distance_to(b) < 1e-6:
			continue
		var na := seg_n[k]
		if k > 0 and profile[k - 1].distance_to(a) > 1e-6 and seg_n[k - 1] != Vector2.ZERO:
			na = (seg_n[k - 1] + seg_n[k]).normalized()
		var nbv := seg_n[k]
		if k + 2 < count and profile[k + 2].distance_to(b) > 1e-6 and seg_n[k + 1] != Vector2.ZERO:
			nbv = (seg_n[k] + seg_n[k + 1]).normalized()
		for s: int in segments:
			var t0 := phase + float(s) / segments * TAU
			var t1 := phase + float(s + 1) / segments * TAU
			var c0 := Vector3(cos(t0), 0.0, sin(t0))
			var c1 := Vector3(cos(t1), 0.0, sin(t1))
			var p00 := c0 * a.x + Vector3(0, a.y, 0)
			var p01 := c1 * a.x + Vector3(0, a.y, 0)
			var p10 := c0 * b.x + Vector3(0, b.y, 0)
			var p11 := c1 * b.x + Vector3(0, b.y, 0)
			var n00 := c0 * na.x + Vector3(0, na.y, 0)
			var n01 := c1 * na.x + Vector3(0, na.y, 0)
			var n10 := c0 * nbv.x + Vector3(0, nbv.y, 0)
			var n11 := c1 * nbv.x + Vector3(0, nbv.y, 0)
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			_tri_n(st, xf, nb, [p00, p10, p11], [n00, n10, n11], [Vector2(u0, a.y), Vector2(u0, b.y), Vector2(u1, b.y)])
			_tri_n(st, xf, nb, [p00, p11, p01], [n00, n11, n01], [Vector2(u0, a.y), Vector2(u1, b.y), Vector2(u1, a.y)])


## Sweep a circle along a path of points, radius per point. Ends are capped when cap is true.
static func tube(st: SurfaceTool, path: Array[Vector3], radii: Array[float], segments: int, xf: Transform3D = Transform3D.IDENTITY, cap: bool = true) -> void:
	var nb := xf.basis.inverse().transposed()
	var count := path.size()
	if count < 2:
		return
	# parallel-transport frames so the tube does not twist
	var tangents: Array[Vector3] = []
	for k: int in count:
		var t: Vector3
		if k == 0:
			t = path[1] - path[0]
		elif k == count - 1:
			t = path[k] - path[k - 1]
		else:
			t = path[k + 1] - path[k - 1]
		tangents.append(t.normalized())
	var normal := tangents[0].cross(Vector3.UP)
	if normal.length() < 0.1:
		normal = tangents[0].cross(Vector3.RIGHT)
	normal = normal.normalized()
	var rings: Array = []
	for k: int in count:
		if k > 0:
			var axis := tangents[k - 1].cross(tangents[k])
			if axis.length() > 1e-6:
				var ang := tangents[k - 1].angle_to(tangents[k])
				normal = normal.rotated(axis.normalized(), ang)
		var binormal := tangents[k].cross(normal).normalized()
		var ring: Array[Vector3] = []
		var norms: Array[Vector3] = []
		for s: int in segments + 1:
			var a := float(s) / segments * TAU
			var dir := normal * cos(a) + binormal * sin(a)
			ring.append(path[k] + dir * radii[k])
			norms.append(dir)
		rings.append([ring, norms])
	for k: int in count - 1:
		var r0: Array[Vector3] = rings[k][0]
		var r1: Array[Vector3] = rings[k + 1][0]
		var n0: Array[Vector3] = rings[k][1]
		var n1: Array[Vector3] = rings[k + 1][1]
		for s: int in segments:
			var v0 := float(k) / (count - 1)
			var v1 := float(k + 1) / (count - 1)
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			_tri_n(st, xf, nb, [r0[s], r0[s + 1], r1[s + 1]], [n0[s], n0[s + 1], n1[s + 1]], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1)])
			_tri_n(st, xf, nb, [r0[s], r1[s + 1], r1[s]], [n0[s], n1[s + 1], n1[s]], [Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)])
	if cap:
		for end: int in [0, count - 1]:
			var ring: Array[Vector3] = rings[end][0]
			var n := tangents[end] * (-1.0 if end == 0 else 1.0)
			for s: int in segments:
				_tri_n(st, xf, nb, [path[end], ring[s], ring[s + 1]], [n, n, n], [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)])


## A loft of rounded-rectangle sections along local +Z. Each section: [z, half_width, half_height, y_centre].
## 'roundness' is the superellipse exponent (2 = ellipse, higher = squarer).
static func loft(st: SurfaceTool, sections: Array, segments: int, roundness: float, xf: Transform3D = Transform3D.IDENTITY, cap: bool = true) -> void:
	var nb := xf.basis.inverse().transposed()
	var rings: Array = []
	var norms: Array = []
	for sec: Array in sections:
		var ring: Array[Vector3] = []
		var nring: Array[Vector3] = []
		var hw: float = maxf(float(sec[1]), 1e-4)
		var hh: float = maxf(float(sec[2]), 1e-4)
		for s: int in segments + 1:
			var a := float(s) / segments * TAU
			var c := cos(a)
			var sn := sin(a)
			var ux := signf(c) * pow(absf(c), 2.0 / roundness)
			var uy := signf(sn) * pow(absf(sn), 2.0 / roundness)
			ring.append(Vector3(ux * hw, uy * hh + float(sec[3]), float(sec[0])))
			# gradient of the superellipse gives a smooth outward normal
			var gx := signf(ux) * pow(absf(ux), roundness - 1.0) / hw
			var gy := signf(uy) * pow(absf(uy), roundness - 1.0) / hh
			nring.append(Vector3(gx, gy, 0.0).normalized())
		rings.append(ring)
		norms.append(nring)
	for k: int in rings.size() - 1:
		var r0: Array[Vector3] = rings[k]
		var r1: Array[Vector3] = rings[k + 1]
		var n0: Array[Vector3] = norms[k]
		var n1: Array[Vector3] = norms[k + 1]
		for s: int in segments:
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			_tri_n(st, xf, nb, [r0[s], r1[s], r1[s + 1]], [n0[s], n1[s], n1[s + 1]], [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1)])
			_tri_n(st, xf, nb, [r0[s], r1[s + 1], r0[s + 1]], [n0[s], n1[s + 1], n0[s + 1]], [Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0)])
	if cap:
		for end: int in [0, rings.size() - 1]:
			var ring: Array[Vector3] = rings[end]
			var centre := Vector3.ZERO
			for p: Vector3 in ring:
				centre += p
			centre /= ring.size()
			var n := Vector3(0, 0, -1.0 if end == 0 else 1.0)
			for s: int in segments:
				_tri_flat(st, xf, nb, centre, ring[s], ring[s + 1], n)


## An axis-aligned box (optionally through a transform). 'bevel' trims the vertical edges.
static func box(st: SurfaceTool, centre: Vector3, size: Vector3, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var nb := xf.basis.inverse().transposed()
	var h := size / 2.0
	var faces: Array = [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := centre + n * h
		var uu := u * h
		var vv := v * h
		var a := c - uu - vv
		var b := c - uu + vv
		var cc := c + uu + vv
		var d := c + uu - vv
		_tri_flat(st, xf, nb, a, b, cc, n)
		_tri_flat(st, xf, nb, a, cc, d, n)


## A flat polygon (in the local XY plane, facing +Z) extruded by 'depth' toward -Z, with side walls.
static func plate(st: SurfaceTool, poly: PackedVector2Array, depth: float, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var nb := xf.basis.inverse().transposed()
	var centre := Vector2.ZERO
	for p: Vector2 in poly:
		centre += p
	centre /= poly.size()
	var n := poly.size()
	for k: int in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		_tri_flat(st, xf, nb, Vector3(centre.x, centre.y, 0.0), Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), Vector3.BACK)
		_tri_flat(st, xf, nb, Vector3(centre.x, centre.y, -depth), Vector3(b.x, b.y, -depth), Vector3(a.x, a.y, -depth), Vector3.FORWARD)
		var side := Vector3(b.y - a.y, -(b.x - a.x), 0.0).normalized()
		if side.dot(Vector3(a.x - centre.x, a.y - centre.y, 0.0)) < 0.0:
			side = -side
		_tri_flat(st, xf, nb, Vector3(a.x, a.y, 0.0), Vector3(a.x, a.y, -depth), Vector3(b.x, b.y, -depth), side)
		_tri_flat(st, xf, nb, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, -depth), Vector3(b.x, b.y, 0.0), side)


## A rounded rectangle outline in the XY plane, for plates.
static func rounded_rect(hw: float, hh: float, r: float, steps: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(hw - r, hh - r), Vector2(-hw + r, hh - r), Vector2(-hw + r, -hh + r), Vector2(hw - r, -hh + r)]
	for c: int in 4:
		for s: int in steps + 1:
			var a := (float(c) + float(s) / steps) * PI * 0.5
			out.append(corners[c] + Vector2(cos(a), sin(a)) * r)
	return out


## A regular polygon (octagon for a stop sign) in the XY plane.
static func ngon(sides: int, radius: float, phase: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k: int in sides:
		var a := phase + float(k) / sides * TAU
		out.append(Vector2(cos(a), sin(a)) * radius)
	return out


## Points along a quadratic curve, for bent arms.
static func bezier(a: Vector3, b: Vector3, c: Vector3, steps: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k: int in steps + 1:
		var t := float(k) / steps
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return out


static func _centre_of(r0: Array[Vector3], r1: Array[Vector3]) -> Vector3:
	var c := Vector3.ZERO
	for p: Vector3 in r0:
		c += p
	for p: Vector3 in r1:
		c += p
	return c / float(r0.size() + r1.size())


static func _tri_auto(st: SurfaceTool, xf: Transform3D, nb: Basis, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	var mid := (a + b + c) / 3.0
	var out := mid - inside
	out.z = 0.0 if absf(out.x) + absf(out.y) > 1e-4 else out.z
	if n.dot(out) < 0.0:
		n = -n
	_tri_flat(st, xf, nb, a, b, c, n.normalized())


## One triangle with a single normal; wound clockwise as seen from the side the normal points to.
static func _tri_flat(st: SurfaceTool, xf: Transform3D, nb: Basis, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var verts: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts = [a, c, b]
	var wn := (nb * n).normalized()
	for v: Vector3 in verts:
		st.set_normal(wn)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(xf * v)


## One triangle with per-vertex normals; the winding follows the average normal.
static func _tri_n(st: SurfaceTool, xf: Transform3D, nb: Basis, p: Array, n: Array, uv: Array) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-14:
		return
	var avg: Vector3 = (n[0] as Vector3) + (n[1] as Vector3) + (n[2] as Vector3)
	var order: Array[int] = [0, 1, 2]
	if face.dot(avg) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		st.set_normal((nb * (n[i] as Vector3)).normalized())
		st.set_uv(uv[i])
		st.add_vertex(xf * (p[i] as Vector3))
