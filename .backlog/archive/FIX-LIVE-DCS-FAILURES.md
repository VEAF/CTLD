# FIX-LIVE-DCS-FAILURES

**Status:** delivered. Compacted from `FIX-LIVE-DCS-FAILURES/` on 2026-08-01; the ticket files live on in git history.

Triaged the 10 (of 18) failures from the first live run (2026-07-10) not already fixed by `POST-FULLGAS-FIXES` — all 10 turned out to be cross-scenario state contamination, cleared by a mission reload (48/48 green, no src/test change). Also closed the L4 gap on Feature Q's whole-vehicle Request Equipment menu. PR #23.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-triage-remaining-failures` | ✅ done | 01 — Triage the 10 remaining live-run failures |

## PRD

## Lot FIX-LIVE-DCS-FAILURES — triage the first live-run failures

Status: ✅ done — full 48/48 green live, no src/test changes needed (see ticket 01)
Branch: fix/live-dcs-failures-triage → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`). Sibling to
`POST-FULLGAS-FIXES` (already merged, PR #22) and `CLEANUP-LEGACY-DCS-TESTS`.

### Problem Statement

The first full live run of `tools/integration-runner/run_scenarios.py --no-ai` against a real DCS
mission (2026-07-10, `test-results-run2.xml`, 45 scenarios) came back 27 passed / 18 failed. This
was mentioned in `CHANGELOG.md` ("~13 remaining failures ... tracked informally, not yet
ticketed") but never actually turned into backlog tickets.

`POST-FULLGAS-FIXES` has since fixed 8 of the 18 as a side effect of FullGas's review answers.
This lot tracks the remaining ones and needs a fresh live run to confirm the current count before
triaging each.

### Already fixed (verify only, no new work here)

Covered by `POST-FULLGAS-FIXES` tickets 01–06 — re-confirm on the next live run, do not re-open:

- `scenario_fq_vehicle_whole_transport.lua` (ticket 01)
- `U-108_modValidatorHeliportProbeOffMap.lua`, `U-108_modValidatorHeliportWarnAndSkip.lua` (tickets 02/03)
- `F-117_reconDisabledScanShowsExplicitMessageNotSilent.lua`, `F-118_reconToggleOFFMarksRemovedImmediatelyEvenWhenNoLay.lua` (ticket 04)
- `scenario_fr_ai_zones.lua` (ticket 05) — already re-checked standalone post-fix: PASS (`test-results.xml`, 2026-07-12)
- `scenario_farp_countryside_spawn.lua`, `scenario_farp_metal_spawn.lua` (ticket 06)

### Tickets

| # | Scope | Nature |
|---|-------|--------|
| 01 | Triage the 10 remaining failures from `test-results-run2.xml`, re-verify live, fix or re-ticket each | live-DCS + src/test |

### Non-goals

- The 8 already-fixed scenarios above (verification is folded into ticket 01's fresh run, not separate work).
- Porting/purging the 194 FullGas relics — `CLEANUP-LEGACY-DCS-TESTS`.
