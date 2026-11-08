## Purpose

The moment-to-moment mowing loop: cutting grass, carrying it under a storage limit, and selling it. This is the behavior every other system feeds into or rewards.

## Requirements

### Requirement: Cutting grass
The player SHALL be able to swing or drive their equipped tool to cut grass tufts near them, with the server validating tool cooldown, reach, and the player's unlocked areas before any grass is harvested.

#### Scenario: Successful cut
- **WHEN** a player swings a tool next to grass in an area they have unlocked and their storage is not full
- **THEN** the tuft loses health equal to the tool's power, and when its health reaches zero the player gains grass units

#### Scenario: Storage full blocks cutting
- **WHEN** a player tries to cut while their carried grass equals their storage capacity
- **THEN** nothing is harvested and the player is told their storage is full

#### Scenario: Locked area cannot be farmed
- **WHEN** a player swings at grass inside an expansion they have not unlocked
- **THEN** no grass is harvested from that tuft

### Requirement: Tagged-variant inventory
Carried grass SHALL be tracked as a count per variant (for example Normal, Golden, Rainbow), and storage capacity SHALL count the total units across all variants.

#### Scenario: Carrying mixed variants
- **WHEN** a player harvests normal and Golden grass
- **THEN** their inventory shows both counts separately while the total respects the storage cap

### Requirement: Selling grass
The player SHALL be able to sell all carried grass at a Sell Pad, receiving Coins where each variant pays its own value multiplier and the area value applies.

#### Scenario: Sell at pad
- **WHEN** a player with carried grass stands on a Sell Pad
- **THEN** all carried grass is removed and Coins are credited according to each variant's multiplier

#### Scenario: Selling with empty storage
- **WHEN** a player uses a Sell Pad carrying no grass
- **THEN** no currency changes
