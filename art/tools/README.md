# Tool art (Blender → Roblox)

The 48 tools are drawn from **15 low-poly base models** made in Blender by
Python scripts (no hand-edited .blend files), so every change is a diff.

| File | What it is |
|---|---|
| `lib.py` | Tiny modelling kit in Roblox coordinates (studs, +Y up, −Z forward): boxes, cylinders, wheels, extruded outlines. Pieces are grouped by colour and joined into one mesh per group. `shade()` bakes the painted look into vertex colours. |
| `models.py` | The 15 base models (plus the themed late-game ones), built from shared parts: `wheels()` on an axle, `caster()`, `fender()`, `track()`, `seat()`, `steering()`, `handrail()`. |
| `build.py` | Builds them all → `out/<model>.fbx`, `out/meta.json` (authored bounding boxes, axles), previews in `out/preview/`. |
| `audit.py` | Checks every model (nothing floating, turning pieces have room, wheels on the ground, rider not inside anything) and renders 4 views with a stand-in rider to `out/audit/`. |
| `catalog.py` | Renders all 48 tools painted like the game paints them → `out/catalog/`. |
| `sheet.py` | Joins renders into sheets: `out/catalog.png`, `out/audit/<model>.png`. |

```bash
flatpak run org.blender.Blender -b --factory-startup --python $PWD/art/tools/build.py      # all models
flatpak run org.blender.Blender -b --factory-startup --python $PWD/art/tools/build.py -- push   # one
flatpak run org.blender.Blender -b --factory-startup --python $PWD/art/tools/audit.py && python3 art/tools/sheet.py audit
flatpak run org.blender.Blender -b --factory-startup --python $PWD/art/tools/catalog.py && python3 art/tools/sheet.py
```

**Run the audit after every change to a model; it must end with
`AUDIT total: 0 problem(s)`.** A piece that is meant to hover belongs in
`audit.FLOATERS`; everything else has to hold on to something.

## Style

Chunky cartoon low-poly, like the rest of the map: big rounded shapes with
one chamfer (bevel, 1 segment), flat shading, few colours.
Proportions are exaggerated so tools read at a glance: fat wheels and
tyres, oversized engines and grips, chrome bits that catch the light.
Machines must make sense: wheels on axles or in forks, mow decks hung
from the chassis, seats on pedestals, steering rims on spokes, a way up
to every cab.
No image textures. The painted look is baked into **vertex colours**
(`lib.shade()`): darker corners and gaps, darker near the ground, tops
lighter than undersides, warm light and cool shadow (late afternoon), and
chamfers a touch brighter like worn paint. Roblox multiplies vertex
colours with the part colour, so one mesh still takes any tool's paint.
Surface feel comes from Roblox materials per group
(`Config/ToolArt.Pieces`): rubber tyres, leather seats, diamond-plate
foot plates (`Tread`), brushed metal, wood, fabric, cobblestone.
Each upgrade family adds a fun signature piece (Turbo exhausts, Longhorn
horns, the Royal crown, Volt bolts, MOWZILLA's teeth and eyes).
References looked at: Roblox mowing simulators (Mowing Masters, Lawn
Mowing Simulator), stylized low-poly farm packs (tractors, scythes,
shears) on CGTrader/Fab — for the vibe only, nothing copied.

## How the game uses them

Mesh names are colour groups the game paints (`Shared/Config/ToolArt.luau`):
`Accent` / `Accent2` take the tool's two colours; `Metal`, `Chrome`,
`Dark`, `Rubber`, `Tread`, `Wood`, `Glass`, `Light`, `Tail`, `Seat`, `Gold`… are fixed.
`Group.Extra` meshes (e.g. `Chrome.Turbo`) are kept only for tools that
list that extra. `HandleGrip` / `SteeringWheel` are where the hands go.

Conventions: hand tools have the grip at the origin and point −Z; ground
tools have the origin on the ground under the player. Push and reel mowers
have no handle in the mesh: the game builds one fitted to the avatar.

## Uploading

Each `out/<model>.fbx` is uploaded as a **Model** owned by the game's group
(152627407) with Studio MCP `open_cloud_invoke`: `POST /assets/v1/assets`
for a new one, `PATCH /assets/v1/assets/<id>` for a new version of an
existing one (keeps the id). Studio runs in Vinegar and only sees
`~/Documents`, approved in Assistant → Settings → MCP Permissions as
`Z:/home/julia/Documents`, so the files go through
`~/Documents/MowItToolArt/` and the upload path is written
`Z:/home/julia/Documents/MowItToolArt/<model>.fbx`. Record new ids in
`out/assets.json`, then `python3 art/tools/sync_config.py` writes ids and
the `out/meta.json` boxes into `Config/ToolArt.Models`.

The importer turns FBX files 180° around Y; `build.py` bakes the opposite
turn into the export, so in the game −Z stays forward. Units are 1:1
(one Blender unit = one stud).
`ToolArtService` loads them with InsertService at startup; a model with
`AssetId = 0` keeps the old Part-built look.
