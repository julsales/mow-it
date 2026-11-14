# Mow It! — Reusable Asset Map

> **Rule #1: map first, import second, build last.**
> This file is the shopping list. Nothing enters the game until it is a row
> in one of these tables, with a source link, a license note, and an audit
> result. Prefer ready-made assets over generating new ones.
>
> **Rule #2: NO assets are copied from `Roblox_Game`.**
> That repo is a different game with a lot of unverified models, embedded
> scripts and mixed-provenance content ("porca" = junk risk). From it we
> reuse **only**:
> - the `roblox` agent skill (`.agents/skills/roblox/`, copied verbatim), and
> - its *repo organization patterns* (see `docs/ARCHITECTURE.md`).
>
> Its models, `tools/build/*` model generators, UI reference images and item
> catalogs stay there. If we ever change our mind about one specific item,
> it gets audited alone (scripts removed, provenance checked) and added as
> a new row here first.

## How to import a Creator Store asset safely

1. In Studio: **Home → Creator Store** (or View → Toolbox), search, **Insert**.
2. **Audit before it touches the real map:**
   - Select the inserted model → search its descendants for `Script` /
     `LocalScript` / `ModuleScript` you didn't write. **Delete them all**
     unless the listing explicitly documents why they exist. (Example
     below: the low-poly farm ships with 1 script — it does not survive.)
   - Check triangle count (View → Stats / model properties). Reject
     anything absurd for its size; grass must be nearly free.
   - Check for `FireServer`, `GetAsync`, free-model backdoors, weird
     `require(<number>)` calls. Any `require` by asset id = reject.
3. Rename to the convention in the last column, move it under the right
   folder (`ServerStorage/AssetLibrary/...` for templates the server
   clones, `ReplicatedStorage/Assets/...` only if the client needs it),
   and mark the row ✅ with the date + your initials.
4. Record the final Roblox asset id in the row after you re-upload any
   edited version as your own model. Never depend on the Toolbox copy
   staying available.

Status key: 🗺️ mapped (researched, not yet inserted) · 🔎 verify in Studio
(quality/license unconfirmed) · ✅ imported & audited · ❌ rejected

---

## 1. Icons (HUD, shop, gamepasses)

### Generated simulator art v3 — mapped and audited, upload pending

The owner requested a richer simulator family and rejected the flat heavy
brown-outline board. Native image_gen produced the following project-bound
art in `assets/UI/generated-v3/`; prompts and generation IDs are recorded in
`docs/art/generated-v3/prompts.json`. Reference: the owner's supplied simulator
screenshot, used for style/composition rather than copied logos/characters.
Audit: 20 PNG files, RGBA with transparent exteriors; no scripts or linked
content. Original generated pixel/alpha data is preserved. The presentation
background in `docs/art/generated-v3/` is design-only, not a new map asset.

| Family | Files | Status |
| --- | --- | --- |
| Currency | `coin-single`, `coin`, `clover` | Audited; single coin for HUD, stack for offers |
| Navigation/resources | `crew`, `passes`, `quests`, `rewards`, `fuel`, `grass` | Audited; separate icon layers |
| Quest availability | `quest-available` | Audited; red exclamation selected by owner |
| Weather | `weather-clear`, `weather-golden`, `weather-rain`, `weather-night`, `weather-storm` | Audited; rounded sun and reflective golden variant selected |
| Skins | `window-frame`, `button-base`, `offer-banner`, `banner-base` | Audited; square and long neutral tintable bases |
| Effects | `rays` | Audited; separate translucent layer |

Assembled and visually inspected in OpenPencil, with editable text, separate
images and a long shop-content board. **Not yet uploaded or bound in Roblox.**
Do not replace Interface IDs with filenames or fabricated IDs. UI viewport,
scroll canvas, aspect ratio/slicing and touch behavior require Studio QA.

### Previous runtime vector icons

HUD revision: project-authored vector sources in `assets/UI/source/`, rendered
to transparent 1024px PNG by `tools/build-ui-icons.py`. Mapped before import:
Crew, Shop, Quests, Rewards, Pack, Coin, Clover, Grass, Fuel and five weather
symbols (clear, rain, golden sun, moon night, storm). No external content or
scripts; project-owned drawings. Audit: SVG geometry only, PNG RGBA only.
Final image IDs are recorded in `Shared/Config/Interface.luau` after upload.

| Need in Mow It! | Candidate | Source | Cost / License | Status | Goes to |
|---|---|---|---|---|---|
| Coin, grass, tool, backpack, zone, boost, settings, close, arrows (≈125 icons) | **Simulator Icon Pack** | [Creator Store asset 99176447965360](https://create.roblox.com/store/asset/99176447965360/Simulator-Icon-Pack) | Free in Creator Store; use under Roblox Creator Store terms | 🗺️ | `ReplicatedStorage/Assets/Icons/` after upload as Images |
| Simulator icon set with PNG/SVG at 64–256px, recolor variants | **Free Icon Pack by gvesster** | [gvesster.itch.io/free-icon-pack](https://gvesster.itch.io/free-icon-pack) | Free; commercial use allowed, credit optional, **no resale/re-upload as a pack** | 🗺️ | Upload individually as Roblox Images; keep license file with sources outside the place |
| 349 cartoon simulator icons (eggs/pets/currency/boosts/gamepasses), 20-icon free sampler | **Simulator Icon Pack (Kedrem)** | [itch.io announcement](https://itch.io/t/7169016/assets-simulator-icon-pack-349-cartoon-ui-icons-for-roblox-simulators-and-tycoons-free-20-icon-sampler) | Sampler free for commercial use; full $7.99 / DEV $11.99 | 🔎 only if the two free sets above leave gaps | Same as above |
| Glossy/Stud icon set + 24 gamepass-ready icons + spritesheets with `icons.json` | **Simulator Icons for Roblox (Gridwright)** | [gridwright.store](https://gridwright.store/library/roblox-simulator-icons-gamepass-icons-svg-glossy-stud) | Free sample; license: use in your games incl. commercial, don't resell/share files | 🔎 optional style alternative — pick ONE icon style for the whole game | Same as above |

**Decision to make in the Assets phase:** pick exactly one icon family
(Creator Store pack is the default choice — zero upload friction) so the
HUD/shop/gamepass art all match. Mixed icon styles = instant slop look.

## 2. UI kits / frames (shop, inventory, settings...)

Current revision: five project-owned, text-free components were authored as
editable OpenPencil layers: `panel-frame`, `nav-crew`, `nav-shop`, `nav-quests`,
`nav-rewards`. Sources, exported SVGs and the `.fig` document are in
`docs/art/openpencil/`; 512px RGBA runtime candidates are in `assets/UI/`.
Audit: local SVG paths only; no scripts, links or external images. Alpha was
verified after removing the editor exporter's opaque full-canvas rectangle
with `tools/render-ui-chrome.py`. Status: **exported, upload and Studio Play
review pending**. `Interface.Images.Chrome` remains empty until real upload
IDs are returned. Native Roblox shapes provide the interim rendering.

| Need in Mow It! | Candidate | Source | Cost / License | Status | Goes to |
|---|---|---|---|---|---|
| Shop frame, inventory frame, settings, stats, codes, quest frames (no scripts — we wire our own remotes) | **Free Clicking Simulator Kit — NO SCRIPTS** | [Creator Store asset 17684626284](https://create.roblox.com/store/asset/17684626284/Free-Clicking-Simulator-Kit-NO-SCRIPTS) | Free; Creator Store terms. "No scripts" is exactly why it's first choice | 🗺️ | Build our `PlayerGui` screens from its frames in Studio; scripts stay ours in `src/` |
| General UI organization guidance (clone UI from ReplicatedFirst/ReplicatedStorage, not StarterGui) | Roblox DevForum: *Organizing your game* | [devforum.roblox.com/t/organizing-your-game/3560964](https://devforum.roblox.com/t/organizing-your-game/3560964) | Reference only | 🗺️ | Pattern, already applied (see ARCHITECTURE) |

Our code HUD (`src/StarterPlayer/.../Main.client.luau`) is a placeholder
that feeds real data to whatever kit wins. Replace widgets, keep bindings.

## 3. 3D models — grass, tools, environment

| Need in Mow It! | Candidate / search | Source | Cost / License | Status | Goes to |
|---|---|---|---|---|---|
| Lawn grass (thousands of cells — must be nearly free) | **Roblox Terrain Grass with Decoration** (built-in 3D blades that sway in the wind); mowed cells switch to LeafyGrass/Ground recolored as striped short lawn | Built into Roblox | Free | ✅ 2026-11-11. The Low Poly Grass (Creator Store 14566481901) was tried first and ❌ dropped: it looked like flat spikes and was rated "very basic" in playtest | `GrassService` (Terrain edits, replicate to everyone) |
| Nail Clipper tool model | Creator Store "nail clippers" by BIack_Rose ([13408646708](https://create.roblox.com/store/asset/13408646708)) — the only real match in a free search | Free listing, but ❌ insert refused in Studio ("loadCachedAssetAsync returned nil": not distributable) | ❌ 2026-11-11 | — |
| Nail Clipper tool model (in use) | **"Fingernail clippers"** by IAmNotL0maxx ([10276788826](https://create.roblox.com/store/asset/10276788826)): 5 Unions + 1 Part, 0 scripts | Free; Creator Store terms | ✅ 2026-11-11 audited (no scripts, no require), turned tip-forward, scaled to 2.2 studs | `ServerStorage/ToolOverrides/nail_clipper` in the place file (Unions can't go through Rojo). Fallback: Part-built clipper in `ToolModels` |
| Safety Scissors tool model | "Scissors" by Galaxy_girl644YT ([14057618925](https://create.roblox.com/store/asset/14057618925)): yellow handles, 0 scripts | Free; Creator Store terms | ✅ 2026-11-11 audited, turned tip-forward | `ServerStorage/ToolOverrides/safety_scissors` (place file) |
| Kitchen Scissors / Garden Shears tool model | "Scissors" by diviznn ([522596912](https://create.roblox.com/store/asset/522596912)): 1 MeshPart, 0 scripts | Free; Creator Store terms | ✅ 2026-11-11 audited; shears = green-tinted copy | `ServerStorage/ToolOverrides/kitchen_scissors`, `garden_shears` (place file) |
| Tool shop building (shell) | "Log cabin (No interior)" by C_KS2009 ([15169621766](https://create.roblox.com/store/asset/15169621766)): 46 parts, 0 scripts | Free; Creator Store terms | ✅ 2026-11-11 audited; scaled 1.6x, door opened in code, furnished by `ShopInterior` | `ServerStorage/MapProps/ShopCabin` (place file). Fallback: Part-built cabin |
| (rejected) log cabin with interior | "Log Cabin Rustic Mountain Home Interior Exterior" ([100939942881172](https://create.roblox.com/store/asset/100939942881172)) | — | ❌ 2026-11-11: hidden "CoreSkyboxSystem" script with `require` (backdoor pattern) | not used |
| Zone 3–4 farm dressing (barn, fences, crops, silo) | **Low poly farm** (69,346 tris ⚠️ heavy, contains 1 script ⚠️ strip it) | [Creator Store asset 12491931365](https://create.roblox.com/store/asset/12491931365/Low-poly-farm) | Free; Creator Store terms | 🔎 use pieces only, never the whole model at once | `Workspace/Zones/sunny_farm/`, `big_ranch/` dressing |
| Zone 1 house + yard props | Creator Store → Structures → search `Classic House`, `Small House`, `Suburban House` | [Creator Store: 3D Structures](https://create.roblox.com/store/category/3d/structures) | Mostly free; check each listing | 🔎 pick in Studio, audit scripts, log the id here | `Workspace/Zones/front_yard/` |
| Zone 5 estate / golf dressing | Search `golf course`, `mansion`, `park fountain` in Creator Store | Creator Store search | Check each listing | 🔎 | `Workspace/Zones/golf_estate/` |
| Tool models ×48 (nail clipper → MOWZILLA) | **Our own low-poly Blender art** (`art/tools/`): 15 base models made by Blender Python scripts, painted and given extras per tool by `Config/ToolArt`. Style: chunky cartoon, flat colours, one chamfer | Made by us; uploaded as Model assets owned by the game's group (ids in `Config/ToolArt.Models`) | Ours | ✅ 2026-11-13 uploaded (no scripts; `ToolArtService` strips code anyway). Supersedes the Creator Store clipper/scissors rows above (their place-file overrides are no longer used while the art loads) | `ToolArtService` → `ReplicatedStorage/ToolArt/<model>` → `ToolModels`. Fallback: Part-built shapes in `ToolModels`; a hand-made `assets/Tools/<ToolId>.rbxm` still wins |
| Helper NPC / robot mower / drone visuals | Reuse tool-search results (`robot mower`, `drone`) + a simple rigged NPC from Creator Store (`NPC rig R6`) | Creator Store search | Check each listing | 🔎 Phase 6 (automation) | `ServerStorage/AssetLibrary/Automation/` |
| Trees, fences, rocks, lamps (all zones) | Search `low poly tree pack`, `fence pack`, `street lamp` | Creator Store search | Mostly free | 🔎 one consistent low-poly pack for all zones if possible | Per-zone dressing folders |
| Trees, bushes, rocks, flowers (all islands) | **"Low Poly Nature Pack"** by Proudism ([9682467046](https://create.roblox.com/store/asset/9682467046)): 47 MeshParts, 0 scripts (it shipped 3 empty Humanoids and Value objects, removed) | Free; Creator Store terms | ✅ 2026-11-13 audited (no scripts, no `require`) | `ServerStorage/MapProps/{Tree,Bush,Rock,Flora,BlossomTree,Log}` in the place file; `Props.place`/`Props.fromLibrary` clone them, Part-built fallback when missing |
| (rejected) farm buildings pack | "Farm Pack Map Barn Crops Low Poly Texture Mesh" ([97494583679971](https://create.roblox.com/store/asset/97494583679971)) | — | ❌ 2026-11-13: listing says "No scripts" but 4 Scripts + 4 LocalScripts were hidden inside `Weld` objects (`Runtime`, RemoteFunctions, ScreenGuis): backdoor pattern. Deleted right after insert | not used |
| Barn (Sunny Farm) | **"Low Poly Barn"** by i_Rook ([3564797011](https://create.roblox.com/store/asset/3564797011)): 138 Parts, 0 scripts (a Camera and a PointLight removed) | Free; Creator Store terms | ✅ 2026-11-13 audited; walls recolored barn red, scaled 0.55 | `ServerStorage/MapProps/Barn` (place file) |
| Rowboat (home island dock) | **"Low poly boat"** by Geetesh4543 ([117381525558870](https://create.roblox.com/store/asset/117381525558870)): 1 MeshPart, 0 scripts | Free; Creator Store terms | ✅ 2026-11-13 audited, scaled 14x | `ServerStorage/MapProps/Boat` (place file) |
| (rejected) dock | "Low Poly Dock Pier Boat Wharf Jetty" ([82555390539837](https://create.roblox.com/store/asset/82555390539837)) | — | ❌ 2026-11-13: says "No scripts", hides Scripts/LocalScripts + RemoteFunctions inside a Part (`Runtime`), same backdoor as the farm pack. Deleted | not used |
| (rejected) windmills | "Low Poly Windmill Prop" ([133677260361290](https://create.roblox.com/store/asset/133677260361290)): Script + 2 ModuleScripts; "Windmill" ([11546100681](https://create.roblox.com/store/asset/11546100681)): 1,812 Textures, realistic | — | ❌ 2026-11-13 | not used; silo, water tower, mansion, hangar, turbine stay Part-built (flat-colored through `MowItFlat`) |
| (rejected) barn | "Low Poly Barn" by RedynnRay ([14734095080](https://create.roblox.com/store/asset/14734095080)) | — | ❌ 2026-11-13: clean but a plain box, weaker than 3564797011 | not used |
| Flat stylized ground/wood | Texture-less `MaterialVariant`s created by code (`Props.UseFlatMaterials`, `MaterialService/MowItFlat`) | Ours, no assets | ✅ 2026-11-13 | MaterialService overrides for Grass, LeafyGrass, Ground, Mud, Sand, Rock, Slate, Cobblestone, Wood, WoodPlanks, Brick, Fabric |

## 4. Audio

| Need | Where to get it | Status |
|---|---|---|
| Cut/snip, mower loop per tool tier, sell "cha-ching", buy, unlock fanfare, UI click, ambient birds/wind per zone | **Creator Store → Audio** (Studio: Toolbox → Audio). Search the exact phrases; filter by length. Roblox audio has per-asset privacy/permissions — use assets listed as distributable, or upload our own from a royalty-free library and log the source here. | 🔎 mapped as a category; individual ids chosen in Studio, logged here before use |
| Snip, Swish, MowCut, Collect, Full, Sell, Buy, Engine loop (mowing cycle) | **Placeholders built into every Roblox client** (`rbxasset://sounds/...`: swordslash, electronicpingshort, snap, victory, clickfast). All ids in `Shared/Config/Sounds.luau`, played by `Mowing.client.luau` | ✅ placeholders playing; 🔎 swap Engine for a real lawn mower loop (Toolbox → Audio → "lawn mower", or upload the CC0 BigSoundBank #1071 recording) and log the id here |

## 5. VFX / animation

| Need | Where to get it | Status |
|---|---|---|
| Grass-cut burst, coin sparkle, unlock confetti | Build from `ParticleEmitter` presets in Studio, or Creator Store search `grass particles`, `coin sparkle`. Keep counts low (fill-rate — see copied `roblox` skill constraints). | 🔎 |
| Swing animation per tool tier | Creator Store search `mow animation`, `swing tool`, or animate once in Studio's Animation Editor and reuse with different speeds. One good swing clip beats 16 bad ones. | 🔎 |

## 6. Explicitly NOT reused

| From | Why not |
|---|---|
| `Roblox_Game` models / item models / `tools/build/*` generators | Different game, unverified provenance, embedded-script and junk risk. Structure patterns only. |
| Any Toolbox model containing scripts we didn't audit | #1 free-model backdoor vector. No exceptions. |
| Any icon/UI pack without a license we can point to | If it's not a row in this file, it doesn't ship. |

## 7. Owner's interface direction (2026-11-12)

The owner supplied `docs/art/ui-reference.png` for the farm-stall interface.
The palette is centralized in `Shared/Config/Interface.luau`; new operations
panels and Shop reuse it. The image's offers/prices are illustrations only.

| Need | Source | License / provenance | Audit | Destination |
| --- | --- | --- | --- | --- |
| Interface reference | Owner attachment, `docs/art/ui-reference.png` | Provided for this project; reference, not imported as game art | Reference only; no executable content | `docs/art/` |
| Individual icon references | Crops in `docs/art/references/` | Derived from the owner's supplied reference | Reference only; not final art | Art generation input |
| Farm Shop icon / Starter Pack chest | Canva generated using the owner reference | Generated study boards; reviewed as reference only | Generated outputs are not standalone icon files; see artwork README | See `docs/art/asset-brief.md` |
| Planting-bed preview | Project-authored wood rails, soil and BillboardGui, in `PlotVisuals.client.luau` | Project code; no external assets | Source reviewed; visual QA pending | Client-only previews at shared planting contract positions |

The eight reference-derived icons were inspected as a contact sheet and uploaded
through Studio MCP on 2026-11-12. They contain image pixels only, no scripts or
models. Their source, resolution limit and content IDs are recorded in
`docs/art/README.md`; the source PNGs live in `assets/UI/`. These are distinct from
the Canva-generated study sheets, which remain reference material.
