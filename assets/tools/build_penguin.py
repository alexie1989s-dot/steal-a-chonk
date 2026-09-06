# Steal a Chonk - Penguin builder. Run inside Blender (via MCP exec or the Text editor).
import bpy, bmesh, math, os
from mathutils import Vector

# Project root: CFG["root"] when exec'd from Blender, else derived from this file's location.
try:
    ROOT = CFG.get("root")
except NameError:
    ROOT = None
if not ROOT:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) if "__file__" in globals() else os.getcwd()

OUT = os.path.join(ROOT, "assets", "chonks", "penguin")
NAME = "Chonk_Penguin"
SX, SY, SZ = 1.08, 1.02, 1.12          # body radii (x width, y depth, z height)
TAPER_TOP = 0.22                        # how much the top narrows
BULGE_BOTTOM = 0.06                     # slight pear widening below middle
CZ = SZ                                 # body center height (bottom sits at 0)
RECT = {"wing": (0.00, 0.34), "foot": (0.36, 0.58), "tail": (0.60, 0.70), "crest": (0.72, 0.80), "beak": (0.82, 1.00)}


def radial_scale(t):                    # t = normalized height -1..1
    b = max(-t, 0.0)
    return 1.0 - TAPER_TOP * max(t, 0.0) ** 2 + BULGE_BOTTOM * b * (1 - b)


def on_body(az_deg, el_deg, push=0.0):
    az, el = math.radians(az_deg), math.radians(el_deg)
    n = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    rs = radial_scale(n.z)
    return Vector((0, 0, CZ)) + Vector((n.x * rs * SX, n.y * rs * SY, n.z * SZ)) * (1.0 + push)


def clear_prefix(prefix):
    for o in list(bpy.data.objects):
        if o.name.startswith(prefix):
            bpy.data.objects.remove(o, do_unlink=True)


def uv_into_rect(o, key):
    bpy.context.view_layer.objects.active = o
    for x in bpy.data.objects:
        x.select_set(False)
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.2, island_margin=0.02, scale_to_bounds=True)
    bm = bmesh.from_edit_mesh(o.data)
    uv = bm.loops.layers.uv.verify()
    u0, u1 = RECT[key]
    m = 0.01
    for f in bm.faces:
        for l in f.loops:
            x, y = l[uv].uv
            l[uv].uv = (u0 + m + x * (u1 - u0 - 2 * m), 0.78 + m + y * (0.22 - 2 * m))
    bmesh.update_edit_mesh(o.data)
    bpy.ops.object.mode_set(mode='OBJECT')


def sphere(name, loc, scale, seg, ring, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def cone(name, loc, rot, r1, r2, depth, verts=16, flatten=1.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=(0, 0, 0), rotation=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    o.scale = (1, flatten, 1)
    bpy.ops.object.transform_apply(scale=True)
    o.rotation_euler = rot
    o.location = loc
    return o


def build():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    clear_prefix("Peng")
    clear_prefix(NAME)
    # body
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=28, radius=1.0, location=(0, 0, CZ))
    body = bpy.context.active_object
    body.name = "PengBody"
    for v in body.data.vertices:
        rs = radial_scale(v.co.z)
        v.co = Vector((v.co.x * rs * SX, v.co.y * rs * SY, v.co.z * SZ))
    # body UV: equirect, front centered, v in [0,0.75]
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(body.data)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            p = l.vert.co
            n = Vector((p.x / SX, p.y / SY, p.z / SZ))
            L = n.length
            az = math.atan2(n.x, -n.y) if (abs(n.x) > 1e-9 or abs(n.y) > 1e-9) else 0.0
            el = math.asin(max(-1, min(1, n.z / L)))
            l[uv].uv = (0.5 + az / (2 * math.pi), (el + math.pi / 2) / math.pi * 0.75)
    for f in bm.faces:
        us = [l[uv].uv.x for l in f.loops]
        if max(us) - min(us) > 0.5:
            for l in f.loops:
                if l[uv].uv.x < 0.5:
                    l[uv].uv.x += 1.0
    bmesh.update_edit_mesh(body.data)
    bpy.ops.object.mode_set(mode='OBJECT')

    parts = [body]
    # beak: small wedge on the face at ~20 deg elevation, pointing forward and slightly down
    bp = on_body(0, 20, -0.02)
    beak = cone("PengBeak", bp + Vector((0, -0.10, -0.01)), (math.radians(-98), 0, 0), 0.12, 0.015, 0.30, verts=14, flatten=0.55)
    uv_into_rect(beak, "beak")
    parts.append(beak)
    # wings: hug the body, slight backward sweep, tips a little outward
    for s in (-1, 1):
        wp = on_body(s * 74, -14, -0.07)
        w = sphere("PengWing%d" % s, wp + Vector((0, 0, -0.04)), (0.12, 0.32, 0.55), 24, 14,
                   rot=(math.radians(6), math.radians(s * 9), math.radians(-s * 16)))
        uv_into_rect(w, "wing")
        parts.append(w)
    # feet with toes
    for s in (-1, 1):
        f = sphere("PengFoot%d" % s, (s * 0.36, -0.60, 0.06), (0.22, 0.30, 0.09), 20, 10)
        toes = [sphere("PengToe%d%d" % (s, k), (s * 0.36 + dx, -0.60 + dy, 0.06), (0.07, 0.12, 0.07), 12, 8)
                for k, (dx, dy) in enumerate([(-0.13, -0.26), (0.0, -0.30), (0.13, -0.26)])]
        for x in bpy.data.objects:
            x.select_set(False)
        for t in toes + [f]:
            t.select_set(True)
        bpy.context.view_layer.objects.active = f
        bpy.ops.object.join()
        f = bpy.context.active_object
        uv_into_rect(f, "foot")
        parts.append(f)
    # tail
    tail = cone("PengTail", (0, SY * 0.95, 0.30), (math.radians(-55), 0, 0), 0.13, 0.02, 0.34, verts=12, flatten=0.5)
    uv_into_rect(tail, "tail")
    parts.append(tail)
    # crest
    top = on_body(0, 90, 0.0)
    crest = cone("PengCrest", top + Vector((0, 0.02, 0.07)), (0, 0, 0), 0.075, 0.01, 0.20, verts=10)
    uv_into_rect(crest, "crest")
    parts.append(crest)

    for x in bpy.data.objects:
        x.select_set(False)
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    peng = bpy.context.active_object
    peng.name = NAME
    bpy.ops.object.shade_smooth()
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return peng


def apply_material(obj, name, texpath):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(texpath, check_existing=True)
    tex.image.reload()
    tex.interpolation = 'Cubic'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.8
    for k, vv in (("Sheen Weight", 0.25), ("Sheen Roughness", 0.5), ("Specular IOR Level", 0.25)):
        if k in bsdf.inputs:
            bsdf.inputs[k].default_value = vv
    obj.data.materials.clear()
    obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.material_index = 0
    return m


def export(obj):
    os.makedirs(OUT, exist_ok=True)
    for x in bpy.data.objects:
        x.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    loc, rot = obj.location.copy(), obj.rotation_euler.copy()
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "penguin.fbx"), use_selection=True, axis_forward='-Z', axis_up='Y',
                             mesh_smooth_type='FACE', add_leaf_bones=False, bake_anim=False)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.export_layout(filepath=os.path.join(OUT, "penguin_uv.png"), size=(1024, 1024), opacity=0.35, export_all=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.location = loc
    obj.rotation_euler = rot


peng = build()
export(peng)
print("built", NAME, "tris", sum(len(p.vertices) - 2 for p in peng.data.polygons))
