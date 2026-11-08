# Mow It! — Game Design Document

**Genre:** Co-op grass-cutting simulator / incremental progression
**Platform:** Roblox · **Language:** English (all player-facing text)
**Players:** 1–4 per match (reserved server), lobby supports full public servers
**Session:** Drop-in mowing loop, persistent progression across sessions

## Pitch

You start in front of your house with a **nail clipper** and a lawn that
doesn't care. Snip grass, fill your pocket, sell the clippings, buy real
scissors. Then shears. Then a trimmer, a mower, a tractor, a combine
harvester — until you're conducting a swarm of mower drones over automated
mega-fields and the grass works for *you*.

## Core loop (30 seconds)

```
CUT grass → fill storage (limited!) → SELL at the Sell Pad → earn Coins
   ↑                                                              ↓
   └────── buy better TOOLS / STORAGE / BUFFS, unlock ZONES ◄────┘
```

1. **Cut** — click/tap swings your tool. Grass tufts near you lose health;
   cleared tufts become carried **Grass**.
2. **Carry** — storage is limited (first backpack: *Your Pocket*, 10 grass).
   Full storage = no more cutting. This limit is the engine of the early game.
3. **Sell** — stand on any Sell Pad: all carried grass → **Coins**, priced by
   zone value (see Zones).
4. **Upgrade** — spend Coins on the next tool, bigger storage, buffs, and
   zone gates. Every upgrade is visibly bigger/faster than the last.

## Tool evolution (the fantasy)

Full stats/prices: `src/ReplicatedStorage/Shared/Config/Tools.luau` (source of truth).

| # | Tool | Zone | Fantasy beat |
|---|---|---|---|
| 1 | Nail Clipper | Front Yard | Absurd, funny, humble start |
| 2 | Safety Scissors | Front Yard | "Real" scissors at last |
| 3 | Kitchen Scissors | Front Yard | Wrong tool, right spirit |
| 4 | Garden Shears | Front Yard | Actual gardener arc begins |
| 5 | Electric Hedge Trimmer | Backyard | First motor |
| 6 | String Trimmer | Backyard | Edge everything |
| 7 | Push Mower | Farm | The classic |
| 8 | Self-Propelled Mower | Farm | It walks for you |
| 9 | Riding Mower | Ranch | Sit & mow |
| 10 | Zero-Turn Mower | Ranch | Pro handling |
| 11 | Commercial Stand-On Mower | Golf Estate | The pros' choice |
| 12 | Tractor Mower | Golf Estate | Farm machinery scale |
| 13 | Combine Harvester | Mega Fields | Fields end where you say |
| 14 | Industrial Mega Mower | Mega Fields | Permit required |
| 15 | Mower Drone Swarm | Mega Fields | You conduct, they cut |
| 16 | MOWZILLA | Mega Fields | Gigantic endgame toy |

Design rules: each tool increases **Power** (grass/hit), **Radius**, and
swing speed. No tool is a pure number bump in the final game — each gets a
model, sound tier and swing feel (Assets/Map phases).

## Storage ladder

Pocket (10) → Plastic Bag → School Backpack → Duffel Bag → Trash Bin →
Wheelbarrow → Pickup Truck Bed → Hay Trailer → Dump Truck → Vacuum Silo →
Auto-Conveyor Rig (500k). Full table: `Config/Backpacks.luau`.

## Zones (one map, gated areas)

Full stats: `Config/Zones.luau`. Zones unlock **in order**, cost Coins, and
each one stocks stronger gear (tools/backpacks/buffs gate on `RequiredZone`).

| # | Zone | Unlock | Grass ¢/unit | What changes |
|---|---|---|---|---|
| 1 | Front Yard (house) | free | 1 | Tutorial space. Nail clipper lawn. |
| 2 | Backyard Garden | 1K | 3 | Flowers/fences, first motors |
| 3 | Sunny Farm | 15K | 8 | Neighbors pay you; first mowers, first automation (Auto-Swing, Hired Gardener) |
| 4 | Big Ranch | 120K | 20 | Riding mowers, big acres |
| 5 | Golf Estate | 900K | 50 | Rich grass, drones, commercial gear |
| 6 | Mega Fields | 6M | 130 | **Automation endgame:** robot crews, auto-sell, drone swarms |

Grass gets tougher per zone (`GrassHealth`), so going back to the Front
Yard with MOWZILLA is a power fantasy, and bringing a nail clipper to the
Mega Fields is a joke the game lets you tell once.

## Buffs & automation (progression of laziness)

Full table: `Config/Buffs.luau`.

- **Stat buffs:** Swift Boots (speed), Grass Magnet (radius), Golden Blades
  (crit ×3 cuts).
- **Small automations on the way:** Auto-Swing (Zone 3), Hired Gardener NPC
  (Zone 3), Mower Drone (Zone 5).
- **Final-zone automation focus:** Auto-Sell Conveyor (never walk to a pad
  again), Robot Mower Crew (robots roam and mow for you), Drone Swarm tool.
  Endgame play = managing/expanding your operation, not clicking.

## Lobby & multiplayer (up to 4)

- The **Lobby** is the start place: hangout, shops preview, leaderboards.
- Step on the **Join Pad** (a physical block) → you join the party queue
  (max **4**). A countdown starts with the first player; a full party of 4
  starts immediately. Step on the pad again to leave.
- The whole party teleports together into a **reserved server** of the Game
  place — private to the party, friends can't crash it.
- In the Game place everyone mows the same shared fields; grass/economy are
  per-player, fields are shared, so co-op = racing for tufts or splitting
  areas. (Co-op bonuses are a Phase-6 stretch goal.)

## Persistence

Per player: Coins, carried Grass, lifetime grass, owned/equipped tool &
backpack, unlocked zones, buff stacks. Server-side DataStore with session
cache and autosave (`ProfileService`). In Studio, profiles are session-only
so testing never pollutes real data.

## Monetization (planned, Phase 7 — not in MVP)

Robux: 2× Coins gamepass, VIP (lobby area + daily bonus), starter pack,
extra robot crew slot. Rules from the copied `roblox` skill apply: single
`ProcessReceipt`, server-granted, idempotent. No pay-to-skip zone order.

## Win / endgame

There is no "ending" — endgame is Mega Fields fully automated + MOWZILLA +
leaderboards (Coins earned, lifetime grass). Future updates: seasons,
prestige ("New Lawn+"), events. See DEVELOPMENT_PLAN Phase 8+.
