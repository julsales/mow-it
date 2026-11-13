## Purpose


The player's land is their persistent, private property and the game's main progression: one contiguous plot that grows expansion by expansion from a house yard to automated mega-fields.

**Phase:** Phase 1 (v1)

## Requirements

### Requirement: Private persistent land
Each player SHALL own a persistent land that is loaded as their own property in Land sessions, showing exactly the expansions they have unlocked, in the fixed order: Front Yard, Backyard Garden, Sunny Farm, Big Ranch, Golf Estate, Mega Fields.

#### Scenario: Returning player
- **WHEN** a player enters their land after having unlocked three expansions
- **THEN** their land presents those three expansions joined together, with later expansions still closed off

### Requirement: Open, organic land layout
The land SHALL be laid out as a farm road: one winding road that starts at the home base (the house) and runs through every expansion in unlock order, never a grid or maze. Each expansion SHALL straddle the road and be larger than the one before, with large, irregularly shaped lawn fields on both sides of the road covering most of its area. Expansions SHALL be separated only by a fence line across the land with one gate on the road, backed by invisible walls; the next gate SHALL always be ahead on the same road, and locked expansions SHALL remain visible beyond their fence. Each expansion SHALL have its sell pad and shop next to the road just past its gate. The edge of the world SHALL never be visible: the land is surrounded by water and haze to the horizon, with invisible walls along the shore.

#### Scenario: Next goal in sight
- **WHEN** a player stands at the edge of their last unlocked area
- **THEN** they can see the next locked area past its fence but cannot walk into it

#### Scenario: Following the road
- **WHEN** a player unlocks an expansion and walks through its gate
- **THEN** the road leads on through it, with its sell pad and shop beside the road, toward the next gate

#### Scenario: No visible map edge
- **WHEN** a player looks away from the land, from the ground or from the zoomed-out camera, anywhere on the land
- **THEN** they see water fading into the horizon, and the shore walls stop them from leaving

### Requirement: Grass type per area with lucky patches
Each area SHALL grow its own grass type with higher health and value than the previous area and a distinct look (color, height and blade shape), and rarer grass types (lucky, golden, or the next area's grass) SHALL spawn sparsely, by chance, as small noticeable patches in earlier areas.

#### Scenario: Lucky patch
- **WHEN** grass regrows in an early area
- **THEN** a small fraction of cells may regrow as a small patch of a rarer, more valuable grass type that looks different from the area's own grass

### Requirement: Physical selling at stalls
Players SHALL sell carried grass by stepping onto a sell stall's pad in an unlocked area; remote selling SHALL only be available through Auto-Sell or a dedicated pass.

#### Scenario: Storage full
- **WHEN** a player's storage is full
- **THEN** they are told so and shown the way to the nearest unlocked sell stall

### Requirement: Land expansions unlock in order
A player SHALL only be able to unlock an expansion when every previous expansion is unlocked, they meet the required Company Level, and they pay the expansion's Coin price.

#### Scenario: Unlock next expansion
- **WHEN** a player with the required level and Coins buys the next expansion at its gate
- **THEN** the expansion opens on their land, its grass becomes cuttable, and its shop starts operating

#### Scenario: Level too low
- **WHEN** a player tries to buy an expansion without the required Company Level
- **THEN** the purchase is refused and the missing requirement is shown

#### Scenario: Skipping is impossible
- **WHEN** a player tries to buy a later expansion while an earlier one is still locked
- **THEN** the purchase is refused

### Requirement: Physical shops per expansion
Each expansion SHALL contain a physical shop selling that expansion's tools, storage and buffs, priced in Coins, and the shop SHALL only sell content whose required expansion the player has unlocked.

#### Scenario: Buying where you play
- **WHEN** a player visits the Sunny Farm shop after unlocking Sunny Farm
- **THEN** they can buy farm-tier tools with Coins without leaving their land

### Requirement: Company Level
Players SHALL earn Company Level experience from cutting, selling, contracts and quests, and the level SHALL gate expansions independently of Coins.

#### Scenario: Earning experience
- **WHEN** a player sells grass or completes a contract
- **THEN** their Company Level experience increases and level-ups are celebrated in the HUD
