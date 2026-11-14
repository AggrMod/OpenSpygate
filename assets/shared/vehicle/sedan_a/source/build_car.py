"""Builds a modern four-door saloon of our own design. No real make, no badges.

    blender -b -P build_car.py -- <asset_dir> [--render]

The body is one surface lofted from side-view and plan-view curves, so every proportion is a number below.
Car space: u forward, v to the car's left, z up, metres, origin on the ground under the centre.
Blender: x = -v, y = u, so the exported car faces -Z in the game.
Writes source/sedan_a.blend, export/sedan_a.glb and, with --render, review/look_*.png.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
ASSET = ARGS[0]
RENDER = "--render" in ARGS

L, HALF_W = 4.66, 0.925
NOSE, TAIL = L / 2, -L / 2
AXLE_F, AXLE_R = 1.42, -1.36
WHEEL_R, WHEEL_W, TRACK = 0.335, 0.225, 0.80
ARCH_R = 0.385

TOP = [(-2.33, 0.80), (-2.26, 0.97), (-1.86, 1.07), (-1.08, 1.36), (-0.30, 1.435), (0.28, 1.40),
       (1.02, 1.00), (1.75, 0.88), (2.18, 0.76), (2.33, 0.58)]          # roof, bonnet and boot line


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


def half_width(u):
    w = HALF_W - 0.045 * (abs(u) / NOSE) ** 3
    reach = 0.50 if u > 0 else 0.42                       # how far back the corner rounding starts
    d = (abs(u) - (NOSE - reach)) / reach
    if d > 0:
        w *= max(1.0 - d ** 2.6, 0.0) ** (1 / 2.6)
    return w


def section(u):
    """One cross-section from the bottom centre round the left side to the top centre: [(v, z)]."""
    w = max(half_width(u) - 0.03, 0.02)
    z0 = 0.19 + 0.11 * smooth(1.75, NOSE, abs(u))
    zt = spline(TOP, u)
    belt = 0.985 + 0.045 * smooth(1.05, -1.86, u)
    zb = min(zt, belt)
    hg = zt - zb                                           # height of the glasshouse here; zero over bonnet and boot
    inset = 0.21 * smooth(0.0, 0.30, hg)
    r1 = min(0.075, w * 0.5)
    pts = []
    for k in range(4):                                     # floor
        pts.append((w - r1) * k / 4)
    out = [(v, z0) for v in pts]
    for k in range(4):                                     # lower corner
        a = -math.pi / 2 + math.pi / 2 * k / 4
        out.append((w - r1 + r1 * math.cos(a), z0 + r1 + r1 * math.sin(a)))
    side_top = zb - 0.055
    for k in range(8):                                     # body side, slightly barrelled
        s = k / 8
        out.append((w + 0.03 * (1 - (2 * s - 1) ** 2), z0 + r1 + (side_top - z0 - r1) * s))
    g0 = (w - 0.055, zb + 0.008)
    for k in range(3):                                     # shoulder
        t = k / 3
        a, c, b = (w, side_top), (w + 0.004, zb - 0.004), g0
        out.append(((1 - t) ** 2 * a[0] + 2 * t * (1 - t) * c[0] + t * t * b[0], (1 - t) ** 2 * a[1] + 2 * t * (1 - t) * c[1] + t * t * b[1]))
    g1 = (max(g0[0] - inset, 0.05), g0[1] + max(hg - 0.075, 0.0))
    for k in range(6):                                     # side glass
        t = k / 6
        out.append((g0[0] + (g1[0] - g0[0]) * t, g0[1] + (g1[1] - g0[1]) * t))
    r0 = (max(g1[0] - 0.10, 0.03), zt)
    for k in range(3):                                     # roof edge
        t = k / 3
        c = (g1[0] - 0.012, zt - 0.004)
        out.append(((1 - t) ** 2 * g1[0] + 2 * t * (1 - t) * c[0] + t * t * r0[0], (1 - t) ** 2 * g1[1] + 2 * t * (1 - t) * c[1] + t * t * r0[1]))
    for k in range(7):                                     # roof, bonnet or boot lid, with a crown
        t = k / 6
        v = r0[0] * (1 - t)
        out.append((v, zt + 0.032 * (1 - (v / r0[0]) ** 2)))
    return out


SEG = {"floor": range(0, 4), "sill": range(4, 8), "side": range(8, 16), "shoulder": range(16, 19),
       "glass": range(19, 25), "edge": range(25, 28), "top": range(28, 35)}


def seg_of(j):
    for name, r in SEG.items():
        if j in r:
            return name
    return "top"


def material_for(seg, u, v, z, j=0):
    if seg in ("floor",):
        return "car_trim"
    if seg == "sill" or z < 0.30:
        return "car_trim"
    if seg == "glass" and -1.84 < u < 1.0:
        if u > 0.22 or u < -1.18 or -0.44 < u < -0.33:      # screen pillar, rear pillar, centre pillar
            return "car_paint"
        return "car_glass"
    if seg == "top" and ((0.33 < u < 0.98) or (-1.80 < u < -1.12)):
        return "car_glass"                                  # windscreen and rear window
    if j in (12, 13) and u > 1.93 and abs(v) > 0.30:
        return "car_light_head"                             # slim lamps that wrap round the corners
    if j in (13, 14) and u < -2.05:
        return "car_light_tail"                             # a full-width light bar
    if seg == "side" and u > 2.2 and 0.30 < z < 0.50 and abs(v) < 0.62:
        return "car_trim"                                   # lower intake
    return "car_paint"


MATS = ["car_paint", "car_glass", "car_trim", "car_light_head", "car_light_tail", "car_tire", "car_rim", "car_plate"]

bpy.ops.wm.read_factory_settings(use_empty=True)
for m in MATS:
    bpy.data.materials.new(m)
root = bpy.data.objects.new("sedan_a", None)
bpy.context.scene.collection.objects.link(root)


def to_blender(u, v, z):
    return Vector((-v, u, z))


# ---- body ----------------------------------------------------------------------------------------
stations = []
n_mid = 44
for k in range(n_mid + 1):                                  # cosine spacing packs stations into the rounded ends
    t = 0.5 - 0.5 * math.cos(math.pi * k / n_mid)
    stations.append(TAIL + 0.004 + (L - 0.008) * t)
bm = bmesh.new()
grid = []
for u in stations:
    grid.append([bm.verts.new(to_blender(u, v, z)) for v, z in section(u)])
mirror = []
for i, u in enumerate(stations):
    row = []
    for j, (v, z) in enumerate(section(u)):
        row.append(grid[i][j] if abs(v) < 1e-6 else bm.verts.new(to_blender(u, -v, z)))
    mirror.append(row)
n_pts = len(grid[0])
face_mat = {}
for i in range(len(stations) - 1):
    um = (stations[i] + stations[i + 1]) / 2
    sa, sb = section(stations[i]), section(stations[i + 1])
    for j in range(n_pts - 1):
        vm = (sa[j][0] + sa[j + 1][0] + sb[j][0] + sb[j + 1][0]) / 4
        zm = (sa[j][1] + sa[j + 1][1] + sb[j][1] + sb[j + 1][1]) / 4
        mat = MATS.index(material_for(seg_of(j), um, vm, zm, j))
        for g, flip in ((grid, False), (mirror, True)):
            q = [g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]]
            if len(set(q)) < 4:
                continue
            try:
                f = bm.faces.new(q[::-1] if flip else q)
                f.material_index = mat
            except ValueError:
                pass
for i in (0, len(stations) - 1):                            # close the ends
    loop = grid[i] + mirror[i][-2:0:-1]
    try:
        f = bm.faces.new(loop if i else loop[::-1]); f.material_index = MATS.index("car_trim")
    except ValueError:
        pass
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
for f in bm.faces:
    f.smooth = True
me = bpy.data.meshes.new("body")
bm.to_mesh(me); bm.free()
for m in MATS:
    me.materials.append(bpy.data.materials[m])
body = bpy.data.objects.new("body", me)
bpy.context.scene.collection.objects.link(body)
body.parent = root


def apply(ob, mod):
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier=mod.name)


sub = body.modifiers.new("smooth", 'SUBSURF'); sub.levels = 2; sub.render_levels = 2
apply(body, sub)

# door shut lines: slice a 5 mm strip at each line and make it dark
SEAMS = [1.00, -0.385, -1.32]
bm = bmesh.new(); bm.from_mesh(body.data)
for su in SEAMS:
    for off in (-0.0025, 0.0025):
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, su + off, 0), plane_no=(0, 1, 0))
paint, dark = MATS.index("car_paint"), MATS.index("car_trim")
for f in bm.faces:
    c = f.calc_center_median()
    if f.material_index == paint and abs(c.x) > 0.55 and 0.31 < c.z < 1.0:
        if any(abs(c.y - su) < 0.0024 for su in SEAMS):
            f.material_index = dark
bm.to_mesh(body.data); bm.free()

# wheel arches: a pocket each side, not a tunnel through the car
for axle in (AXLE_F, AXLE_R):
    for side in (-1, 1):
        cb = bmesh.new()
        bmesh.ops.create_cone(cb, cap_ends=True, segments=48, radius1=ARCH_R, radius2=ARCH_R, depth=0.62,
                              matrix=Matrix.Translation(to_blender(axle, side * (0.52 + 0.31), WHEEL_R + 0.015)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
        cm = bpy.data.meshes.new("cut"); cb.to_mesh(cm); cb.free()
        cut = bpy.data.objects.new("cut", cm); bpy.context.scene.collection.objects.link(cut)
        mod = body.modifiers.new("arch", 'BOOLEAN'); mod.operation = 'DIFFERENCE'; mod.solver = 'EXACT'; mod.object = cut
        apply(body, mod)
        bpy.data.objects.remove(cut)
# the cut faces inherit paint; make the pockets black plastic
trim = MATS.index("car_trim")
bm = bmesh.new(); bm.from_mesh(body.data)
for f in bm.faces:
    c = f.calc_center_median()
    u, v, z = c.y, -c.x, c.z
    for axle in (AXLE_F, AXLE_R):
        d = math.hypot(u - axle, z - (WHEEL_R + 0.015))
        if d < ARCH_R + 0.004 and abs(v) > 0.50 and abs(f.normal.x) < 0.985 and (d < ARCH_R - 0.03 or abs(abs(f.normal.x) - 1.0) > 0.2):
            if abs(Vector((f.normal.y, f.normal.z)).length) > 0.5 or abs(v) < 0.56:
                f.material_index = trim
bm.to_mesh(body.data); bm.free()

# ---- wheels --------------------------------------------------------------------------------------
def lathe_y(profile, segs=40):
    """Revolve [(radius, offset along the axle)] round the X axis of a wheel centred on the origin."""
    verts, faces = [], []
    for r, d in profile:
        for s in range(segs):
            a = 2 * math.pi * s / segs
            verts.append(Vector((d, r * math.cos(a), r * math.sin(a))))
    for i in range(len(profile) - 1):
        for s in range(segs):
            s2 = (s + 1) % segs
            faces.append((i * segs + s, i * segs + s2, (i + 1) * segs + s2, (i + 1) * segs + s))
    return verts, faces


def make_wheel(name, side):
    hw = WHEEL_W / 2
    tire = [(0.232, -hw + 0.012), (0.275, -hw), (0.315, -hw + 0.012), (WHEEL_R - 0.006, -hw + 0.034), (WHEEL_R, -hw + 0.06),
            (WHEEL_R, hw - 0.06), (WHEEL_R - 0.006, hw - 0.034), (0.315, hw - 0.012), (0.275, hw), (0.232, hw - 0.012)]
    rim = [(0.232, hw - 0.012), (0.224, hw - 0.03), (0.215, hw - 0.05), (0.20, hw - 0.075), (0.07, hw - 0.085), (0.05, hw - 0.06), (0.0, hw - 0.055)]
    barrel = [(0.232, -hw + 0.012), (0.215, -hw + 0.03), (0.215, hw - 0.05)]
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    def add(profile, mat, flip=False):
        v, f = lathe_y(profile)
        vs = [bm.verts.new(p) for p in v]
        for q in f:
            face = bm.faces.new([vs[i] for i in (q[::-1] if flip else q)]); face.material_index = mat; face.smooth = True
    add(tire, 0); add(rim, 1); add(barrel, 1, True)
    # five split spokes
    for k in range(5):
        for off in (-0.085, 0.085):
            a = 2 * math.pi * k / 5 + off
            sp = bmesh.new()
            bmesh.ops.create_cube(sp, size=1.0)
            for v in sp.verts:
                v.co = Vector((v.co.x * 0.022 + hw - 0.062, v.co.y * 0.026, v.co.z * 0.150 + 0.135))
            bmesh.ops.bevel(sp, geom=list(sp.edges), offset=0.006, segments=2, affect='EDGES')
            rot = Matrix.Rotation(a, 4, 'X')
            vs = [bm.verts.new(rot @ v.co) for v in sp.verts]
            for f in sp.faces:
                face = bm.faces.new([vs[v.index] for v in f.verts]); face.material_index = 1; face.smooth = True
            sp.free()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if side > 0:
        bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    me.materials.append(bpy.data.materials["car_tire"]); me.materials.append(bpy.data.materials["car_rim"])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = root
    return ob


for nm, axle, side in (("wheel_fl", AXLE_F, 1), ("wheel_fr", AXLE_F, -1), ("wheel_rl", AXLE_R, 1), ("wheel_rr", AXLE_R, -1)):
    w = make_wheel(nm, side)
    w.location = to_blender(axle, side * TRACK, WHEEL_R)

# ---- small parts: mirrors and number plates (blank) ------------------------------------------------
def box_part(name, lo, hi, mat, bevel=0.01, segs=3):
    lo, hi = Vector(lo), Vector(hi)
    lo, hi = Vector(map(min, lo, hi)), Vector(map(max, lo, hi))
    b = bmesh.new(); bmesh.ops.create_cube(b, size=1.0)
    size, mid = hi - lo, (lo + hi) / 2
    for v in b.verts:
        v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) + mid
    bmesh.ops.bevel(b, geom=list(b.edges), offset=min(bevel, min(abs(s) for s in size) * 0.45), segments=segs, affect='EDGES')
    for f in b.faces:
        f.smooth = True
    me = bpy.data.meshes.new(name); b.to_mesh(me); b.free()
    me.materials.append(bpy.data.materials[mat])
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob); ob.parent = root
    return ob


for side, tag in ((1, "l"), (-1, "r")):
    mw = half_width(0.92)
    box_part("mirror_" + tag, to_blender(0.84, side * (mw + 0.035), 1.012), to_blender(0.95, side * (mw + 0.165), 1.082), "car_paint", 0.028, 4)
    box_part("mirror_arm_" + tag, to_blender(0.87, side * (mw - 0.03), 1.016), to_blender(0.93, side * (mw + 0.05), 1.036), "car_trim", 0.006, 2)
    for hu in (-0.22, -1.16):                               # flush door handles
        hw_ = half_width(hu)
        box_part("handle_%s_%d" % (tag, int(-hu * 100)), to_blender(hu - 0.07, side * (hw_ - 0.012), 0.905), to_blender(hu + 0.07, side * (hw_ + 0.012), 0.925), "car_paint", 0.006, 2)
box_part("plate_front", to_blender(NOSE - 0.012, -0.26, 0.36), to_blender(NOSE + 0.004, 0.26, 0.47), "car_plate", 0.003, 2)
box_part("plate_rear", to_blender(TAIL - 0.004, -0.26, 0.60), to_blender(TAIL + 0.012, 0.26, 0.71), "car_plate", 0.003, 2)

# ---- materials -------------------------------------------------------------------------------------
def principled(name, color, rough, metal=0.0, coat=0.0, emit=None, strength=0.0):
    m = bpy.data.materials[name]; m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal; b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.04
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = strength


principled("car_paint", (0.012, 0.055, 0.085), 0.32, metal=0.85, coat=1.0)          # deep petrol blue
principled("car_glass", (0.006, 0.008, 0.010), 0.04)
principled("car_trim", (0.012, 0.012, 0.013), 0.55)
principled("car_light_head", (0.9, 0.9, 0.9), 0.1, emit=(1.0, 0.96, 0.88), strength=6.0)
principled("car_light_tail", (0.25, 0.0, 0.0), 0.15, emit=(1.0, 0.02, 0.01), strength=4.0)
principled("car_tire", (0.012, 0.012, 0.012), 0.82)
principled("car_rim", (0.55, 0.56, 0.58), 0.25, metal=1.0)
principled("car_plate", (0.75, 0.75, 0.72), 0.5)

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print("CAR triangles", tris)
os.makedirs(os.path.join(ASSET, "source"), exist_ok=True); os.makedirs(os.path.join(ASSET, "export"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET, "source", "sedan_a.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ASSET, "export", "sedan_a.glb"), export_format='GLB', export_apply=True, export_yup=True)
print("EXPORTED", os.path.getsize(os.path.join(ASSET, "export", "sedan_a.glb")) // 1024, "KB")

# ---- review renders: a wet street at night -----------------------------------------------------------
if RENDER:
    sc = bpy.context.scene
    w = bpy.data.worlds.new("night"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.005, 0.008, 1)
    gm = bpy.data.materials.new("asphalt"); gm.use_nodes = True
    t = gm.node_tree; b = t.nodes["Principled BSDF"]
    n1 = t.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = 0.6; n1.inputs["Detail"].default_value = 5
    n2 = t.nodes.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = 180.0; n2.inputs["Detail"].default_value = 3
    r = t.nodes.new("ShaderNodeMapRange"); r.inputs[1].default_value = 0.42; r.inputs[2].default_value = 0.60
    r.inputs[3].default_value = 0.62; r.inputs[4].default_value = 0.06                 # dry grit to standing water
    t.links.new(n1.outputs["Fac"], r.inputs[0]); t.links.new(r.outputs[0], b.inputs["Roughness"])
    bump = t.nodes.new("ShaderNodeBump"); bump.inputs["Distance"].default_value = 0.004
    mul = t.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'
    t.links.new(n2.outputs["Fac"], mul.inputs[0]); t.links.new(r.outputs[0], mul.inputs[1])
    t.links.new(mul.outputs[0], bump.inputs["Height"]); t.links.new(bump.outputs[0], b.inputs["Normal"])
    b.inputs["Base Color"].default_value = (0.018, 0.018, 0.020, 1)
    pm = bpy.data.meshes.new("ground"); pm.from_pydata([(-40, -40, 0), (40, -40, 0), (40, 40, 0), (-40, 40, 0)], [], [(0, 1, 2, 3)])
    pm.materials.append(gm)
    sc.collection.objects.link(bpy.data.objects.new("ground", pm))

    def light(kind, loc, target, power, size, color, spot=None):
        l = bpy.data.lights.new("l", kind); l.energy = power; l.color = color
        if kind == 'AREA':
            l.size = size
        else:
            l.shadow_soft_size = size
        if spot:
            l.spot_size = math.radians(spot); l.spot_blend = 0.5
        o = bpy.data.objects.new("l", l); sc.collection.objects.link(o); o.location = loc
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

    light('SPOT', (-3.0, 1.0, 7.5), (0.0, 0.4, 0.3), 9000, 0.25, (1.0, 0.86, 0.66), 95)      # street lamp
    light('AREA', (5.0, 6.0, 2.2), (0.0, 0.0, 0.8), 420, 5.0, (0.45, 0.60, 1.0))               # shop-window spill
    light('AREA', (-6.0, -5.0, 3.0), (0.0, 0.0, 0.9), 160, 4.0, (1.0, 0.35, 0.45))               # neon across the road
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 96; sc.cycles.use_denoising = True
    sc.view_settings.view_transform = 'AgX'
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam

    def shot(name, loc, target, lens, res=(1400, 800)):
        cam.location = loc; cam.data.lens = lens
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.filepath = os.path.join(ASSET, "review", "look_" + name + ".png")
        bpy.ops.render.render(write_still=True)
        print("SHOT", name)

    shot("front34", (3.6, 5.2, 1.35), (0.0, 0.2, 0.62), 50)
    if "--all" in ARGS:
        shot("side", (6.8, 0.2, 1.1), (0.0, 0.0, 0.66), 60)
    shot("rear34", (-3.4, -5.4, 1.5), (0.0, -0.3, 0.62), 50)
