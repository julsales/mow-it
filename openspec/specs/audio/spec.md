## Purpose

What the player hears: tool sounds that match the tool, feedback for the
core loop (cut, collect, sell, buy, unlock, level up), UI clicks, and calm
background music with an outdoor ambience per island. Asset ids and levels
are data in `Shared/Config/Sounds.luau`; sources are logged in
`docs/ASSETS.md` > Audio.

**Phase:** Phase 1 (v1)

## Requirements

### Requirement: Tool sounds match the tool
Each tool kind SHALL have its own sound: hand tools play a cut one-shot per
successful swing and a whoosh on a miss; motor tools play an engine loop
that idles while held, revs with movement speed and adds a grass-cutting
layer while grass is being cut; reel mowers rattle only while moving.

#### Scenario: Push mower
- **WHEN** a player holds a push mower and walks across grass
- **THEN** the engine revs up and a cutting sound fades in, and both settle back to idle when they stop

#### Scenario: Other players' machines
- **WHEN** another player drives a mower nearby
- **THEN** its engine is heard from its position and fades with distance

### Requirement: Loop feedback
Cutting into the bag, a full bag, selling, buying, unlocking an island and
levelling up SHALL each have a distinct sound heard only by that player.
Progress stingers duck the music while they play and never overlap each other.

#### Scenario: Selling
- **WHEN** a player sells grass on a sell pad
- **THEN** a cash drawer and a cascade of coins play, with more coins for bigger sales

### Requirement: Music and ambience per island
Background music SHALL be calm acoustic tracks, one theme per island, that
crossfade when the player reaches another island and keep rotating (never
the same track twice in a row) with a short pause between tracks. An
outdoor ambience bed plays under the music.

#### Scenario: Crossing to a new island
- **WHEN** a player walks from the Front Yard onto the Backyard Garden island
- **THEN** the Front Yard theme fades out and the Backyard theme fades in

### Requirement: No repetition fatigue
Repeated one-shots SHALL vary (random variant never repeated twice in a
row, small pitch variation) and be rate limited so fast tools cannot spam them.
