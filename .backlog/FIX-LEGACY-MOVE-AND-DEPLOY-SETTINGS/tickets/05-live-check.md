# 05 — Live check in DCS

**Status:** ⬜ ready (after 01-04 are merged or built) · **Type:** AFK, needs the mission reloaded

## Parent

[PRD — FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS](../PRD.md). Verification of stories 1, 2, 4 and 12. GitHub issue #309.

## What to build

A `noPlayer` live scenario, run over the DCS bridge's HTTP API on `Test_CTLDNEXT_01.miz`, in the manner of `scenario_create_before_destroy.lua`: a mock transport 3 km from the first BLUE player, real DCS groups, everything cleaned up afterwards.

1. An enemy group is placed within `maximumSearchDistance` of the mock transport; troops dropped by it get a route whose destination is that enemy.
2. With no enemy in range, the dropped troops get a route whose destination lies within `maximumMoveDistance` of the drop point.
3. With both distances at 0 the dropped troops get no route.
4. A scripted spawn through the deprecated `ctld.spawnGroupAtPoint` with a search distance behaves as in 1 and 2.

The result is recorded in the lot's backlog.

## Acceptance criteria

- [ ] Each of the four checks is recorded PASS or FAIL with the DCS log lines that prove it.
- [ ] No object, group or setting change is left in the mission afterwards.
- [ ] The lot's index line and PRD status record the live check.

## Blocked by

- [01](01-dropped-groups-act-alone.md), [02](02-parachute-and-vehicles.md), [03](03-scripted-spawns.md), [04](04-unpack-guard-and-retired-key.md)
