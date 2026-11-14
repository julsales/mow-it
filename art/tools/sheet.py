# Contact sheets (system Python + Pillow; Blender's Python has none):
#   python3 art/tools/sheet.py          out/catalog/*.png -> out/catalog.png,
#                                       labelled, in Config/ToolArt order
#                                       (run after catalog.py)
#   python3 art/tools/sheet.py audit    joins audit.py's four views per
#                                       model into out/audit/<model>.png
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))


def catalog_sheet():
    cfg = open(os.path.join(HERE, "../../src/ReplicatedStorage/Shared/Config/ToolArt.luau")).read()
    ids = re.findall(r'^\s*(\w+) = \{ Model = "', cfg, re.M)
    cell, cols = 220, 8
    sheet = Image.new("RGB", (cols * cell, (len(ids) + cols - 1) // cols * cell), (238, 230, 210))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 14)
    except OSError:
        font = None
    for i, tool in enumerate(ids):
        x, y = (i % cols) * cell, (i // cols) * cell
        sheet.paste(Image.open(os.path.join(HERE, f"out/catalog/{tool}.png")).convert("RGB").resize((cell, cell)), (x, y))
        draw.text((x + 6, y + 6), tool, fill=(40, 30, 20), font=font)
    sheet.save(os.path.join(HERE, "out/catalog.png"))


def audit_sheets():
    folder = os.path.join(HERE, "out/audit")
    names = sorted({f[1:].rsplit("_", 1)[0] for f in os.listdir(folder) if f.startswith(".")})
    for name in names:
        out = Image.new("RGB", (1120, 1120))
        for i, view in enumerate(("front", "side", "back", "top")):
            path = os.path.join(folder, f".{name}_{view}.png")
            out.paste(Image.open(path).convert("RGB"), ((i % 2) * 560, (i // 2) * 560))
            os.remove(path)
        out.save(os.path.join(folder, f"{name}.png"))


if __name__ == "__main__":
    audit_sheets() if "audit" in sys.argv[1:] else catalog_sheet()
