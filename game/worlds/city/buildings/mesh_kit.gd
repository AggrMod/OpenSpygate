class_name CityMeshKit
extends RefCounted
## Collects the triangles of one building surface (one material, one draw call).
## Faces get UVs in metres projected on their own plane, so a shader's brick or panel
## pattern runs on unbroken across neighbouring pieces of the same wall.
## UV2.x carries the material id of the opaque shader, UV2.y a weathering gradient.
## Window glass instead carries room data in CUSTOM0 and CUSTOM1 (see building_glass.gdshader).

var verts: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var tangents: PackedFloat32Array = PackedFloat32Array()
var colors: PackedColorArray = PackedColorArray()
var uvs: PackedVector2Array = PackedVector2Array()
var uv2s: PackedVector2Array = PackedVector2Array()
var custom0: PackedFloat32Array = PackedFloat32Array()
var custom1: PackedFloat32Array = PackedFloat32Array()
var indices: PackedInt32Array = PackedInt32Array()
var glass: bool = false

## Faces of a box, for skipping hidden ones.
const F_FRONT: int = 1
const F_BACK: int = 2
const F_LEFT: int = 4
const F_RIGHT: int = 8
const F_TOP: int = 16
const F_BOTTOM: int = 32
const F_ALL: int = 63


func _init(is_glass: bool = false) -> void:
	glass = is_glass


func triangle_count() -> int:
	return indices.size() / 3


func is_empty() -> bool:
	return indices.is_empty()


## A flat quad: corners o, o+u, o+u+v, o+v. It faces u x v. g0/g1 is the weathering gradient
## at the bottom (o side) and top (o+v side).
func quad(o: Vector3, u: Vector3, v: Vector3, col: Color, mat: float, g0: float = 0.0, g1: float = 0.0) -> void:
	var n := u.cross(v).normalized()
	if n == Vector3.ZERO:
		return
	var uh := u.normalized()
	var vh := v.normalized()
	var base := verts.size()
	var corners: Array[Vector3] = [o, o + u, o + u + v, o + v]
	var grads: Array[float] = [g0, g0, g1, g1]
	for i: int in 4:
		var p: Vector3 = corners[i]
		verts.append(p)
		normals.append(n)
		tangents.append_array([uh.x, uh.y, uh.z, 1.0])
		colors.append(col)
		uvs.append(Vector2(p.dot(uh), p.dot(vh)))
		uv2s.append(Vector2(mat, grads[i]))
	indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


## A window pane for the interior shader. UV runs 0..w, 0..h in metres across the pane.
## room: x seed, y room depth, z kind, w sill height of the pane above the room floor.
## extra: x storey height, y room margin either side, z blind override (-1 none), w unused.
func pane(o: Vector3, u: Vector3, v: Vector3, room: Vector4, extra: Vector4, col: Color = Color.WHITE) -> void:
	var n := u.cross(v).normalized()
	var uh := u.normalized()
	var w := u.length()
	var h := v.length()
	var base := verts.size()
	var corners: Array[Vector3] = [o, o + u, o + u + v, o + v]
	var local: Array[Vector2] = [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	for i: int in 4:
		verts.append(corners[i])
		normals.append(n)
		tangents.append_array([uh.x, uh.y, uh.z, 1.0])
		colors.append(col)
		uvs.append(local[i])
		uv2s.append(Vector2(w, h))
		custom0.append_array([room.x, room.y, room.z, room.w])
		custom1.append_array([extra.x, extra.y, extra.z, extra.w])
	indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


## An axis-aligned box in building space.
func box(lo: Vector3, hi: Vector3, col: Color, mat: float, faces: int = F_ALL, g0: float = 0.0, g1: float = 0.0) -> void:
	var s := hi - lo
	if s.x <= 0.0 or s.y <= 0.0 or s.z <= 0.0:
		return
	var X := Vector3(s.x, 0, 0)
	var Y := Vector3(0, s.y, 0)
	var Z := Vector3(0, 0, s.z)
	if faces & F_FRONT:     # +Z
		quad(Vector3(lo.x, lo.y, hi.z), X, Y, col, mat, g0, g1)
	if faces & F_BACK:      # -Z
		quad(Vector3(hi.x, lo.y, lo.z), -X, Y, col, mat, g0, g1)
	if faces & F_LEFT:      # -X
		quad(Vector3(lo.x, lo.y, lo.z), Z, Y, col, mat, g0, g1)
	if faces & F_RIGHT:     # +X
		quad(Vector3(hi.x, lo.y, hi.z), -Z, Y, col, mat, g0, g1)
	if faces & F_TOP:
		quad(Vector3(lo.x, hi.y, hi.z), X, -Z, col, mat)
	if faces & F_BOTTOM:
		quad(Vector3(lo.x, lo.y, lo.z), X, Z, col, mat)


## A box with any orientation: centre c, half-axes ax, ay, az (must be right-handed).
func obox(c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, col: Color, mat: float) -> void:
	var o := c - ax - ay - az
	quad(o + az * 2.0, ax * 2.0, ay * 2.0, col, mat)                  # +az
	quad(o + ax * 2.0, -ax * 2.0, ay * 2.0, col, mat)                 # -az
	quad(o, az * 2.0, ay * 2.0, col, mat)                             # -ax
	quad(o + ax * 2.0 + az * 2.0, -az * 2.0, ay * 2.0, col, mat)      # +ax
	quad(o + ay * 2.0 + az * 2.0, ax * 2.0, -az * 2.0, col, mat)      # +ay
	quad(o, ax * 2.0, az * 2.0, col, mat)                             # -ay


## An upright cylinder (prism) from base centre c, radius r, height h.
func cylinder(c: Vector3, r: float, h: float, sides: int, col: Color, mat: float, cap_top: bool = true) -> void:
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		quad(p1, p0 - p1, Vector3(0, h, 0), col, mat)
	if cap_top:
		cone(c + Vector3(0, h, 0), r, 0.0, sides, col, mat)


## A cone or flat disc on top of a cylinder: rim at c, apex at c + (0, rise, 0).
func cone(c: Vector3, r: float, rise: float, sides: int, col: Color, mat: float) -> void:
	var apex := c + Vector3(0, rise, 0)
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var n := (p0 - apex).cross(p1 - apex).normalized()
		if n.y < 0.0:
			n = -n
		var uh := (p1 - p0).normalized()
		var base := verts.size()
		for p: Vector3 in [apex, p0, p1]:
			verts.append(p)
			normals.append(n)
			tangents.append_array([uh.x, uh.y, uh.z, 1.0])
			colors.append(col)
			uvs.append(Vector2(p.x + p.z, p.y))
			uv2s.append(Vector2(mat, 0.0))
		indices.append_array([base, base + 1, base + 2])


## Raised lettering from a TextMesh, laid on a plane: centre c, right axis r, normal n.
## Scaled to fit max_w by max_h metres. Returns the width used.
func text(s: String, c: Vector3, r: Vector3, n: Vector3, max_w: float, max_h: float, depth: float, col: Color, mat: float) -> float:
	var tm := TextMesh.new()
	tm.text = s
	tm.font_size = 32
	tm.pixel_size = 0.01
	tm.depth = 0.0
	tm.curve_step = 3.0
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arrays := tm.get_mesh_arrays()
	if arrays.is_empty():
		return 0.0
	var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var pi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if pv.is_empty():
		return 0.0
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Vector3 in pv:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	var size := mx - mn
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0
	var k := minf(max_w / size.x, max_h / size.y)
	var mid := (mn + mx) * 0.5
	var up := n.cross(r).normalized()
	# front faces only: TextMesh with depth 0 gives one flat face per glyph; we lift it off the board.
	var base := verts.size()
	for p: Vector3 in pv:
		var q := c + r * ((p.x - mid.x) * k) + up * ((p.y - mid.y) * k) + n * depth
		verts.append(q)
		normals.append(n)
		tangents.append_array([r.x, r.y, r.z, 1.0])
		colors.append(col)
		uvs.append(Vector2(q.dot(r), q.dot(up)))
		uv2s.append(Vector2(mat, 1.0))
	# TextMesh front faces are wound for +Z; keep the order, the plane basis keeps handedness.
	for i: int in pi.size():
		indices.append(base + pi[i])
	return size.x * k


func commit(mesh: ArrayMesh, material: Material) -> void:
	if indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var flags := 0
	if glass:
		arrays[Mesh.ARRAY_CUSTOM0] = custom0
		arrays[Mesh.ARRAY_CUSTOM1] = custom1
		flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## Sum of vertex positions and count, for the determinism check.
func fingerprint() -> Vector4:
	var s := Vector3.ZERO
	for p: Vector3 in verts:
		s += p
	return Vector4(s.x, s.y, s.z, float(verts.size()))
