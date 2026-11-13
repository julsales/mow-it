# Writes out/meta.json boxes and out/assets.json asset ids into
# Config/ToolArt.luau (Models table), so the game puts each imported mesh
# back exactly where it was authored.
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "../../src/ReplicatedStorage/Shared/Config/ToolArt.luau")
meta = json.load(open(os.path.join(HERE, "out/meta.json")))
assets_path = os.path.join(HERE, "out/assets.json")
assets = json.load(open(assets_path)) if os.path.exists(assets_path) else {}
text = open(CONFIG).read()


def v3(v):
    return "Vector3.new(" + ", ".join(f"{x:g}" for x in v) + ")"


for name, box in meta.items():
    pattern = re.compile(rf"(\t{name} = \{{ AssetId = )(\d+)(, Center = )Vector3\.new\([^)]*\)(, Size = )Vector3\.new\([^)]*\)")
    if not pattern.search(text):
        raise SystemExit(f"no Models row for {name}")
    asset = str(assets.get(name, 0))
    text = pattern.sub(lambda m: m.group(1) + (asset if asset != "0" else m.group(2)) + m.group(3) + v3(box["center"]) + m.group(4) + v3(box["size"]), text)
open(CONFIG, "w").write(text)
print("synced", len(meta), "models,", len(assets), "asset ids")
