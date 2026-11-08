## Purpose

Franchising is the prestige loop with the game's own flavor: sell your lawn-care company, start a new one, and grow permanently stronger through a Franchise Points upgrade tree.

## ADDED Requirements

### Requirement: Sell the company to franchise
A player who has reached the late game SHALL be able to franchise: resetting Coins, tools, storage and land expansions in exchange for Franchise Points scaled by their run's progress.

#### Scenario: Franchising
- **WHEN** a qualifying player confirms franchising after seeing exactly what resets and what is kept
- **THEN** their run resets, and Franchise Points and permanent multipliers are credited

### Requirement: Collection is never reset
Franchising MUST NOT remove Crew, Crew evolution, cosmetics, badges or showcase identity.

#### Scenario: Keeping the Crew
- **WHEN** a player with a Mythic Crew member franchises
- **THEN** the Mythic Crew member is still owned and equippable in the new run

### Requirement: Franchise Points tree
Franchise Points SHALL be spendable on a permanent upgrade tree (for example extra Crew slots, stronger offline caps, automation strength) that persists across all future runs.

#### Scenario: Buying a permanent upgrade
- **WHEN** a player spends Franchise Points on an extra Crew slot node
- **THEN** their Crew slot count increases permanently, including after future franchises

### Requirement: First franchise pacing
The economy SHALL be tuned so a casual player (roughly 30–60 minutes a day) reaches their first franchise in about one to two weeks.

#### Scenario: Casual pacing target
- **WHEN** progression is simulated at casual daily play including offline production
- **THEN** the simulated first franchise lands within the one-to-two-week window
