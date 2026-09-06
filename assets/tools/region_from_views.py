# Steal a Chonk - bake the concept sheet's Front / Side / Top views onto a prepared (blank) model,
# weighted by how squarely each view sees the surface, into the model's own UVs.
# Output: <out>/work/<name>_viewcolor.png  (then classify it into a region mask with numpy).
# Run inside Blender: exec(open(path).read(), {"CFG": {...}})
import bpy, os, math
from mathutils import Vector

# Project root: CFG["root"] when exec'd from Blender, else derived from this file's location.
try:
    ROOT = CFG.get("root")
except NameError:
    ROOT = None
if not ROOT:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) if "__file__" in globals() else os.getcwd()

DEFAULTS = dict(
    name="Chonk_Corgi",
    out=os.path.join(ROOT, "assets", "chonks", "corgi"),
    views=dict(
        # image, camera direction the view looks ALONG, camera up vector, image fraction the body spans (w, h)
        front=dict(image=os.path.join(ROOT, "concepts", "corgi", "views", "concept_front.png"), look=(0, 1, 0),  up=(0, 0, 1)),
        side=dict(image=os.path.join(ROOT, "concepts", "corgi", "views", "concept_side.png"),   look=(1, 0, 0),  up=(0, 0, 1), symmetric=True, floor=0.02),
        top=dict(image=os.path.join(ROOT, "concepts", "corgi", "views", "concept_top.png"),     look=(0, 0, -1), up=(0, 1, 0)),
    ),
    fit_margin=1.06,     # ortho size = model extent in that view * margin (concept views have a little air around the body)
    size=2048,
)
cfg = dict(DEFAULTS)
try:
    cfg.update(CFG)
except NameError:
    pass

sc = bpy.context.scene
lo = bpy.data.objects[cfg["name"]]
me = lo.data
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active = lo
orig_uv = me.uv_layers[0].name
bb = [lo.matrix_world @ Vector(c) for c in lo.bound_box]
mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
ctr = (mn + mx) / 2; ext = mx - mn

mat = bpy.data.materials.new("M_ViewProject"); mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes): nt.nodes.remove(n)
outn = nt.nodes.new("ShaderNodeOutputMaterial"); emit = nt.nodes.new("ShaderNodeEmission")
nt.links.new(emit.outputs[0], outn.inputs["Surface"])
geo = nt.nodes.new("ShaderNodeNewGeometry")

weighted = []   # (color socket, weight socket)
for key, v in cfg["views"].items():
    look = Vector(v["look"]).normalized()
    if "color" in v:
        # virtual view: a constant color painted on surfaces facing this direction (e.g. cream underside)
        rgb = nt.nodes.new("ShaderNodeRGB"); rgb.outputs[0].default_value = tuple(v["color"]) + (1.0,)
        d = nt.nodes.new("ShaderNodeVectorMath"); d.operation = 'DOT_PRODUCT'; d.inputs[1].default_value = tuple(-look)
        nt.links.new(geo.outputs["Normal"], d.inputs[0])
        mxn = nt.nodes.new("ShaderNodeMath"); mxn.operation = 'MAXIMUM'; mxn.inputs[1].default_value = 0.0; nt.links.new(d.outputs["Value"], mxn.inputs[0])
        pw = nt.nodes.new("ShaderNodeMath"); pw.operation = 'POWER'; pw.inputs[1].default_value = v.get("power", 2.0); nt.links.new(mxn.outputs[0], pw.inputs[0])
        weighted.append((rgb.outputs[0], pw.outputs[0]))
        continue
    up = Vector(v["up"]).normalized()
    # ortho extent: the two axes perpendicular to look
    right = look.cross(up).normalized()
    w_ext = abs(right.dot(ext)); h_ext = abs(up.dot(ext))
    size = max(w_ext, h_ext) * cfg["fit_margin"]
    cam = bpy.data.objects.get("ViewProj_" + key)
    if cam is None:
        cd = bpy.data.cameras.new("ViewProj_" + key); cam = bpy.data.objects.new("ViewProj_" + key, cd); sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = size
    # camera basis: X = right, Y = up, Z = -look (a Blender camera looks down its local -Z)
    from mathutils import Matrix
    R = Matrix((right, up, -look)).transposed().to_4x4()
    cam.matrix_world = Matrix.Translation(ctr - look * 6.0) @ R
    bpy.context.view_layer.update()
    uvname = "VP_" + key
    if uvname in me.uv_layers: me.uv_layers.remove(me.uv_layers[uvname])
    me.uv_layers.new(name=uvname); me.uv_layers.active = me.uv_layers[uvname]
    vimg = bpy.data.images.load(v["image"], check_existing=True)
    mod = lo.modifiers.new("VP_" + key, 'UV_PROJECT'); mod.uv_layer = uvname; mod.projector_count = 1; mod.projectors[0].object = cam
    ar = vimg.size[0] / vimg.size[1]                              # non-square view crops: ratio, not pixels
    mod.aspect_x = max(ar, 1.0); mod.aspect_y = max(1.0 / ar, 1.0)
    bpy.ops.object.modifier_apply(modifier="VP_" + key)
    uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = uvname
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = vimg; tex.extension = 'EXTEND'
    nt.links.new(uvn.outputs[0], tex.inputs["Vector"])
    # weight = facing ^ 2. "symmetric" views (the side of a symmetric animal) use |dot| so one image covers both sides
    # and wraps around the rear; others use max(0, -dot(normal, look)).
    d = nt.nodes.new("ShaderNodeVectorMath"); d.operation = 'DOT_PRODUCT'; d.inputs[1].default_value = tuple(-look)
    nt.links.new(geo.outputs["Normal"], d.inputs[0])
    if v.get("symmetric"):
        mxn = nt.nodes.new("ShaderNodeMath"); mxn.operation = 'ABSOLUTE'; nt.links.new(d.outputs["Value"], mxn.inputs[0])
    else:
        mxn = nt.nodes.new("ShaderNodeMath"); mxn.operation = 'MAXIMUM'; mxn.inputs[1].default_value = 0.0; nt.links.new(d.outputs["Value"], mxn.inputs[0])
    pw = nt.nodes.new("ShaderNodeMath"); pw.operation = 'POWER'; pw.inputs[1].default_value = v.get("power", cfg.get("power", 4.0)); nt.links.new(mxn.outputs[0], pw.inputs[0])
    if v.get("floor"):
        fl = nt.nodes.new("ShaderNodeMath"); fl.operation = 'ADD'; fl.inputs[1].default_value = v["floor"]; nt.links.new(pw.outputs[0], fl.inputs[0])
        pw = fl
    weighted.append((tex.outputs["Color"], pw.outputs[0]))
me.uv_layers.active = me.uv_layers[orig_uv]

# normalised weighted sum: sum(c_i * w_i) / (sum(w_i) + eps)
def vmul(col, w):
    n = nt.nodes.new("ShaderNodeVectorMath"); n.operation = 'SCALE'; nt.links.new(col, n.inputs[0]); nt.links.new(w, n.inputs["Scale"]); return n.outputs[0]
def vadd(a, b):
    n = nt.nodes.new("ShaderNodeVectorMath"); n.operation = 'ADD'; nt.links.new(a, n.inputs[0]); nt.links.new(b, n.inputs[1]); return n.outputs[0]
def sadd(a, b):
    n = nt.nodes.new("ShaderNodeMath"); n.operation = 'ADD'; nt.links.new(a, n.inputs[0]); nt.links.new(b, n.inputs[1]); return n.outputs[0]
num = vmul(*weighted[0]); den = weighted[0][1]
for col, w in weighted[1:]:
    num = vadd(num, vmul(col, w)); den = sadd(den, w)
eps = nt.nodes.new("ShaderNodeMath"); eps.operation = 'ADD'; eps.inputs[1].default_value = 1e-4; nt.links.new(den, eps.inputs[0])
inv = nt.nodes.new("ShaderNodeMath"); inv.operation = 'DIVIDE'; inv.inputs[0].default_value = 1.0; nt.links.new(eps.outputs[0], inv.inputs[1])
res = vmul(num, inv.outputs[0])
nt.links.new(res, emit.inputs["Color"])

me.materials.clear(); me.materials.append(mat)
for p in me.polygons: p.material_index = 0
img_name = cfg["name"] + "_viewcolor"
old = bpy.data.images.get(img_name)
if old: bpy.data.images.remove(old)
img = bpy.data.images.new(img_name, cfg["size"], cfg["size"], alpha=False)
bn = nt.nodes.new("ShaderNodeTexImage"); bn.image = img
for n in nt.nodes: n.select = False
bn.select = True; nt.nodes.active = bn
prev = sc.render.engine
sc.render.engine = 'CYCLES'; sc.cycles.samples = 8
sc.render.bake.margin = 8
bpy.ops.object.bake(type='EMIT')
work = os.path.join(cfg["out"], "work"); os.makedirs(work, exist_ok=True)
path = os.path.join(work, cfg["name"].lower() + "_viewcolor.png")
img.filepath_raw = path; img.file_format = 'PNG'; img.save()
sc.render.engine = prev if prev != 'CYCLES' else 'BLENDER_EEVEE'
for key in cfg["views"]:
    if "VP_" + key in me.uv_layers: me.uv_layers.remove(me.uv_layers["VP_" + key])
print("viewcolor baked", path)
