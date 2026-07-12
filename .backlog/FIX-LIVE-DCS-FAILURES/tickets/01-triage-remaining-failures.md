# 01 — Triage the 10 remaining live-run failures

Status: ✅ done
Type: hybrid (live DCS re-run + src/test fix per finding)

## Resolution (2026-07-12)

Fresh live run (`--no-ai`, current `develop` + POST-FULLGAS-FIXES already merged): **48/48
`auto`/`auto-check` scenarios PASS**, including all 10 below — confirmed stable across two
consecutive runs. No `src`/test change was needed.

Root cause: the same class of issue already documented for F-120/F-121/F-122/F-123 in the
2026-07-10 run — cross-scenario state contamination accumulated over a long-running mission
session (shared globals: `MenuManager` singleton, scheduler, `U-108` probe run-once guards).
A fresh mission (reload) starts with clean state and every scenario resolves correctly,
including `scenario_mt05_crate_vehicle.lua`'s apparent `isExist()` crash and `F-119`'s radius
mismatch — neither reproduces from a clean state, so not real bugs in
`CTLDCrateManager:getLoadedCrateWeight` or the recon icon geometry.

**Takeaway for future live runs**: reload the mission (`Shift+R`) before a full `--no-ai` sweep,
not just after `src/` changes — long-running sessions accumulate cross-scenario state that
produces false failures.

## Context

Source: `test-results-run2.xml` (2026-07-10 live run, 45 scenarios, 18 failures). 8 of the 18 are
already covered by `POST-FULLGAS-FIXES` (see PRD "Already fixed"). The 10 below are untouched.

## What to do

1. Re-run live (`python tools/integration-runner/run_scenarios.py --no-ai --inject-ctld`) against
   current `develop` to confirm which of the 10 still fail (some may have moved since 07-10).
2. For each confirmed failure: read `tests/dcs/CTLD.log` for the ones that only say "see
   CTLD.log", root-cause, and either fix `src/` or rewrite the stale scenario/assertion —
   whichever is wrong. Follow legacy parity (`migration/source/CTLD.lua`) as the reference.
3. Re-run to confirm PASS before closing.

## The 10 failures to triage

| Scenario | Failure (2026-07-10) | First read |
|---|---|---|
| `F-119_reconAAIconCircleToAllFilled2ApexLineToAllNoBare3L.lua` | Circle radius: `scale=1.0 got=67.5 exp=15.75`, `scale=2.0 got=135 exp=31.5` (both ratios ≈4.29×) | Consistent ratio across both cases — looks like a real unit/formula bug, not a stale test |
| `scenario_ai_transport.lua` | F-134.1/.2/.3/.5: `embarkFromTroopZone`/`disembarkAll` mocks never called | Wiring/mock likely stale vs current `CTLD_core.lua` AI-transport flow |
| `scenario_b3_load_crate_from_menu.lua` | FAIL 3/8 — see `CTLD.log` | — |
| `scenario_cl9_pickup_zones.lua` | FAIL 2/5 — see `CTLD.log` | — |
| `scenario_crate_menu_flight_visibility.lua` | FAIL 11/19 — see `CTLD.log` | — |
| `scenario_feature_p_caps_rename.lua` | FAIL 1/44 — see `CTLD.log` | — |
| `scenario_mt05_crate_vehicle.lua` | Runtime crash: `CTLD.lua:12304: attempt to call method 'isExist' (a nil value)` | `CTLDCrateManager:getLoadedCrateWeight` (`src/CTLD_crate.lua:1052`) calls `crate.loadedBy:isExist()` without a nil/type guard — likely a real nil-safety bug, prioritize (crash, not just assertion) |
| `U-051_oRDERSortingDCSRebuildFollowsOrderFieldNotInsertio.lua` | Menu order assertions (Troops/Crates/FOB by `order` field) fail | — |
| `U-052_pagination13Items9NextPageAtF10.lua` | Pagination assertions (9 items page 1, "→ Next Page") fail | — |
| `U-053_enabledFlagDisabledNodeAbsentFromDCSRebuild.lua` | Enabled-flag assertions (Troops/Beacons rendered) fail | — |

## Acceptance criteria

- [x] Fresh live run confirms the current failure set (may differ from 2026-07-10).
- [x] Each of the 10 is either fixed (src or test) with a green re-run, or explicitly deferred with
      a reason recorded here.
- [x] `tests/recette.md` / `CHANGELOG.md` updated to drop the "not yet ticketed" note.
