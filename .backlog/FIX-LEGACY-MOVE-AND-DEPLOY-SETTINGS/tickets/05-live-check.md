# 05 — Live check in DCS

**Status:** ✅ done (PR #315) · **Type:** AFK, needs the mission reloaded

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

- [x] Each of the four checks is recorded PASS or FAIL with the DCS log lines that prove it.
- [x] No object, group or setting change is left in the mission afterwards.
- [x] The lot's index line and PRD status record the live check.

## Blocked by

- [01](01-dropped-groups-act-alone.md), [02](02-parachute-and-vehicles.md), [03](03-scripted-spawns.md), [04](04-unpack-guard-and-retired-key.md)

## Result — live check of 2026-11-18

Scenario `tests/dcs/noPlayer/scenario_dropped_group_orders.lua` (tier `auto-check`), run with `tools/integration-runner/run_scenarios.py` on `Test_CTLDNEXT_01.miz` after a mission reload on the freshly built `CTLD.lua` (mock transport 3 km from the BLUE player, a real enemy infantry group 700 m from the drop point, the two settings overridden for the run only): **`[DGO] PASS 17/17`** in 48.5 s, recorded in `dcs.log`.

| Check | Result | Proof |
| --- | --- | --- |
| A. Enemy in range (pilot drop) | PASS | one order whose destination is the enemy (A.3); the group really walks toward it, 8 m closer or more after 16 s (A.4) |
| B. No enemy in range | PASS | one order, destination within `maximumMoveDistance` of the drop point and not the enemy (B.3, B.4); the group walks toward it (B.5) |
| C. Both distances at 0 | PASS | no order (C.2); the group moved less than 4 m (C.3) |
| D. `ctld.spawnGroupAtPoint` | PASS | a last argument of 5000 reaches the enemy although `maximumSearchDistance` is 0 (D.2); 50 does not reach it although the setting is 4000, so the group walks at random within `maximumMoveDistance` (D.4) |

Cleanup verified afterwards: no `DGO_` group left, the overridden settings and patched functions restored, the scenario's running flag cleared. A first run failed at once (the mock has no DCS cargo weight to update): the scenario now skips that call, and the failed attempt had changed nothing in the mission.
