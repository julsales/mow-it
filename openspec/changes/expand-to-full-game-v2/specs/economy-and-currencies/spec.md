## Purpose

Three currencies with separate jobs keep every system purchasable without breaking the others: Coins for the mowing economy, Clovers for Crew and social systems, Franchise Points for prestige only.

## ADDED Requirements

### Requirement: Three currencies with fixed roles
Coins SHALL be earned mainly by selling grass and spent on tools, storage, buffs and land expansions; Clovers SHALL be earned from quests, contracts and weather play and spent mainly on Crew; Franchise Points SHALL only come from franchising and only be spent on the franchise tree.

#### Scenario: Right money for the shop
- **WHEN** a player buys a tool at an expansion shop and a Crew member at the market
- **THEN** the tool costs Coins and the Crew member costs Clovers

### Requirement: Server-validated purchases
Every purchase SHALL be validated on the server for currency, unlock state and ownership before anything is deducted or granted.

#### Scenario: Cannot afford
- **WHEN** a player tries to buy an item they cannot afford
- **THEN** nothing is deducted, nothing is granted, and the player is told why

### Requirement: Physical purchase locations
Outside the Crew restock market and lobby mirrors of unlocked content, purchases SHALL happen at physical shops located in their expansions; there SHALL be no global buy-anywhere shop for locked content.

#### Scenario: Travel to buy
- **WHEN** a player wants Ranch-tier gear
- **THEN** they buy it at the Ranch shop on their land (or its unlocked mirror in the lobby), not from a universal menu while standing in the Front Yard
