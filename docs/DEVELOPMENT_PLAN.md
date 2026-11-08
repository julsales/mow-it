# Mow It! — Development Plan

Order matters: **assets → maps → code polish**. Code skeleton already
exists (Phase 0 done in the first commit) so every later phase has
something playable to attach to. Assets are mapped *before* importing
anything (`docs/ASSETS.md`), and nothing is taken from other projects
without an audit.

Legend: ☐ todo · ◐ in progress · ☑ done

---

## Phase 0 — Repo & skeleton ☑

- ☑ Repo created (`~/Github/mow-it`, GitHub: `julsales/mow-it`)
- ☑ `roblox` skill copied from `Roblox_Game` (skill only, no assets)
- ☑ Rojo projects for both places, Rokit-pinned toolchain
- ☑ Shared configs = full progression tables (16 tools, 11 backpacks,
  6 zones, 8 buffs/automations)
- ☑ Server skeleton: profiles/DataStore, grass, cut→sell economy,
  shops, zone unlocks, lobby queue (≤4) → reserved-server teleport
- ☑ Functional placeholder HUD + graybox world (playable in Studio today)
- ☑ GDD, asset map, architecture notes

## Phase 1 — Assets (map → audit → import)

Do this **before** building maps, so builders dress zones with final art.

- ☐ Pick ONE icon family (default: Creator Store Simulator Icon Pack,
  asset `99176447965360`); upload needed icons as Images, log ids in ASSETS.md
- ☐ Import Free Clicking Simulator Kit (no-scripts UI frames,
  asset `17684626284`); rebuild shop/inventory/settings screens from it
- ☐ Pick grass tuft visual (Low Poly Grass, asset `14566481901`) and wire
  it into `GrassService` as a child visual (server tufts stay Parts)
- ☐ Tool models ×16: one Studio session per `docs/ASSETS.md` §3 search
  list; strip all scripts, rename `Tools/<ToolId>`, log ids
- ☐ Zone dressing packs: farm (asset `12491931365`, pieces only, strip its
  script), house, trees/fences — one consistent low-poly style
- ☐ Audio pass: cut/mower/sell/buy/unlock/ambient from Creator Store
  Audio, ids logged in ASSETS.md §4
- ☐ One swing animation, reused at different speeds per tool tier
- ☐ **Audit gate:** every imported model searched for scripts/`require`s;
  anything failing is rejected and logged ❌ in ASSETS.md

**Exit criteria:** ASSETS.md rows for everything above are ✅ with ids.

## Phase 2 — Maps (Studio, following the contract in ARCHITECTURE.md)

- ☐ Lobby place: spawn plaza, Join Pad block, shop-preview stalls,
  leaderboard boards, hangout props
- ☐ Game place Zone 1 *Front Yard*: house, yard, fence, Sell Pad, tutorial signs
- ☐ Zone 2 *Backyard Garden*: garden beds, hedges (trimmer fantasy)
- ☐ Zone 3 *Sunny Farm*: fields, barn, silo — farm dressing from Phase 1
- ☐ Zone 4 *Big Ranch*: open acres, fences, ranch house
- ☐ Zone 5 *Golf Estate*: fairways, sand traps, mansion, fountain
- ☐ Zone 6 *Mega Fields*: huge flat fields, factory/conveyor dressing,
  robot parking — built for automation visuals
- ☐ Zone gates between every zone (visual), lighting/sky per zone mood
- ☐ Delete reliance on GrayboxService zone-by-zone as real zones land
  (it auto-skips folders that already exist)

**Exit criteria:** Play Solo → walk all 6 zones; no graybox blocks left.

## Phase 3 — Code: MVP loop polish

- ☐ Real shop UI (scrolling lists from Shared configs) replacing the
  3 placeholder buttons; inventory/equip screen; settings screen
- ☐ Equipped tool model on character + swing animation + per-tier sounds
- ☐ Grass-per-origin value tracking (grass remembers its zone; selling
  pays per-stack value instead of best-zone approximation)
- ☐ Tool as physical `Tool` instances (backpack equip) if it feels better
  than click-anywhere cutting — decide in playtest
- ☐ Tutorial: first-join prompts (cut 10 → sell → buy scissors)
- ☐ Daily rewards + codes screen (frames already in the UI kit)

**Exit criteria:** A new player reaches Garden Shears without explanation.

## Phase 4 — Economy & balance

- ☐ Simulate the config tables (spreadsheet or Lune script like the old
  repo's `tools/` pattern): time-to-next-tool per zone should feel
  ≈2–4 min early, ≈10–15 min late
- ☐ Tune prices/GrassHealth from the simulation, not by feel
- ☐ Anti-exploit pass: remote rate limits (done for cutting), distance
  checks, purchase validation review, DataStore failure drills
- ☐ Ordered leaderboards: Coins, Lifetime Grass

## Phase 5 — Lobby & co-op (publish required)

- ☐ Create both places in Studio, paste PlaceIds into `GameConfig`
- ☐ Live test: 1, 2 and 4-player parties; full-party instant start;
  teleport failure → party restored to queue (already coded)
- ☐ Game place: `MaxPlayers` guidance + reserved-server-only access
  control (*Secure within universe only*)
- ☐ Return-to-lobby pad in the Game place

## Phase 6 — Automation endgame

- ☐ Auto-Swing client hold behavior (skeleton exists) + visual
- ☐ Hired Gardener NPC (pathfinding around player, slow shared mowing)
- ☐ Mower Drone (orbits player, cuts on its own timer)
- ☐ Robot Mower Crew for Mega Fields (roam zone, mow, return to dock)
- ☐ Auto-Sell Conveyor behavior polish (skeleton exists in EconomyService)
- ☐ Co-op bonus: +10% sell value per party member in the same zone (stretch)

## Phase 7 — Monetization & live prep

- ☐ Gamepasses: 2× Coins, VIP, +1 Robot Crew slot (single ProcessReceipt,
  server-granted — per copied `roblox` skill + gamepasses guidance)
- ☐ Game icon + thumbnails from the chosen icon family (no AI slop:
  screenshot real gameplay in Studio)
- ☐ Analytics events: first cut, first sell, first tool, zone unlocks
- ☐ Device QA: PC, phone, tablet, gamepad; low-graphics performance pass
  (tuft counts per zone are config — tune down for mobile)

## Phase 8 — Launch & beyond

- ☐ Soft launch → watch funnel (cut→sell→buy conversion) → balance patch
- ☐ Prestige "New Lawn+", seasonal events, new zone (Phase 9 candidates)

---

## Working rules (from day one)

1. **Assets:** mapped in ASSETS.md before import, audited on import,
   one visual style per category. No un-audited Toolbox models, ever.
2. **Server authority:** clients ask, servers decide. No exceptions.
3. **Config first:** new content = config row + asset, not new code.
4. **Playable always:** every commit must Play Solo end-to-end (cut, sell,
   buy, unlock). Graybox fills gaps until real maps land.
