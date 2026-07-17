Status: ⬜ ready

# Lot TOOLING-TEST-TAXONOMY — Formalise the test taxonomy post CATCH-UP-PILOT-SCENARIOS

Branch: `tooling/test-taxonomy`
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`).
Follows: `CATCH-UP-PILOT-SCENARIOS` (PR #24, merged `develop` `8421c60`).

---

## Problem Statement

The `CATCH-UP-PILOT-SCENARIOS` lot introduced several breaking changes to the test
taxonomy — renaming the `ia` tier to `human`, adding the `auto-slow` and `disabled`
tiers, renaming the `--no-ai` flag to `--headless`, renaming `run_ia_scenario.py` to
`run_manual_scenario.py` — but did not update the project's ubiquitous language
(`CONTEXT.md`), which still describes the old taxonomy (`ia`, `--no-ai`). The L1–L6
level taxonomy (stable since `DCS-BRIDGE-MCP`) is also absent from the glossary.

Two additional defects were surfaced during the post-lot review session with FullGas
(2026-07-17):

- `mt08` and `mt14` are quarantined (`disabled`) due to DCS AI pathfinding failure on
  their `Land` waypoint. The root cause is a fixable mission configuration (waypoint
  too close to urban terrain), not a CTLD bug. Fixing the waypoint would let these
  scenarios rejoin the `auto-slow` sweep.
- `tests/manual_test_sequences.md` (MT-06 prerequisites) still references
  `recette/enable_debug.lua` and `recette/inject_red_fob.lua` — the `recette/` folder
  was renamed to `tests/dcs/util/` during `DCS-BRIDGE-MCP`. MT-06 cannot be executed
  without correcting these paths.

---

## Solution

1. Update `CONTEXT.md` with the current tier taxonomy (`human`, `auto-slow`,
   `disabled`, `headless sweep`) and the L1–L6 level taxonomy.
2. Create ADR `0006` documenting the `disabled` tier pattern (quarantine for
   external-blocker scenarios).
3. Fix the `Land` waypoint for `mt08`/`mt14` in the test mission and verify both
   scenarios reach PASS under `--tier auto-slow`.
4. Correct the stale `recette/` paths in MT-06's prerequisites
   (`tests/manual_test_sequences.md`).

---

## User Stories

1. As a developer reading `CONTEXT.md`, I want to find the canonical definition of
   every test tier (`auto`, `auto-check`, `auto-slow`, `human`, `disabled`) and every
   test level (L1–L6), so that I use consistent vocabulary without consulting
   `docs/integration-testing.md`.
2. As a developer reading `CONTEXT.md`, I want to see `ia` listed as a banned alias
   for `human`, so that I don't reintroduce the old term in code or docs.
3. As a developer reading `CONTEXT.md`, I want `headless sweep` defined as the
   canonical term for running `--headless`, so that I don't write `--no-ai` in
   documentation or scripts.
4. As a future developer encountering `-- @tier: disabled` on a scenario, I want an
   ADR explaining why such scenarios exist and how the quarantine works, so that I
   don't "fix" them by re-enabling without understanding the external blocker.
5. As a developer running the `auto-slow` sweep, I want `mt08` and `mt14` to reach
   PASS, so that the AI-vehicle and AA-system transport paths have end-to-end
   coverage alongside the other `auto-slow` scenarios.
6. As FullGas following the MT-06 checklist, I want the prerequisite script paths to
   point to `tests/dcs/util/`, so that I can execute MT-06 without a missing-file
   error.

---

## Implementation Decisions

- `CONTEXT.md` — Testing terms section rewritten in place. Tier table mirrors
  `docs/integration-testing.md` (single source of truth for definitions; glossary
  carries canonical terms + banned aliases only, not how-to detail). L1–L6 level
  table added as a sub-section under Testing terms.
- ADR `0006` — records the `disabled` pattern: when a test cannot reach a verdict due
  to an external DCS blocker (pathfinding, missing mod), it is quarantined as
  `disabled` rather than deleted or left permanently red. Excluded from all default
  sweeps; reachable only via `--tier disabled`. Logic coverage lives in fast
  deterministic tests. The `mt08`/`mt14` pathfinding case and the
  `warehouse_cycle`/mod-absent case are cited as concrete examples.
- `mt08`/`mt14` fix — move the `Land` waypoint for groups `heliai_vehicle` (mt08) and
  `heliai_mt14` (mt14) away from the urban area that causes the pathfinding stall.
  Target: open, flat terrain within the pickup zone radius. Retag both scenarios from
  `disabled` to `auto-slow` once PASS is confirmed.
- MT-06 path fix — two occurrences in `tests/manual_test_sequences.md`:
  `recette/enable_debug.lua` → `tests/dcs/util/enable_debug.lua` and
  `recette/inject_red_fob.lua` → `tests/dcs/util/inject_red_fob.lua`.

---

## Testing Decisions

- **CONTEXT.md / ADR** — human review only; no automated gate.
- **mt08/mt14** — run `python tools/integration-runner/run_scenarios.py --tier auto-slow
  --poll-timeout 900` after waypoint fix and verify both scenarios emit PASS. Prior art:
  the other `auto-slow` scenarios (`scenario_ai_troops`, `mt09`–`mt13`) which already
  pass under the same command.
- **MT-06 paths** — manual spot-check: follow MT-06 step 1 with the corrected paths
  and confirm `enable_debug.lua` and `inject_red_fob.lua` are found.

---

## Out of Scope

- `warehouse_cycle` (`disabled`, blocked by missing `Farp_FG_Petit_Helipad` mod) —
  deferred to the `scene-as-plugins` grill (separate lot).
- MT-06 execution (L6 manual checklist) — addressed separately when FullGas is
  available for a full manual session.
- `CLEANUP-LEGACY-DCS-TESTS` (194 dead FullGas relics) — separate lot, sign-off
  already obtained.

---

## Further Notes

MT-01 (multi-group troop transport) was retested manually by FullGas on 2026-07-17
and confirmed PASS after the `refreshMenuSection` fix (`eeeb005`). MT-02 and MT-03
remain valid (no changes to `CTLD_vehicle.lua` since their 2026-05-12 validation).
MT-06 is the only L6 sequence never executed; it is unblocked by this lot's path fix.
