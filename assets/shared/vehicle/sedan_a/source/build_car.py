"""Builds sedan_a: a 2020s mid-size four-door saloon of our own design. No real make, no badges, no marks.

    blender -b -P source/build_car.py -- <asset_dir> [--studio] [--render] [--all] [--quick] [--samples=N]

Method. The body is a subdivision surface. Its control cage is a box lattice: stations from tail to nose (a),
columns from the right side to the left (b) and rows from the sill to the shoulder (c). Every cage point is
placed by the tables below, so each line of the car is a number in this file. Feature lines (shoulder, lower
character line, sill, bonnet and boot edges) are creased cage edges. Windows, pillars, lamps and trim are whole
cage faces, so their outlines follow the smooth subdivided curves. Wheel arches are cut afterwards, panel gaps
are cut as 5 mm grooves, the headlamps get a pocket with modelled lamps under a clear lens.

Car space: u forward, v to the car's left, z up, metres, origin on the ground at the middle of the wheelbase.
Blender: x = -v, y = u. The glTF export turns that into -Z forward in the game.
Writes source/sedan_a.blend and export/sedan_a.glb; --studio or --render also write review/*.png.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
ASSET = ARGS[0]
STUDIO = "--studio" in ARGS
NIGHT = "--render" in ARGS
QUICK = "--quick" in ARGS
SAMPLES = next((int(a.split("=")[1]) for a in ARGS if a.startswith("--samples=")), 16 if QUICK else 64)

# ---- overall numbers ------------------------------------------------------------------------------
AXLE_F, AXLE_R = 1.40, -1.40                 # 2.80 m wheelbase, centred on the origin
WHEEL_R, TRACK = 0.335, 0.80                 # 235/40 R19 tyre; wheel centres 0.80 m either side
ARCH_R, ARCH_Z = 0.385, 0.348                # wheel-arch opening, centred just above the axle

# rows of the cage, bottom to top: S0 underbody edge, S1-S2 sill, S3 sill top (door bottom), S4 lower door,
# S5 lower character line, S6/S6b/S7 lamp band rows, S8, E shoulder crease (the top of the side)
NC = 10
VS = [0.858, 0.890, 0.909, 0.910, 0.905, 0.925, 0.918, 0.911, 0.901, 0.884, 0.864]   # half-width of each row
ZS_FIX = [0.170, 0.185, 0.240, 0.335, 0.455]                                         # side heights, rows S0-S4
S5K = [(-2.45, 0.680), (-1.40, 0.660), (0.0, 0.622), (1.40, 0.598), (2.35, 0.590)]  # lower character line
ZEK = [(-2.45, 0.982), (-1.90, 0.982), (-1.0, 0.964), (0.0, 0.945), (1.0, 0.922), (1.6, 0.872), (1.95, 0.812), (2.30, 0.760)]
FRAC = {6: 0.36, 7: 0.53, 8: 0.70, 9: 0.89}                                          # rows between S5 and E
ZF = [0.205, 0.220, 0.290, 0.390, 0.480, 0.560, 0.615, 0.650, 0.685, 0.725, 0.752]   # front face row heights
NF = [2.180, 2.222, 2.252, 2.272, 2.282, 2.262, 2.228, 2.205, 2.182, 2.140, 2.100]   # front face, nose of each row
ZRR = [0.275, 0.290, 0.335, 0.425, 0.525, 0.638, 0.790, 0.832, 0.872, 0.952, 0.990]  # rear face row heights
NR = [-2.335, -2.370, -2.395, -2.412, -2.420, -2.416, -2.400, -2.390, -2.378, -2.348, -2.362]
U_FS = 1.66                                  # where the plan starts to round off at the front
EXPF = [2.30, 2.30, 2.35, 2.40, 2.45, 2.50, 2.60, 2.65, 2.70, 2.70, 2.70]   # how square each row's nose is
U_RS, EXP_R = -1.98, 2.9
H = 9                                        # columns from the centreline to the side
FV = [0.0, 0.16, 0.31, 0.43, 0.52, 0.60, 0.67, 0.735, 0.795, 0.85]                    # end-face columns (fraction of width)
BONF = [0.0, 0.28, 0.54, 0.74, 0.78, 0.82, 0.86, 0.90, 0.95]                          # bonnet and boot columns
Q_END = 0.985                                # the station just round each end corner
STA = [None, None, -2.06, -1.92, -1.86, -1.62, -1.45, -1.40, -1.015, -0.955, -0.60, -0.15, -0.07,
       0.09, 0.15, 0.50, 0.86, 0.92, 1.02, 1.32, 1.62, None, None]
NA = len(STA) - 1
U_RB, U_CW = -1.92, 0.92                     # rear-screen base and windscreen base (the cowl)
# the glasshouse
ZCK = [(-1.92, 1.003), (-1.70, 1.100), (-1.40, 1.245), (-1.15, 1.360), (-0.99, 1.412), (-0.60, 1.448), (-0.20, 1.452),
       (0.09, 1.432), (0.15, 1.418), (0.50, 1.230), (0.86, 1.005), (0.92, 0.975)]          # centreline
ZRK = [(-1.92, 1.000), (-1.70, 1.075), (-1.40, 1.205), (-1.15, 1.315), (-0.99, 1.370), (-0.60, 1.405), (-0.20, 1.410),
       (0.09, 1.392), (0.15, 1.380), (0.50, 1.200), (0.86, 0.990), (0.92, 0.968)]          # roof edge / pillar line
VRK = [(-1.92, 0.650), (-1.40, 0.612), (-0.99, 0.590), (-0.50, 0.608), (0.09, 0.605), (0.50, 0.635), (0.92, 0.672)]
ZGK = [(-1.92, 1.002), (-1.0, 0.995), (0.0, 0.985), (0.92, 0.968)]                       # belt (glass base)
VGK = [(-1.92, 0.752), (-1.0, 0.770), (0.0, 0.781), (0.92, 0.782)]
ZBK = [(0.92, 0.972), (1.02, 0.964), (1.32, 0.925), (1.62, 0.872), (1.85, 0.822), (2.00, 0.785), (2.10, 0.752)]   # bonnet
ZKK = [(-2.36, 0.986), (-2.20, 0.998), (-2.06, 1.004), (-1.92, 1.004)]                   # boot deck


def spline(keys, x):
    """Catmull-Rom through (x, y) keys."""
    if x <= keys[0][0]:
        return keys[0][1]
    if x >= keys[-1][0]:
        return keys[-1][1]
    i = max(k for k in range(len(keys) - 1) if keys[k][0] <= x)
    p0, p1, p2, p3 = keys[max(i - 1, 0)], keys[i], keys[i + 1], keys[min(i + 2, len(keys) - 1)]
    t = (x - p1[0]) / (p2[0] - p1[0])
    m1 = (p2[1] - p0[1]) / max(p2[0] - p0[0], 1e-6) * (p2[0] - p1[0])
    m2 = (p3[1] - p1[1]) / max(p3[0] - p1[0], 1e-6) * (p2[0] - p1[0])
    return (2 * t**3 - 3 * t**2 + 1) * p1[1] + (t**3 - 2 * t**2 + t) * m1 + (-2 * t**3 + 3 * t**2) * p2[1] + (t**3 - t**2) * m2


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def se(x, n):
    """Superellipse: width fraction from length fraction, and the other way round."""
    return max(1.0 - min(x, 1.0) ** n, 0.0) ** (1.0 / n)


def cb(u, v, z):
    return Vector((-v, u, z))


def cu(co):
    return co.y, -co.x, co.z


# ---- the cage --------------------------------------------------------------------------------------
def width(c, u):
    """Half-width of row c at station u: a slight taper to both ends and a haunch over the rear wheels."""
    w = VS[c] * (1.0 - 0.016 * smooth(0.9, 2.3, u) - 0.010 * smooth(-1.7, -2.45, u))
    if 6 <= c <= 9:
        w += 0.010 * math.exp(-((u + 1.35) / 0.45) ** 2)
    return w


def row_z(c, u):
    if c <= 4:
        return ZS_FIX[c]
    s5, e = spline(S5K, u), spline(ZEK, u)
    if c == 5:
        return s5
    if c == NC:
        return e
    return s5 + FRAC[c] * (e - s5)


def end_point(c, q=None, s=None, front=True):
    """A point on row c round the front or rear corner, by width fraction q or length fraction s."""
    u0, n, nose, zend = (U_FS, EXPF[c], NF[c], ZF[c]) if front else (U_RS, EXP_R, NR[c], ZRR[c])
    W = width(c, nose)
    if q is None:
        q = se(s, n)
    s = se(q, n)
    u = u0 + (nose - u0) * s
    W = width(c, u0)
    A = abs(nose - u0)
    gu, gv = s ** (n - 1) / A, q ** (n - 1) / W
    w = smooth(0.15, 0.85, math.atan2(gu, gv) / (math.pi / 2))     # 0 facing sideways, 1 facing along the car
    return Vector((u, q * W, lerp(row_z(c, u), zend, w)))


def plan_normal(c, q, front=True):
    W = VS[c]
    u0, n, nose = (U_FS, EXPF[c], NF[c]) if front else (U_RS, EXP_R, NR[c])
    s = se(q, n)
    A = abs(nose - u0)
    gu, gv = s ** (n - 1) / A, q ** (n - 1) / W
    d = Vector(((1 if front else -1) * gu, gv, 0.0))
    return d.normalized()


def front(k, c):
    return end_point(c, q=FV[k], front=True)


def rear(k, c):
    return end_point(c, q=FV[k], front=False)


def side(a, c):
    if a == NA:
        return front(H, c)
    if a == 0:
        return rear(H, c)
    if a == NA - 1:
        return end_point(c, q=Q_END, front=True)
    if a == 1:
        return end_point(c, q=Q_END, front=False)
    u = STA[a]
    if u > U_FS:
        return end_point(c, s=(u - U_FS) / (NF[c] - U_FS), front=True)
    if u < U_RS:
        return end_point(c, s=(u - U_RS) / (NR[c] - U_RS), front=False)
    return Vector((u, width(c, u), row_z(c, u)))


def deck_z(u, v, E):
    if u > 0:
        zi = spline(ZBK, u) - 0.052 * (v / 0.9) ** 2
    else:
        zi = spline(ZKK, u) - 0.018 * (v / 0.9) ** 2
    return lerp(zi, E.z, smooth(0.70 * E.y, E.y, v))


BOW = {3: -0.05, 4: -0.05, 5: -0.04, 6: -0.03, 7: -0.03, 8: -0.02, 9: -0.02, 13: 0.03, 14: 0.035, 15: 0.05, 16: 0.06, 17: 0.06}


def green(u, k, E, bow=0.0):
    """The glasshouse section at station u: roof crown, roof edge, glass frame, side glass, waist seal, ledge."""
    zc, zr, vr, zg, VG = spline(ZCK, u), spline(ZRK, u), spline(VRK, u), spline(ZGK, u), spline(VGK, u)
    crown = zc - zr
    if k <= 2:
        f = (0.0, 0.45, 0.85)[k]
        return Vector((u + bow * (1 - f * f), f * vr, zc - crown * f * f))
    full = [(vr, zr), (vr + 0.014, zr - 0.012), (vr + 0.030, zr - 0.052), (VG, zg + 0.016), (VG + 0.012, zg - 0.004),
            (lerp(VG + 0.012, E.y, 0.5), lerp(zg - 0.004, E.z, 0.42))]
    p = Vector(full[k - 3])
    if k - 3 <= 4:                                            # near the screen bases the glass runs out: spread
        t = smooth(0.0, 0.14, zr - zg)                        # the columns along the base instead of collapsing
        spread = Vector(full[0]).lerp(Vector(full[4]), (k - 3) / 4)
        p = spread.lerp(p, t)
    return Vector((u, p.x, p.y))


def lid(a, k):
    if a == NA:
        return front(k, NC)
    if a == 0:
        return rear(k, NC)
    if k == H:
        return side(a, NC)
    E = side(a, NC)
    if a in (1, NA - 1):                                      # round the corner: lean the row towards the end edge
        F = front(k, NC) if a == NA - 1 else rear(k, NC)
        S = Vector((E.x, BONF[k] * E.y, 0.0))
        lam = 0.55 * (1 - (k / H) ** 2)
        Pp = S.lerp(Vector((F.x, F.y, 0.0)), lam)
        return Vector((Pp.x, Pp.y, deck_z(Pp.x, Pp.y, E)))
    u = STA[a]
    if U_RB <= u <= U_CW:
        return green(u, k, E, BOW.get(a, 0.0))
    v = BONF[k] * E.y
    if a == 18:
        u += 0.04 * (1 - BONF[k] ** 2)
    return Vector((u, v, deck_z(u, v, E)))


def bottom(a, k):
    if a == NA:
        return front(k, 0)
    if a == 0:
        return rear(k, 0)
    if k == H:
        return side(a, 0)
    S0 = side(a, 0)
    Pp = Vector((S0.x, k / H * 0.96 * S0.y, 0.165))
    if a in (1, NA - 1):
        F = front(k, 0) if a == NA - 1 else rear(k, 0)
        Pp = Pp.lerp(F, 0.5 * (1 - (k / H) ** 2))
    return Pp


def P(a, b, c):
    k = abs(b - H)
    sgn = 1 if b >= H else -1
    if c == NC:
        p = lid(a, k)
    elif a == NA:
        p = front(k, c)
    elif a == 0:
        p = rear(k, c)
    elif k == H:
        p = side(a, c)
    else:
        p = bottom(a, k)
    return p.x, sgn * p.y, p.z


# ---- materials -------------------------------------------------------------------------------------
MATS = ["car_paint", "glass", "trim_black", "trim_gloss", "chrome", "rubber", "alloy", "interior", "headliner",
        "metal_dark", "caliper", "plate", "lamp_lens", "lamp_head", "lamp_tail", "lamp_brake", "lamp_reverse",
        "lamp_indicator", "tag_head", "tag_intake", "tag_vent"]
MI = {m: i for i, m in enumerate(MATS)}

bpy.ops.wm.read_factory_settings(use_empty=True)
for m in MATS:
    bpy.data.materials.new(m)
root = bpy.data.objects.new("sedan_a", None)
bpy.context.scene.collection.objects.link(root)


def new_object(name, bm, smooth_all=True):
    if smooth_all:
        for f in bm.faces:
            f.smooth = True
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    for m in MATS:
        me.materials.append(bpy.data.materials[m])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = root
    return ob


def lid_mat(a, kf):
    if 3 <= a <= 16:                                          # glasshouse
        if kf <= 1:
            if a in (3, 8, 13, 16):
                return "trim_gloss"                           # ceramic band round the screens
            if 4 <= a <= 7 or a in (14, 15):
                return "glass"                                # rear screen, windscreen
            return "car_paint"                                # roof
        if kf == 2:
            return "car_paint" if 9 <= a <= 12 else "trim_gloss"
        if kf == 3:
            return "car_paint"                                # roof rail, A and C pillars
        if kf == 4:
            return "car_paint" if a <= 5 else "trim_gloss"    # glass frame
        if kf == 5:
            if a <= 5:
                return "car_paint"                            # C pillar
            return {6: "trim_gloss", 7: "glass", 8: "trim_gloss", 11: "trim_gloss", 16: "trim_gloss"}.get(a, "glass")
        if kf == 6:
            return "trim_gloss"                               # waist seal
        return "car_paint"
    if a == 17 and kf <= 2:
        return "trim_black"                                   # scuttle panel under the windscreen
    return "car_paint"


def side_mat(a, c):
    if c <= 1:
        return "trim_black"
    if a == 0:
        if c == 7:
            return "lamp_tail"
        if c == 6:
            return "lamp_indicator"
    if a == NA - 1 and c in (6, 7):
        return "tag_head"
    return "car_paint"


def front_mat(kf, c):
    if c == 0 or (c == 1 and kf <= 5):
        return "trim_black"
    if c in (2, 3) and kf <= 3:
        return "tag_intake"
    if c in (2, 3) and kf in (6, 7):
        return "tag_vent"
    if c in (6, 7) and kf >= 5:
        return "tag_head"
    if c == 7:
        return "trim_gloss"
    return "car_paint"


def rear_mat(kf, c):
    if c <= 1:
        return "trim_black"
    if c == 7:
        return "lamp_tail"                                    # the lamps are joined by a slim light bar
    if c == 6 and kf >= 4:
        return "lamp_reverse" if kf == 4 else "lamp_brake"
    return "car_paint"


def build_cage():
    bm = bmesh.new()
    V, key_of = {}, {}
    NB = 2 * H
    for a in range(NA + 1):
        for b in range(NB + 1):
            for c in range(NC + 1):
                if a in (0, NA) or b in (0, NB) or c in (0, NC):
                    v = bm.verts.new(cb(*P(a, b, c)))
                    V[(a, b, c)] = v
                    key_of[v] = (a, b, c)

    def quad(keys, mat):
        f = bm.faces.new([V[k] for k in keys])
        f.material_index = MI[mat]

    def kf(b):
        return min(abs(b - H), abs(b + 1 - H))

    for a in range(NA):
        for b in range(NB):
            quad([(a, b, NC), (a + 1, b, NC), (a + 1, b + 1, NC), (a, b + 1, NC)], lid_mat(a, kf(b)))
            quad([(a, b, 0), (a + 1, b, 0), (a + 1, b + 1, 0), (a, b + 1, 0)], "trim_black")
        for c in range(NC):
            for b in (0, NB):
                quad([(a, b, c), (a + 1, b, c), (a + 1, b, c + 1), (a, b, c + 1)], side_mat(a, c))
    for b in range(NB):
        for c in range(NC):
            quad([(NA, b, c), (NA, b + 1, c), (NA, b + 1, c + 1), (NA, b, c + 1)], front_mat(kf(b), c))
            quad([(0, b, c), (0, b + 1, c), (0, b + 1, c + 1), (0, b, c + 1)], rear_mat(kf(b), c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cl = bm.edges.layers.float.new("crease_edge")
    for e in bm.edges:
        (a1, b1, c1), (a2, b2, c2) = key_of[e.verts[0]], key_of[e.verts[1]]
        along_side = b1 == b2 and b1 in (0, NB) and c1 == c2 and a1 != a2
        across = a1 == a2 and c1 == c2 and b1 != b2
        if c1 == c2 == NC and along_side:
            e[cl] = 0.72                                      # shoulder crease
        elif c1 == c2 == NC and across and a1 == NA:
            e[cl] = 0.55                                      # bonnet leading edge
        elif c1 == c2 == NC and across and a1 == 0:
            e[cl] = 0.85                                      # boot lid trailing edge
        elif c1 == c2 == 5 and along_side and 1 <= min(a1, a2) < NA - 1:
            e[cl] = 0.75                                      # lower character line
        elif c1 == c2 == 3 and along_side:
            e[cl] = 0.35                                      # sill top
        elif c1 == c2 == 5 and across and a1 in (0, NA):
            e[cl] = 0.25                                      # bumper tops
    return bm


def apply_mod(ob, mod):
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier=mod.name)


body = new_object("body", build_cage())
sub = body.modifiers.new("subd", 'SUBSURF')
sub.levels = sub.render_levels = 2
apply_mod(body, sub)

# ---- wheel arches: a pocket each side, lined in black plastic ------------------------------------------
for axle in (AXLE_F, AXLE_R):
    for sgn in (-1, 1):
        cbm = bmesh.new()
        bmesh.ops.create_cone(cbm, cap_ends=True, segments=72, radius1=ARCH_R, radius2=ARCH_R, depth=0.66,
                              matrix=Matrix.Translation(cb(axle, sgn * 0.84, ARCH_Z)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
        for f in cbm.faces:
            f.material_index = 0
        cm = bpy.data.meshes.new("cut")
        cbm.to_mesh(cm)
        cm.materials.append(bpy.data.materials["trim_black"])
        cut = bpy.data.objects.new("cut", cm)
        bpy.context.scene.collection.objects.link(cut)
        mod = body.modifiers.new("arch", 'BOOLEAN')
        mod.operation, mod.solver, mod.object = 'DIFFERENCE', 'EXACT', cut
        mod.material_mode = 'TRANSFER'
        mod.use_hole_tolerant = True
        apply_mod(body, mod)
        bpy.data.objects.remove(cut)

bm = bmesh.new()
bm.from_mesh(body.data)
# the flat underbody does not need the subdivision: merge it into large panels
flat = [f for f in bm.faces if f.normal.z < -0.995 and f.calc_center_median().z < 0.168]
bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=list({v for f in flat for v in f.verts}),
                         edges=list({e for f in flat for e in f.edges}), delimit={'MATERIAL'})
bm.normal_update()
SURF = BVHTree.FromBMesh(bm)                                  # the outer surface, before pockets and grooves


def hit(o, d):
    """Ray-cast the outer body surface (car space in, Blender-space location and normal out)."""
    loc, nrm, _, _ = SURF.ray_cast(cb(*o), Vector((-d[1], d[0], d[2])).normalized(), 5.0)
    return loc, nrm


# ---- pockets: headlamps under a clear lens, the lower intake and the corner inlets ---------------------
def pocket(bm, tag, depth, new_mat):
    faces = [f for f in bm.faces if f.material_index == MI[tag]]
    verts = {v for f in faces for v in f.verts}
    edge = {v for v in verts if any(f.material_index != MI[tag] for f in v.link_faces)}
    moves = [(v, v.normal.copy()) for v in verts - edge]
    for v, n in moves:
        v.co -= n * depth
    for f in faces:
        f.material_index = MI[new_mat]
    return faces


lens_bm = bmesh.new()
lvm = {}
for f in [f for f in bm.faces if f.material_index == MI["tag_head"]]:
    vs = []
    for v in f.verts:
        if v not in lvm:
            lvm[v] = lens_bm.verts.new(v.co)
        vs.append(lvm[v])
    nf = lens_bm.faces.new(vs)
    nf.material_index = MI["lamp_lens"]
pocket(bm, "tag_head", 0.030, "trim_gloss")
pocket(bm, "tag_intake", 0.045, "trim_black")
pocket(bm, "tag_vent", 0.030, "trim_black")


# ---- panel gaps: 5 mm grooves, cut on planes ---------------------------------------------------------
def groove(bm, origin, normal, region, side_only=None):
    o, n = cb(*origin), Vector((-normal[1], normal[0], normal[2])).normalized()

    def inside(f):
        u, v, z = cu(f.calc_center_median())
        return region(u, v, z) and f.material_index != MI["glass"]

    for off in (-0.0045, -0.002, 0.002, 0.0045):
        faces = [f for f in bm.faces if inside(f)]
        if not faces:
            return
        geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=o + n * off, plane_no=n)
    bm.normal_update()
    faces = [f for f in bm.faces if inside(f)]
    sink = []
    for v in {v for f in faces for v in f.verts}:
        if abs(abs((v.co - o).dot(n)) - 0.002) < 2e-5:
            sink.append((v, v.normal.copy()))
    for v, nv in sink:
        v.co -= nv * 0.0035
    for f in faces:                                           # floor and both walls dark, so a gap reads as a
        if abs((f.calc_center_median() - o).dot(n)) < 0.0042:   # shadow line, not a bright painted edge
            f.material_index = MI["trim_black"]


DOOR = lambda u, v, z: abs(v) > 0.79 and 0.333 < z < 0.99
for su in (0.94, -0.11, -0.95):
    groove(bm, (su, 0, 0), (1, 0, 0), DOOR)
groove(bm, (0, 0, 0.335), (0, 0, 1), lambda u, v, z: -0.95 < u < 0.94 and abs(v) > 0.85)
for sv in (0.70, -0.70):
    groove(bm, (0, sv, 0), (0, 1, 0), lambda u, v, z: u > 1.035 and z > 0.709 and abs(v) > 0.6)
groove(bm, (0, 0, 0.712), (0, 0, 1), lambda u, v, z: u > 2.0 and abs(v) < 0.70)
groove(bm, (1.035, 0, 0), (1, 0, 0), lambda u, v, z: abs(v) < 0.70 and z > 0.9)
groove(bm, (1.90, 0, 0), (1, 0, 0), lambda u, v, z: abs(v) > 0.6 and 0.40 < z < 0.62)
for sv in (0.66, -0.66):
    groove(bm, (0, sv, 0), (0, 1, 0), lambda u, v, z: u < -1.955 and z > 0.645 and abs(v) > 0.55)
groove(bm, (-1.955, 0, 0), (1, 0, 0), lambda u, v, z: abs(v) < 0.66 and z > 0.95)
groove(bm, (0, 0, 0.645), (0, 0, 1), lambda u, v, z: u < -1.93 and 0.55 < z < 0.75)
groove(bm, (-1.93, 0, 0), (1, 0, 0), lambda u, v, z: abs(v) > 0.6 and 0.36 < z < 0.645)
FLAP = (-1.71, -1.55, 0.805, 0.915)                          # fuel filler flap, right-hand rear wing
for su in FLAP[:2]:
    groove(bm, (su, 0, 0), (1, 0, 0), lambda u, v, z: v < -0.6 and FLAP[2] - 0.003 < z < FLAP[3] + 0.003)
for sz in FLAP[2:]:
    groove(bm, (0, 0, sz), (0, 0, 1), lambda u, v, z: v < -0.6 and FLAP[0] - 0.003 < u < FLAP[1] + 0.003)

bm.to_mesh(body.data)
bm.free()


# ---- helpers for the parts -----------------------------------------------------------------------------
def copy_into(dst, src, mat=None):
    src.verts.index_update()
    vm = [dst.verts.new(v.co) for v in src.verts]
    for f in src.faces:
        try:
            nf = dst.faces.new([vm[v.index] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = f.material_index if mat is None else MI[mat]
        nf.smooth = f.smooth


def rbox(dst, centre, size, mat, bevel=0.01, segs=3, tilt=0.0, yaw=0.0, roll=0.0, M=None):
    """A rounded box in car space: centre (u, v, z), size (along u, v, z); tilt leans its top backwards."""
    t = bmesh.new()
    bmesh.ops.create_cube(t, size=1.0)
    for v in t.verts:
        v.co = Vector((v.co.x * size[1], v.co.y * size[0], v.co.z * size[2]))
    bv = min(bevel, min(size) * 0.49)
    if bv > 0:
        bmesh.ops.bevel(t, geom=list(t.edges), offset=bv, segments=segs, affect='EDGES', profile=0.5)
    R = Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(tilt), 4, 'X') @ Matrix.Rotation(math.radians(roll), 4, 'Y')
    T = Matrix.Translation(cb(*centre)) @ R
    if M is not None:
        T = M @ T
    for v in t.verts:
        v.co = T @ v.co
    for f in t.faces:
        f.smooth = True
        f.material_index = MI[mat]
    copy_into(dst, t)
    t.free()


def loft(dst, rings, mat, closed=True, cap=False, smooth_faces=True):
    """Quads between rings of points (Blender space); optional n-gon caps."""
    vr = [[dst.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    out = []
    for i in range(len(vr) - 1):
        for j in range(n if closed else n - 1):
            j2 = (j + 1) % n
            try:
                f = dst.faces.new([vr[i][j], vr[i + 1][j], vr[i + 1][j2], vr[i][j2]])
            except ValueError:
                continue
            f.material_index = MI[mat]
            f.smooth = smooth_faces
            out.append(f)
    if cap:
        for r, other in ((vr[0], vr[1]), (vr[-1], vr[-2])):
            try:
                f = dst.faces.new(r)
            except ValueError:
                continue
            f.material_index = MI[mat]
            f.normal_update()
            c0 = sum((v.co for v in r), Vector()) / len(r)
            c1 = sum((v.co for v in other), Vector()) / len(other)
            if f.normal.dot(c0 - c1) < 0:
                f.normal_flip()
            out.append(f)
    return out


def tube(dst, pts, radius, mat, segs=8):
    """A round tube along a polyline (Blender space)."""
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = d.cross(Vector((0, 0, 1)))
        if a.length < 1e-3:
            a = d.cross(Vector((1, 0, 0)))
        a.normalize()
        b = d.cross(a)
        rings.append([p + (a * math.cos(2 * math.pi * s / segs) - b * math.sin(2 * math.pi * s / segs)) * radius for s in range(segs)])
    loft(dst, rings, mat, cap=True)


def lathe(dst, profile, segs, mat, M=Matrix.Identity(4)):
    """Revolve [(radius, axial)] round the X axis."""
    rings = [[M @ Vector((d, r * math.cos(2 * math.pi * s / segs), r * math.sin(2 * math.pi * s / segs))) for s in range(segs)]
             for r, d in profile]
    return loft(dst, rings, mat)


details = bmesh.new()                                         # small parts that do not move: one object

# ---- wheel-arch lips: the panel rolled over at the opening -------------------------------------------
for axle in (AXLE_F, AXLE_R):
    for sgn in (-1, 1):
        rings = []
        for i in range(57):
            ph = math.radians(-20 + 220 * i / 56)
            du, dz = math.cos(ph), math.sin(ph)
            prof = []
            for dr, dv in ((0.032, -0.0025), (0.016, 0.0028), (0.006, 0.0035), (-0.001, 0.0), (-0.003, -0.012), (-0.004, -0.04)):
                rr = ARCH_R + max(dr, 0.004)
                loc, _ = hit((axle + rr * du, sgn * 1.4, ARCH_Z + rr * dz), (0, -sgn, 0))
                vs = cu(loc)[1] if loc else sgn * 0.9
                r2 = ARCH_R + dr
                prof.append(cb(axle + r2 * du, vs + sgn * dv, ARCH_Z + r2 * dz))
            rings.append(prof)
        fs = loft(details, rings, "car_paint", closed=False)
        if sgn > 0:
            bmesh.ops.reverse_faces(details, faces=fs)

# ---- headlamps: projector modules, a daytime light guide and an indicator strip, under the lens ---------
LENS = BVHTree.FromBMesh(lens_bm)


def lamp_path(sgn, f, q0, q1, inset, n=24):
    out = []
    for i in range(n + 1):
        q = lerp(q0, q1, i / n)
        p = end_point(6, q=q).lerp(end_point(8, q=q), f)
        d = plan_normal(7, q)
        o = cb(p.x + d.x * 0.2, sgn * (p.y + d.y * 0.2), p.z)
        loc, nrm, _, _ = LENS.ray_cast(o, (cb(p.x, sgn * p.y, p.z) - o).normalized(), 1.0)
        if loc:
            out.append((loc - nrm * inset, nrm))
    return out


for sgn in (1, -1):
    drl = [p for p, _ in lamp_path(sgn, 0.80, 0.62, 0.975, 0.011)]
    ind = [p for p, _ in lamp_path(sgn, 0.16, 0.80, 0.975, 0.010)]
    for path, mat, r in ((drl, "lamp_head", 0.0042), (ind, "lamp_indicator", 0.0038)):
        if len(path) > 2:
            tube(details, path, r, mat)
    for q in (0.665, 0.75):
        hp = lamp_path(sgn, 0.36, q, q, 0.014, n=1)
        if not hp:
            continue
        p, nrm = hp[0]
        z = nrm.normalized()
        x = z.cross(Vector((0, 0, 1))).normalized()
        y = x.cross(z)
        M = Matrix.Translation(p) @ Matrix((x, y, z)).transposed().to_4x4() @ Matrix.Rotation(-math.pi / 2, 4, 'Y')
        lathe(details, [(0.0, 0.0), (0.016, 0.0)], 20, "lamp_head", M)                       # the lens of the module
        lathe(details, [(0.016, 0.0), (0.0185, 0.002), (0.024, 0.002), (0.026, -0.004), (0.026, -0.016)], 20, "chrome", M)

# ---- lower intake mesh: a diagonal lattice of thin bars just behind the opening ------------------------
for fam in (1, -1):
    for i in range(-30, 31):
        pts = []
        for j in range(15):
            t = j / 14
            z = lerp(0.30, 0.468, t)
            v = i * 0.034 + fam * (z - 0.384) * 1.1
            if abs(v) > 0.445:
                if pts:
                    break
                continue
            loc, nrm = hit((3.0, v, z), (-1, 0, 0))
            if loc is None:
                continue
            pts.append(loc - nrm * 0.012)
        if len(pts) >= 2:
            tube(details, pts, 0.0028, "trim_gloss", segs=4)

# ---- number plates (blank), mirrors, handles, wipers, aerial fin, third brake light, exhausts ------------
def surface_frame(loc, nrm, up=Vector((0, 0, 1))):
    z = nrm.normalized()
    x = up.cross(z).normalized()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_4x4()


def plate(u_dir, z):
    loc, nrm = hit((3.0 * u_dir, 0.0, z), (-u_dir, 0, 0))
    if loc is None:
        return
    F = Matrix.Translation(loc) @ surface_frame(loc, nrm)
    t = bmesh.new()
    rbox(t, (0, 0, 0), (0.11, 0.535, 0.010), "trim_gloss", 0.004, 2)
    rbox(t, (0, 0, 0.004), (0.104, 0.52, 0.006), "plate", 0.003, 2)
    for v in t.verts:
        v.co = F @ Vector((v.co.x, v.co.y, v.co.z + 0.002))
    copy_into(details, t)
    t.free()


plate(1, 0.392)
plate(-1, 0.703)


def handle(u, sgn):
    loc, nrm = hit((u, sgn * 1.4, 0.896), (0, -sgn, 0))
    if loc is None:
        return
    F = Matrix.Translation(loc) @ surface_frame(loc, nrm)
    t = bmesh.new()
    rbox(t, (0, 0, 0), (0.026, 0.165, 0.024), "car_paint", 0.010, 3)
    for v in t.verts:
        v.co = F @ Vector((v.co.x, v.co.y, v.co.z + 0.004))
    copy_into(details, t)
    t.free()


for sgn in (1, -1):
    handle(0.05, sgn)
    handle(-0.86, sgn)


def mirror(sgn):
    t = bmesh.new()
    bmesh.ops.create_uvsphere(t, u_segments=24, v_segments=14, radius=1.0)
    m = 3.2
    for v in t.verts:
        x, y, z = v.co
        f = lambda s: math.copysign(abs(s) ** (2 / m), s)
        lat, fwd, up = f(x) * 0.100, f(y) * 0.052, f(z) * 0.058
        if fwd < -0.018:
            fwd = -0.018
        lat -= 0.010 * (up / 0.064) ** 2                     # a little sweep at the tips
        v.co = Vector((lat, fwd, up))
    for f_ in t.faces:
        f_.smooth = True
        c = f_.calc_center_median()
        f_.material_index = MI["car_paint"]
        if c.y < -0.0175:
            f_.material_index = MI["trim_gloss"]
        elif c.x > 0.060 and c.y > 0.028 and -0.026 < c.z < -0.010:
            f_.material_index = MI["lamp_indicator"]
    g = bmesh.new()                                           # the mirror glass on the back face
    ring = []
    for i in range(32):
        a = 2 * math.pi * i / 32
        cx, sz = math.cos(a), math.sin(a)
        ring.append(Vector((math.copysign(abs(cx) ** (2 / 3.4), cx) * 0.090, -0.0195, math.copysign(abs(sz) ** (2 / 3.4), sz) * 0.049)))
    gv = [g.verts.new(p) for p in ring]
    gf = g.faces.new(gv)
    gf.material_index = MI["chrome"]
    copy_into(t, g)
    g.free()
    rbox(t, (-0.005, 0.090, -0.048), (0.050, 0.060, 0.022), "trim_black", 0.008, 2)   # foot on the door
    M = Matrix.Translation(cb(0.80, sgn * 0.975, 1.045)) @ Matrix.Rotation(math.radians(-6 * sgn), 4, 'Z')
    for v in t.verts:
        co = v.co.copy()
        if sgn < 0:
            co.x = -co.x
        v.co = M @ Vector((-co.x, co.y, co.z))
    if sgn > 0:
        bmesh.ops.reverse_faces(t, faces=t.faces)
    copy_into(details, t)
    t.free()


mirror(1)
mirror(-1)


def wiper(v0, length, du):
    pts_arm, pts_blade = [], []
    for i in range(13):
        t = i / 12
        v = v0 - length * t
        u = 0.885 - du * t
        loc, nrm = hit((u, v, 2.0), (0, 0, -1))
        if loc is None:
            continue
        pts_blade.append(loc + nrm * 0.007)
        if t < 0.72:
            pts_arm.append(loc + nrm * 0.016)
    if len(pts_blade) > 1:
        tube(details, pts_blade, 0.0045, "trim_black", segs=5)
    if len(pts_arm) > 1:
        tube(details, pts_arm, 0.0055, "trim_black", segs=5)
    loc, nrm = hit((0.905, v0, 2.0), (0, 0, -1))
    if loc:
        lathe(details, [(0.0, 0.016), (0.012, 0.014), (0.015, 0.0), (0.015, -0.01)], 12, "trim_black",
              Matrix.Translation(loc) @ surface_frame(loc, nrm, Vector((0, 1, 0))) @ Matrix.Rotation(-math.pi / 2, 4, 'Y'))


wiper(0.50, 0.62, 0.05)
wiper(-0.06, 0.50, 0.04)

# aerial fin on the roof, towards the back
fin_rings = []
for i in range(11):
    t = i / 10
    u = -0.70 - 0.17 * t
    loc, nrm = hit((u, 0.0, 2.0), (0, 0, -1))
    h = 0.008 + 0.040 * math.sin(min(t * 1.25, 1) * math.pi / 2) * (1 - smooth(0.85, 1.0, t) * 0.85)
    w = 0.030 * (1 - 0.6 * t)
    zb = loc.z - 0.004
    ring = []
    for j in range(10):
        a = math.pi * j / 9
        ring.append(Vector((-math.cos(a) * w * (0.4 + 0.6 * math.sin(a) ** 0.3), u, zb + h * math.sin(a))))
    fin_rings.append(ring)
loft(details, fin_rings, "trim_gloss", closed=True, cap=True)

# third brake light at the top of the rear screen
loc, nrm = hit((-0.985, 0.0, 2.0), (0, 0, -1))
if loc:
    F = Matrix.Translation(loc) @ surface_frame(loc, nrm, Vector((0, 1, 0)))
    t = bmesh.new()
    rbox(t, (0, 0, 0.002), (0.016, 0.42, 0.010), "trim_gloss", 0.004, 2)
    rbox(t, (-0.006, 0, 0.003), (0.006, 0.38, 0.006), "lamp_brake", 0.002, 1)
    for v in t.verts:
        v.co = F @ Vector((v.co.x, v.co.y, v.co.z))
    copy_into(details, t)
    t.free()

# twin exhaust tips under the right-hand side of the rear bumper
for v0 in (-0.46, -0.56):
    M = Matrix.Translation(cb(-2.395, v0, 0.312)) @ Matrix.Rotation(-math.pi / 2, 4, 'Z')
    lathe(details, [(0.032, 0.0), (0.036, 0.0), (0.038, -0.004), (0.038, -0.16)], 24, "chrome", M)
    lathe(details, [(0.030, -0.13), (0.030, -0.002), (0.032, 0.0)], 24, "trim_black", M)

# brake calipers: fixed to the body at the top of each disc, so they never spin. The driving code moves and
# steers only the wheel, so the caliper sits centred over the steering axis (78-102 degrees), radially midway
# between the hub and the rim barrel, and thin enough to stay clear of the spokes: it clears the rim at full
# lock and about +-3 cm of suspension travel (a BVH overlap test against rim and tyre at +-0.56 rad and
# +-3 cm showed no contact; at +-5 cm it touches, the disc edge always runs inside the caliper, hidden).
for axle in (AXLE_F, AXLE_R):
    for sgn in (1, -1):
        rings = []
        for i in range(9):
            ps = math.radians(78 + 24 * i / 8)
            ring = []
            for r, d in ((0.115, -0.032), (0.115, 0.020), (0.122, 0.025), (0.178, 0.025), (0.185, 0.020), (0.185, -0.032), (0.178, -0.037), (0.122, -0.037)):
                ring.append(cb(axle + r * math.cos(ps), sgn * (TRACK + d), WHEEL_R + r * math.sin(ps)))
            rings.append(ring)
        fs = loft(details, rings, "caliper", closed=True, cap=True)
        if sgn < 0:
            bmesh.ops.reverse_faces(details, faces=fs)

details_ob = new_object("details", details, smooth_all=False)
lens_ob = new_object("lamp_lens", lens_bm)

# ---- wheels -----------------------------------------------------------------------------------------------
def tyre_profile():
    p = [(0.248, -0.102), (0.258, -0.108), (0.276, -0.1155), (0.296, -0.1175), (0.314, -0.114), (0.327, -0.105), (0.333, -0.093), (0.335, -0.081)]
    for g in (-0.062, -0.021, 0.021, 0.062):
        p += [(0.335, g - 0.0062), (0.3295, g - 0.0045), (0.3285, g), (0.3295, g + 0.0045), (0.335, g + 0.0062)]
    p += [(0.335, 0.081), (0.333, 0.093), (0.327, 0.105), (0.314, 0.114), (0.296, 0.1175), (0.276, 0.1155), (0.262, 0.111), (0.256, 0.1105), (0.248, 0.102)]
    return p


def make_wheel(name, sgn):
    bm = bmesh.new()
    S = 64
    lathe(bm, tyre_profile()[::-1], S, "rubber")
    lathe(bm, [(0.242, 0.100), (0.2505, 0.1035), (0.249, 0.1085), (0.238, 0.1075), (0.229, 0.1025), (0.223, 0.094), (0.219, 0.05),
               (0.217, -0.07), (0.224, -0.098), (0.242, -0.102)][::-1], S, "alloy")
    lathe(bm, [(0.0, 0.069), (0.026, 0.068), (0.031, 0.064), (0.036, 0.061), (0.074, 0.060), (0.080, 0.052), (0.080, 0.025)], S, "alloy")
    # disc: friction ring and hat, inboard of the spokes; it turns with the wheel as a real one does
    lathe(bm, [(0.070, 0.058), (0.088, 0.056), (0.088, 0.017), (0.175, 0.017), (0.176, 0.003), (0.175, -0.011), (0.088, -0.011), (0.075, -0.006)], S, "metal_dark")
    for k in range(5):                                        # five twin spokes
        for off in (-0.118, 0.118):
            th = 2 * math.pi * k / 5 + off
            rings = []
            for i in range(9):
                t = i / 8
                r = lerp(0.066, 0.228, t)
                df = 0.062 + 0.037 * t ** 1.3
                w = lerp(0.031, 0.021, t)
                dep = lerp(0.030, 0.022, t)
                sec = [(-w / 2, df - 0.003), (-w / 2 + 0.003, df), (w / 2 - 0.003, df), (w / 2, df - 0.003), (w * 0.36, df - dep), (-w * 0.36, df - dep)]
                ring = []
                for tt, dd in sec:
                    a = th + tt / r
                    ring.append(Vector((dd, r * math.cos(a), r * math.sin(a))))
                rings.append(ring)
            loft(bm, rings, "alloy", closed=True)
    for k in range(5):                                        # wheel nuts between the spoke pairs
        a = 2 * math.pi * (k + 0.5) / 5
        M = Matrix.Translation(Vector((0.0, 0.050 * math.cos(a), 0.050 * math.sin(a))))
        lathe(bm, [(0.0, 0.072), (0.0075, 0.071), (0.0085, 0.066), (0.0085, 0.058)], 6, "chrome", M)
    if sgn > 0:                                               # left wheels: the outer face looks towards +v (Blender -x)
        bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    ob = new_object(name, bm)
    return ob


for nm, axle, sgn in (("wheel_fl", AXLE_F, 1), ("wheel_fr", AXLE_F, -1), ("wheel_rl", AXLE_R, 1), ("wheel_rr", AXLE_R, -1)):
    w = make_wheel(nm, sgn)
    w.location = cb(axle, sgn * TRACK, WHEEL_R)

# ---- interior: enough of a cabin that the glass does not show a hollow shell ------------------------------
cab = bmesh.new()
src = bmesh.new()
src.from_mesh(body.data)
src.normal_update()
keep = []
for f in src.faces:
    u, v, z = cu(f.calc_center_median())
    if f.material_index in (MI["car_paint"], MI["trim_gloss"]) and z > 0.99 and abs(v) < 0.79 and U_RB - 0.02 < u < U_CW + 0.02:
        keep.append(f)
vm = {}
for f in keep:
    vs = []
    for v in f.verts:
        if v not in vm:
            vm[v] = cab.verts.new(v.co - v.normal * 0.016)
        vs.append(vm[v])
    try:
        nf = cab.faces.new(vs[::-1])
    except ValueError:
        continue
    u, v, z = cu(f.calc_center_median())
    nf.material_index = MI["headliner"] if (z > 1.30 and abs(v) < 0.62) else MI["interior"]
src.free()

for sgn in (1, -1):                                           # door cards and rear quarter trims
    rings = []
    for i in range(23):
        u = lerp(-1.86, 0.88, i / 22)
        zg = spline(ZGK, min(max(u, U_RB), U_CW))
        arm = smooth(-1.05, -0.85, u)
        vg = spline(VGK, min(max(u, U_RB), U_CW))
        sec = [(vg - 0.04, 0.28), (vg - 0.042, 0.52), (vg - 0.042 - 0.045 * arm, 0.60), (vg - 0.042 - 0.045 * arm, 0.625),
               (vg - 0.035, 0.66), (vg - 0.03, 0.88), (vg - 0.017, zg - 0.03), (vg - 0.004, zg - 0.002)]
        rings.append([cb(u, sgn * vv, zz) for vv, zz in sec])
    fs = loft(cab, rings, "interior", closed=False, cap=False)
    if sgn < 0:
        bmesh.ops.reverse_faces(cab, faces=fs)

dash = []                                                     # dashboard, lofted across the car
for i in range(17):
    v = lerp(-0.76, 0.76, i / 16)
    hump = 0.035 * math.exp(-((v - 0.37) / 0.16) ** 2)
    sec = [(0.93, 0.972), (0.72, 0.985 + hump * 0.4), (0.56, 0.965 + hump), (0.50, 0.935 + hump), (0.47, 0.86), (0.48, 0.74),
           (0.56, 0.62), (0.70, 0.50), (0.84, 0.36), (0.88, 0.28)]
    dash.append([cb(uu, v, zz) for uu, zz in sec])
loft(cab, dash, "interior", closed=False, cap=False)
rbox(cab, (0.52, 0.37, 0.99), (0.012, 0.30, 0.085), "trim_gloss", 0.004, 2, tilt=-62)        # instrument display
rbox(cab, (0.50, 0.0, 0.93), (0.012, 0.26, 0.15), "trim_gloss", 0.006, 2, tilt=-72)          # centre screen
rbox(cab, (0.0, 0.0, 0.42), (0.90, 0.20, 0.24), "interior", 0.04, 3)                          # centre console
rbox(cab, (-0.25, 0.0, 0.57), (0.30, 0.18, 0.06), "interior", 0.025, 3)                       # armrest
floor = [[cb(u, v, 0.29) for v in (-0.76, 0.76)] for u in (-1.30, 0.88)]
loft(cab, floor, "interior", closed=False)

for sv in (0.37, -0.37):                                      # front seats
    rbox(cab, (-0.06, sv, 0.46), (0.52, 0.50, 0.10), "interior", 0.04, 3, tilt=-6)
    for bo in (-0.215, 0.215):
        rbox(cab, (-0.06, sv + bo, 0.50), (0.48, 0.08, 0.08), "interior", 0.035, 3, tilt=-6)
    rbox(cab, (-0.40, sv, 0.80), (0.12, 0.50, 0.62), "interior", 0.045, 3, tilt=21)
    for bo in (-0.22, 0.22):
        rbox(cab, (-0.37, sv + bo, 0.78), (0.10, 0.08, 0.52), "interior", 0.035, 3, tilt=21)
    rbox(cab, (-0.53, sv, 1.18), (0.09, 0.26, 0.17), "interior", 0.04, 3, tilt=14)
    rbox(cab, (-0.08, sv, 0.34), (0.40, 0.36, 0.10), "trim_black", 0.02, 2)
rbox(cab, (-0.82, 0.0, 0.45), (0.50, 1.34, 0.11), "interior", 0.045, 3, tilt=-5)             # rear bench
rbox(cab, (-1.16, 0.0, 0.76), (0.13, 1.34, 0.56), "interior", 0.05, 3, tilt=22)
for sv in (0.42, -0.42):
    rbox(cab, (-1.28, sv, 1.08), (0.09, 0.24, 0.13), "interior", 0.04, 3, tilt=18)
shelf = [[cb(u, v, 1.0) for v in (-0.76, 0.76)] for u in (-1.88, -1.24)]
loft(cab, shelf, "interior", closed=False)

# steering wheel (the car is left-hand drive: the driver gets out on the left)
SW = Matrix.Translation(cb(0.36, 0.37, 0.88)) @ Matrix.Rotation(math.radians(156), 4, 'X') @ Matrix.Rotation(math.pi / 2, 4, 'Z')
rim = []
for i in range(41):
    a = 2 * math.pi * i / 40
    rim.append(SW @ Vector((0.0, 0.182 * math.cos(a), 0.182 * math.sin(a))))
tube(cab, rim[:-1] + [rim[0]], 0.016, "interior", segs=10)
for a in (0.0, math.pi, math.pi / 2):
    tube(cab, [SW @ Vector((0.012, 0.05 * math.cos(a), 0.05 * math.sin(a))), SW @ Vector((0.004, 0.17 * math.cos(a), 0.17 * math.sin(a)))], 0.012, "interior", segs=6)
lathe(cab, [(0.0, 0.035), (0.05, 0.03), (0.062, 0.015), (0.062, -0.02), (0.03, -0.05), (0.03, -0.20)], 20, "interior", SW)
cab_ob = new_object("interior", cab)

# ---- materials ---------------------------------------------------------------------------------------
def principled(name, color, rough, metal=0.0, coat=0.0, alpha=1.0, emit=None):
    m = bpy.data.materials[name]
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.03
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = 'BLENDED'
        m.use_backface_culling = False
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 0.0      # lamps are off in the file; the game switches them
    m["emit"] = emit or (0, 0, 0)


principled("car_paint", (0.085, 0.13, 0.19), 0.30, metal=0.7, coat=1.0)    # slate blue metallic
principled("glass", (0.025, 0.03, 0.033), 0.03, alpha=0.40)
principled("trim_black", (0.011, 0.011, 0.012), 0.65)
principled("trim_gloss", (0.010, 0.010, 0.011), 0.10)
principled("chrome", (0.90, 0.90, 0.92), 0.06, metal=1.0)
principled("rubber", (0.014, 0.014, 0.014), 0.90)
principled("alloy", (0.60, 0.61, 0.63), 0.26, metal=1.0)
principled("interior", (0.035, 0.034, 0.033), 0.72)
principled("headliner", (0.28, 0.27, 0.25), 0.92)
principled("metal_dark", (0.15, 0.15, 0.155), 0.48, metal=1.0)      # cast-iron discs: dark, not polished
principled("caliper", (0.045, 0.045, 0.05), 0.38)
principled("plate", (0.55, 0.55, 0.54), 0.35)
principled("lamp_lens", (0.015, 0.015, 0.017), 0.02, alpha=0.20)   # clear: reflections, no milky haze
principled("lamp_head", (0.85, 0.86, 0.88), 0.12, emit=(1.0, 0.97, 0.92))
principled("lamp_tail", (0.20, 0.004, 0.006), 0.12, emit=(1.0, 0.03, 0.01))
principled("lamp_brake", (0.26, 0.006, 0.008), 0.12, emit=(1.0, 0.02, 0.01))
principled("lamp_reverse", (0.13, 0.13, 0.135), 0.10, emit=(1.0, 1.0, 1.0))
principled("lamp_indicator", (0.17, 0.065, 0.010), 0.12, emit=(1.0, 0.45, 0.02))

for ob in bpy.data.objects:
    if ob.type == 'MESH':
        ob.data.set_sharp_from_angle(angle=math.radians(40))

# ---- numbers -----------------------------------------------------------------------------------------
tris, used = 0, set()
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    tris += t
    bm = bmesh.new()
    bm.from_mesh(o.data)
    opened = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    used |= {o.data.materials[p.material_index].name for p in o.data.polygons}
    print("CAR part %-10s tris %6d verts %6d open-edges %d" % (o.name, t, len(o.data.vertices), opened))
print("CAR triangles", tris)
print("CAR materials", sorted(used))
bpy.context.view_layer.update()
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name != "details":
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
print("CAR size (width, length, height)", tuple(round(x, 3) for x in (hi - lo)), "from", tuple(round(x, 3) for x in lo))
os.makedirs(os.path.join(ASSET, "source"), exist_ok=True)
os.makedirs(os.path.join(ASSET, "export"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET, "source", "sedan_a.blend"), relative_remap=True, compress=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ASSET, "export", "sedan_a.glb"), export_format='GLB', export_apply=True,
                          export_yup=True, export_texcoords=False, export_cameras=False, export_lights=False)
print("EXPORTED", os.path.getsize(os.path.join(ASSET, "export", "sedan_a.glb")) // 1024, "KB")

# ---- review pictures ---------------------------------------------------------------------------------
if STUDIO or NIGHT:
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 6
    sc.view_settings.view_transform = 'AgX'
    try:
        sc.view_settings.look = 'AgX - Medium High Contrast'
    except TypeError:
        pass
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gb = gm.node_tree.nodes["Principled BSDF"]
    pm = bpy.data.meshes.new("ground")
    pm.from_pydata([(-60, -60, 0), (60, -60, 0), (60, 60, 0), (-60, 60, 0)], [], [(0, 1, 2, 3)])
    pm.materials.append(gm)
    sc.collection.objects.link(bpy.data.objects.new("ground", pm))

    def light(kind, loc, target, power, size, color=(1, 1, 1), size_y=None, spot=None):
        l = bpy.data.lights.new("l", kind)
        l.energy, l.color = power, color
        if kind == 'AREA':
            if size_y:
                l.shape, l.size, l.size_y = 'RECTANGLE', size, size_y
            else:
                l.size = size
        else:
            l.shadow_soft_size = size
        if spot:
            l.spot_size, l.spot_blend = math.radians(spot), 0.5
        o = bpy.data.objects.new("l", l)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

    lit = {}
    if STUDIO:                                                # neutral studio: long soft strips show the surfacing
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.205, 0.21, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
        gb.inputs["Base Color"].default_value = (0.16, 0.16, 0.165, 1)
        gb.inputs["Roughness"].default_value = 0.55
        light('AREA', (0.0, 0.0, 4.2), (0, 0, 0), 900, 1.2, size_y=7.0)
        light('AREA', (5.0, 1.5, 2.4), (0, 0, 0.6), 700, 0.8, size_y=6.0)
        light('AREA', (-5.0, -1.0, 2.6), (0, 0, 0.6), 450, 0.8, size_y=6.0)
        light('AREA', (0.5, 7.0, 2.0), (0, 0, 0.6), 300, 3.0)
        light('AREA', (-0.5, -7.0, 2.0), (0, 0, 0.6), 300, 3.0)
        lit = {"lamp_head": 3.0, "lamp_tail": 2.0}
    else:                                                     # a wet street at night
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.005, 0.008, 1)
        gb.inputs["Base Color"].default_value = (0.02, 0.02, 0.022, 1)
        gb.inputs["Roughness"].default_value = 0.18
        light('SPOT', (-3.0, 1.0, 7.5), (0.0, 0.4, 0.3), 9000, 0.25, (1.0, 0.86, 0.66), spot=95)
        light('AREA', (5.0, 6.0, 2.2), (0.0, 0.0, 0.8), 600, 5.0, (0.45, 0.60, 1.0))
        light('AREA', (-6.0, -5.0, 3.0), (0.0, 0.0, 0.9), 260, 4.0, (1.0, 0.35, 0.45))
        light('AREA', (6.5, -3.0, 2.5), (0.0, 0.0, 0.8), 300, 4.0, (0.9, 0.85, 0.8))
        lit = {"lamp_head": 8.0, "lamp_tail": 3.0}
    for name, s in lit.items():
        m = bpy.data.materials[name]
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = s
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    os.makedirs(os.path.join(ASSET, "review"), exist_ok=True)
    res = (640, 360) if QUICK else (1600, 900)

    def shot(name, loc, target, lens, ortho=None):
        cam.location = loc
        cam.data.lens = lens
        cam.data.type = 'ORTHO' if ortho else 'PERSP'
        if ortho:
            cam.data.ortho_scale = ortho
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        if name == "top":
            cam.rotation_euler = (0.0, 0.0, math.pi / 2)
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.use_stamp_filename = False      # keep the machine's file path out of the picture's metadata
        sc.render.filepath = os.path.join(ASSET, "review", ("studio_" if STUDIO else "look_") + name + ".png")
        bpy.ops.render.render(write_still=True)
        print("SHOT", name)

    shot("front34", (4.0, 5.6, 1.45), (0.0, 0.25, 0.62), 50)
    shot("side", (9.0, 0.0, 0.75), (0.0, 0.0, 0.75), 50, ortho=5.3)
    shot("rear34", (-3.8, -5.8, 1.6), (0.0, -0.3, 0.62), 50)
    if "--all" in ARGS:
        shot("front", (0.0, 9.0, 0.75), (0.0, 0.0, 0.75), 50, ortho=2.6)
        shot("wheel", (2.1, 3.4, 0.55), (0.75, 1.55, 0.45), 50)
        shot("interior", (2.9, -0.25, 1.30), (0.0, 0.0, 0.80), 30)
        shot("top", (0.0, 0.0, 9.0), (0.0, 0.0, 0.0), 50, ortho=5.2)
