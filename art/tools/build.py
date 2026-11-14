# Builds every base model, exports one FBX per model to out/, and renders
# a preview PNG per model (Workbench, flat colours) to out/preview/.
#
#   flatpak run org.blender.Blender -b --factory-startup \
#       --python $PWD/art/tools/build.py -- [model names…]
#
# (The flatpak needs the script's absolute path.)

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
from models import HAND, MODELS  # noqa: E402

OUT = os.path.join(HERE, "out")
PREVIEW = os.path.join(OUT, "preview")
os.makedirs(PREVIEW, exist_ok=True)

# Preview colours (the game sets the real ones per tool).
COLORS = {
    "Accent": (0.85, 0.2, 0.15),
    "Accent2": (0.98, 0.78, 0.15),
    "Metal": (0.7, 0.72, 0.76),
    "Chrome": (0.92, 0.93, 0.95),
    "Dark": (0.16, 0.16, 0.18),
    "Rubber": (0.08, 0.08, 0.09),
    "Wood": (0.55, 0.36, 0.2),
    "Glass": (0.6, 0.85, 0.95),
    "Light": (1.0, 0.95, 0.55),
    "Seat": (0.25, 0.17, 0.12),
    "Eye": (1, 1, 1),
    "Teeth": (0.98, 0.96, 0.88),
    "Gold": (1.0, 0.78, 0.2),
    "Fabric": (0.3, 0.35, 0.25),
    "Battery": (0.2, 0.75, 0.35),
    "Stone": (0.5, 0.5, 0.55),
    "Glow": (0.9, 0.4, 1.0),
    "Crystal": (0.75, 0.55, 1.0),
    "HandleGrip": (0.12, 0.12, 0.13),
    "SteeringWheel": (0.1, 0.1, 0.1),
    "Tread": (0.3, 0.3, 0.32),
    "Tail": (0.9, 0.12, 0.1),
}


PREVIEW_OVERRIDE = None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lib.reset_state()


def export(name):
    # Roblox's importer turns FBX models 180 degrees around Y (it ignores
    # the axis settings), so bake the opposite turn into the file: in the
    # game, -Z stays forward and +X right.
    bpy.ops.object.select_all(action="SELECT")
    for o in bpy.context.selected_objects:
        o.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ o.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, f"{name}.fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        colors_type="SRGB",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
    )
    for o in bpy.context.selected_objects:
        o.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ o.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)


def shoot(path, direction=(-0.75, 1.0, 0.6), res=640, ortho=False):
    """Render the scene to `path`, looking from `direction` (Blender axes:
    -Y is roblox +Z, so roblox front -Z is Blender +Y)."""
    scene = bpy.context.scene
    shaded = True
    for o in scene.objects:
        if o.type != "MESH":
            continue
        base = o.get("grp") or o.name.split("#")[0].split(".")[0]
        c = COLORS.get(base.split(".")[0], (1, 0, 1))
        o.color = (*c, 1)
        baked = o.data.color_attributes.get("Col")
        if not baked:
            shaded = False
            continue
        # paint x baked shading, roughly as the game shows it
        look = o.data.color_attributes.get("Look") or o.data.color_attributes.new("Look", "FLOAT_COLOR", "CORNER")
        for i, d in enumerate(baked.data):
            look.data[i].color = (c[0] * d.color[0], c[1] * d.color[1], c[2] * d.color[2], 1)
        o.data.color_attributes.active_color = look
    pts = [o.matrix_world @ Vector(c) for o in scene.objects if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center, size = (lo + hi) / 2, (hi - lo).length
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 50
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = size * 0.95
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = center + Vector(direction).normalized() * size * 1.55
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"  # colours as painted, not film-toned
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "VERTEX" if shaded else "OBJECT"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_object_outline = True
    scene.display.render_aa = "8"
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.film_transparent = False
    if not scene.world:
        scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.93, 0.9, 0.82)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def preview(name):
    shoot(PREVIEW_OVERRIDE or os.path.join(PREVIEW, f"{name}.png"))


def bounds():
    """Bounding box of the whole model (all extras), in roblox coords."""
    pts = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == "MESH" for c in o.bound_box]
    rb = [(p.x, p.z, -p.y) for p in pts]
    lo = [min(p[i] for p in rb) for i in range(3)]
    hi = [max(p[i] for p in rb) for i in range(3)]
    return {"center": [round((lo[i] + hi[i]) / 2, 3) for i in range(3)], "size": [round(hi[i] - lo[i], 3) for i in range(3)]}


# Where the rider's body goes, per model (roblox coords): ("stand", deck
# height) for platforms, ("sit", (x, seat top, z)) for seats. clearance()
# reports every mesh that pokes into that space (head, torso or legs).
RIDERS = {
    "rider": ("sit", (0, 2.4, 0.6)),
    "zeroturn": ("sit", (0, 2.15, 0.4)),
    "tractor": ("sit", (0, 3.075, 0.6)),
    "combine": ("sit", (0, 3.2, -0.2)),
    "fortress": ("sit", (0, 3.2, -0.2)),
    "mega_push": ("stand", 2.23),
    "drone": ("stand", 2.28),
    "swarm": ("stand", 2.28),
    "void": ("stand", 2.2),
    "airship": ("stand", 2.2),
    "drill": ("stand", 3.15),
    "mowzilla": ("stand", 3.95),
}
ALLOWED = {"SteeringWheel", "Seat", "Tread"}  # what the rider holds, sits and stands on


def _box_tree(lo, hi):
    from mathutils.bvhtree import BVHTree

    (x0, y0, z0), (x1, y1, z1) = lo, hi
    corners = [lib.R(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return BVHTree.FromPolygons(corners, faces)


def clearance(name):
    spec = RIDERS.get(name)
    if not spec:
        return []
    from mathutils.bvhtree import BVHTree

    kind, where = spec
    if kind == "stand":
        boxes = {"body": ((-0.85, where + 0.15, -0.65), (0.85, where + 5.4, 0.65))}
    else:
        x, y, z = where
        boxes = {
            "body": ((x - 0.85, y + 0.1, z - 0.6), (x + 0.85, y + 3.7, z + 0.6)),
            "legs": ((x - 0.8, y - 0.95, z - 1.5), (x + 0.8, y + 0.5, z - 0.45)),  # feet rest 1 stud under the seat
        }
    hits = []
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.get("grp", o.name).split("#")[0].split(".")[0] in ALLOWED:
            continue
        world = [o.matrix_world @ v.co for v in o.data.vertices]
        tree = BVHTree.FromPolygons(world, [tuple(p.vertices) for p in o.data.polygons])
        for part, (lo, hi) in boxes.items():
            box = _box_tree(lo, hi)
            inside = any(all(lo[i] - 1e-3 <= (v.x, v.z, -v.y)[i] <= hi[i] + 1e-3 for i in range(3)) for v in world)
            if inside or tree.overlap(box):
                hits.append(f"{o.get('grp', o.name)}->{part}")
    return hits


def main():
    path = os.path.join(OUT, "meta.json")
    meta = json.load(open(path)) if os.path.exists(path) else {}
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    for name in names or list(MODELS):
        reset()
        MODELS[name]()
        lib.finish(name, ground=name not in HAND)
        meta[name] = bounds()
        meta[name]["pivots"] = {k: v for k, v in lib.PIVOTS.items() if not k.startswith("Spin")}
        hits = clearance(name)
        print(f"CLEAR {name}: " + (", ".join(hits) if hits else "ok"))
        export(name)
        preview(name)
    json.dump(meta, open(path, "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
