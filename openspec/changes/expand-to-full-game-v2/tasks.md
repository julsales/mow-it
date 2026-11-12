# Tasks: Expand to Full Game v2

Phased and always playable. Each release slice must Play Solo end-to-end
before the next starts. Spec references are to this change's `specs/`.

## 1. Specs & docs adoption
- [x] 1.1 Adopt OpenSpec in repo (`openspec init`, change `expand-to-full-game-v2`)
- [x] 1.2 Write proposal/design/delta specs for all 14 capabilities
- [x] 1.3 Sync `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_PLAN.md`, `README.md` to v2 (OpenSpec = source of truth)
- [x] 1.4 `openspec validate expand-to-full-game-v2 --strict`

## 2. Config expansion (no behavior yet)
- [x] 2.1 `Config/Crew.luau`: ~60 Crew across 6 zones × rarities, follow/station power, offline rate
- [x] 2.2 `Config/Weather.luau`: weather types, duration, variant odds/multipliers
- [x] 2.3 `Config/Seeds.luau`: plantable seeds per expansion, grow times, yields
- [x] 2.4 `Config/Franchise.luau`: points curve, tree nodes, permanent multipliers
- [x] 2.5 Expand `Config/Tools.luau` 16 → ~48 in families; add rideable/fuel flags
- [x] 2.6 `Config/Contracts.luau`: yard sizes, targets, deadlines, reward bands

## 3. Phase 1 — Update "Your Land" (v1): land instead of neutral match (`private-land-progression`, `lobby-showcase-and-party`, `core-mowing-loop`)
- [x] 3.1 Rename Game place → Land place in configs; land loads host profile (`LandService`). Rojo project names stay until the places are split
- [x] 3.2 Grass inventory becomes per-variant table (Normal only at first)
- [x] 3.3 Company Level + XP sources (cutting, selling); expansion gating = Coins + Level, bought at the gate
- [ ] 3.4 Lobby showcase lots (snapshot builder) + PLAY pad + PARTY pad → host land
- [x] 3.5 Land with six expansions on one property (open map v2); helpers earn fully

## 4. Phase 2 — Update "Crew & Restock" (v1.1) (`crew-system`, `crew-restock-market`)
- [ ] 4.1 Crew roster/equip UI; follow & station behavior (server mowing agents)
- [ ] 4.2 Global 5-min restock market (server-time seeded shelf, Clovers, per-player stock)
- [ ] 4.3 Shining-tuft Crew discovery; duplicates equip-stack + merge evolution
- [ ] 4.4 Crew assets imported per `docs/ASSETS.md` audit flow

## 5. Phase 3 — Update "Sky & Jobs" (v1.2): contracts, weather, variants, plots (`contracts`, `weather-and-grass-variants`, `seed-plots`)
- [ ] 5.1 Job board + timed client yards, party-scaled, gentle failure
- [ ] 5.2 Server weather cycle + variant drops end-to-end (tagged sell already in 3.2)
- [ ] 5.3 Seed plots: planting, real-time + offline growth, variant harvest

## 6. Phase 4 — Update "Machines & Franchise" (v1.3): vehicles, fuel, franchise, offline (`tools-and-vehicles`, `franchise-prestige`)
- [ ] 6.1 Rideable tools as driveable vehicles that mow by contact
- [ ] 6.2 Fuel: manual points, capped automation refill, Infinite Fuel pass check
- [ ] 6.3 Franchise flow (confirm screen, reset set, points, tree UI)
- [ ] 6.4 Offline production from stationed Crew with caps; collect on land

## 7. Phase 5 — Update "Live" (v1.4): retention & monetization (`retention-and-events`, `monetization-and-cosmetics`)
- [ ] 7.1 Guided first loop (objectives + step rewards)
- [ ] 7.2 Daily login 7-day, daily/weekly quests, codes, badges + leaderboards
- [ ] 7.3 Passes/products catalog with single idempotent receipt handler
- [ ] 7.4 Cosmetics: tool skins/trails, land/showcase decoration, avatar auras/titles

## 8. Later updates (separate OpenSpec changes when started)
- [ ] 8.1 Trading change proposal (atomic two-sided Crew trades)
- [ ] 8.2 Crewdex album change proposal
- [ ] 8.3 Monthly event cadence becomes recurring live-ops changes

## 9. Verification per release
- [ ] 9.1 `rojo build` both projects; Luau compile check all `src/**/*.luau`
- [ ] 9.2 Play Solo script: first loop ≤3 min to first tool purchase
- [ ] 9.3 Multiplayer test: party of 4 to host land; helper rewards; teleport failure retains party
- [ ] 9.4 Economy simulation: casual pacing reaches first franchise in 1–2 weeks
