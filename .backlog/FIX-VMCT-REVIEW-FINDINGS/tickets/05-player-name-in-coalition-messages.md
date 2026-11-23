# 05 — Coalition messages name the player (#326)

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #326.

## What to build
A `ctld.utils` helper equivalent to v1's `ctld.getPlayerNameOrType` (player name, else type name). Used in "%1 started building a FOB" (`src/CTLD_fob.lua` ~253) and the three SAM messages (`src/CTLD_aasystem.lua` ~546, ~623, ~692). The `player` doc line of `unpackFOBCrates` says "unit name".

## Acceptance criteria
- [ ] With a player in the slot, the four messages show the player's name; with an AI unit, its type name.
- [ ] Event payloads unchanged (`OnFOBDeployed.player` stays the unit name).
- [ ] CHANGELOG *Fixed* entry.
