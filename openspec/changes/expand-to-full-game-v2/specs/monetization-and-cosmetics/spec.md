## Purpose


Robux monetization in the full genre style — convenience passes, currency packs, luck and shortcut products — plus deep cosmetics, all presented transparently so spending is a choice, never a trap.

**Phase:** Phase 5 (v1.4)

## ADDED Requirements

### Requirement: Genre-standard purchase catalog
The game SHALL offer one-time passes (for example 2x Coins, extra Crew slots, Auto-Sell, Infinite Fuel, VIP) and repeatable products (currency packs, market restocks, luck boosts, unlock shortcuts) at a range of price points.

#### Scenario: Buying a pass
- **WHEN** a player purchases a game pass
- **THEN** its benefit is granted server-side, persists across sessions, and is visible in their profile

### Requirement: Transparent offers
Every Robux offer SHALL show exactly what it grants before purchase; fake countdowns, misleading discounts and auto-renewing pressure timers MUST NOT be used.

#### Scenario: Honest discount
- **WHEN** an item is displayed as discounted
- **THEN** the discount is genuine against its normal price and does not use a timer that silently restarts

### Requirement: Receipt safety
Developer product purchases SHALL be granted through a single server receipt process that is idempotent: processing the same receipt twice MUST NOT grant rewards twice.

#### Scenario: Duplicate receipt
- **WHEN** the same purchase receipt is delivered twice
- **THEN** the reward is granted only once

### Requirement: Cosmetics on tools, land and avatar
Players SHALL be able to own and apply cosmetics for tools and vehicles (skins, colors, cutting trails/effects), land and showcase decoration, and avatar-facing items (auras, titles), obtained from play, events, the restock ecosystem and Robux offers.

#### Scenario: Applying a tool skin
- **WHEN** a player applies an owned skin to their mower
- **THEN** that mower shows the skin to everyone who sees it, with no gameplay stat change
