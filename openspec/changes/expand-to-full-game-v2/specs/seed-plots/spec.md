## Purpose


Seed plots give the player's land a planting layer: special grass grown deliberately in limited beds, contrasting with the wild grass that simply regrows in every expansion.

**Phase:** Phase 3 (v1.2)

## ADDED Requirements

### Requirement: Wild grass regrows in expansions
Grass in land expansions SHALL regrow after being cut, without any planting, so mowing is always available.

#### Scenario: Endless basic mowing
- **WHEN** a player cuts all grass in an expansion and waits
- **THEN** grass tufts regrow over time in that expansion

### Requirement: Plantable seed plots
Each expansion SHALL offer a limited number of seed plots where the player can plant seeds obtained from shops, the restock ecosystem or rewards; planted grass SHALL grow over real time, including while the player is offline.

#### Scenario: Plant and return
- **WHEN** a player plants a special seed and leaves the game
- **THEN** on return the planted grass has grown according to elapsed time, ready or progressing toward harvest

### Requirement: Planted grass yields variants
Mature planted grass SHALL be cut like wild grass but SHALL yield its special variant or high-value units at rates set by the seed type.

#### Scenario: Harvesting a plot
- **WHEN** a player cuts fully grown planted grass
- **THEN** they gain that seed's special grass units, respecting storage capacity
