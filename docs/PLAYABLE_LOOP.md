# Playable progression slice — 2026-11-12

The branch integrates PR #7 (and its Company Level dependency #6), plus the
already-merged #8. The published LandPlaceId remains 83958278376153.

## Play

Connect Rojo to `default.project.json`, then Play Solo. The current baked map is
preserved. Cut the lawn, walk onto the buyer's SELL pad, and buy better tools and
storage in Shop. Gate purchases require both Coins and Company Level. Helpers
use the host's open land, with their own shop progression and earnings.

The left HUD opens Crew, Shop, Quests (Jobs) and Rewards. Crew's panel has Market,
Garden and Franchise tabs too. Market uses Clovers and restocks on global
five-minute boundaries; inventory and remaining stock belong to each player.
Equip copies, switch equipped Crew to Station while standing on your own lawn,
or merge three matching copies. Crew and purchased automation use the same
server harvest function as the player's tool.

Jobs mark an existing expansion as the client yard, scale the target with the
qualifying party, and pay each participant. Only grass cut in that expansion
advances the target. Completing late pays 40%; the host can abandon without a
fee. Weather changes special-variant chances, and selling prices each carried
variant independently.

Garden offers two visible beds per expansion, positioned from GrassArea
contracts. Walk to the beds before planting. Growth uses real timestamps and
continues offline. Cut mature beds to harvest; overflow remains in the bed
rather than disappearing. For this slice all special seeds yield Golden grass,
with yield and growth differences from the seed catalog.

Motorized tools consume fuel while cutting. SELL pads refill it for free,
including when carrying no grass, so there is always a recovery path. Rideable
models use the existing character-mounted tool presentation and movement speed
boost; a separate physically driven vehicle system is not implemented.

Franchise requires Mega Fields and the configured run-earnings threshold. Review
and confirm the reset within 30 seconds. Coins, tools, storage, expansions,
automation, Company Level and planted beds reset. Crew/evolution, Clovers,
permanent upgrades and lifetime statistics survive. Franchise points buy the
permanent tree. Equipped Station Crew produce offline only after an offline cap
is earned; collect into storage on your own land, then sell physically.

## Automated checks

Install the official Luau CLI/compiler, then:

```sh
python3 tools/test-progression.py --luau luau --compiler luau-compile
python3 tools/test-services.py --luau luau
rojo build -o /tmp/mow-it-land.rbxl
rojo build lobby.project.json -o /tmp/mow-it-lobby.rbxl
```

The tests execute production modules with engine boundaries stubbed, covering
variant capacity/value, Crew merges, prestige/reset preservation, permanent
nodes, offline caps, deterministic stock, contract rewards, remote validation,
tutorial idempotency, and persistent profile session ownership/migration.

## Evidence and limits

- Compiled all 57 source scripts; built Land and Lobby.
- 61 progression assertions, 16 service assertions, 17 persistence assertions.
- In Studio Play Solo: cut grass via client request, mixed Normal/Golden
  inventory, physical sell-pad payout, Safety Scissors purchase/equip, Backyard
  unlock with Coins + Level, daily claim and disabled repeat action, Crew buy
  and equip/station, planting and mature-plot cut (10 Golden collected, 20
  remaining with pocket storage), and Franchise confirmation/reset retaining evolved Crew.
- Late-game state was accelerated with **Studio-only** DevProfile to exercise
  Franchise; this is not a measured full grind or pacing result.
- Screenshots inspected in Play: HUD, Rewards panel, Franchise confirmation,
  player-height and wide world views. Icons verified loaded by ImageLabel.
  First-person camera inspected, but the starter tool was not visible in that
  capture; held-tool first-person visual acceptance remains open.
- iPhone 17 Pro landscape HUD inspected; overlap fixed and viewport restored.
  No four-client party/teleport test, published DataStore roundtrip, first
  purchase timing, economy pacing simulation or full touch/gamepad QA yet.
- Studio logs also contain a pre-existing asset type mismatch for 203785492
  and DevCommentJournal API-access messages from the Studio environment.

The full v2 plan remains larger than this slice. Lobby showcase lots, unique
species Crew assets, shining-tuft reveal animation, weekly featured weather,
physical vehicles, automatic fuel/pass checks, daily/weekly quest catalogs,
codes, badges, global leaderboards, paid receipts/products and cosmetics remain
open in OpenSpec. No Robux prices or offers were copied from the illustration.

Profiles now acquire a session lock with UpdateAsync, retry, reconcile defaults,
autosave and release on leave. An unavailable or already-owned live profile
rejects the join; it never saves an empty fallback over existing progress.
Studio uses memory only and never writes the production DataStore.
