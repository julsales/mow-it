## Purpose


Crew are the game's showy companions — garden animals, garden-fantasy creatures and personality machines — that follow the player or work stationed in place, cutting grass, multiplying earnings, and working offline.

**Phase:** Phase 2 (v1.1) — offline work completes in Phase 4

## ADDED Requirements

### Requirement: Mixed Crew roster in six rarities
Crew members SHALL belong to one of six rarities (Common, Uncommon, Rare, Epic, Legendary, Mythic), and their theme SHALL progress with the player's land: animals early, garden fantasy in the middle, personality machines late. Higher rarities SHALL be visibly larger, flashier and stronger.

#### Scenario: Seeing rarity at a glance
- **WHEN** a Mythic Crew member stands next to a Common one in the lobby showcase
- **THEN** the Mythic is obviously bigger and more decorated without reading any text

### Requirement: Equip slots and multiple copies
Players SHALL equip Crew up to their slot count (starting at 1, growing to 5 or more through level, expansions and franchise), and SHALL be able to equip multiple copies of the same Crew member with stacking effects.

#### Scenario: Equipping a copy
- **WHEN** a player equips a second copy of a Crew member they already have equipped and has a free slot
- **THEN** both copies are active and their effects stack

### Requirement: Merge evolution
Players SHALL be able to merge multiple copies of the same Crew member into an evolved form with stronger effects and an upgraded look (for example Shiny/Golden tiers).

#### Scenario: Merging duplicates
- **WHEN** a player merges the required number of copies of the same Crew member
- **THEN** the copies are consumed and replaced by one evolved Crew member

### Requirement: Follow and station modes
Each equipped Crew member SHALL be settable to Follow mode, cutting grass near the player, or Station mode, staying at a chosen spot and cutting grass around it.

#### Scenario: Stationed Crew keeps working
- **WHEN** a player stations a Crew member in their farm expansion and walks to another expansion
- **THEN** the stationed Crew member keeps cutting grass around its spot

### Requirement: Crew work offline
Stationed and equipped Crew SHALL keep producing while the player is offline, up to an offline cap that starts at zero and grows with automation progress, and the accumulated production SHALL be collectable from the player's land on return.

#### Scenario: Collecting offline production
- **WHEN** a player returns after being offline with Crew stationed on their land
- **THEN** the grass their Crew produced (up to their offline cap) is waiting to collect on their land

### Requirement: Crew is collection, never reset by prestige
Crew ownership and evolution SHALL be stored as collection data that prestige never removes.

#### Scenario: Franchising keeps Crew
- **WHEN** a player franchises (prestiges)
- **THEN** all their Crew members and their evolution state remain owned
