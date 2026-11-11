# Mow It! — Game Design Document (v2 summary)

> **Behavioral source of truth: OpenSpec.** Every system below is specified
> normatively in [`openspec/specs/`](../openspec/specs) (14 capabilities,
> SHALL requirements + WHEN/THEN scenarios) and tracked as the change
> [`expand-to-full-game-v2`](../openspec/changes/expand-to-full-game-v2).
> This document is the readable summary. If they disagree, OpenSpec wins.

## Pitch

Your land, your Crew, your company. You start in the front yard of your
house with a **nail clipper**. You end with automated mega-fields, a swarm
of showy Crew creatures and machines mowing for you — even while you're
offline — and a lawn-care franchise that keeps getting stronger.

## The world (this changed in v2)

- **Your private land is the game.** One persistent property that grows
  expansion by expansion, all joined together: Front Yard (your house) →
  Backyard Garden → Sunny Farm → Big Ranch → Golf Estate → Mega Fields.
  Expansions unlock **in order**, for **Coins + Company Level**, each with
  its own **physical shop**, grass tier and roster.
- **The lobby is public and social:** a street where your **showcase
  mini-base** (a safe, simplified copy: house, best Crew, parked vehicles,
  trophies) is displayed for flex, the **Crew Restock Market**, shops that
  only sell what you already unlocked, and leaderboards.
- **Entering play:** `PLAY` takes you solo to your land. The **party
  block** groups up to **4 players** and takes everyone to the **host's
  land** — helpers earn full personal rewards; only the host's land
  progresses.

### Map feel (v2 direction)

- **Open and organic, with an "endless" feeling.** The home base (house,
  first stall, shop) sits at the center; areas keep opening outward,
  each one bigger and richer, so there is always more land past the next
  fence. Nothing is laid out on a grid: lawns have irregular shapes,
  paths wind, trees and props are clustered and scattered.
- **Fences + invisible walls** separate areas, with a gate per area.
  Locked land stays visible, so the next goal is always in sight.
- **Grass types per area:** every area grows its own, better grass
  (more health, more value, its own color/look). **Lucky patches:** rarer
  grass from later areas spawns sparsely in earlier ones.
- **Selling at stalls:** each area has a sell stall (pad + buyer NPC).
  When storage is full, the game points the way to the nearest stall.
- First-person play is supported (zoom in), third person by default.

## Core loop

Cut grass (tagged by variant) → fill limited storage → sell at a pad →
Coins → tools/storage/buffs + next expansion. Planted **seed plots** add
a deliberate, offline-growing layer on top of wild regrowing grass.

- **48 tools** in 6 families (`Config/Tools.luau`): nail clipper →
  scissors → electrics → push mowers → **rideable** mowers/tractors you
  drive over grass → combines, drone swarms, **MOWZILLA**. Fueled tools
  refuel manually, via capped automation, or with the Infinite Fuel pass.
- **Crew replaces pets:** ~60 companions (`Config/Crew.luau`) — garden
  animals → garden fantasy → personality machines — in **6 rarities**.
  They **follow you** cutting, or **stay stationed** cutting a spot; they
  work **offline** up to a growing cap. Copies can be **equipped stacking**
  and **merged to evolve**. Crew is collection: prestige never removes it.
- **Getting Crew:** the lobby's **global restock market** (same shelf on
  every server, refreshes every **5 minutes**, priced in **Clovers**,
  commons always there, Mythics rarely) — plus the surprise of **shining
  tufts** that reveal Crew while you mow.
- **Grass variants & weather:** carried grass is counted per variant
  (Normal/Wet/Golden/Lunar/Rainbow…, `Config/Weather.luau`); server-wide
  weather opens variant windows everyone chases together.
- **Contracts:** a job board of timed client yards, solo or party,
  paying Coins + Clovers + Company XP; late = reduced pay, never a
  punishment spiral.
- **Franchise (prestige):** sell the company, reset progress (never
  collection), earn **Franchise Points** for a permanent upgrade tree.
  First franchise tuned for ~1–2 weeks of casual daily play.

## Currencies

**Coins** (mowing economy) · **Clovers** (Crew, quests, contracts) ·
**Franchise Points** (prestige only). Event currencies exist only inside
their events.

## Retention & live

Guided first loop (~3 min to first scissors), 7-day login, daily/weekly
quests, codes, badges on your showcase, monthly themed events, weekly
featured weather, and offline Crew production to collect on your land.

## Monetization

Full genre catalog (2x Coins, Crew slots, Auto-Sell, Infinite Fuel, VIP,
currency packs, restocks, luck, shortcuts) under strict transparency
rules, plus cosmetics for tools/vehicles, land/showcase and avatar.
Specs: `openspec/specs/monetization-and-cosmetics`.

## Later (designed, not launch)

Trading (Crew are already unique, tradable-by-design items; atomic
two-sided trades ship in their own change) and the Crewdex album.
