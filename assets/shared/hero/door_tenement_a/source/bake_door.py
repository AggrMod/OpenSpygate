"""Bake the door's procedural materials into textures and export it for the game.

    blender -b source/door_tenement_a_look.blend -P source/bake_door.py -- <asset_dir> [size]

Writes textures/door_tenement_a_<set>_{basecolor,normal,orm}.png and export/door_tenement_a.glb.
ORM packing: red = occlusion (left white), green = roughness, blue = metallic.
"""
import bpy, sys, os
import numpy as np

ARGS = sys.argv[sys.argv.index("--") + 1:]
ASSET = ARGS[0]
SIZE = int(ARGS[1]) if len(ARGS) > 1 else 2048
NAME = "door_tenement_a"
sc = bpy.context.scene
vl = bpy.context.view_layer

door = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent is not None]
sets = {
    "leaf": ([o for o in door if o.name == "leaf_wood"], SIZE),
    "frame": ([o for o in door if o.name == "frame_wood"], SIZE),
    "hardware": ([o for o in door if o.name not in ("leaf_wood", "frame_wood", "leaf_glass")], SIZE // 2),
}
glass = [o for o in door if o.name == "leaf_glass"]


def select(objs):
    for o in bpy.data.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    vl.objects.active = objs[0]


def unwrap(objs):
    for o in objs:
        while o.data.uv_layers:
            o.data.uv_layers.remove(o.data.uv_layers[0])
        o.data.uv_layers.new(name="bake")
    select(objs)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')


def new_image(name, size, data):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=data)
    img.colorspace_settings.name = 'Non-Color' if data else 'sRGB'
    return img


def target(mats, img):
    for m in mats:
        t = m.node_tree
        n = t.nodes.get("bake_target") or t.nodes.new("ShaderNodeTexImage")
        n.name = "bake_target"; n.image = img
        for x in t.nodes:
            x.select = False
        n.select = True; t.nodes.active = n


def emit_from(mats, socket_name):
    """Route one Principled input to an emission shader so it can be baked exactly."""
    undo = []
    for m in mats:
        t = m.node_tree
        bsdf = next(n for n in t.nodes if n.type == 'BSDF_PRINCIPLED')
        out = next(n for n in t.nodes if n.type == 'OUTPUT_MATERIAL')
        em = t.nodes.new("ShaderNodeEmission")
        sock = bsdf.inputs[socket_name]
        if sock.is_linked:
            t.links.new(sock.links[0].from_socket, em.inputs["Color"])
        else:
            v = sock.default_value
            em.inputs["Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1.0)
        t.links.new(em.outputs[0], out.inputs["Surface"])
        undo.append((t, bsdf, out, em))
    return undo


def restore(undo):
    for t, bsdf, out, em in undo:
        t.links.new(bsdf.outputs[0], out.inputs["Surface"])
        t.nodes.remove(em)


def pixels(img):
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(-1, 4)


def save(img, path, data):
    img.filepath_raw = path; img.file_format = 'PNG'
    sc.render.image_settings.color_depth = '8'
    img.save()
    print("WROTE", os.path.basename(path))


sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 10
sc.cycles.use_denoising = False
sc.render.bake.margin = 6
sc.render.bake.use_selected_to_active = False
os.makedirs(os.path.join(ASSET, "textures"), exist_ok=True)
os.makedirs(os.path.join(ASSET, "export"), exist_ok=True)

baked = {}
for set_name, (objs, size) in sets.items():
    unwrap(objs)
    mats = list({s.material for o in objs for s in o.material_slots if s.material})
    out = {}
    for key, sock, data in (("basecolor", "Base Color", False), ("roughness", "Roughness", True), ("metallic", "Metallic", True)):
        img = new_image("%s_%s_%s" % (NAME, set_name, key), size, data)
        target(mats, img)
        undo = emit_from(mats, sock)
        select(objs)
        bpy.ops.object.bake(type='EMIT', use_clear=True)
        restore(undo)
        out[key] = img
        print("BAKED", set_name, key)
    img = new_image("%s_%s_normal" % (NAME, set_name), size, True)
    target(mats, img)
    select(objs)
    bpy.ops.object.bake(type='NORMAL', use_clear=True)
    out["normal"] = img
    print("BAKED", set_name, "normal")
    # pack occlusion (white), roughness and metallic into one texture
    r, m = pixels(out["roughness"]), pixels(out["metallic"])
    orm = new_image("%s_%s_orm" % (NAME, set_name), size, True)
    packed = np.ones_like(r)
    packed[:, 1] = r[:, 0]; packed[:, 2] = m[:, 0]
    orm.pixels.foreach_set(packed.ravel())
    out["orm"] = orm
    for key in ("basecolor", "normal", "orm"):
        save(out[key], os.path.join(ASSET, "textures", "%s_%s_%s.png" % (NAME, set_name, key)), key != "basecolor")
    baked[set_name] = out

# ---- game materials: plain textured materials in place of the node graphs ----------------------
for set_name, (objs, size) in sets.items():
    mat = bpy.data.materials.new("%s_%s" % (NAME, set_name)); mat.use_nodes = True
    t = mat.node_tree
    bsdf = t.nodes["Principled BSDF"]
    def tex(img, x):
        n = t.nodes.new("ShaderNodeTexImage"); n.image = img; return n
    bc = tex(baked[set_name]["basecolor"], 0)
    t.links.new(bc.outputs["Color"], bsdf.inputs["Base Color"])
    orm = tex(baked[set_name]["orm"], 1)
    sep = t.nodes.new("ShaderNodeSeparateColor")
    t.links.new(orm.outputs["Color"], sep.inputs[0])
    t.links.new(sep.outputs[1], bsdf.inputs["Roughness"]); t.links.new(sep.outputs[2], bsdf.inputs["Metallic"])
    nrm = tex(baked[set_name]["normal"], 2)
    nm = t.nodes.new("ShaderNodeNormalMap")
    t.links.new(nrm.outputs["Color"], nm.inputs["Color"]); t.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    for o in objs:
        o.data.materials.clear(); o.data.materials.append(mat)
        for a in ("horiz", "bare"):
            if a in o.data.attributes:
                o.data.attributes.remove(o.data.attributes[a])
for o in glass:
    gm = bpy.data.materials.new(NAME + "_glass"); gm.use_nodes = True
    b = gm.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.93, 0.90, 0.80, 1); b.inputs["Roughness"].default_value = 0.34
    o.data.materials.clear(); o.data.materials.append(gm)

keep = set(door) | {o for o in bpy.data.objects if o.name == NAME}
for o in list(bpy.data.objects):
    if o not in keep:
        bpy.data.objects.remove(o)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print("EXPORT triangles", tris)
bpy.ops.export_scene.gltf(filepath=os.path.join(ASSET, "export", NAME + ".glb"), export_format='GLB',
                          export_apply=True, export_yup=True, export_image_format='WEBP', export_image_quality=92,
                          export_tangents=True)
print("EXPORTED", os.path.getsize(os.path.join(ASSET, "export", NAME + ".glb")) // 1024, "KB")
