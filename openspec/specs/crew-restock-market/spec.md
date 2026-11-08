## Purpose


Crew are primarily obtained from a rotating market in the lobby whose stock refreshes globally every five minutes, creating the shared anticipation of a restock moment, plus the surprise of finding Crew while mowing.

**Phase:** Phase 2 (v1.1)

## Requirements

### Requirement: Global five-minute restock
The Crew market SHALL refresh its stock on a global 5-minute clock that is identical on every server, with a visible countdown in the lobby.

#### Scenario: Same shelf everywhere
- **WHEN** two players on different servers open the Crew market at the same time
- **THEN** they see the same Crew stock and the same countdown

### Requirement: Rarity-weighted shelf with commons always present
Common Crew SHALL always be in stock; higher rarities SHALL appear with decreasing probability, and Legendary/Mythic appearances SHALL have small per-player stock.

#### Scenario: Rare appearance
- **WHEN** a restock rolls a Legendary Crew member
- **THEN** it is purchasable for a small number of purchases per player until the next restock, and one player buying it does not remove it for others

### Requirement: Clovers pricing
Crew market purchases SHALL be priced in Clovers.

#### Scenario: Buying Crew
- **WHEN** a player buys a Crew member from the market shelf
- **THEN** Clovers are deducted and that Crew member (a tradable collection item) is added to their roster

### Requirement: Crew discovery while mowing
Rarely, cutting grass SHALL reveal a special shining tuft that grants a Crew member from the current expansion's roster.

#### Scenario: Found in the grass
- **WHEN** a player cuts a shining tuft
- **THEN** a Crew reveal moment plays and that Crew member joins their roster without any purchase

### Requirement: Manual restock product
Players SHALL be able to pay Robux to refresh their market view immediately; this MUST NOT change the global shelf for other players.

#### Scenario: Paid refresh
- **WHEN** a player buys a manual restock
- **THEN** only their shelf rerolls instantly
