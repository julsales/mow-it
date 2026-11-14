# Mow It! tool art: tiny modelling kit for Blender (headless, Python).
#
# Everything is authored in ROBLOX coordinates (studs): +X right, +Y up,
# -Z forward. R() converts to Blender (Z up); the FBX export maps it back.
#
# Each piece belongs to a colour GROUP. Pieces of one group are joined into
# one mesh named after the group, so a model is a handful of MeshParts the
# game recolours by name (src/ReplicatedStorage/Shared/ToolArt.luau):
#   Accent, Accent2, Metal, Chrome, Dark, Rubber, Wood, Glass, Light, Seat,
#   Eye, Teeth, Gold, Fabric, plus the special HandleGrip / SteeringWheel.
# "Group.Extra" pieces are optional: the game keeps them only for tools
# whose config lists that extra (e.g. "Chrome.Turbo").
# "…#Rig" pieces move in the game (ToolAnimations.client): built inside a
# `with rig("SnipL"):` block. Wheels get their own "Spin<n>" rig each, so
# every wheel turns around its own centre.

import contextlib
import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def R(x, y, z):
    return Vector((x, -z, y))


_AXIS = {"x": Vector((1, 0, 0)), "y": Vector((0, 0, 1)), "z": Vector((0, -1, 0))}


def rotm(rot):
    """rot: list of (axis, degrees), applied in order (world axes)."""
    m = Matrix.Identity(4)
    for axis, deg in rot or ():
        m = Matrix.Rotation(math.radians(deg), 4, _AXIS[axis]) @ m
    return m


_RIG = [None]
_XFORM = [Matrix.Identity(4)]
_SPIN = [0]
PIVOTS = {}  # rig name -> centre of its first piece (the axle it turns on), roblox coords


@contextlib.contextmanager
def rig(name):
    """Pieces built inside move together as one animated part. Inside
    another rig the outer one wins (a mini drone orbits as one piece)."""
    old = _RIG[0]
    _RIG[0] = old or name
    try:
        yield
    finally:
        _RIG[0] = old


@contextlib.contextmanager
def xform(scale=1.0, offset=(0, 0, 0)):
    """Build pieces scaled around the origin, then moved (roblox coords)."""
    old = _XFORM[0]
    _XFORM[0] = old @ Matrix.Translation(R(*offset)) @ Matrix.Diagonal((scale, scale, scale, 1))
    try:
        yield
    finally:
        _XFORM[0] = old


def next_spin():
    _SPIN[0] += 1
    return f"Spin{_SPIN[0]}"


def reset_state():
    PIVOTS.clear()
    _RIG[0] = None
    _XFORM[0] = Matrix.Identity(4)
    _SPIN[0] = 0


def _place(o, matrix, group, bevel, smooth=False):
    o.matrix_world = _XFORM[0] @ matrix
    bpy.context.view_layer.objects.active = o
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel and bevel > 0:
        flats = [p.normal.copy() for p in o.data.polygons]
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = False
        bpy.ops.object.modifier_apply(modifier=mod.name)
        # the chamfers are the new faces: shade() paints them as worn edges
        edge = o.data.attributes.new(EDGE, "BOOLEAN", "FACE")
        for p in o.data.polygons:
            edge.data[p.index].value = not any(p.normal.dot(n) > 0.999 for n in flats)
    o["grp"] = group
    if _RIG[0]:
        o["rig"] = _RIG[0]
        if _RIG[0] not in PIVOTS:
            pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
            mid = sum(pts, Vector()) / 8
            PIVOTS[_RIG[0]] = [round(mid.x, 3), round(mid.z, 3), round(-mid.y, 3)]
    return o


def box(group, c, s, bevel=0.06, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    m = Matrix.Translation(R(*c)) @ rotm(rot) @ Matrix.Diagonal((s[0], s[2], s[1], 1))
    return _place(o, m, group, min(bevel, min(s) * 0.45))


def wedge(group, c, s, bevel=0.04, rot=None):
    """Box whose top-front edge is cut off: the top slopes down toward -Z."""
    bm = bmesh.new()
    x, y, z = s[0] / 2, s[1] / 2, s[2] / 2
    pts = [(-z, -y), (z, -y), (z, y), (-z + s[2] * 0.0, -y + s[1] * 0.35)]
    # profile in (z, y); extrude along x
    verts_l = [bm.verts.new(R(-x, py, pz)) for pz, py in pts]
    verts_r = [bm.verts.new(R(x, py, pz)) for pz, py in pts]
    bm.faces.new(verts_l[::-1])
    bm.faces.new(verts_r)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((verts_l[i], verts_l[j], verts_r[j], verts_r[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("wedge")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("wedge", me)
    bpy.context.collection.objects.link(o)
    m = Matrix.Translation(R(*c)) @ rotm(rot)
    return _place(o, m, group, min(bevel, min(s) * 0.4))


def cyl(group, a, b, r, verts=12, bevel=0.04, r2=None):
    """Cylinder (or frustum when r2 is given) from point a to point b."""
    pa, pb = R(*a), R(*b)
    d = pb - pa
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=1, depth=1)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=1, radius2=r2 / r, depth=1)
    o = bpy.context.object
    q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    m = Matrix.Translation((pa + pb) / 2) @ q @ Matrix.Diagonal((r, r, d.length, 1))
    return _place(o, m, group, min(bevel, r * 0.4, d.length * 0.3))


def ball(group, c, s, seg=10, rings=7, rot=None):
    """Low-poly ellipsoid, size s = diameters (x, y, z)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=0.5)
    o = bpy.context.object
    m = Matrix.Translation(R(*c)) @ rotm(rot) @ Matrix.Diagonal((s[0], s[2], s[1], 1))
    return _place(o, m, group, 0)


def ring(group, c, normal, major, minor, seg=12, minor_seg=6):
    """Torus centred at c, its hole facing `normal` (roblox vector)."""
    bpy.ops.mesh.primitive_torus_add(major_segments=seg, minor_segments=minor_seg, major_radius=major, minor_radius=minor)
    o = bpy.context.object
    n = R(*normal)
    q = Vector((0, 0, 1)).rotation_difference(n.normalized()).to_matrix().to_4x4()
    return _place(o, Matrix.Translation(R(*c)) @ q, group, 0)


def prism(group, pts, origin, u, v, thick, bevel=0.02):
    """Extrude a 2D outline `pts` [(pu, pv)…] lying in the plane spanned by
    roblox vectors u, v at `origin`, `thick` studs thick (centred)."""
    o3, u3, v3 = Vector(origin), Vector(u).normalized(), Vector(v).normalized()
    n3 = u3.cross(v3).normalized() * (thick / 2)
    bm = bmesh.new()
    front = [bm.verts.new(R(*(o3 + u3 * a + v3 * b + n3))) for a, b in pts]
    back = [bm.verts.new(R(*(o3 + u3 * a + v3 * b - n3))) for a, b in pts]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("prism")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("prism", me)
    bpy.context.collection.objects.link(o)
    return _place(o, Matrix.Identity(4), group, min(bevel, thick * 0.4))


def arc_pts(cx, cy, r, a0, a1, steps):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


def wheel(c, diameter, width, hub="Accent", tread=False, spokes=0):
    """Chunky cartoon wheel: rubber tyre, coloured rim, chrome cap. Gets
    its own spin rig (unless built inside another rig). What holds it
    (axle, fork, track) is the model's job: see models.wheels()."""
    if _RIG[0] is None:
        with rig(next_spin()):
            wheel(c, diameter, width, hub, tread, spokes)
        return
    x, y, z = c
    hw = width / 2
    r = diameter / 2
    cyl("Rubber", (x - hw, y, z), (x + hw, y, z), r, verts=16, bevel=r * 0.25)
    side = 1 if x >= 0 else -1
    cyl(hub, (x - hw * 1.04, y, z), (x + hw * 1.04, y, z), r * 0.58, verts=12, bevel=0.03)
    cyl("Chrome", (x + side * hw, y, z), (x + side * (hw + 0.06 + r * 0.05), y, z), r * 0.22, verts=8, bevel=0.02)
    for i in range(5 if r > 0.45 else 0):  # wheel nuts round the cap
        a = 2 * math.pi * i / 5
        cyl("Chrome", (x + side * hw, y + math.sin(a) * r * 0.4, z + math.cos(a) * r * 0.4), (x + side * (hw * 1.04 + 0.04), y + math.sin(a) * r * 0.4, z + math.cos(a) * r * 0.4), r * 0.06, verts=5, bevel=0)
    if tread:
        n = 14
        for i in range(n):
            a = 2 * math.pi * i / n
            box("Rubber", (x, y + math.sin(a) * r, z + math.cos(a) * r), (width * 1.02, r * 0.16, r * 0.3), bevel=0.02, rot=[("x", -math.degrees(a))])
    for i in range(spokes):
        a = 360 * i / spokes
        box("Dark", (x + side * hw * 0.9, y, z), (0.04, r * 1.0, r * 0.12), bevel=0.0, rot=[("x", a)])


# Baked shading, stored as vertex colours (Roblox multiplies them with the
# part's colour, so every repaint of a tool keeps it). It is the painted
# look of the models: corners and gaps get darker (ambient occlusion), so
# does everything near the ground, tops catch more light than undersides,
# light is warm and shadow cool (late afternoon), and chamfered edges are
# a touch brighter, like worn paint.
EDGE = "edge"  # face attribute: this face is a chamfer
AO_REACH = 1.6  # studs a neighbour can shade from
AO_DARKEST = 0.5  # multiplier in the deepest corner
GROUND_SHADE = (2.5, 0.85)  # below this height (studs) pieces fade down to this multiplier
UNDERSIDE = 0.8  # faces looking straight down (sides get 0.93)
FLAT = 0.93  # flat faces; chamfers stay at 1
WARM = (1.0, 0.97, 0.9)  # tint of full light
COOL = (0.78, 0.8, 1.0)  # tint of deep shadow
UNSHADED = {"Light", "Glow", "Tail", "Glass", "Crystal"}  # glowing / see-through groups keep their colour
_RAYS = [
    Vector((math.cos(a) * math.sin(t), math.sin(a) * math.sin(t), math.cos(t)))
    for t in (math.radians(25), math.radians(55), math.radians(80))
    for a in [math.radians(k * 45 + t * 37) for k in range(8)]
]


def _tree(objs):
    from mathutils.bvhtree import BVHTree

    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def shade(objs, ground):
    """Bake the shading of `objs` (pieces that never move against each
    other) into their "Col" colour attribute."""
    tree = _tree(objs)
    for o in objs:
        me = o.data
        layer = me.color_attributes.get("Col") or me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        if o.get("grp", "").split(".")[0] in UNSHADED:
            for d in layer.data:
                d.color = (1, 1, 1, 1)
            continue
        edge = me.attributes.get(EDGE)
        mw = o.matrix_world
        for poly in me.polygons:
            n = (mw.to_3x3() @ poly.normal).normalized()
            side = n.orthogonal().normalized()
            basis = Matrix((side, n.cross(side), n)).transposed()
            centre = mw @ poly.center
            light = UNDERSIDE + (1 - UNDERSIDE) * (0.5 + 0.5 * n.z) ** 0.6
            if not (edge and edge.data[poly.index].value):
                light *= FLAT
            for li in poly.loop_indices:
                corner = mw @ me.vertices[me.loops[li].vertex_index].co
                p = corner.lerp(centre, 0.12) + n * 0.02
                open_sky = 0.0
                for ray in _RAYS:
                    d = basis @ ray
                    hit = tree.ray_cast(p, d, AO_REACH)[0]
                    reach = (hit - p).length / AO_REACH if hit else 1.0
                    if ground and d.z < -1e-3:  # the ground shades too (Blender Z is up)
                        reach = min(reach, max(p.z, 0) / -d.z / AO_REACH)
                    open_sky += min(reach, 1.0)
                v = light * (AO_DARKEST + (1 - AO_DARKEST) * (open_sky / len(_RAYS)) ** 0.8)
                if ground:
                    height, low = GROUND_SHADE
                    v *= low + (1 - low) * min(max(corner.z, 0) / height, 1)
                layer.data[li].color = (*(v * (c + (w - c) * v) for w, c in zip(WARM, COOL)), 1)


def finish(name, ground=True):
    """Shade, join pieces by group, flat-shade, export-ready. `ground`:
    the model stands on the ground (hand tools don't)."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    fixed = [o for o in meshes if not o.get("rig")]
    if fixed:
        shade(fixed, ground)
    rigs = {}
    for o in meshes:
        if o.get("rig"):
            rigs.setdefault(o["rig"], []).append(o)
    for objs in rigs.values():
        shade(objs, False)  # moving pieces only shade themselves
    groups = {}
    for o in meshes:
        key = o.get("grp", "Dark") + (f"#{o['rig']}" if o.get("rig") else "")
        groups.setdefault(key, []).append(o)
    for g, objs in groups.items():
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        for ob in objs:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j.name = g
        j.data.name = g
        for f in j.data.polygons:
            f.use_smooth = False
        # origin at the piece's centre (Roblox places MeshParts by centre)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print(f"MODEL {name}: groups={sorted(groups)} faces={tris}")
