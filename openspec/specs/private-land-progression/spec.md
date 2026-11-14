## Purpose


The islands are a shared world: up to six players are on them together. What is private is each player's progression through them (which islands they have unlocked, their own grass, their own hay yard) and their personal base, a small island of their own next to the home island.

**Phase:** Phase 1 (v1)

## Requirements

### Requirement: Shared islands, private progression
The islands SHALL be shared by every player on the server, in the fixed order: Front Yard (the home island), Backyard Garden, Sunny Farm, Big Ranch, Golf Estate, Mega Fields. Which islands are open SHALL be each player's own: a gate is open for the players who unlocked that island and shut for everybody else, and nobody's purchase opens anything for another player.

#### Scenario: Returning player
- **WHEN** a player who has unlocked three islands joins a server
- **THEN** the gates to those three islands are open for them and the later ones are shut, whatever the other players have unlocked

#### Scenario: Two players at one gate
- **WHEN** a player who unlocked an island and a player who has not stand at its gate
- **THEN** the first walks through it and the second is stopped and offered the unlock

### Requirement: Own grass on shared lawns
Every player SHALL mow their own grass: what one player cuts stays standing for every other player, regrows for that player alone, and rare patches are rolled per player. Mowing SHALL only work on islands the player has unlocked (and on the lawns of the personal bases).

#### Scenario: Mowing side by side
- **WHEN** two players mow the same lawn
- **THEN** each sees and harvests only their own cuts, and neither can empty the lawn for the other

### Requirement: Personal base
Every player SHALL get a personal base when they join: one of six identical small islands evenly spaced round the home island, each joined to it by a short bridge, with a cabin, the player's hay yard (baler, bale stack, silo), a jetty with a boat and a small lawn. No two players SHALL share a base. The player SHALL spawn on their base; its board SHALL read "<name>'s Island" and the player's round picture with their name SHALL float over it. A base's hay yard SHALL work only for its owner. When the player leaves, the base becomes free again.

#### Scenario: Joining
- **WHEN** a player joins a server
- **THEN** they are given a free base, appear on it, and see their name and picture on it

#### Scenario: Someone else's base
- **WHEN** a player stands on the loading deck of another player's baler
- **THEN** nothing is loaded

### Requirement: Open, organic land layout
The land SHALL be laid out as a chain of islands in open water, one island per expansion in unlock order, never a grid or maze: the home base (the player's base, where they spawn) on the first, small island, and every next island clearly bigger than the previous one. Islands SHALL have organic coastlines (beaches, rocks, cliffs) and large, irregular lawns covering most of their area. Each island SHALL be joined to the next by a bridge that carries that expansion's gate, backed by invisible walls, so there are no fence lines on land; the next island SHALL always be visible across the water. The home island SHALL have the hay yard (baler, bale stack and silo) by the base; every other island SHALL have a drop-off pad next to the bridge arrival; every island SHALL have a farmer's tool stand off to the side. The edge of the world SHALL never be visible: water and haze reach the horizon, with invisible walls just offshore.

#### Scenario: Next goal in sight
- **WHEN** a player stands on their last unlocked island
- **THEN** they can see the next locked island across the water and its gate on the bridge, but cannot cross the gate

#### Scenario: Crossing a bridge
- **WHEN** a player unlocks an expansion and crosses its bridge
- **THEN** they arrive next to that island's drop-off pad, with the island's farmer selling its tools nearby

#### Scenario: No visible map edge
- **WHEN** a player looks out to sea, from the ground or from the zoomed-out camera, anywhere on the land
- **THEN** they see water fading into the horizon, and the offshore walls stop them from leaving

### Requirement: Grass type per area with lucky patches
Each area SHALL grow its own grass type with higher health and value than the previous area and a distinct look (color, height and blade shape), and rarer grass types (lucky, golden, or the next area's grass) SHALL spawn sparsely, by chance, as small noticeable patches in earlier areas.

#### Scenario: Lucky patch
- **WHEN** grass regrows in an early area
- **THEN** a small fraction of cells may regrow as a small patch of a rarer, more valuable grass type that looks different from the area's own grass

### Requirement: Boat travel between islands and the base
Every island past the home one SHALL have a jetty with a boat by the bridge arrival, and every personal base a jetty of its own. From an island's jetty a player who unlocked that island SHALL be able to sail to their own base; from their base's jetty, to any island they have unlocked. The server SHALL check every trip (the player stands by a jetty they may use, the destination is theirs to go to, trips have a cooldown).

#### Scenario: Going home to sell
- **WHEN** a player on a far island uses the boat at its jetty
- **THEN** after a short trip they stand on the jetty of their own base

#### Scenario: Locked destination
- **WHEN** a player asks to sail to an island they have not unlocked
- **THEN** nothing happens

### Requirement: Physical selling at the hay yard
Players SHALL hand carried grass in physically: at the baler in the hay yard on their own base, or at an island's drop-off pad on an island they have unlocked, which sends it to that baler. Bales SHALL only be sold at the yard (see `core-mowing-loop`); remote selling SHALL only be available through Auto-Sell or a dedicated pass.

#### Scenario: Storage full
- **WHEN** a player's storage is full
- **THEN** they are told so and shown the way to the nearest place to unload (the baler or an unlocked drop-off pad)

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
Each expansion SHALL contain a physical shop (a farmer's tool stand on its island) selling that expansion's tools, storage and buffs, priced in Coins, and the shop SHALL only sell content whose required expansion the player has unlocked.

#### Scenario: Buying where you play
- **WHEN** a player visits the Sunny Farm shop after unlocking Sunny Farm
- **THEN** they can buy farm-tier tools with Coins without leaving their land

### Requirement: Company Level
Players SHALL earn Company Level experience from cutting, selling, contracts and quests, and the level SHALL gate expansions independently of Coins.

#### Scenario: Earning experience
- **WHEN** a player sells grass or completes a contract
- **THEN** their Company Level experience increases and level-ups are celebrated in the HUD
