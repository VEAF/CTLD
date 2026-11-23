# 02 — Inactive zones stay inactive (#323)

**Status:** ✅ done (PR #330) · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #323.

## What to build
`self.active = data.active ~= false` in `CTLDTroopZone:init` (`src/CTLD_zone.lua:136`) and `CTLDLogisticZone:init` (`:408`).

## Acceptance criteria
- [x] A `troopZones` entry with `"no"` and a `wpZones` entry with `"no"` load inactive; `activate()` opens them.
- [x] `active` absent or `true` still loads active.
- [x] CHANGELOG *Fixed* entry.
