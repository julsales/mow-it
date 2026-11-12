## Purpose


Contracts are timed client jobs discovered through local NPC contacts: mow a client's yard to a target before the deadline, alone or with your party, for Coins, Clovers and Company experience.

**Phase:** Phase 3 (v1.2)

## ADDED Requirements

### Requirement: NPC contacts with timed client contracts
Local NPC contacts SHALL offer contracts naming their expansion, a grass target, rewards and a time limit, scaling difficulty with party size. The journal SHALL show only contacts in expansions unlocked both by the player and the land owner. Unmet contacts SHALL appear as invitations to talk; their full job details SHALL be revealed after server-observed discovery.

#### Scenario: Taking a contract
- **WHEN** the host accepts a contract while alive and within conversation distance of its discovered NPC
- **THEN** a client yard session (or marked area) becomes active with its target and countdown visible to the whole party

### Requirement: Shared co-op rewards
When a party completes a contract, every participating member SHALL receive the contract's Coins, Clovers and experience rewards personally.

#### Scenario: Party delivery
- **WHEN** a 3-player party reaches the contract target before the deadline
- **THEN** all 3 players receive the full contract rewards on their own accounts

### Requirement: Gentle failure
Missing a deadline SHALL reduce the payout rather than punish the players, and the contract SHALL be abandonable without penalty beyond losing progress on it.

#### Scenario: Late delivery
- **WHEN** a party reaches the target after the deadline
- **THEN** they receive a reduced payout and can immediately take another contract

### Requirement: Persistent NPC discovery and guided conversation
The server SHALL persist discovered contact IDs when a living player approaches an NPC in an eligible expansion. Acceptance SHALL independently recheck the player's discovery, expansion eligibility and current physical distance to that NPC. A conversation prompt SHALL open the journal; a remote request alone SHALL NOT discover a distant contact or start a job remotely.

#### Scenario: First contact
- **WHEN** a new player enters their land
- **THEN** the HUD invites them to meet the first eligible contact and offers a route to the NPC; approaching discovers that contact once, and talking opens its job offer

#### Scenario: Remote acceptance attempt
- **WHEN** a player requests a known job while far from its NPC or dead
- **THEN** no job starts and no reward or discovery is granted

### Requirement: Local route to quest contacts
The client SHALL offer a pathfinding trail to the selected contact's physical approach pad and a named marker above that NPC. It SHALL discard stale path results, refresh after movement or respawn, and clear destinations that become locked or missing. Full-storage selling guidance SHALL take priority. If no route is found, the NPC marker SHALL remain without a line through obstacles.

#### Scenario: Quest navigation
- **WHEN** the player chooses to talk to a contact in the journal
- **THEN** the journal closes and the golden route leads toward that contact; accepting a job clears that route and displays the party's progress and remaining time
