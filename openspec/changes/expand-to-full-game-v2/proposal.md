# Proposal: Expand to Full Game v2 — Your Land, Your Crew, Your Company

## Why

The Phase-1 skeleton (cut → sell → buy, 16 tools, 6 zones in a neutral match
map) proves the loop but is not a complete game: top Roblox grass/simulator
titles retain players with collection systems, rotating shops, weather,
offline progress, prestige and live events, none of which exist yet. A
grilling session (Q1–Q39) produced a differentiated design: instead of a
pet-simulator clone, Mow It! becomes a game about **your own land growing**
from a house yard into automated mega-fields, with a showy mixed Crew,
co-op help on the host's land, and a franchise prestige loop.

## What Changes

- **BREAKING** — World model changes: zones stop being areas of a neutral
  match map and become **expansions of the player's private, persistent
  land** (house yard → garden → farm → ranch → golf estate → mega fields).
- **BREAKING** — Place model changes: Lobby keeps a **public showcase
  mini-base** (flex only), the real land lives in a private Land place;
  PLAY goes solo to your land, the party pad (≤4) goes to the host's land.
- New: Crew system (mixed animals → garden fantasy → machines, 6 rarities,
  follow/station modes, equip-multiple + merge evolution, offline work).
- New: Restock market (global 5-minute rotation, Clovers) + Crew found in
  special grass tufts.
- New: three currencies (Coins, Clovers, Franchise Points), Company Level
  gating land expansions together with Coins.
- New: grass variants tagged per unit (Golden/Rainbow/…) and server-wide
  weather that creates variant windows.
- New: seed plots on your land (plant special grass; grows offline too).
- New: timed co-op contracts (job board), host-land helping with full
  rewards for helpers.
- New: rideable vehicle tools with fuel (manual refill, limited
  automation refill, infinite-fuel pass).
- New: Franchise prestige — resets progress, never collection.
- New: retention (daily login, daily/weekly quests, codes, badges),
  monthly events + weekly special weather, full-genre monetization and
  cosmetics (tools, yard, avatar). Crewdex album and trading are designed
  now and shipped later (out of scope for implementation tasks here).

## Capabilities

### New Capabilities
- `core-mowing-loop`: cutting, tagged-variant inventory, selling, storage limits
- `private-land-progression`: persistent private land, expansions, physical shops, Company Level gating
- `lobby-showcase-and-party`: public showcase mini-base, PLAY/party entry, host-land sessions
- `crew-system`: Crew collection, rarities, equip/merge, follow/station behavior, offline work
- `crew-restock-market`: global 5-minute restock, Clovers pricing, in-grass Crew discovery
- `tools-and-vehicles`: ~48 tools in families, rideable mowers, fuel and refill paths
- `weather-and-grass-variants`: server weather cycle, variant multipliers
- `seed-plots`: plantable special grass plots on private land
- `contracts`: timed solo/co-op client jobs with shared rewards
- `franchise-prestige`: sell-the-company reset, Franchise Points tree
- `economy-and-currencies`: three currencies, sinks/sources, physical vs lobby shop rules
- `retention-and-events`: daily login, quests, codes, badges, monthly event + weekly weather
- `monetization-and-cosmetics`: Robux passes/products, cosmetics for tools/yard/avatar
- `player-data-and-safety`: profile persistence, server authority, future trading constraints

### Modified Capabilities
- (none — no main specs exist yet; this change seeds them on archive)

## Impact

- Places: Lobby place rework; Game place becomes Land place
  (`GameConfig.GamePlaceId` → Land place); Rojo projects renamed over time.
- Code: profile schema grows (variants breakdown, Crew, land state, level,
  franchise); new server services per capability; client UI rebuilt from
  the mapped UI kit (see `docs/ASSETS.md`).
- Existing skeleton services (grass/economy/shops/lobby queue) evolve into
  the above; configs remain the numeric source of truth.
- Design docs: `docs/GDD.md` becomes a summary pointing here; OpenSpec is
  the behavioral source of truth from this change on.
