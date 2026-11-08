# Mow It! — Phases & Updates Map

Everything in the game is separated here by phase/update. Each OpenSpec
spec also carries a `**Phase:**` line, and implementation checklists live
in `openspec/changes/expand-to-full-game-v2/tasks.md` under the same
numbering. **A phase only starts when the previous one is playable
end-to-end.**

---

## Phase 0 — Foundation (DONE)

- Repo, Rojo skeleton, graybox core loop (cut → sell → buy → unlock)
- Reusable asset map (`docs/ASSETS.md`), `roblox` skill, research
- **This phase is the only one with shipped code so far.**

## Phase 1 — Update "Your Land" (v1)

**Goal:** the v2 world model works: your private growing land replaces
the neutral match map.

- Specs: `private-land-progression`, `lobby-showcase-and-party`,
  `core-mowing-loop`, `economy-and-currencies` (Coins side),
  `player-data-and-safety`, `tools-and-vehicles` (ladder),
  `retention-and-events` (guided first loop only)
- Assets: icon family + UI kit import/audit; house + Front Yard set;
  first tool models
- Maps: Lobby street (showcase lots, market building, PLAY/PARTY pads);
  Land property with 6 expansions grayboxed, shops physical in each
- Code: Land place loads host profile; per-variant inventory (Normal);
  Company Level + XP; expansion gate = Coins + Level; showcase snapshot
  builder; PLAY solo / PARTY ≤4 → host land; helpers earn fully
- **Exit:** new player buys first scissors in ≈3 min; party of 4 mows a
  friend's land; failed teleport keeps party in lobby

## Phase 2 — Update "Crew & Restock" (v1.1)

**Goal:** collection lands — Crew and the 5-minute market habit.

- Specs: `crew-system` (except offline completion), `crew-restock-market`,
  `economy-and-currencies` (Clovers go live)
- Assets: ~60 Crew models by zone/rarity (animals → fantasy → machines),
  market stall, shining-tuft effect
- Maps: Crew Market in the lobby; Crew display on showcase lots
- Code: roster/equip UI (1→5 slots), Follow/Station server agents,
  global server-time-seeded restock (Clovers, per-player stock),
  shining-tuft discovery, duplicate equip-stack + merge evolution
- **Exit:** two servers show the identical shelf and countdown; a found
  Crew reveal plays while mowing; merging  duplicates evolves a Crew

## Phase 3 — Update "Sky & Jobs" (v1.2)

**Goal:** every session is different — weather, variants, contracts, plots.

- Specs: `weather-and-grass-variants`, `core-mowing-loop` (variants
  complete), `contracts`, `seed-plots`
- Assets: variant grass visuals (Wet/Golden/Lunar/Rainbow), weather sky/
  audio, client-yard props, seed/plot models
- Maps: job board (lobby + land), generated client yards, seed plots per
  expansion
- Code: server weather cycle + weekly featured weather; variant drops and
  tagged selling end-to-end; timed contracts scaled by party with gentle
  failure; planting with real-time + offline growth
- **Exit:** a Storm makes the whole session chase Rainbow grass; a party
  finishes a contract and everyone is paid; planted seeds grow offline

## Phase 4 — Update "Machines & Franchise" (v1.3)

**Goal:** the automation endgame and the prestige loop.

- Specs: `tools-and-vehicles` (rideable + fuel), `franchise-prestige`,
  `crew-system` (offline work), `economy-and-currencies` (Franchise Points)
- Assets: rideable mower/tractor/combine vehicles, robot Crew, fuel
  station, franchise office visuals
- Maps: driveable-scale fields/roads in Ranch→Mega Fields; fuel points
- Code: vehicle driving that mows by contact; fuel (manual, capped
  automation refill, Infinite Fuel pass); franchise flow + points tree;
  offline Crew production with caps, collected on the land
- **Exit:** driving a mower cuts; franchising resets progress but never
  collection; casual simulation franchises in 1–2 weeks

## Phase 5 — Update "Live" (v1.4)

**Goal:** daily habit and revenue, fairly presented.

- Specs: `retention-and-events` (full), `monetization-and-cosmetics`
- Assets: cosmetics (tool skins/trails, yard/showcase decoration, avatar
  auras/titles), event dressing kit, badge icons
- Maps: event overlay dressing for lobby/land; VIP/showcase cosmetics
- Code: 7-day login, daily/weekly quests, codes, badges + leaderboards;
  passes/products with one idempotent receipt handler; cosmetics apply
  system; first monthly themed event (~2 weeks, temporary event currency)
- **Exit:** day-7 reward claimable; duplicate receipt grants once; an
  event runs start-to-finish with limited Crew in the restock pool

## Later Updates (designed in specs, separate OpenSpec changes when started)

| Update | Content | Blocked by |
|---|---|---|
| Trading | Atomic two-sided Crew trades, trade history | Crew instances already tradable-by-design (Phase 2) |
| Crewdex | Collection album with completion rewards per expansion | Full Crew roster shipped (Phase 2) |
| Events cadence | Monthly events become routine live-ops changes | Phase 5 event system |
| New expansion | 7th land expansion (new zone family of tools/Crew) | Franchise population healthy (post Phase 4) |
