# Mow It! — Development Plan (v2)

The implementation checklist lives in OpenSpec:
[`openspec/changes/expand-to-full-game-v2/tasks.md`](../openspec/changes/expand-to-full-game-v2/tasks.md).
This page is the release-level view. Rule from day one: **assets → maps →
code**, every slice playable end-to-end (Play Solo) before the next starts.

## Release slices

| Slice | Content | Specs |
|---|---|---|
| **v1 — Your Land** | Game place becomes the Land place; land loads the host's expansions; per-variant inventory (Normal first); Company Level gating; lobby showcase lots + PLAY/PARTY pads | private-land-progression, lobby-showcase-and-party, core-mowing-loop |
| **v1.1 — Crew & Restock** | 60-Crew roster, equip (follow/station), global 5-min restock in Clovers, shining-tuft discovery, merge evolution | crew-system, crew-restock-market |
| **v1.2 — Sky & Jobs** | Timed co-op contracts, server weather + variants end-to-end, seed plots growing offline | contracts, weather-and-grass-variants, seed-plots |
| **v1.3 — Machines & Franchise** | Rideable driveable tools, fuel (manual/automation/pass), franchise prestige, offline Crew production | tools-and-vehicles, franchise-prestige, crew-system |
| **v1.4 — Live** | Daily login/quests/codes/badges, monetization catalog, cosmetics, first monthly event | retention-and-events, monetization-and-cosmetics |
| **Later changes** | Trading (atomic Crew trades), Crewdex album, recurring monthly events | player-data-and-safety (constraints already specced) |

## Assets first (before each slice's maps/code)

Everything goes through [`ASSETS.md`](ASSETS.md): map it, audit it
(no unaudited Toolbox scripts, ever), import it, log the id. One icon
family, one low-poly art style (cute, saturated, funny — the nail clipper
is the joke and the brand).

## Verification per slice

- `openspec validate --all --strict` green; specs updated in the same PR as behavior.
- `rojo build` both projects; Luau compile check on `src/**/*.luau`.
- Play Solo: new account reaches first tool purchase in ≈3 minutes.
- Multiplayer: party of 4 lands on the host's land; helpers earn fully;
  failed teleport keeps the party in the lobby.
- Economy simulation: casual play (30–60 min/day + offline) franchises
  first time in 1–2 weeks.
