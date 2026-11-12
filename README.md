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

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this repo:
   ```sh
   rokit install        # installs the pinned Rojo
   rojo serve           # Land place  (or: rojo serve lobby.project.json)
   ```
2. Open an empty baseplate in Roblox Studio, connect the Rojo plugin.
   Step-by-step guide (pt-BR), incl. plugin install and troubleshooting:
   [docs/ROJO.md](docs/ROJO.md).
3. Press **Play**. The server builds a graybox world (labeled zone
   fields, Sell pads, Join Pad), so the full loop works before any
   real map exists: click to cut, fill up, stand on SELL, buy the next
   tool from the top-right buttons, unlock zones.
4. To test like production, create two places (Lobby = start place,
   Game = sub-place), paste their ids into
   `src/ReplicatedStorage/Shared/Config/GameConfig.luau`, and sync each
   project file into its place.

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
