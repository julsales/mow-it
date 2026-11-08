## Purpose


The tool ladder is the game's central fantasy: from a nail clipper to gigantic machines, including rideable mowers the player actually drives over the grass, with a fuel system that can be refilled manually, by limited automation, or by an infinite-fuel pass.

**Phase:** Phase 1 (v1) ladder — rideable + fuel in Phase 4

## ADDED Requirements

### Requirement: Roughly 48 tools in families across six expansions
The tool catalog SHALL contain about 48 tools in escalating families (manual, electric, rideable, industrial, fantasy/future), about 8 per expansion, each stronger in power, reach and speed than the last, starting with the Nail Clipper.

#### Scenario: First upgrade feels huge
- **WHEN** a starting player replaces the Nail Clipper with Safety Scissors
- **THEN** their grass-per-minute visibly increases

### Requirement: Rideable tools drive and mow
From the riding-mower tier upward, tools SHALL be vehicles the player mounts and drives; grass under a moving rideable tool SHALL be cut without swinging.

#### Scenario: Driving over grass
- **WHEN** a player drives a riding mower across a grass field
- **THEN** grass under the mower is cut and collected subject to storage capacity

### Requirement: Fuel for motorized and rideable tools
Motorized and rideable tools SHALL consume fuel while operating, and running out SHALL stop the tool (hand tools never consume fuel).

#### Scenario: Out of fuel
- **WHEN** a rideable mower's fuel reaches zero while driving
- **THEN** it stops cutting and the player is directed to refuel options

### Requirement: Three refuel paths
Fuel SHALL be refillable manually at fuel points in expansions, automatically over time by fuel automation with a capped reserve, or unlimited while the player owns the Infinite Fuel pass.

#### Scenario: Automation refills slowly
- **WHEN** a player owns fuel automation and waits with a partially empty tank
- **THEN** fuel regenerates up to the automation's reserve cap, never beyond it

#### Scenario: Infinite Fuel pass
- **WHEN** a player with the Infinite Fuel pass uses any fueled tool
- **THEN** fuel is never consumed
