## Purpose


Server-wide weather turns ordinary mowing into shared events: for a few minutes everyone on the land chases the same sky, because weather creates high-value grass variants.

**Phase:** Phase 3 (v1.2)

## Requirements

### Requirement: Server-wide weather cycle
Land sessions SHALL run a weather cycle visible and announced to every player in the session, with weather types such as Rain, Golden Sun, Moon Night and Storm.

#### Scenario: Weather announcement
- **WHEN** a Storm begins on a land session with several players
- **THEN** every player in that session sees and hears the weather change at the same time

### Requirement: Weather creates variant windows
During weather, newly grown and existing grass SHALL gain increased chances of weather-linked variants (for example Wet in rain, Golden in Golden Sun, Lunar at Moon Night, Rainbow in Storms).

#### Scenario: Chasing the storm
- **WHEN** a player cuts grass during a Storm
- **THEN** cut units have the storm's increased Rainbow chance, tagged as Rainbow units in their inventory

### Requirement: Variant value multipliers
Each grass variant SHALL have a sell multiplier above Normal, and selling SHALL pay variants at their own multipliers (see `core-mowing-loop`).

#### Scenario: Golden payday
- **WHEN** a player sells a load containing Golden units
- **THEN** those units pay their Golden multiplier instead of the Normal value

### Requirement: Weekly special weather rotation
Beyond the normal cycle, a featured special weather SHALL rotate weekly, announced in the lobby.

#### Scenario: Weekly feature
- **WHEN** a new week starts
- **THEN** the lobby shows which special weather is featured that week
