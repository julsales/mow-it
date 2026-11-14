# Mow It! 🌿✂️

A Roblox grass-cutting simulator about **your land, your Crew, your company**.
Start in your front yard with a **nail clipper**; end with automated mega-fields
and a Crew of creatures and machines mowing for you — even while you're offline.

Cut grass → fill your (tiny) storage → sell it → buy absurdly better
tools → unlock new zones, from your front yard to automated mega-fields.
Lobby parties of up to **4 players** teleport together into a private match.

## Docs

| File | What |
|---|---|
| [openspec/specs/](openspec/specs) | **Behavioral source of truth (OpenSpec):** 14 capabilities, SHALL requirements + scenarios |
| [openspec/changes/expand-to-full-game-v2/](openspec/changes/expand-to-full-game-v2) | Current change: proposal, design + rollout phases (`design.md`), checklist (`tasks.md`) |
| [docs/ASSETS.md](docs/ASSETS.md) | **Reusable asset map** — ready-made icons/UI/models/audio with links & licenses. Map first, import second. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How Roblox games are normally structured (researched), our Rojo layout, and the Studio map contract |
| [docs/ROJO.md](docs/ROJO.md) | Como conectar o repo ao Roblox Studio com Rojo (pt-BR) |

## Quick start (Studio)

### 1. Install the pinned Rojo

Rojo 7.6.1 is pinned by [`rokit.toml`](rokit.toml). Pick one path:

**Option A - Rokit (cross-platform):**

Install [Rokit](https://github.com/rojo-rbx/rokit) first, then:

```sh
rokit install        # reads rokit.toml, installs Rojo 7.6.1
make serve ROJO=rojo
```

**Option B - download the binary straight into `.tools/bin` (Linux x86_64):**

```sh
mkdir -p .tools/bin
curl --fail --location -o /tmp/rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-linux-x86_64.zip
unzip -o /tmp/rojo.zip -d /tmp/rojo
cp /tmp/rojo/rojo .tools/bin/rojo && chmod +x .tools/bin/rojo
.tools/bin/rojo --version    # expect: Rojo 7.6.1
```

Other platforms: take the matching asset from the same
[v7.6.1 release page](https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1)
(`rojo-7.6.1-macos-aarch64.zip`, `rojo-7.6.1-windows-x86_64.zip`, ...).

`.tools/` is gitignored, so a clean checkout has no binary in it -
install it once, or point the Makefile at a Rojo already on your PATH:

```sh
make serve ROJO=rojo
```

### 2. Serve the project

The [Makefile](Makefile) wraps the commands local dev actually uses.
Both serve targets listen on `127.0.0.1:34872`, so the Studio plugin
connects to `localhost:34872`:

```sh
make serve           # Game place  (default.project.json)
make serve-lobby     # Lobby place (lobby.project.json)
make build           # writes build/MowIt-Game.rbxlx + build/MowIt-Lobby.rbxlx
make clean           # deletes those two files
```
Stop serving one project before serving the other: both use the same
port, so only one can be connected at a time.

### 3. Connect from Studio

Step-by-step guide (pt-BR), incl. plugin install and troubleshooting:
[docs/ROJO.md](docs/ROJO.md).

1. Start `make serve` (or `make serve-lobby`) in a terminal and leave it
   running.
2. Install the Rojo plugin: download
   [`Rojo.rbxm`](https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/Rojo.rbxm)
   from the same release, then in Studio open **Plugins** -> **Plugins
   Folder** and drop the file there. With Vinegar Flatpak, the folder is
   `~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/<user>/AppData/Local/Roblox/Plugins/`.
   Restart Studio after installing the plugin.
3. Open `build/MowIt-Game.rbxlx` after `make build`, or an empty baseplate.
   In edit mode, open the **Rojo** plugin, enter host `localhost` and port
   `34872`, click **Connect**, and accept the sync if prompted. The project
   should show **MowIt-Game** (or **MowIt-Lobby** when serving the lobby).
4. Press **Play**. The server builds a graybox world (labeled zone
   fields, Sell pads, Join Pad), so the full loop works before any
   real map exists: click to cut, fill up, load the Baler and click the bales, buy the next
   tool from the top-right buttons, unlock zones.

### 4. PlaceIds

PlaceIds stay `0` in this repo for local dev. In Studio, the server runs
both grayboxes so one place can exercise the local loop. Real PlaceIds are
production-only: create two places in Studio (Lobby = start place,
Game = sub-place), then paste their ids into
[`src/ReplicatedStorage/Shared/Config/GameConfig.luau`](src/ReplicatedStorage/Shared/Config/GameConfig.luau).
Until then `make build` still produces valid local place files - they
just don't teleport anywhere.

## Layout

```
src/
  ReplicatedStorage/Shared/Config/   ← all progression tables (tools, zones…)
  ServerScriptService/Services/      ← server authority: profiles, grass, economy, shops, lobby
  StarterPlayer/StarterPlayerScripts/← client input + placeholder HUD
openspec/                            ← design source of truth: specs + current change
docs/                                ← how-to/reference: assets, editing, architecture, Rojo
.agents/skills/                      ← agent skills: roblox* + openspec-* (.claude/skills links here)
```

## Reuse policy

- The `roblox` agent skill in `.agents/skills/roblox/` was copied
  verbatim from [`julsales/Roblox_Game`](https://github.com/julsales/Roblox_Game)
  (`@a9e8728`), along with that repo's *organizational patterns* (service
  layout, shared configs, phased docs).
- **No models/assets/code were copied from it** — different game,
  unverified provenance. Every external asset used by Mow It! is mapped
  and audited in [docs/ASSETS.md](docs/ASSETS.md) first.
