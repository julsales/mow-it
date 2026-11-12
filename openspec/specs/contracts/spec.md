## Purpose


Contracts are timed client jobs taken from a job board: mow a client's yard to a target before the deadline, alone or with your party, for Coins, Clovers and Company experience.

**Phase:** Phase 3 (v1.2)

## Requirements

### Requirement: Job board with timed client contracts
A job board SHALL offer generated contracts naming a client yard, a grass target and a time limit, scaling from small yards to mansions and scaling difficulty with party size.

#### Scenario: Taking a contract
- **WHEN** a player accepts a contract from the board
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

### Requirement: Playable-slice marked-yard jobs
The playable slice SHALL follow this implementation contract: Jobs mark the existing named expansion instead of teleporting to a separate yard. Participants are captured at acceptance and must qualify by their own expansion progression. Only their cuts within that expansion advance the job; completion pays once and clears the active job.

#### Scenario: Playable-slice acceptance
- **WHEN** this slice is tested
- **THEN** its documented behavior and exclusions match `docs/PLAYABLE_LOOP.md`, and broader v2 requirements remain tracked until independently verified
