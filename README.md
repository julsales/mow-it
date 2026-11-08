# Mow It! 🌿✂️

A co-op Roblox grass-cutting simulator. Start with a **nail clipper**,
end with **MOWZILLA** and a crew of robot mowers doing the work for you.

Cut grass → fill your (tiny) storage → sell it → buy absurdly better
tools → unlock new zones, from your front yard to automated mega-fields.
Lobby parties of up to **4 players** teleport together into a private match.

## Docs

| File | What |
|---|---|
| [docs/GDD.md](docs/GDD.md) | Full game design: loop, tools, zones, economy, lobby, automation |
| [docs/ASSETS.md](docs/ASSETS.md) | **Reusable asset map** — ready-made icons/UI/models/audio with links & licenses. Map first, import second. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How Roblox games are normally structured (researched), our Rojo layout, and the Studio map contract |
| [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | Phased plan: **assets → maps → code** |

## Quick start (Studio)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this repo:
   ```sh
   rokit install        # installs the pinned Rojo
   rojo serve           # Game place  (or: rojo serve lobby.project.json)
   ```
2. Open an empty baseplate in Roblox Studio, connect the Rojo plugin.
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
docs/                                ← design, asset map, architecture, plan
.agents/skills/roblox/               ← agent skill copied from Roblox_Game (see below)
```

## Reuse policy

- The `roblox` agent skill in `.agents/skills/roblox/` was copied
  verbatim from [`julsales/Roblox_Game`](https://github.com/julsales/Roblox_Game)
  (`@a9e8728`), along with that repo's *organizational patterns* (service
  layout, shared configs, phased docs).
- **No models/assets/code were copied from it** — different game,
  unverified provenance. Every external asset used by Mow It! is mapped
  and audited in [docs/ASSETS.md](docs/ASSETS.md) first.
