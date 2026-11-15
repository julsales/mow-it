## Purpose


The tool ladder is the game's central fantasy: from a nail clipper to gigantic machines, including rideable mowers the player actually drives over the grass, with a fuel system that can be refilled manually, by limited automation, or by an infinite-fuel pass.

**Phase:** Phase 1 (v1) ladder — rideable + fuel in Phase 4

## Requirements

### Requirement: Roughly 48 tools in families across six expansions
The tool catalog SHALL contain about 48 tools in escalating families (manual, electric, rideable, industrial, fantasy/future), about 8 per expansion, each stronger in power, reach and speed than the last, starting with the Nail Clipper.

#### Scenario: First upgrade feels huge
- **WHEN** a starting player replaces the Nail Clipper with Safety Scissors
- **THEN** their grass-per-minute visibly increases

### Requirement: The first hand tools cut blade by blade
The first hand tools SHALL cut single blades of grass instead of whole lawn cells: one swing snips up to the tool's `Blades` (`Config/Tools`), nearest the player first, starting at 1 for the Nail Clipper and growing by one per tool (2, 3, 4...). Each snipped blade SHALL disappear from the player's own lawn and yield grass; a cell is mowed when its last blade is cut. Tools without `Blades` SHALL mow every whole cell in reach.

#### Scenario: Nail Clipper
- **WHEN** a player swings the Nail Clipper on tall grass
- **THEN** exactly one blade disappears from the lawn and the player gains its grass

#### Scenario: Next tool
- **WHEN** a player swings Safety Scissors on tall grass
- **THEN** two blades disappear and the player gains the grass of both

### Requirement: Tool rarity shown as stars
Every tool SHALL have a rarity of 0 to 6 stars (`Stars` in `Config/Tools`, tiers in `Config/Rarity`): the free starter tool has 0, each later family one more, the last family 6. Wherever a tool is shown (shop rows, hotbar, backpack, world price tags) its rarity SHALL appear as stars in the tier's color: a single empty star for 0, otherwise one filled star per star.

#### Scenario: Starter tool
- **WHEN** a player sees the Nail Clipper in the hotbar, the backpack, the shop or on a stand
- **THEN** it shows one empty star

#### Scenario: Top tool
- **WHEN** a player sees MOWZILLA in the shop
- **THEN** it shows six filled stars

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
