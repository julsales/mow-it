# Renders every tool as the game paints it (Config/ToolArt.luau colours and
# extras) to out/catalog/<tool>.png, then a labelled sheet out/catalog.png.
#
#   flatpak run org.blender.Blender -b --factory-startup --python $PWD/art/tools/catalog.py
import os, re, sys
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build  # noqa: E402  (builds nothing when imported with no-op args)
import lib  # noqa: E402
from models import MODELS  # noqa: E402

CONFIG = os.path.join(HERE, "../../src/ReplicatedStorage/Shared/Config/ToolArt.luau")
ROW = re.compile(r'^\s*(\w+) = \{ Model = "(\w+)", Color = rgb\((\d+), (\d+), (\d+)\), Color2 = rgb\((\d+), (\d+), (\d+)\)(?:, Extras = \{ ([^}]*) \})?', re.M)
OUT = os.path.join(HERE, "out/catalog")
os.makedirs(OUT, exist_ok=True)

def srgb(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

rows = ROW.findall(open(CONFIG).read())
for tool, model, r, g, b, r2, g2, b2, extras in rows:
    keep = set(re.findall(r'"(\w+)"', extras or ""))
    build.reset()
    MODELS[model]()
    lib.finish(model)
    for o in list(bpy.context.scene.objects):
        name = o.name.split("#")[0]
        if "." in name and name.split(".", 1)[1] not in keep:
            bpy.data.objects.remove(o)
    build.COLORS["Accent"] = tuple(srgb(int(v)) for v in (r, g, b))
    build.COLORS["Accent2"] = tuple(srgb(int(v)) for v in (r2, g2, b2))
    build.PREVIEW_OVERRIDE = os.path.join(OUT, f"{tool}.png")
    build.preview(tool)
print("CATALOG", len(rows))
