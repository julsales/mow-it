## Purpose


The public lobby is the social front door: a showcase mini-base for flex, the restock market, leaderboards, and the two ways into play — solo to your own land, or a party of up to four to the host's land.

**Phase:** Phase 1 (v1)

## ADDED Requirements

### Requirement: Showcase mini-base
When a player is in the lobby, a simplified showcase of their progress SHALL be displayed on a public lot: their house tier, best equipped Crew visible, parked vehicles and headline stats. The showcase MUST NOT expose any economy or editable state.

#### Scenario: Showing off progress
- **WHEN** a player with a riding mower and a Legendary Crew member enters the lobby
- **THEN** other players can see the Crew member and vehicle on that player's showcase lot

#### Scenario: Showcase cannot be harmed
- **WHEN** another player interacts with someone else's showcase lot
- **THEN** nothing about the owner's progress, currency or land changes

### Requirement: Solo entry (PLAY)
The lobby SHALL provide a PLAY entry that takes a single player directly to their own land in a private session.

#### Scenario: Playing solo
- **WHEN** a player uses the PLAY entry alone
- **THEN** they arrive on their own land with their own progression loaded

### Requirement: Party entry (host's land)
The lobby SHALL provide a party block that queues up to 4 players; when the party starts, all members SHALL travel together to the party host's land in a private session.

#### Scenario: Full party starts
- **WHEN** 4 players have joined the party block
- **THEN** the countdown ends early and all 4 travel to the host's land together

#### Scenario: Helpers earn fully
- **WHEN** a guest helps mow on the host's land
- **THEN** the guest earns their own Coins, Clovers and experience normally (respecting the guest's own unlocks), while land expansion state only progresses for the host

#### Scenario: Teleport failure keeps the party
- **WHEN** the teleport to the host's land fails
- **THEN** party members remain in the lobby with the party intact so they can retry

### Requirement: Lobby shops mirror unlocked content only
Lobby shops SHALL only display and sell content the player has already unlocked on their land, plus Crew from the restock market; they MUST NOT sell locked-expansion content.

#### Scenario: No skipping progression from the lobby
- **WHEN** a player who has not unlocked the Ranch browses lobby shops
- **THEN** Ranch-tier tools are not purchasable there
