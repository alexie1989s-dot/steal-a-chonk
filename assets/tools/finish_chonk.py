# Steal a Chonk - finish a Hyper3D-generated Chonk for Roblox.
#
# Stages (CFG["stage"]):
#   "prepare" : copy generated mesh -> normalise height -> decimate -> fresh UV unwrap. Geometry only, no color.
#   "bake"    : on the prepared mesh, build the surface (tiled fur by region mask, or generated diffuse),
#               project the flat face image from the front, bake one diffuse, export FBX + renders.
#   "all"     : both.
# Run inside Blender: exec(open(path).read(), {"CFG": {...}})
import bpy, bmesh, os, math
from mathutils import Vector

# Project root: CFG["root"] when exec'd from Blender, else derived from this file's location.
try:
    ROOT = CFG.get("root")
except NameError:
    ROOT = None
if not ROOT:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) if "__file__" in globals() else os.getcwd()

DEFAULTS = dict(
    stage="all",
    src="Chonk_Corgi_Gen",            # generated (high-poly) object name
    name="Chonk_Corgi",               # output object name
    out=os.path.join(ROOT, "assets", "chonks", "corgi"),
    fbx="corgi.fbx",
    face_image=os.path.join(ROOT, "concepts", "corgi", "face_front.png"),
    height=2.3,                       # world height to normalise to
    decimate=0.30,                    # ratio (0.3 of 23k ~ 7k tris)
    unwrap=True,                      # replace generator UVs with a fresh smart unwrap
    unwrap_angle=66.0,
    proj_size=1.42,                   # world width the face image spans
    proj_center_z=1.50,               # world z of the face image center
    proj_offset_x=0.0,
    eyes_uv=[(0.279, 0.514), (0.694, 0.514)],   # eye centers in face-image UV (u right, v up)
    eye_patch=(0.15, 0.095),          # patch ellipse radii in image UV
    patch_color=(0.62, 0.235, 0.075, 1.0),     # linear fur color painted under the eyes (non-fur mode)
    front_threshold=0.15,             # dot(normal, -Y) needed to receive the face projection
    bake_size=2048,
    roughness=0.85,
    renders=True,
    # fur mode: replace the surface with tiled fur driven by a region mask sampled through the model UVs.
    # mask: R = primary fur, G = secondary fur, B = ear pink, black = dark (nose)
    fur=None,   # dict(mask=..., primary=..., secondary=..., pink_rgb=(r,g,b) linear, dark_rgb=(...), tile_scale=1.0)
)
cfg = dict(DEFAULTS)
try:
    cfg.update(CFG)
except NameError:
    pass

sc = bpy.context.scene
out = cfg["out"]; os.makedirs(out, exist_ok=True)
stage = cfg["stage"]
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')


def select_only(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o


# =====================================================================================
# PREPARE: geometry only
# =====================================================================================
if stage in ("prepare", "all"):
    src = bpy.data.objects[cfg["src"]]
    old = bpy.data.objects.get(cfg["name"])
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    lo = src.copy(); lo.data = src.data.copy(); lo.name = cfg["name"]; sc.collection.objects.link(lo)
    lo.hide_render = False; lo.hide_viewport = False
    src.hide_render = True; src.hide_viewport = True
    select_only(lo)
    lo.location = (0, 0, 0); lo.rotation_euler = (0, 0, 0); lo.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    bb = [Vector(c) for c in lo.bound_box]
    h = max(v.z for v in bb) - min(v.z for v in bb)
    s = cfg["height"] / h
    lo.scale = (s, s, s); bpy.context.view_layer.update()
    bb = [lo.matrix_world @ Vector(c) for c in lo.bound_box]
    lo.location.z = -min(v.z for v in bb)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mod = lo.modifiers.new("Decimate", 'DECIMATE'); mod.ratio = cfg["decimate"]; mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="Decimate")
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    if cfg["unwrap"]:
        me = lo.data
        for uvl in list(me.uv_layers):
            me.uv_layers.remove(uvl)
        me.uv_layers.new(name="UVMap")
        bpy.ops.uv.smart_project(angle_limit=math.radians(cfg["unwrap_angle"]), island_margin=0.003, scale_to_bounds=False)
        bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_smooth()
    # blank grey material so the prepared model is visibly "uncolored"
    blank = bpy.data.materials.get("M_Blank") or bpy.data.materials.new("M_Blank")
    blank.use_nodes = True
    blank.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.6, 0.6, 0.6, 1)
    lo.data.materials.clear(); lo.data.materials.append(blank)
    tris = sum(len(p.vertices) - 2 for p in lo.data.polygons)
    print("prepared", lo.name, "tris", tris, "uv islands packed")

# =====================================================================================
# BAKE: surface + face -> one texture -> export
# =====================================================================================
if stage in ("bake", "all"):
    lo = bpy.data.objects[cfg["name"]]
    select_only(lo)
    me = lo.data
    orig_uv = me.uv_layers[0].name
    tris = sum(len(p.vertices) - 2 for p in me.polygons)

    # ---------- face projector + Proj UV
    proj = bpy.data.objects.get("FaceProjector")
    if proj is None:
        cd = bpy.data.cameras.new("FaceProjector"); proj = bpy.data.objects.new("FaceProjector", cd); sc.collection.objects.link(proj)
    proj.data.type = 'ORTHO'; proj.data.ortho_scale = cfg["proj_size"]
    proj.location = (cfg["proj_offset_x"], -5.0, cfg["proj_center_z"]); proj.rotation_euler = (math.radians(90), 0, 0)
    if "Proj" in me.uv_layers:
        me.uv_layers.remove(me.uv_layers["Proj"])
    me.uv_layers.new(name="Proj"); me.uv_layers.active = me.uv_layers["Proj"]
    m = lo.modifiers.new("FaceProj", 'UV_PROJECT'); m.uv_layer = "Proj"; m.projector_count = 1; m.projectors[0].object = proj
    bpy.ops.object.modifier_apply(modifier="FaceProj")
    me.uv_layers.active = me.uv_layers[orig_uv]

    # ---------- material graph
    mat = bpy.data.materials.new(cfg["name"] + "_Mat"); mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    outn = nt.nodes.new("ShaderNodeOutputMaterial"); bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = cfg["roughness"]
    uv_o = nt.nodes.new("ShaderNodeUVMap"); uv_o.uv_map = orig_uv
    uv_p = nt.nodes.new("ShaderNodeUVMap"); uv_p.uv_map = "Proj"
    face = nt.nodes.new("ShaderNodeTexImage"); face.image = bpy.data.images.load(cfg["face_image"], check_existing=True); face.extension = 'CLIP'
    nt.links.new(uv_p.outputs[0], face.inputs["Vector"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath"); dot.operation = 'DOT_PRODUCT'; dot.inputs[1].default_value = (0, -1, 0)
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    front = nt.nodes.new("ShaderNodeMath"); front.operation = 'GREATER_THAN'; front.inputs[1].default_value = cfg["front_threshold"]
    nt.links.new(dot.outputs["Value"], front.inputs[0])
    # depth limit: the face only lands on the front of the head (world Y below a limit), never inside ears or on the body behind
    if cfg.get("face_depth_y") is not None:
        posn = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Position"], posn.inputs[0])
        near = nt.nodes.new("ShaderNodeMath"); near.operation = 'LESS_THAN'; near.inputs[1].default_value = cfg["face_depth_y"]
        nt.links.new(posn.outputs["Y"], near.inputs[0])
        front2 = nt.nodes.new("ShaderNodeMath"); front2.operation = 'MULTIPLY'
        nt.links.new(front.outputs[0], front2.inputs[0]); nt.links.new(near.outputs[0], front2.inputs[1])
        front = front2
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(uv_p.outputs[0], sep.inputs[0])

    def math_node(op, a=None, b=None, const=None):
        n = nt.nodes.new("ShaderNodeMath"); n.operation = op
        if a is not None: nt.links.new(a, n.inputs[0])
        if b is not None: nt.links.new(b, n.inputs[1])
        if const is not None: n.inputs[1].default_value = const
        return n

    def ellipse(cu, cv, ru, rv):
        du = math_node('DIVIDE', math_node('SUBTRACT', sep.outputs[0], const=cu).outputs[0], const=ru)
        dv = math_node('DIVIDE', math_node('SUBTRACT', sep.outputs[1], const=cv).outputs[0], const=rv)
        pu = math_node('POWER', du.outputs[0], const=2.0); pv = math_node('POWER', dv.outputs[0], const=2.0)
        ad = math_node('ADD', pu.outputs[0], pv.outputs[0])
        return math_node('LESS_THAN', ad.outputs[0], const=1.0)

    # ---- base surface
    F = cfg.get("fur")
    patch_color_socket = None
    if F:
        mask_tex = nt.nodes.new("ShaderNodeTexImage"); mask_tex.image = bpy.data.images.load(F["mask"], check_existing=True)
        mask_tex.image.reload(); mask_tex.image.colorspace_settings.name = 'Non-Color'
        nt.links.new(uv_o.outputs[0], mask_tex.inputs["Vector"])
        texco = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping"); sc_ = F.get("tile_scale", 1.0); mapping.inputs["Scale"].default_value = (sc_, sc_, sc_)
        nt.links.new(texco.outputs["Object"], mapping.inputs["Vector"])

        def tile(path):
            t = nt.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(path, check_existing=True)
            t.projection = 'BOX'; t.projection_blend = 0.35
            nt.links.new(mapping.outputs["Vector"], t.inputs["Vector"]); return t
        prim = tile(F["primary"]); sec = tile(F["secondary"])
        sepc = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(mask_tex.outputs["Color"], sepc.inputs["Color"])
        # base = primary fur everywhere, secondary where the mask's G says so (no dark fallback: pink that is
        # suppressed on non-forward faces must fall back to fur, not black)
        m2 = nt.nodes.new("ShaderNodeMix"); m2.data_type = 'RGBA'
        nt.links.new(sepc.outputs["Green"], m2.inputs["Factor"]); nt.links.new(prim.outputs["Color"], m2.inputs[6]); nt.links.new(sec.outputs["Color"], m2.inputs[7])
        tint = nt.nodes.new("ShaderNodeMix"); tint.data_type = 'RGBA'; tint.blend_type = 'MULTIPLY'; tint.inputs["Factor"].default_value = 1.0
        tint.inputs[7].default_value = tuple(F.get("pink_rgb", (0.95, 0.42, 0.40))) + (1.0,)
        nt.links.new(sec.outputs["Color"], tint.inputs[6])
        # ear pink only on forward-facing surfaces (inner ear), never on the ear backs
        pink_front = math_node('GREATER_THAN', dot.outputs["Value"], const=0.25)
        pink_fac = math_node('MULTIPLY', sepc.outputs["Blue"], pink_front.outputs[0])
        m3 = nt.nodes.new("ShaderNodeMix"); m3.data_type = 'RGBA'
        nt.links.new(pink_fac.outputs[0], m3.inputs["Factor"]); nt.links.new(m2.outputs[2], m3.inputs[6]); nt.links.new(tint.outputs[2], m3.inputs[7])
        base_color = m3.outputs[2]
        patch_color_socket = prim.outputs["Color"]
    else:
        src = bpy.data.objects[cfg["src"]]
        src_mat = src.data.materials[0]
        diffuse_img = [n.image for n in src_mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image and 'diffuse' in n.image.name.lower()][0]
        diff = nt.nodes.new("ShaderNodeTexImage"); diff.image = diffuse_img; nt.links.new(uv_o.outputs[0], diff.inputs["Vector"])
        base_color = diff.outputs["Color"]

    # ---- eye patch under the face, then the face
    ru, rv = cfg["eye_patch"]
    masks = [ellipse(cu, cv, ru, rv) for (cu, cv) in cfg["eyes_uv"]]
    acc = masks[0].outputs[0]
    for mk in masks[1:]:
        acc = math_node('MAXIMUM', acc, mk.outputs[0]).outputs[0]
    patch_fac = math_node('MULTIPLY', acc, front.outputs[0])
    patch = nt.nodes.new("ShaderNodeMix"); patch.data_type = 'RGBA'; patch.inputs[7].default_value = cfg["patch_color"]
    if patch_color_socket is not None:
        nt.links.new(patch_color_socket, patch.inputs[7])
    nt.links.new(patch_fac.outputs[0], patch.inputs["Factor"]); nt.links.new(base_color, patch.inputs[6])
    face_fac = math_node('MULTIPLY', face.outputs["Alpha"], front.outputs[0])
    fmix = nt.nodes.new("ShaderNodeMix"); fmix.data_type = 'RGBA'
    nt.links.new(face_fac.outputs[0], fmix.inputs["Factor"]); nt.links.new(patch.outputs[2], fmix.inputs[6]); nt.links.new(face.outputs["Color"], fmix.inputs[7])
    nt.links.new(fmix.outputs[2], bsdf.inputs["Base Color"])
    me.materials.clear(); me.materials.append(mat)
    for p in me.polygons: p.material_index = 0

    # ---------- bake
    bake_name = cfg["fbx"].rsplit(".", 1)[0] + "_diffuse"
    old_img = bpy.data.images.get(bake_name)
    if old_img: bpy.data.images.remove(old_img)
    bake_img = bpy.data.images.new(bake_name, cfg["bake_size"], cfg["bake_size"], alpha=False)
    bake_node = nt.nodes.new("ShaderNodeTexImage"); bake_node.image = bake_img
    for n in nt.nodes: n.select = False
    bake_node.select = True; nt.nodes.active = bake_node
    prev_engine = sc.render.engine
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 16
    sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False; sc.render.bake.use_pass_color = True; sc.render.bake.margin = 8
    bpy.ops.object.bake(type='DIFFUSE')
    bake_path = os.path.join(out, bake_name + ".png")
    bake_img.filepath_raw = bake_path; bake_img.file_format = 'PNG'; bake_img.save()
    nt.links.new(bake_node.outputs["Color"], bsdf.inputs["Base Color"]); nt.links.new(uv_o.outputs[0], bake_node.inputs["Vector"])
    sc.render.engine = prev_engine if prev_engine != 'CYCLES' else 'BLENDER_EEVEE'

    # ---------- export (single UV set) + renders
    me.uv_layers.remove(me.uv_layers["Proj"])
    select_only(lo)
    bpy.ops.export_scene.fbx(filepath=os.path.join(out, cfg["fbx"]), use_selection=True, axis_forward='-Z', axis_up='Y',
                             mesh_smooth_type='FACE', add_leaf_bones=False, bake_anim=False, path_mode='RELATIVE', embed_textures=False)
    if cfg["renders"]:
        for o in bpy.data.objects:
            if o.type == 'MESH' and o.name not in ("Ground", lo.name):
                o.hide_render = True
        H = lo.dimensions.z; cam = bpy.data.objects["Camera"]; cam.data.lens = 55
        cam.location = Vector((0.0, -6.4, 1.4)); cam.rotation_euler = (Vector((0, 0, H * 0.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.resolution_x = 1600; sc.render.resolution_y = 1600
        sc.render.filepath = os.path.join(out, cfg["name"].lower() + "_front.png"); bpy.ops.render.render(write_still=True)
        cam.location = Vector((3.4, -5.2, 2.2)); cam.rotation_euler = (Vector((0, 0, H * 0.48)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.resolution_x = 1920; sc.render.resolution_y = 1440
        sc.render.filepath = os.path.join(out, cfg["name"].lower() + "_threequarter.png"); bpy.ops.render.render(write_still=True)
    print("finished", cfg["name"], "tris", tris, "bake", bake_path)
