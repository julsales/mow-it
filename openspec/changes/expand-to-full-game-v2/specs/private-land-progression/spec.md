## Purpose


The player's land is their persistent, private property and the game's main progression: one contiguous plot that grows expansion by expansion from a house yard to automated mega-fields.

**Phase:** Phase 1 (v1)

## ADDED Requirements

### Requirement: Private persistent land
Each player SHALL own a persistent land that is loaded as their own property in Land sessions, showing exactly the expansions they have unlocked, in the fixed order: Front Yard, Backyard Garden, Sunny Farm, Big Ranch, Golf Estate, Mega Fields.

#### Scenario: Returning player
- **WHEN** a player enters their land after having unlocked three expansions
- **THEN** their land presents those three expansions joined together, with later expansions still closed off

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
