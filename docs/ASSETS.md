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
| Nail Clipper tool model | Creator Store "nail clippers" by BIack_Rose ([13408646708](https://create.roblox.com/store/asset/13408646708)) — the only real match in a free search | Free listing, but ❌ insert refused in Studio ("loadCachedAssetAsync returned nil": not distributable) | ❌ 2026-11-11 | Rebuilt from Parts instead (`ToolModels` clipper: jaws, pin, lever with thumb pad, key ring) |
| Zone 3–4 farm dressing (barn, fences, crops, silo) | **Low poly farm** (69,346 tris ⚠️ heavy, contains 1 script ⚠️ strip it) | [Creator Store asset 12491931365](https://create.roblox.com/store/asset/12491931365/Low-poly-farm) | Free; Creator Store terms | 🔎 use pieces only, never the whole model at once | `Workspace/Zones/sunny_farm/`, `big_ranch/` dressing |
| Zone 1 house + yard props | Creator Store → Structures → search `Classic House`, `Small House`, `Suburban House` | [Creator Store: 3D Structures](https://create.roblox.com/store/category/3d/structures) | Mostly free; check each listing | 🔎 pick in Studio, audit scripts, log the id here | `Workspace/Zones/front_yard/` |
| Zone 5 estate / golf dressing | Search `golf course`, `mansion`, `park fountain` in Creator Store | Creator Store search | Check each listing | 🔎 | `Workspace/Zones/golf_estate/` |
| Tool models ×48 (nail clipper → MOWZILLA) | **Built from Parts** in `Shared/ToolModels.luau`: 8 shapes (clipper, scissors, sickle, trimmer, reel, push, rider, tractor), color and size change per tool. Any tool can be replaced by a Creator Store model | No verified free mower model with a clear license was found, so the placeholders are ours | Ours | ✅ placeholders in game; 🔎 real models per tool optional | Override: `assets/Tools/<ToolId>.rbxm` → `ReplicatedStorage/Assets/Tools/<ToolId>`; `ToolVisualService` welds it to the character |
| Helper NPC / robot mower / drone visuals | Reuse tool-search results (`robot mower`, `drone`) + a simple rigged NPC from Creator Store (`NPC rig R6`) | Creator Store search | Check each listing | 🔎 Phase 6 (automation) | `ServerStorage/AssetLibrary/Automation/` |
| Trees, fences, rocks, lamps (all zones) | Search `low poly tree pack`, `fence pack`, `street lamp` | Creator Store search | Mostly free | 🔎 one consistent low-poly pack for all zones if possible | Per-zone dressing folders |

## 4. Audio

| Need | Where to get it | Status |
|---|---|---|
| Cut/snip, mower loop per tool tier, sell "cha-ching", buy, unlock fanfare, UI click, ambient birds/wind per zone | **Creator Store → Audio** (Studio: Toolbox → Audio). Search the exact phrases; filter by length. Roblox audio has per-asset privacy/permissions — use assets listed as distributable, or upload our own from a royalty-free library and log the source here. | 🔎 mapped as a category; individual ids chosen in Studio, logged here before use |
| Snip, Swish, MowCut, Collect, Full, Sell, Buy, Engine loop (mowing cycle) | **Placeholders built into every Roblox client** (`rbxasset://sounds/...`: swordslash, swoosh, electronicpingshort, snap, victory, clickfast). All ids in `Shared/Config/Sounds.luau`, played by `Mowing.client.luau` | ✅ placeholders playing; 🔎 swap Engine for a real lawn mower loop (Toolbox → Audio → "lawn mower", or upload the CC0 BigSoundBank #1071 recording) and log the id here |

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
