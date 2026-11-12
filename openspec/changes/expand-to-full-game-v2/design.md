# Design: Full Game v2

## Context

Phase-1 shipped a playable graybox: one Game place with 6 zone fields,
click-to-cut, sell pads, simple shops, and a lobby queue teleporting to a
neutral reserved match. Market research (Grass Cutting Simulator, Lawn
Mowing Simulator, Mow The Lawn!, Grow a Garden) plus a 39-question grilling
session concluded that design is a skeleton, not a game. All decisions
below come from that session; this document records the technical shape,
the specs record the behavior.

## Decisions

### D1. Private land is the game; zones are its expansions
The player's persistent property is one contiguous land that grows by
purchasing the neighboring expansion (the former "zones", in fixed order).
This unifies home base, progression and world: shops are physical stores
inside each expansion, and grass/plot/crew state is per-player data.
The neutral 4-player match map is removed.

### D2. Three places, clear jobs
- **Lobby place (public):** street with showcase mini-base lots, restock
  market, shops that only sell already-unlocked content, leaderboards,
  PLAY pad (solo → own land) and PARTY pad (≤4 → host's land).
- **Land place (reserved servers):** loads one player's land (the host).
  Solo sessions and hosted parties both run here. Helpers earn full
  personal rewards; only the host's land state progresses.
- (Later) Trading, when shipped, is an area of the Lobby place, not a
  third place. Contracts are generated yards inside the Land session.

### D3. Showcase is a snapshot, not the land
The lobby mini-base is built from a lightweight summary (best Crew,
vehicles, house tier, trophies). It has no economy and cannot be damaged,
which removes theft/grief and public-server replication cost while keeping
the social flex that makes Grow a Garden plots work.

### D4. Crew replaces pets, with two acquisition channels
Crew = mixed roster (garden animals → garden fantasy → personality
machines) in 6 rarities. Primary channel is the **global restock market**
(Grow-a-Garden model: seeded by global server time so every server shows
the same shelf; 5-minute cycle; per-player stock so buying never steals).
Secondary channel is discovery in special tufts while mowing. Duplicates
are useful twice: they can be equipped for stacking and merged to evolve.

### D5. Variants are data on units, weather is a server event
Carried grass is a per-variant count table (Normal/Golden/Rainbow/…),
capacity counts total units, selling pays each variant its multiplier.
Weather runs on the Land server for everyone at once and mainly changes
variant odds/value for a few minutes — the shared "everybody run outside"
moment. Seed plots give the deterministic, offline-growing counterpart.

### D6. Money stays boring on purpose: 3 currencies, physical shops
Coins (mowing economy), Clovers (Crew/quests/contracts), Franchise Points
(prestige only). Prices live in shared configs. Purchases happen at
physical shops (per expansion; lobby mirrors only unlocked stock) — no
global buy-anywhere menu, so travel and place identity matter.

### D7. Prestige keeps collection
Franchising resets Coins/tools/storage/expansions and grants Franchise
Points + permanent multipliers. Crew, cosmetics, badges and the yard's
cosmetic state are never reset — losing rare collection to prestige is
the genre's most hated pattern.

### D8. Rollout stays phased and always playable
Implementation follows `tasks.md` in releasable slices (v1 loop on land →
Crew/restock → contracts/weather → franchise/offline → later trading/
Crewdex/events cadence). The graybox approach from Phase 1 remains: every
slice must Play Solo end-to-end. Order inside every slice: **assets →
maps → code** (assets go through `docs/ASSETS.md` first). A phase only
starts when the previous one is playable end-to-end. Each main spec
carries a `**Phase:**` line; the checklist is `tasks.md`, same numbering.

| Phase | Update | Assets | Maps | Exit criteria |
|---|---|---|---|---|
| 0 | Foundation (done) | asset map, `roblox` skill | graybox | cut → sell → buy → unlock in Play Solo |
| 0.9 | Map v2 | grass looks per area, fences, stalls | open organic land: home base at center, areas expanding outward, fences + invisible walls + gates (AGENTS.md "Map rules") | every area has its grass type, lucky rare patches and a sell stall |
| 1 | "Your Land" (v1) | icon family + UI kit; house + Front Yard set; first tool models | lobby street (showcase lots, market, PLAY/PARTY pads); land with 6 expansions grayboxed, physical shop in each | new player buys first scissors in ≈3 min; party of 4 mows a friend's land; failed teleport keeps the party in the lobby |
| 2 | "Crew & Restock" (v1.1) | ~60 Crew models by zone/rarity, market stall, shining-tuft effect | Crew Market in the lobby; Crew on showcase lots | two servers show the same shelf and countdown; found-Crew reveal plays while mowing; merging duplicates evolves a Crew |
| 3 | "Sky & Jobs" (v1.2) | variant grass visuals, weather sky/audio, client-yard props, seed/plot models | job board (lobby + land), generated client yards, seed plots per expansion | a Storm makes the session chase Rainbow grass; a party finishes a contract and everyone is paid; seeds grow offline |
| 4 | "Machines & Franchise" (v1.3) | rideable mower/tractor/combine, robot Crew, fuel station, franchise office | driveable fields/roads in Ranch → Mega Fields; fuel points | driving a mower cuts; franchising resets progress but never collection; casual simulation franchises in 1–2 weeks |
| 5 | "Live" (v1.4) | cosmetics, event dressing kit, badge icons | event overlay for lobby/land; VIP/showcase cosmetics | day-7 reward claimable; duplicate receipt grants once; an event runs start to finish with limited Crew in the restock pool |
| Later | Trading, Crewdex, events cadence, 7th expansion | | | each ships as its own OpenSpec change |

Per release, also: `openspec validate --all --strict` green and specs
updated in the same PR as behavior.

## Risks

- **Land data size/complexity:** land state (expansions, plots, placed
  automation) must stay a compact serializable table; visual building is
  regenerated from state on session start, never stored as instances.
- **Helping exploits:** helpers earning "full rewards" on host land needs
  per-player caps tied to their own progression, or high-level lands
  become a carry service. Specs require helper rewards to respect the
  helper's own unlocks.
- **Restock fairness:** global seeded stock must be identical across
  servers; use server-time-derived seeds (documented community pattern),
  never per-server RNG.
- **Full-genre monetization vs trust:** currency packs/shortcuts ship
  with the transparency rules in the monetization spec (no fake timers,
  no misleading discounts).
