# Hay yard: how grass is sold

Selling is a small production line at the player's base instead of a pad
on the ground. Behaviour is specified in
`openspec/specs/core-mowing-loop/spec.md` ("Selling grass"); this file is
the plan: what exists, how it is put together and what comes next.

## The loop

1. **Cut** grass until storage is full (unchanged).
2. **Load**: step onto the baler's loading deck at the base (it glows
   with an outline). All carried
   grass flies into the hopper. On the other islands the old sell pads are
   **drop-off pads**: they send the grass to the same hopper, so you don't
   have to walk home to empty your storage (fuel is refilled at both).
3. **Bale**: the baler presses the hopper into hay bales, one every few
   seconds, and they hop onto the stack on the pallet. A full storage is
   always about six bales, so bigger storage means richer bales, not more
   clicking. Now and then a bale comes out **golden** (worth 5x). When the
   stack is full the baler waits (red lamp).
4. **Sell**: click a bale (the waiting bales are outlined; clicking works
   with a tool in the hand). Coins are paid at once, the bale hops onto the
   elevator, rides up and drops into the **silo**.
5. **Customers**: while the silo has stock, customers walk up to its
   counter (they arrive at the dock), take 1 or 2 bales and pay a tip (10% of what those bales sold
   for). Nobody buys loose grass from the player any more.

While the player is at the yard, a line at the top of the screen always
names the next step (load, wait for the baler, click the bales, go mow
more), and every sale pops "+N Coins" where the bale was.

Every step is animated on the client: flywheel, rattling body, press,
exhaust puffs and gauge on the baler; grass thrown into the hopper and the
heap sinking; bales squeezing out, hopping, dropping when one below is
sold; the elevator belt, the silo hatch, the weather vane; customers
walking in, picking the bales up and carrying them away; coin pop-ups.

## Baler upgrades

A prompt on the baler buys its next level (`Config.Levels`, state in
`profile.Hay.Level`): each level gives the stack more room (6 bales per
layer) and, from level 3 on, more bales per press. A level can only be
bought once its `RequiredZone` island is unlocked, so the machine grows
with the land: level 2 at the base, then one level per island.

## Where things live

| What | Where |
|---|---|
| Numbers, upgrade ladder, model layout, rigs, markers, colours | `Shared/Config/HayYard.luau` |
| State shape and rules shared by server and client | `Shared/Hay.luau` (`profile.Hay`) |
| Server: load, press, sell, customers, tips | `Services/HayService.luau` |
| Server: builds the yard and the customer templates | `Services/Map/HayYard.luau` |
| Painted copy of a yard model (server and client) | `Shared/YardArt.luau`, `Shared/ArtModels.luau` (shared with the tools) |
| Client: everything visible | `StarterPlayerScripts/HayYard.client.luau` |
| Client: moving machine pieces (data-driven rig player) | `StarterPlayerScripts/HayRigs.luau` |
| Client: bale model, hops, the stack | `StarterPlayerScripts/HayBales.luau` |
| Client: customers | `StarterPlayerScripts/HayCustomers.luau` |
| Blender sources and exports | `art/yard/` |

The server owns the state (`profile.Hay`: hopper units and value, bales
with id/value/golden, silo stock) and validates every click (bale exists,
player near the stack). Clients draw it from the profile they already
receive; only customers and tips have their own events. Each player sees
their own bales.

In the place, the yard is one Model `HayYard` inside the home island with
the Models `Baler`, `BaleStack`, `Silo` and `Ground` (the packed dirt),
plus two invisible parts: `SellPad` (inside `Baler`, on its loading
deck) and `CustomerSpawn` (where customers walk in from). Code finds them by
name and reads where they stand, so each can be dragged by hand
(docs/EDITING.md).

## Later (designed for, not built)

- **Conveyor to the silo**: automation that sells without the click: call
  `HayService.Sell` for the oldest bale on a timer when the player owns it.
- **Truck**: a big customer that empties the silo for a bonus, same event
  as a customer with its own model and route.
- **Silo upgrades**: `SiloCapacity`, `TipRate`, customer frequency.
- **Sounds**: machine loop, press stomp, bale thump, belt, till. Left out
  here on purpose: the sound system is being reworked in another PR
  (`Config/Sounds`, `SoundManager`); selling keeps the existing coin sound.
- **Helpers seeing each other's bales** (party play): replicate the stack
  instead of drawing it locally.
- Auto-Sell (the late-game buff) still pays out directly; it should become
  the conveyor above.
