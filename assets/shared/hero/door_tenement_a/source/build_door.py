"""Builds the door (art bible, section 11): geometry pass.

    blender -b -P build_door.py -- <asset_dir> [--clay]

Writes source/door_tenement_a.blend and, with --clay, review/clay_*.png.
Units are metres. X across the door, Y through it (side A, where the player arrives, is -Y), Z up.
"""
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
ASSET = ARGS[0]
CLAY = "--clay" in ARGS
random.seed(1961)

# ---- dimensions (art bible 11) ---------------------------------------------------------------
LEAF_W, LEAF_H, LEAF_T = 0.92, 2.12, 0.045
SILL_H = 0.018                      # threshold height
GAP_BOTTOM, GAP_SIDE = 0.008, 0.003
Z0 = SILL_H + GAP_BOTTOM            # leaf bottom
Z1 = Z0 + LEAF_H                    # leaf top
HX = LEAF_W / 2
HT = LEAF_T / 2
STILE, MUNTIN = 0.11, 0.09
RAIL_BOTTOM, RAIL_LOCK, RAIL_FRIEZE, RAIL_TOP = 0.22, 0.16, 0.10, 0.11
LOCK_Z = Z0 + 1.02                  # centre of the lock rail
FRIEZE_Z = Z0 + 1.72
JAMB_W, JAMB_D = 0.104, 0.16
OPEN_X = HX + GAP_SIDE              # inner face of the jambs
HEAD_Z = Z1 + GAP_SIDE              # underside of the head
HANDLE_X, HANDLE_Z = -HX + 0.058, Z0 + 1.05
BEVEL = 0.0012


TAG = {"horiz": 0.0, "bare": 0.0}   # read by Part.add: grain direction and unpainted wood


class Part:
    """Collects raw geometry for one object."""
    def __init__(self, name, material):
        self.name, self.material = name, material
        self.verts, self.faces, self.tags = [], [], []

    def add(self, verts, faces):
        o = len(self.verts)
        self.verts.extend(verts)
        self.tags.extend([(TAG["horiz"], TAG["bare"])] * len(verts))
        self.faces.extend([tuple(i + o for i in f) for f in faces])

    def add_bm(self, bm):
        bm.verts.index_update()
        self.add([v.co.copy() for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
        bm.free()

    def build(self, parent=None, origin=None):
        me = bpy.data.meshes.new(self.name)
        bm = bmesh.new()
        lh, lb = bm.verts.layers.float.new("horiz"), bm.verts.layers.float.new("bare")
        vs = []
        for co, (h, b) in zip(self.verts, self.tags):
            v = bm.verts.new(co); v[lh] = h; v[lb] = b; vs.append(v)
        for f in self.faces:
            try:
                bm.faces.new([vs[i] for i in f])
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.calc_face_angle(0.0) < math.radians(32)
        for f in bm.faces:
            f.smooth = True
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        mat = bpy.data.materials.get(self.material) or bpy.data.materials.new(self.material)
        me.materials.append(mat)
        if origin is not None:
            o = Vector(origin)
            me.transform(Matrix.Translation(-o))
            ob.location = o
        if parent is not None:
            ob.parent = parent
            ob.matrix_parent_inverse = parent.matrix_world.inverted()
        return ob


# ---- primitives --------------------------------------------------------------------------------
def box(lo, hi, bevel=BEVEL, segs=2):
    lo, hi = Vector(lo), Vector(hi)
    lo, hi = Vector(map(min, lo, hi)), Vector(map(max, lo, hi))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    size, mid = hi - lo, (lo + hi) / 2
    for v in bm.verts:
        v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) + mid
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=segs,
                        profile=0.5, affect='EDGES')
    return bm


def plate(cx, cz, w, h, y0, t, out, corner, edge=0.0008):
    """Rounded-corner plate lying on a door face. y0 is the face, out is -1 (side A) or +1 (side B)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * w + cx, v.co.y * t + y0 + out * t / 2, v.co.z * h + cz))
    vert_edges = [e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) > t * 0.5]
    bmesh.ops.bevel(bm, geom=vert_edges, offset=corner, segments=6, profile=0.5, affect='EDGES')
    front = [e for e in bm.edges if all(abs(v.co.y - (y0 + out * t)) < 1e-6 for v in e.verts)]
    bmesh.ops.bevel(bm, geom=front, offset=edge, segments=2, profile=0.5, affect='EDGES')
    return bm


def sweep_closed(corners, dirs, profile, place):
    """Sweep a profile round a closed loop of mitred corners.
    profile: [(d, h)], place(corner, dir, d, h) -> Vector."""
    verts, faces = [], []
    n, m = len(corners), len(profile)
    for c, dr in zip(corners, dirs):
        for d, h in profile:
            verts.append(place(c, dr, d, h))
    for i in range(n):
        j = (i + 1) % n
        for k in range(m - 1):
            faces.append((i * m + k, j * m + k, j * m + k + 1, i * m + k + 1))
    return verts, faces


def sweep_open(corners, dirs, profile, place):
    verts, faces = [], []
    n, m = len(corners), len(profile)
    for c, dr in zip(corners, dirs):
        for d, h in profile:
            verts.append(place(c, dr, d, h))
    for i in range(n - 1):
        for k in range(m):
            k2 = (k + 1) % m
            faces.append((i * m + k, (i + 1) * m + k, (i + 1) * m + k2, i * m + k2))
    faces.append(tuple(range(m)))
    faces.append(tuple((n - 1) * m + k for k in reversed(range(m))))
    return verts, faces


def lathe(origin, axis, profile, segs=24):
    """Revolve [(radius, distance along axis)] round an axis."""
    origin, axis = Vector(origin), Vector(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized(); v = axis.cross(u)
    verts, faces = [], []
    for r, d in profile:
        for s in range(segs):
            a = 2 * math.pi * s / segs
            verts.append(origin + axis * d + (u * math.cos(a) + v * math.sin(a)) * r)
    for i in range(len(profile) - 1):
        for s in range(segs):
            s2 = (s + 1) % segs
            faces.append((i * segs + s, i * segs + s2, (i + 1) * segs + s2, (i + 1) * segs + s))
    if profile[0][0] > 1e-6:
        faces.append(tuple(reversed(range(segs))))
    if profile[-1][0] > 1e-6:
        faces.append(tuple((len(profile) - 1) * segs + s for s in range(segs)))
    return verts, faces


def tube(path, radii, segs=16):
    """Round bar along a path, with a parallel-transported frame."""
    path = [Vector(p) for p in path]
    verts, faces = [], []
    t0 = (path[1] - path[0]).normalized()
    nrm = t0.cross(Vector((0, 0, 1)))
    if nrm.length < 1e-4:
        nrm = t0.cross(Vector((1, 0, 0)))
    nrm.normalize()
    for i, p in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        t = (b - a).normalized()
        nrm = (nrm - t * nrm.dot(t)).normalized()
        bi = t.cross(nrm)
        for s in range(segs):
            ang = 2 * math.pi * s / segs
            verts.append(p + (nrm * math.cos(ang) + bi * math.sin(ang)) * radii[i])
    for i in range(len(path) - 1):
        for s in range(segs):
            s2 = (s + 1) % segs
            faces.append((i * segs + s, i * segs + s2, (i + 1) * segs + s2, (i + 1) * segs + s))
    faces.append(tuple(reversed(range(segs))))
    faces.append(tuple((len(path) - 1) * segs + s for s in range(segs)))
    return verts, faces


def boolean_cut(ob, cutter_bm):
    me = bpy.data.meshes.new("cutter"); cutter_bm.to_mesh(me); cutter_bm.free()
    cut = bpy.data.objects.new("cutter", me)
    bpy.context.scene.collection.objects.link(cut)
    mod = ob.modifiers.new("cut", 'BOOLEAN')
    mod.operation, mod.solver, mod.object = 'DIFFERENCE', 'EXACT', cut
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier="cut")
    bpy.data.objects.remove(cut)


# ---- scene ---------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
root = bpy.data.objects.new("door_tenement_a", None)
bpy.context.scene.collection.objects.link(root)

# ---- leaf: frame-and-panel joinery -------------------------------------------------------------
leaf = Part("leaf_wood", "wood_leaf")
rails = [  # (z_lo, z_hi)
    (Z0, Z0 + RAIL_BOTTOM),
    (LOCK_Z - RAIL_LOCK / 2, LOCK_Z + RAIL_LOCK / 2),
    (FRIEZE_Z - RAIL_FRIEZE / 2, FRIEZE_Z + RAIL_FRIEZE / 2),
    (Z1 - RAIL_TOP, Z1),
]
for sx in (-1, 1):  # stiles run the full height
    leaf.add_bm(box((sx * HX, -HT, Z0), (sx * (HX - STILE), HT, Z1)))
TAG["horiz"] = 1.0
for zl, zh in rails:
    leaf.add_bm(box((-(HX - STILE), -HT, zl), (HX - STILE, HT, zh)))
TAG["horiz"] = 0.0
openings = []
for (_, zl), (zh, _) in zip(rails[:-1], rails[1:]):
    leaf.add_bm(box((-MUNTIN / 2, -HT, zl), (MUNTIN / 2, HT, zh)))  # muntin between rails
    openings.append((-(HX - STILE), -MUNTIN / 2, zl, zh))
    openings.append((MUNTIN / 2, HX - STILE, zl, zh))

# panel moulding + fielded panel, both faces. (distance in from the opening edge, height above the face)
PANEL_PROFILE = [(-0.0006, 0.0), (0.0015, -0.0004), (0.004, -0.0022), (0.0075, -0.0060), (0.011, -0.0105),
                 (0.0135, -0.0140), (0.0150, -0.0160), (0.0165, -0.0166), (0.040, -0.0166), (0.0415, -0.0160),
                 (0.072, -0.0075), (0.0745, -0.0066), (0.078, -0.0064)]
for x0, x1, z0, z1 in openings:
    for out in (-1, 1):
        yf = out * HT
        corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        dirs = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
        place = lambda c, d, dd, h, yf=yf, out=out: Vector((c[0] + d[0] * dd, yf + out * h, c[1] + d[1] * dd))
        v, f = sweep_closed(corners, dirs, PANEL_PROFILE, place)
        m = len(PANEL_PROFILE)
        f.append(tuple(i * m + m - 1 for i in range(4)))  # the raised field
        leaf.add(v, f)

leaf_ob = leaf.build(root, origin=(HX + 0.0015, HT + 0.008, 0.0))  # pivot on the hinge line

# ---- frame, casing, threshold ------------------------------------------------------------------
frame = Part("frame_wood", "wood_frame")
top = HEAD_Z + JAMB_W
for sx in (-1, 1):
    frame.add_bm(box((sx * OPEN_X, -JAMB_D / 2, 0), (sx * (OPEN_X + JAMB_W), JAMB_D / 2, top)))
    # stop bead the leaf closes against (side A)
    frame.add_bm(box((sx * (OPEN_X - 0.012), -HT - 0.0225, SILL_H), (sx * OPEN_X, -HT - 0.003, HEAD_Z)))
    for out in (-1, 1):  # plinth blocks
        yf = out * JAMB_D / 2
        frame.add_bm(box((sx * (OPEN_X - 0.004), yf, 0), (sx * (OPEN_X + JAMB_W + 0.006), yf + out * 0.034, 0.21),
                         bevel=0.004, segs=3))
TAG["horiz"] = 1.0
frame.add_bm(box((-OPEN_X, -JAMB_D / 2, HEAD_Z), (OPEN_X, JAMB_D / 2, top)))
TAG["horiz"] = 0.0
frame.add_bm(box((-OPEN_X, -HT - 0.0225, HEAD_Z - 0.012), (OPEN_X, -HT - 0.003, HEAD_Z)))
# casing: (distance out from the opening edge, height off the frame face), a closed section
CASING = [(0.0, 0.0), (0.0, 0.011), (0.003, 0.0135), (0.009, 0.0150), (0.012, 0.0185), (0.017, 0.0200),
          (0.022, 0.0185), (0.026, 0.0150), (0.050, 0.0150), (0.055, 0.0175), (0.062, 0.0215), (0.070, 0.0250),
          (0.078, 0.0270), (0.086, 0.0290), (0.090, 0.0330), (0.096, 0.0345), (0.101, 0.0330), (0.104, 0.0290),
          (0.104, 0.0)]
for out in (-1, 1):
    yf = out * JAMB_D / 2
    corners = [(-OPEN_X, 0.21), (-OPEN_X, HEAD_Z), (OPEN_X, HEAD_Z), (OPEN_X, 0.21)]
    dirs = [(-1, 0), (-1, 1), (1, 1), (1, 0)]
    place = lambda c, d, dd, h, yf=yf, out=out: Vector((c[0] + d[0] * dd, yf + out * h, c[1] + d[1] * dd))
    frame.add(*sweep_open(corners, dirs, CASING, place))
# threshold: worn hollow where sixty years of feet have crossed it
bm = bmesh.new()
segx, segy = 28, 8
gx = [-OPEN_X + 2 * OPEN_X * i / segx for i in range(segx + 1)]
gy = [-(JAMB_D / 2 + 0.03) + (JAMB_D + 0.06) * j / segy for j in range(segy + 1)]
grid = [[bm.verts.new((x, y, SILL_H - 0.0045 * math.exp(-(x / 0.2) ** 2) * (1 - (2 * j / segy - 1) ** 4)
                       - (0.006 * ((abs(2 * j / segy - 1) - 0.75) / 0.25) ** 2 if abs(2 * j / segy - 1) > 0.75 else 0)))
         for x in gx] for j, y in enumerate(gy)]
base = [[bm.verts.new((x, y, 0.0)) for x in gx] for y in gy]
for j in range(segy):
    for i in range(segx):
        bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
for i in range(segx):
    bm.faces.new((base[0][i], base[0][i + 1], grid[0][i + 1], grid[0][i]))
    bm.faces.new((grid[segy][i], grid[segy][i + 1], base[segy][i + 1], base[segy][i]))
for j in range(segy):
    bm.faces.new((grid[j][0], grid[j + 1][0], base[j + 1][0], base[j][0]))
    bm.faces.new((base[j][segx], base[j + 1][segx], grid[j + 1][segx], grid[j][segx]))
TAG["horiz"], TAG["bare"] = 1.0, 1.0
frame.add_bm(bm)
TAG["horiz"], TAG["bare"] = 0.0, 0.0
frame_ob = frame.build(root)

# ---- hardware ------------------------------------------------------------------------------------
def screw(part, x, z, yf, out, r=0.0034):
    ang = random.uniform(0, math.pi)
    v, f = lathe((x, yf, z), (0, out, 0), [(0.0, 0.0016), (r * 0.5, 0.0015), (r * 0.85, 0.0011), (r, 0.0004), (r, 0.0)], segs=14)
    part.add(v, f)
    return (x, z, yf, out, ang, r)

brass = Part("hardware_brass", "brass")
iron = Part("hardware_iron", "iron")
dark = Part("hardware_dark", "dark")
slots = []
plates = []

for out in (-1, 1):
    yf = out * HT
    # long backplate with keyhole
    pc_z = HANDLE_Z - 0.036
    plates.append((HANDLE_X, pc_z, 0.044, 0.235, yf, 0.0032, out))
    for dz in (0.105, -0.105):
        slots.append(screw(brass, HANDLE_X, pc_z + dz, yf + out * 0.0032, out))
    # collar and lever
    v, f = lathe((HANDLE_X, yf + out * 0.0032, HANDLE_Z), (0, out, 0),
                 [(0.0165, 0.0), (0.0165, 0.0015), (0.0150, 0.0035), (0.0125, 0.0045), (0.0118, 0.0090), (0.0105, 0.0100)], segs=28)
    brass.add(v, f)

def lever(out):
    yf = out * HT + out * 0.0032
    p, r = [], []
    p.append((HANDLE_X, yf + out * 0.008, HANDLE_Z)); r.append(0.0098)
    p.append((HANDLE_X, yf + out * 0.030, HANDLE_Z)); r.append(0.0096)
    cx, cy, rad = HANDLE_X + 0.020, yf + out * 0.030, 0.020
    for k in range(1, 9):
        a = math.pi / 2 * k / 8
        p.append((cx - rad * math.cos(a), cy + out * rad * math.sin(a), HANDLE_Z)); r.append(0.0096 - 0.0006 * k / 8)
    n = 14
    for k in range(1, n + 1):
        t = k / n
        x = cx + 0.112 * t
        droop = -0.006 * t * t
        y = yf + out * (0.050 - 0.004 * math.sin(t * math.pi))
        rr = 0.0090 + 0.0006 * math.sin(t * math.pi) + 0.0022 * max(0.0, t - 0.72) / 0.28
        p.append((x, y, HANDLE_Z + droop)); r.append(rr)
    for k in range(1, 6):  # rounded end
        a = math.pi / 2 * k / 5
        p.append((cx + 0.112 + 0.011 * math.sin(a), yf + out * 0.050, HANDLE_Z - 0.006)); r.append(max(0.0112 * math.cos(a), 0.0004))
    return tube(p, r, segs=20)

handles = []
for out, tag in ((-1, "a"), (1, "b")):
    h = Part("handle_" + tag, "brass")
    h.add(*lever(out))
    handles.append((h, (HANDLE_X, out * HT, HANDLE_Z)))

# letter slot on the lock rail (side A) with a lifting flap, plain inner flap on side B
LS_X, LS_Z = 0.06, LOCK_Z + 0.012
plates.append((LS_X, LS_Z, 0.262, 0.074, -HT, 0.0030, -1))
for sx in (-1, 1):
    slots.append(screw(brass, LS_X + sx * 0.118, LS_Z, -HT - 0.0030, -1))
flap = Part("letter_flap", "brass")
flap.add_bm(plate(LS_X, LS_Z - 0.002, 0.212, 0.046, -HT - 0.0030, 0.0026, -1, 0.004))
v, f = tube([(LS_X - 0.112, -HT - 0.0062, LS_Z + 0.0225), (LS_X + 0.112, -HT - 0.0062, LS_Z + 0.0225)], [0.0032, 0.0032], segs=12)
flap.add(v, f)
plates.append((LS_X, LS_Z, 0.236, 0.060, HT, 0.0022, 1))
dark.add_bm(box((LS_X - 0.100, -HT - 0.0005, LS_Z - 0.019), (LS_X + 0.100, HT + 0.0005, LS_Z + 0.019), bevel=0))

# name-plate holder on the frieze rail (side A): a brass frame round a blank card
NP_X, NP_Z = 0.0, FRIEZE_Z
corners = [(NP_X - 0.048, NP_Z - 0.019), (NP_X + 0.048, NP_Z - 0.019), (NP_X + 0.048, NP_Z + 0.019), (NP_X - 0.048, NP_Z + 0.019)]
place = lambda c, d, dd, h: Vector((c[0] + d[0] * dd, -HT - h, c[1] + d[1] * dd))
v, f = sweep_closed(corners, [(1, 1), (-1, 1), (-1, -1), (1, -1)],
                    [(0.0, 0.0), (0.0, 0.0030), (0.0012, 0.0042), (0.0045, 0.0042), (0.0060, 0.0030), (0.0060, 0.0012)], place)
brass.add(v, f)
card = Part("name_card", "paper")
card.add_bm(box((NP_X - 0.0425, -HT - 0.0014, NP_Z - 0.0135), (NP_X + 0.0425, -HT, NP_Z + 0.0135), bevel=0))
for sx in (-1, 1):
    slots.append(screw(brass, NP_X + sx * 0.0452, NP_Z, -HT - 0.0042, -1, r=0.0019))

# hinges: three lift-off hinges on side B, knuckle on the hinge line
for hz in (Z0 + 0.20, Z0 + 1.06, Z0 + 1.90):
    ax = (HX + 0.0015, HT + 0.008, hz)
    for sgn in (-1, 1):  # lower half on the frame, upper half on the leaf
        v, f = lathe((ax[0], ax[1], hz), (0, 0, sgn),
                     [(0.0, 0.094), (0.0030, 0.093), (0.0052, 0.089), (0.0056, 0.085), (0.0040, 0.081), (0.0046, 0.078),
                      (0.0082, 0.076), (0.0082, 0.0006), (0.0078, 0.0)][::-1], segs=20)
        iron.add(v, f)
    iron.add_bm(box((HX - 0.030, HT, hz + 0.002), (HX + 0.0015, HT + 0.0022, hz + 0.074), bevel=0.0005))
    iron.add_bm(box((HX + 0.0015, HT, hz - 0.074), (OPEN_X + 0.030, HT + 0.0022, hz - 0.002), bevel=0.0005))

# lock: faceplate on the leaf edge, with latch
iron.add_bm(box((-HX - 0.0006, -0.011, HANDLE_Z - 0.115), (-HX + 0.002, 0.011, HANDLE_Z + 0.045), bevel=0.0004))
iron.add_bm(box((-HX - 0.009, -0.007, HANDLE_Z - 0.012), (-HX, 0.007, HANDLE_Z + 0.012), bevel=0.002, segs=3))

# bell push on the casing, handle side, side A
BX, BZ, BY = -(OPEN_X + 0.038), Z0 + 1.22, -JAMB_D / 2 - 0.015
v, f = lathe((BX, BY, BZ), (0, -1, 0), [(0.0290, 0.0), (0.0290, 0.0020), (0.0265, 0.0050), (0.0200, 0.0085), (0.0135, 0.0105), (0.0118, 0.0112), (0.0112, 0.0090)], segs=32)
brass.add(v, f)
button = Part("bell_button", "porcelain")
v, f = lathe((BX, BY, BZ), (0, -1, 0), [(0.0100, 0.0085), (0.0100, 0.0128), (0.0085, 0.0146), (0.0050, 0.0156), (0.0, 0.0160)], segs=24)
button.add(v, f)

# build plates with real cut-outs
plate_obs = []
for i, (cx, cz, w, h, yf, t, out) in enumerate(plates):
    p = Part("plate_%d" % i, "brass")
    p.add_bm(plate(cx, cz, w, h, yf, t, out, 0.007 if h > 0.1 else 0.006))
    ob = p.build(root)
    if h > 0.2:  # handle plate: keyhole and spindle hole
        kz = HANDLE_Z - 0.072
        cut = bmesh.new()
        bmesh.ops.create_cone(cut, cap_ends=True, segments=24, radius1=0.0046, radius2=0.0046, depth=0.02,
                              matrix=Matrix.Translation((cx, yf + out * t / 2, kz)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
        boolean_cut(ob, cut)
        boolean_cut(ob, box((cx - 0.0021, yf - 0.01, kz - 0.0135), (cx + 0.0021, yf + 0.01, kz - 0.002), bevel=0))
        dark.add_bm(box((cx - 0.006, yf - out * 0.012, kz - 0.016), (cx + 0.006, yf + out * 0.0004, kz + 0.006), bevel=0))
    elif i == 2:  # outer letter plate: the mouth behind the flap
        boolean_cut(ob, box((cx - 0.100, yf - 0.01, cz - 0.019), (cx + 0.100, yf + 0.01, cz + 0.019), bevel=0))
    else:         # inner letter plate
        boolean_cut(ob, box((cx - 0.100, yf - 0.01, cz - 0.019), (cx + 0.100, yf + 0.01, cz + 0.019), bevel=0))
    plate_obs.append(ob)

brass_ob = brass.build(root)
# screw slots, cut after the heads exist
for (x, z, yf, out, ang, r) in slots:
    c = box((-r * 1.3, -0.0006, -0.00038), (r * 1.3, 0.0012, 0.00038), bevel=0)
    rot = Matrix.Rotation(ang, 4, 'Y')
    for vv in c.verts:
        co = rot @ Vector((vv.co.x, 0.0, vv.co.z))
        vv.co = Vector((co.x + x, yf + out * (0.0016 + vv.co.y), co.z + z))
    bmesh.ops.recalc_face_normals(c, faces=c.faces)
    boolean_cut(brass_ob, c)

iron_ob = iron.build(root)
dark_ob = dark.build(root)
card_ob = card.build(root)
button_ob = button.build(root)
flap_ob = flap.build(root, origin=(LS_X, -HT - 0.0062, LS_Z + 0.0225))
handle_obs = [h.build(root, origin=o) for h, o in handles]

# everything that moves with the leaf hangs from it
for ob in plate_obs + [brass_ob, dark_ob, card_ob, flap_ob] + handle_obs:
    w = ob.matrix_world.copy(); ob.parent = leaf_ob; ob.matrix_parent_inverse = leaf_ob.matrix_world.inverted()
# the bell rose and the frame halves of the hinges stay with the frame (kept in their meshes for now)

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print("DOOR objects", len([o for o in bpy.data.objects if o.type == 'MESH']), "triangles", tris)
os.makedirs(os.path.join(ASSET, "source"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET, "source", "door_tenement_a.blend"))

# ---- clay review renders -------------------------------------------------------------------------
if CLAY:
    sc = bpy.context.scene
    clay = bpy.data.materials.new("clay"); clay.use_nodes = True
    b = clay.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.36, 0.35, 0.33, 1); b.inputs["Roughness"].default_value = 0.6
    metal = bpy.data.materials.new("clay_metal"); metal.use_nodes = True
    b = metal.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.78, 0.62, 0.32, 1); b.inputs["Metallic"].default_value = 1.0; b.inputs["Roughness"].default_value = 0.32
    for o in bpy.data.objects:
        if o.type == 'MESH':
            m = o.data.materials[0].name
            o.data.materials[0] = metal if m in ("brass", "iron") else clay
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 72; sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1100, 1400
    sc.view_settings.view_transform = 'Filmic'
    w = bpy.data.worlds.new("void"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.025, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0

    def light(loc, target, power, size, color=(1, 1, 1)):
        l = bpy.data.lights.new("l", 'AREA'); l.energy = power; l.size = size; l.color = color
        o = bpy.data.objects.new("l", l); sc.collection.objects.link(o); o.location = loc
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

    light((-1.6, -2.6, 2.6), (0, 0, 1.2), 170, 1.4)
    light((2.2, -1.8, 1.2), (0, 0, 1.0), 30, 2.0, (0.75, 0.82, 1.0))
    light((0.4, 2.4, 2.2), (0, 0, 1.2), 120, 1.2, (1.0, 0.86, 0.66))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam

    def shot(name, loc, target, lens, res=(1100, 1400)):
        cam.location = loc; cam.data.lens = lens
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.filepath = os.path.join(ASSET, "review", name + ".png")
        bpy.ops.render.render(write_still=True)
        print("SHOT", name)

    shot("clay_front_a", (-1.1, -3.3, 1.55), (0, 0, 1.12), 40)
    shot("clay_handle_a", (HANDLE_X + 0.26, -0.50, HANDLE_Z + 0.10), (HANDLE_X + 0.05, 0, HANDLE_Z - 0.03), 50, (1200, 1000))
    shot("clay_back_b", (1.3, 3.1, 1.55), (0, 0, 1.12), 40)
    shot("clay_bottom_a", (0.35, -0.75, 0.42), (0.05, 0, 0.16), 35, (1200, 900))
