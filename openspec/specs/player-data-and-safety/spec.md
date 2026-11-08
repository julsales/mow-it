## Purpose

Player progress is valuable and persistent: profiles must save safely, the server must be the authority on anything worth currency, and future trading must be designed so it cannot scam or duplicate items.

## Requirements

### Requirement: Complete persistent profile
The player's profile SHALL persist currencies, per-variant carried grass (session state may reset carried grass, never lifetime stats), tools, storage, land expansions, plots, Company Level, Crew roster and evolution, franchise state, cosmetics, badges and settings.

#### Scenario: Progress survives sessions
- **WHEN** a player unlocks an expansion, evolves a Crew member and logs out
- **THEN** on their next session both the expansion and the evolved Crew are present

### Requirement: Server authority and validation
All currency, inventory, Crew and land changes SHALL be decided by the server; clients only send requests, and invalid requests (bad amounts, locked content, excessive rates) SHALL be rejected without state changes.

#### Scenario: Forged purchase request
- **WHEN** a client sends a purchase request for content the player has not unlocked
- **THEN** the server rejects it and no currency or items change

### Requirement: Save resilience
Profile saving SHALL use protected calls with defaults reconciliation, autosaves and save-on-leave, so a failed save or a new content update never wipes a player's progress.

#### Scenario: New field added by an update
- **WHEN** an update adds a new profile field and an old player logs in
- **THEN** their existing progress loads and the new field gets its default value

### Requirement: Crew designed as tradable items (future trading)
Crew instances SHALL carry a unique identity and ownership history from day one; if trading ships later, it SHALL use a two-sided confirmed trade that moves ownership atomically and records the trade. Trading is NOT required to be available at launch.

#### Scenario: Future trade safety by design
- **WHEN** trading is implemented in a later change
- **THEN** it can operate on existing Crew instances without a data migration, and a confirmed trade cannot leave the same Crew member owned by two players
