# 01 — Parachuted troops keep their template (#322)

**Status:** ✅ done (PR #330) · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #322.

## What to build
`CTLDTroopManager:parachuteTroops` (`src/CTLD_troop.lua` ~1814-1822) builds each unit from the template's own unit list, resolving `unitType(coalition)` per unit, as the landed unload does through `CTLDObjectRegistry.spawnObject`. `"Soldier AK"` remains only as a logged fallback.

## Acceptance criteria
- [x] A parachuted "Standard Group" (blue) lands with the same types, in the same order, as the same group unloaded on the ground.
- [x] A red template resolves the red types.
- [x] A JTAC template still lases (wiring by position unchanged).
- [x] CHANGELOG `[Unreleased]` *Fixed* entry.
