# Labelled contact sheet of the catalog renders: out/catalog/*.png ->
# out/catalog.png, in Config/ToolArt order (run after catalog.py).
import os
import re

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
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
