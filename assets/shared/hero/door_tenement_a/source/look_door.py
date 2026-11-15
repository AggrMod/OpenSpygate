"""The door's materials and the void it stands in: look pass.

    blender -b source/door_tenement_a.blend -P source/look_door.py -- <asset_dir> [shot ...]

Every material is authored here as a procedural node graph: no downloaded textures.
Writes source/door_tenement_a_look.blend and review/look_*.png.
"""
import bpy, sys, os, math
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
ASSET = ARGS[0]
ONLY = set(ARGS[1:])

# must match build_door.py
LEAF_W, LEAF_T, SILL_H = 0.92, 0.045, 0.018
Z0 = SILL_H + 0.008
HX, HT = LEAF_W / 2, LEAF_T / 2
HANDLE_X, HANDLE_Z = -HX + 0.058, Z0 + 1.05
JAMB_D = 0.16

PAINT_TOP = (0.105, 0.046, 0.026, 1)     # dark red-brown oil paint, the last coat (period colour not yet confirmed from a source)
PAINT_UNDER = (0.56, 0.47, 0.30, 1)      # the older ochre-cream coat under it
WOOD_DARK = (0.165, 0.095, 0.048, 1)
WOOD_LIGHT = (0.37, 0.245, 0.135, 1)


class G:
    """Small helper for building a node graph."""
    def __init__(self, mat):
        mat.use_nodes = True
        self.t = mat.node_tree
        self.t.nodes.clear()
        self.out = self.t.nodes.new("ShaderNodeOutputMaterial")
        self.bsdf = self.t.nodes.new("ShaderNodeBsdfPrincipled")
        self.t.links.new(self.bsdf.outputs[0], self.out.inputs[0])
        geo = self.t.nodes.new("ShaderNodeNewGeometry")
        self.pos, self.normal = geo.outputs["Position"], geo.outputs["Normal"]
        sep = self.t.nodes.new("ShaderNodeSeparateXYZ")
        self.t.links.new(self.pos, sep.inputs[0])
        self.x, self.y, self.z = sep.outputs

    def put(self, node, key, v):
        sock = node.inputs[key]
        if hasattr(v, "node"):
            self.t.links.new(v, sock)
        else:
            sock.default_value = v

    def math(self, op, a, b=None, clamp=False):
        n = self.t.nodes.new("ShaderNodeMath"); n.operation = op; n.use_clamp = clamp
        self.put(n, 0, a)
        if b is not None:
            self.put(n, 1, b)
        return n.outputs[0]

    def add(self, a, b): return self.math('ADD', a, b)
    def sub(self, a, b): return self.math('SUBTRACT', a, b)
    def mul(self, a, b): return self.math('MULTIPLY', a, b)
    def mx(self, a, b): return self.math('MAXIMUM', a, b)
    def sat(self, a): return self.math('ADD', a, 0.0, clamp=True)

    def ramp(self, v, a, b, c=0.0, d=1.0):
        n = self.t.nodes.new("ShaderNodeMapRange"); n.interpolation_type = 'SMOOTHSTEP'; n.clamp = True
        self.put(n, "Value", v); self.put(n, "From Min", a); self.put(n, "From Max", b)
        self.put(n, "To Min", c); self.put(n, "To Max", d)
        return n.outputs[0]

    def mixf(self, f, a, b):
        n = self.t.nodes.new("ShaderNodeMix"); n.data_type = 'FLOAT'
        self.put(n, 0, f); self.put(n, 2, a); self.put(n, 3, b)
        return n.outputs[0]

    def mixc(self, f, a, b):
        n = self.t.nodes.new("ShaderNodeMix"); n.data_type = 'RGBA'
        self.put(n, 0, f); self.put(n, 6, a); self.put(n, 7, b)
        return n.outputs[2]

    def vec(self, x, y, z):
        n = self.t.nodes.new("ShaderNodeCombineXYZ")
        self.put(n, 0, x); self.put(n, 1, y); self.put(n, 2, z)
        return n.outputs[0]

    def noise(self, vec, scale, detail=4.0, rough=0.55, dist=0.0):
        n = self.t.nodes.new("ShaderNodeTexNoise")
        self.put(n, "Vector", vec); n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail; n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = dist
        return n.outputs["Fac"]

    def cracks(self, vec, scale):
        n = self.t.nodes.new("ShaderNodeTexVoronoi"); n.feature = 'DISTANCE_TO_EDGE'
        self.put(n, "Vector", vec); n.inputs["Scale"].default_value = scale
        return n.outputs["Distance"]

    def cells(self, vec, scale):
        """A random value per angular flake."""
        n = self.t.nodes.new("ShaderNodeTexVoronoi"); n.feature = 'F1'
        self.put(n, "Vector", vec); n.inputs["Scale"].default_value = scale
        sep = self.t.nodes.new("ShaderNodeSeparateColor")
        self.t.links.new(n.outputs["Color"], sep.inputs[0])
        return sep.outputs[0]

    def edge(self, radius, lo=0.015, hi=0.22):
        """1 on corners and arrises, 0 on flat faces. Works on low-poly geometry, unlike pointiness."""
        b = self.t.nodes.new("ShaderNodeBevel"); b.samples = 6
        b.inputs["Radius"].default_value = radius
        d = self.t.nodes.new("ShaderNodeVectorMath"); d.operation = 'DOT_PRODUCT'
        self.t.links.new(b.outputs[0], d.inputs[0]); self.t.links.new(self.normal, d.inputs[1])
        return self.ramp(self.sub(1.0, d.outputs["Value"]), lo, hi)

    def attr(self, name):
        n = self.t.nodes.new("ShaderNodeAttribute"); n.attribute_type = 'GEOMETRY'; n.attribute_name = name
        return n.outputs["Fac"]

    def ao(self, distance, inside=False):
        n = self.t.nodes.new("ShaderNodeAmbientOcclusion"); n.inside = inside; n.samples = 8
        n.inputs["Distance"].default_value = distance
        return n.outputs["AO"]

    def dist2d(self, cx, cz):
        dx, dz = self.sub(self.x, cx), self.sub(self.z, cz)
        return self.math('SQRT', self.add(self.mul(dx, dx), self.mul(dz, dz)))

    def finish(self, color, rough, height=None, metallic=0.0, bump_dist=0.001, bump_strength=1.0):
        self.put(self.bsdf, "Base Color", color); self.put(self.bsdf, "Roughness", rough)
        self.put(self.bsdf, "Metallic", metallic)
        if height is not None:
            b = self.t.nodes.new("ShaderNodeBump")
            b.inputs["Distance"].default_value = bump_dist; b.inputs["Strength"].default_value = bump_strength
            self.put(b, "Height", height)
            self.t.links.new(b.outputs[0], self.bsdf.inputs["Normal"])


def painted_wood(mat, seed):
    g = G(mat)
    horiz, bare = g.attr("horiz"), g.attr("bare")
    off = seed * 7.31
    # grain runs along the member: tall for stiles, across for rails
    sx, sz = g.mixf(horiz, 36.0, 1.5), g.mixf(horiz, 1.5, 36.0)
    gv = g.vec(g.add(g.mul(g.x, sx), off), g.mul(g.y, 36.0), g.mul(g.z, sz))
    grain = g.noise(gv, 1.0, 7.0, 0.62, 0.6)
    fibre = g.noise(gv, 9.0, 3.0, 0.5)
    wood = g.mixc(g.ramp(grain, 0.34, 0.68), WOOD_DARK, WOOD_LIGHT)
    wood = g.mixc(g.mul(g.ramp(fibre, 0.35, 0.75), 0.35), wood, (0.10, 0.058, 0.03, 1))
    grey = g.mixc(g.mul(bare, 0.55), wood, (0.19, 0.165, 0.135, 1))   # trodden, unoiled wood goes grey

    p = g.vec(g.add(g.x, off), g.y, g.z)
    big = g.noise(p, 7.0, 4.0, 0.6)
    mid = g.noise(p, 24.0, 4.0, 0.6, 0.4)
    fine = g.noise(p, 130.0, 3.0, 0.5)
    edge = g.edge(0.006)
    flake = g.cells(p, 46.0)
    kick = g.ramp(g.z, 0.03, 0.46, 1.0, 0.0)
    hand = g.ramp(g.dist2d(HANDLE_X + 0.05, HANDLE_Z - 0.01), 0.04, 0.21, 1.0, 0.0)
    cavity = g.ramp(g.ao(0.022), 0.45, 0.95, 1.0, 0.0)

    # where the paint has gone: edges first, then the kick zone, then where hands push
    drive = g.add(g.add(g.mul(edge, 0.30), g.mul(kick, 0.10)), g.mul(hand, 0.05))
    field = g.add(g.add(g.add(g.mul(big, 0.42), g.mul(mid, 0.28)), g.mul(flake, 0.30)), drive)
    chip_top = g.mx(g.ramp(field, 0.775, 0.785), bare)       # last coat gone, older coat shows
    chip_all = g.mx(g.ramp(field, 0.845, 0.855), bare)       # down to the wood

    # old oil paint crazes into fine islands
    crack = g.ramp(g.cracks(p, 260.0), 0.0, 0.05, 1.0, 0.0)      # hairline, a few millimetres across
    crack = g.mul(g.mul(crack, g.ramp(big, 0.48, 0.66)), 0.45)

    shade = lambda k: (PAINT_TOP[0] * k, PAINT_TOP[1] * k, PAINT_TOP[2] * k, 1)
    top = g.mixc(g.ramp(big, 0.25, 0.8), shade(0.74), PAINT_TOP)
    top = g.mixc(crack, top, shade(0.38))
    top = g.mixc(g.mul(hand, 0.45), top, shade(0.60))                              # greasy and darkened by hands
    col = g.mixc(chip_top, top, PAINT_UNDER)
    col = g.mixc(chip_all, col, grey)
    col = g.mixc(g.mul(cavity, 0.75), col, (0.030, 0.026, 0.020, 1))               # grime settles in the mouldings
    dust = g.mul(g.mul(kick, g.ramp(mid, 0.3, 0.75)), 0.42)
    col = g.mixc(dust, col, (0.20, 0.18, 0.15, 1))                                 # dust and scuffs low down

    rough = g.mixf(g.ramp(fine, 0.2, 0.8), 0.24, 0.40)
    rough = g.mixf(g.mul(hand, 0.6), rough, 0.20)
    rough = g.mixf(chip_top, rough, 0.62)
    rough = g.mixf(chip_all, rough, 0.80)
    rough = g.sat(g.add(g.add(rough, g.mul(cavity, 0.30)), g.mul(dust, 0.5)))

    # height: two coats of paint with brush marks over the grain
    brush = g.noise(g.vec(g.mul(g.x, g.mixf(horiz, 420.0, 9.0)), g.mul(g.y, 420.0), g.mul(g.z, g.mixf(horiz, 9.0, 420.0))), 1.0, 2.0, 0.5)
    paint_h = g.add(g.mul(g.sub(1.0, chip_top), 0.55), g.mul(g.sub(1.0, chip_all), 0.45))
    h = g.add(paint_h, g.mul(g.mul(brush, 0.10), g.sub(1.0, chip_top)))
    h = g.sub(h, g.mul(crack, 0.16))
    h = g.add(h, g.mul(g.mul(grain, 0.30), chip_all))
    h = g.add(h, g.mul(fine, 0.03))
    g.finish(col, rough, h, bump_dist=0.0007, bump_strength=1.0)


def brass(mat):
    g = G(mat)
    p = g.pos
    n1, n2 = g.noise(p, 55.0, 4.0, 0.6), g.noise(p, 9.0, 3.0, 0.6)
    cavity = g.ramp(g.ao(0.006), 0.5, 0.97, 1.0, 0.0)
    touch = g.ramp(g.dist2d(HANDLE_X + 0.075, HANDLE_Z - 0.004), 0.03, 0.12, 1.0, 0.0)   # where the hand lands
    tarnish = g.sat(g.sub(g.add(g.add(g.mul(cavity, 1.3), g.mul(n1, 0.55)), g.mul(n2, 0.45)), g.add(0.42, g.mul(touch, 0.75))))
    col = g.mixc(tarnish, (0.83, 0.58, 0.22, 1), (0.21, 0.135, 0.050, 1))
    col = g.mixc(g.mul(g.ramp(n1, 0.62, 0.8), g.mul(cavity, 0.8)), col, (0.16, 0.24, 0.17, 1))          # a little verdigris in the corners
    rough = g.mixf(tarnish, 0.17, 0.52)
    scratch = g.noise(g.vec(g.mul(g.x, 60.0), g.mul(g.y, 900.0), g.mul(g.z, 900.0)), 1.0, 2.0, 0.5)
    rough = g.sat(g.add(rough, g.mul(g.sub(scratch, 0.5), 0.10)))
    g.finish(col, rough, g.add(g.mul(scratch, 0.25), g.mul(n1, 0.2)), metallic=g.sub(1.0, g.mul(tarnish, 0.35)),
             bump_dist=0.00012, bump_strength=0.6)


def iron(mat):
    g = G(mat)
    p = g.pos
    n1, n2 = g.noise(p, 90.0, 4.0, 0.6), g.noise(p, 22.0, 4.0, 0.6)
    rust = g.ramp(g.add(g.mul(n1, 0.5), g.mul(n2, 0.5)), 0.52, 0.62)
    col = g.mixc(rust, (0.030, 0.028, 0.026, 1), (0.16, 0.070, 0.030, 1))
    g.finish(col, g.mixf(rust, 0.42, 0.85), g.add(g.mul(n1, 0.5), g.mul(rust, 0.4)), metallic=g.sub(1.0, rust),
             bump_dist=0.0002, bump_strength=0.8)


def simple(mat, color, rough, grime=0.0):
    g = G(mat)
    n = g.noise(g.pos, 60.0, 4.0, 0.6)
    col = g.mixc(g.mul(g.ramp(n, 0.4, 0.8), grime), color, (0.20, 0.16, 0.10, 1))
    g.finish(col, rough)


def glass(mat):
    """Hammered ornamental glass: lets the light through and hides what is behind it."""
    g = G(mat)
    n1, n2 = g.noise(g.pos, 95.0, 2.0, 0.5), g.noise(g.pos, 300.0, 2.0, 0.5)
    g.put(g.bsdf, "Transmission Weight", 1.0)
    g.put(g.bsdf, "IOR", 1.5)
    g.finish((0.93, 0.90, 0.80, 1), 0.34, g.add(g.mul(n1, 0.8), g.mul(n2, 0.2)), bump_dist=0.0012, bump_strength=1.0)


def floor(mat):
    g = G(mat)
    p = g.pos
    n1, n2 = g.noise(p, 3.0, 5.0, 0.6), g.noise(p, 40.0, 4.0, 0.6)
    col = g.mixc(n1, (0.012, 0.012, 0.013, 1), (0.030, 0.029, 0.028, 1))
    g.finish(col, g.mixf(g.ramp(n1, 0.3, 0.7), 0.30, 0.46), g.mul(n2, 0.5), bump_dist=0.0002, bump_strength=0.3)


def M(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


painted_wood(M("wood_leaf"), 1.0)
painted_wood(M("wood_frame"), 2.0)
brass(M("brass"))
iron(M("iron"))
glass(M("glass"))
simple(M("dark"), (0.004, 0.004, 0.004, 1), 0.9)
simple(M("paper"), (0.62, 0.56, 0.42, 1), 0.92, grime=0.55)
simple(M("porcelain"), (0.80, 0.78, 0.72, 1), 0.16, grime=0.25)

# ---- the void ----------------------------------------------------------------------------------
sc = bpy.context.scene
w = bpy.data.worlds.new("void"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)


def plane(name, verts, mat):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob); me.materials.append(mat)
    return ob


fm = M("void_floor"); floor(fm)
plane("void_floor", [(-9, -9, 0), (9, -9, 0), (9, 9, 0), (-9, 9, 0)], fm)
black = M("void_black"); simple(black, (0, 0, 0, 1), 1.0)
# the place behind the door: light gets out only through the gaps
bx, by0, by1, bz = 0.53, JAMB_D / 2 + 0.001, 1.3, 2.30
for nm, v in (("back", [(-bx, by1, 0), (bx, by1, 0), (bx, by1, bz), (-bx, by1, bz)]),
              ("l", [(-bx, by0, 0), (-bx, by1, 0), (-bx, by1, bz), (-bx, by0, bz)]),
              ("r", [(bx, by0, 0), (bx, by1, 0), (bx, by1, bz), (bx, by0, bz)]),
              ("top", [(-bx, by0, bz), (bx, by0, bz), (bx, by1, bz), (-bx, by1, bz)])):
    plane("room_" + nm, v, black)


def light(name, loc, target, power, size, color, size_y=None):
    l = bpy.data.lights.new(name, 'AREA'); l.energy = power; l.size = size; l.color = color
    if size_y:
        l.shape = 'RECTANGLE'; l.size_y = size_y
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return o


light("behind", (0.0, 0.75, 0.16), (0.0, -0.3, 0.02), 900, 0.85, (1.0, 0.70, 0.38), 0.22)   # the room beyond
light("lamp", (0.15, 1.05, 1.95), (0.0, 0.0, 1.75), 26, 0.5, (1.0, 0.72, 0.42))                    # a lamp in the room, seen through the glass
light("key", (-2.3, -3.0, 3.1), (0.0, 0.0, 1.15), 150, 2.6, (0.80, 0.88, 1.0))
light("rim", (2.6, -1.2, 2.2), (0.0, 0.0, 1.2), 34, 1.2, (0.70, 0.80, 1.0))

sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = 160; sc.cycles.use_denoising = True
sc.view_settings.view_transform = 'AgX'
try:
    sc.view_settings.look = 'AgX - Medium High Contrast'
except TypeError:
    pass
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET, "source", "door_tenement_a_look.blend"))


def shot(name, loc, target, lens, res, fstop=None):
    if ONLY and name not in ONLY:
        return
    cam.location = loc; cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cam.data.dof.use_dof = fstop is not None
    if fstop:
        cam.data.dof.focus_distance = (Vector(target) - Vector(loc)).length; cam.data.dof.aperture_fstop = fstop
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.use_stamp_filename = False      # keep the machine's file path out of the picture's metadata
    sc.render.filepath = os.path.join(ASSET, "review", "look_" + name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SHOT", name)


shot("void", (-0.75, -4.5, 1.45), (0.0, 0.0, 1.12), 42, (1100, 1400))
shot("handle", (HANDLE_X + 0.22, -0.42, HANDLE_Z + 0.07), (HANDLE_X + 0.05, 0.0, HANDLE_Z - 0.035), 50, (1200, 1000), 5.6)
shot("bottom", (-0.05, -0.62, 0.30), (-0.22, 0.0, 0.11), 35, (1200, 900), 8.0)
shot("midrail", (0.40, -0.72, 1.36), (0.0, 0.0, 1.24), 45, (1200, 900), 8.0)
shot("glass", (0.30, -0.80, 1.86), (0.0, 0.0, 1.78), 45, (1200, 900), 8.0)
