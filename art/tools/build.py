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
from models import MODELS  # noqa: E402

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
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
    )
    for o in bpy.context.selected_objects:
        o.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ o.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)


def preview(name):
    scene = bpy.context.scene
    for o in scene.objects:
        base = o.name.split("#")[0].split(".")[0]
        c = COLORS.get(base, (1, 0, 1))
        o.color = (*c, 1)
    pts = [o.matrix_world @ Vector(c) for o in scene.objects if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center, size = (lo + hi) / 2, (hi - lo).length
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    # 3/4 view from the front-left, a bit above (Blender: -Y is roblox +Z,
    # so roblox front -Z is Blender +Y).
    direction = Vector((-0.75, 1.0, 0.6)).normalized()
    cam.location = center + direction * size * 1.55
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "OBJECT"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_object_outline = True
    scene.display.render_aa = "8"
    scene.render.resolution_x = scene.render.resolution_y = 520
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.color = (0.93, 0.9, 0.82)
    scene.world = world
    scene.render.filepath = PREVIEW_OVERRIDE or os.path.join(PREVIEW, f"{name}.png")
    bpy.ops.render.render(write_still=True)


def bounds():
    """Bounding box of the whole model (all extras), in roblox coords."""
    pts = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == "MESH" for c in o.bound_box]
    rb = [(p.x, p.z, -p.y) for p in pts]
    lo = [min(p[i] for p in rb) for i in range(3)]
    hi = [max(p[i] for p in rb) for i in range(3)]
    return {"center": [round((lo[i] + hi[i]) / 2, 3) for i in range(3)], "size": [round(hi[i] - lo[i], 3) for i in range(3)]}


def main():
    path = os.path.join(OUT, "meta.json")
    meta = json.load(open(path)) if os.path.exists(path) else {}
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    for name in names or list(MODELS):
        reset()
        MODELS[name]()
        lib.finish(name)
        meta[name] = bounds()
        export(name)
        preview(name)
    json.dump(meta, open(path, "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
