# AGENTS.md — Mow It!

Read before working in this repo:

1. **Design source of truth:** OpenSpec — `openspec/specs/` (behavior) and
   `openspec/changes/expand-to-full-game-v2/tasks.md` (implementation order).
   `docs/GDD.md` is a summary. Update specs in the same change as behavior. Progression numbers live in
   `src/ReplicatedStorage/Shared/Config/*.luau` — change numbers there,
   never hard-code them in systems.
2. **Assets:** `docs/ASSETS.md` is a gate, not a suggestion. Map →
   audit → import, in that order. Never import Toolbox/Creator Store
   models containing unaudited scripts. **Never copy assets/models/code
   from `julsales/Roblox_Game`** — only its `roblox` skill (already in
   `.agents/skills/roblox/`) and its repo-structure patterns are reused.
3. **Roblox work:** follow `.agents/skills/roblox/SKILL.md` (server
   authority, `pcall` cloud calls, modern APIs — e.g. ReservedServerId
   GUID teleport, not deprecated `ReserveServer()`).
   For deeper topics, the `roblox-*` skills in `.agents/skills/` (from
   EL4CTEO/roblox-skills, see `ROBLOX-SKILLS-NOTICE.md` there) cover
   data stores, networking, security, UI, monetization, testing, etc.
   Where they disagree with this file or OpenSpec, this repo wins.
4. **Maps** are built in Studio under the contract in
   `docs/ARCHITECTURE.md`; code must keep working on the graybox when
   map pieces are missing.
5. **Keep it playable:** every change must leave the loop working —
   cut → sell → buy → unlock — in Play Solo.
6. All player-facing text is **English**. Game name: **Mow It!**
