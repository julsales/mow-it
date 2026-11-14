# Writes out/meta.json boxes/pivots and out/assets.json asset ids into
# Config/HayYard.luau (Models table), like art/tools/sync_config.py does for
# the tools.
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "../../src/ReplicatedStorage/Shared/Config/HayYard.luau")
meta = json.load(open(os.path.join(HERE, "out/meta.json")))
assets_path = os.path.join(HERE, "out/assets.json")
assets = json.load(open(assets_path)) if os.path.exists(assets_path) else {}
text = open(CONFIG).read()


def v3(v):
    return "Vector3.new(" + ", ".join(f"{x:g}" for x in v) + ")"


for name, box in meta.items():
    row = re.compile(rf"\t\t{name} = \{{ AssetId = (\d+),[^\n]*\n")
    found = row.search(text)
    if not found:
        raise SystemExit(f"no Models row for {name}")
    asset = assets.get(name) or int(found.group(1))
    piv = box.get("pivots") or {}
    pivots = ", Pivots = { " + ", ".join(f"{k} = {v3(v)}" for k, v in sorted(piv.items())) + " }" if piv else ""
    line = f"\t\t{name} = {{ AssetId = {asset}, Center = {v3(box['center'])}, Size = {v3(box['size'])}{pivots} }},\n"
    text = text[: found.start()] + line + text[found.end() :]
open(CONFIG, "w").write(text)
print("synced", len(meta), "models,", len(assets), "asset ids")
