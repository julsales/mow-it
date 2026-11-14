# Builds the hay yard models -> out/<model>.fbx, out/meta.json (authored
# boxes and rig pivots), checks that nothing floats, and renders four views
# per model to out/views/ (python3 art/tools/sheet.py is for the tools; the
# views here are single PNGs).
#
#   flatpak run org.blender.Blender -b --factory-startup \
#       --python $PWD/art/yard/build.py -- [model names…]

import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(HERE, "..", "tools")
sys.path.insert(0, HERE)
sys.path.insert(0, TOOLS)

import audit  # noqa: E402  (tools: float check)
import build as kit  # noqa: E402  (tools: export, shoot, bounds)
import lib  # noqa: E402
from yard_models import MODELS  # noqa: E402

OUT = os.path.join(HERE, "out")
VIEWS = os.path.join(OUT, "views")
os.makedirs(VIEWS, exist_ok=True)
kit.OUT = OUT

kit.COLORS.update(
    {
        "Accent": (0.84, 0.25, 0.2),
        "Accent2": (0.98, 0.77, 0.24),
        "Body": (0.93, 0.89, 0.77),
        "Roof": (0.7, 0.22, 0.19),
        "Hay": (0.8, 0.72, 0.36),
        "Straw": (0.9, 0.84, 0.5),
        "Twine": (0.47, 0.33, 0.2),
        "Grass": (0.43, 0.67, 0.27),
        "Lamp": (1.0, 0.75, 0.2),
        "Stone": (0.62, 0.6, 0.57),
        "Mannequin": (0.35, 0.6, 0.95),
    }
)
# A stand-in player beside each model, for scale (not exported).
MANNEQUIN_AT = {"baler": (-1.6, 0.54, 3.6), "pallet": (0, 0, 3.2), "silo": (0, 0, 6.6), "bale": (0, 0, 2.2)}


def mannequin(at):
    x, y, z = at
    return [
        lib.box("Mannequin", (x, y + 1.35, z), (0.95, 2.7, 0.9), bevel=0.08),
        lib.box("Mannequin", (x, y + 3.6, z), (1.9, 1.8, 0.95), bevel=0.08),
        lib.box("Mannequin", (x, y + 5.05, z), (1.15, 1.1, 1.1), bevel=0.08),
    ]


def main():
    path = os.path.join(OUT, "meta.json")
    meta = json.load(open(path)) if os.path.exists(path) else {}
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    total = 0
    for name in names or list(MODELS):
        # 1. audit on the separate pieces
        kit.reset()
        MODELS[name]()
        pieces = [audit.Piece(o) for o in bpy.context.scene.objects if o.type == "MESH"]
        problems = audit.check_float(pieces, [None] * len(pieces))
        for p in pieces:
            low = min(audit.rb(v).y for v in p.verts)
            if low < -0.02:
                problems.append(f"GROUND {p.label()} is {-low:.2f} under the ground")
        total += len(problems)
        print(f"AUDIT {name}: {len(pieces)} pieces, " + (f"{len(problems)} problem(s)" if problems else "ok"))
        for line in problems:
            print(f"AUDIT   {line}")
        # 2. export
        lib.finish(name, ground=True)
        meta[name] = kit.bounds()
        meta[name]["pivots"] = dict(lib.PIVOTS)
        kit.export(name)
        # 3. views, with a player for scale
        for o in mannequin(MANNEQUIN_AT[name]):
            o.name = "Mannequin"
        for label, direction, ortho in audit.VIEWS:
            kit.shoot(os.path.join(VIEWS, f"{name}_{label}.png"), direction, res=720, ortho=ortho)
    json.dump(meta, open(path, "w"), indent=1, sort_keys=True)
    print(f"AUDIT total: {total} problem(s)")


if __name__ == "__main__":
    main()
