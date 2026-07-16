# 04 — Multi-group / weight / warehouse

Status: ✅ done (4/5 PASS; `scenario_warehouse_cycle` deferred — blocked on a missing DCS mod)
Type: mixed — 4 of 5 retagged `auto-check` (audited before running, per the ticket 03 lesson);
only `scenario_warehouse_cycle.lua` is genuine `ia (fly)`

## Scenarios

Audited each one's actual code before asking for a pilot (per the ticket 03 mistagging lesson)
— 4 of 5 need no piloting at all:

- `tests/dcs/pilotPassive/scenario_multigroup_transport.lua` → `auto-check`. Fully
  self-contained: mocks `ctld.MenuManager`/`Unit.getByName` with a fake unit, doesn't touch a
  real player at all.
- `tests/dcs/pilotPassive/scenario_weight_aggregation.lua` → `auto-check`. "1 step auto" per
  its own header; just needs a BLUE slot for position.
- `tests/dcs/pilotPassive/scenario_unpack_jtac_drone.lua` → **`auto-slow`** (later reclassified
  from `auto-check`: its ~13 min of internal timers, up to T+795s, is too slow for the fast
  `--no-ai` sweep — it stalled a live sweep and looked hung. Run with `--tier auto-slow
  --poll-timeout 900`.) Resolves the helicopter via hardcoded `Unit.getByName("uh1-1")`, no
  piloting. **Found + fixed a scenario/mission conflict**
  (David chose option 1): V3/V4 asserted the drone had *no target* after destroying the
  scenario's own spawned RED unit, but the test mission has `Sol_g-2` at 4135m — inside the
  drone's `JTAC_maxDistance` (~10km) and closer than the scenario's own target (~5442m) — so
  the drone correctly re-tasks to it. That's correct CTLD behaviour, not a failure. Rewrote
  V3/V4 to assert the drone is no longer lasing the *specific destroyed unit*
  (`JTAC_TEST_RED_TARGET-1`); re-tasking to any other in-range enemy now PASSes. Known
  limitation: with `Sol_g-2` closer, the drone may lase it the whole time and never our target,
  so the "returns to initial orbit" aspect isn't validated in this mission — the essential
  "drops a destroyed target" regression is still covered.
- `tests/dcs/pilotPassive/scenario_farp_repack.lua` → `auto-check`. **Found + fixed two bugs.**
  (1) Referenced the dead FullGas `ctld_test` framework (`ctld_test.getTransport()`/`.cleanup()`
  — nil, same cause as the 194 relics) — replaced with a local `getTransport()` (first BLUE
  player). (2) **No terminal verdict**: the step machine ran 1→2→99→1→2→99… forever under the
  automated re-inject loop — step 99 did the summary, reset `_G[STEP_VAR]=1`, but the return
  logic always emitted `RUNNING` (never `PASS`). Added a `_done` terminal flag so step 99 emits
  `PASS`. Also the earlier premature-reinjection fix (step 2 retries up to 20× while
  `playSceneAtPos` takes ~15-20s to register the scene, instead of a false immediate `fail()`).
- `tests/dcs/pilotActive/scenario_warehouse_cycle.lua` → stays `ia (fly)`. Genuine piloting:
  crate load, takeoff, FARP deploy, reposition >400m, land — real `inAir()`/`setHumanStep` use.

Run the 4 `auto-check` ones via `run_ia_scenario.py` (still works) or `run_scenarios.py
--no-ai` (`--poll-timeout 900` or higher for `scenario_unpack_jtac_drone.lua`). Only
`scenario_warehouse_cycle.lua` needs you to actually fly.

## Progress

- [x] `scenario_multigroup_transport.lua` — PASS 15/15 (confirmed live, David).
- [x] `scenario_weight_aggregation.lua` — PASS 4/4 (confirmed live, David).
- [x] `scenario_farp_repack.lua` — PASS (after the `ctld_test` + terminal-verdict fixes).
- [x] `scenario_unpack_jtac_drone.lua` — PASS 5/5 (option-1 V3/V4 fix confirmed: drone drops the
  destroyed target and re-tasks to the mission's `Sol_g-2`, stays alive). Scenario finalized
  DCS-side on its own after a transient HTTP 504 killed the Python client near T+500 — timers
  are `timer.scheduleFunction` (DCS-side), so the run completed regardless; verdict read back
  via `exec_lua`.
- [~] `scenario_warehouse_cycle.lua` — **deferred, blocked on a missing DCS mod.** Requires
  `Farp_FG_Petit_Helipad` (FullGas) for its S3/S4/S8 warehouse-snapshot checks
  (`Airbase.getByName` + `getWarehouse()` on the deployed FARP). David's install doesn't have
  the mod, so the scenario would FAIL at W.3.4 after ~4 min of flight. Not run. Stays `ia (fly)`;
  revisit when the mod is available. Not a code/scenario defect.

## Runner robustness fixes surfaced by this ticket

The drone run (13 min) exposed three `run_ia_scenario.py` gaps, all fixed:
- **No progress on STARTED scenarios**: `_SCN_JTACDRONE_RESULT` stays `STARTED` until T+795, so
  the CLI showed nothing for 13 min. The drone's `instruct()` didn't expose `_SCN_<ID>_INSTR`
  at all (only printed to the DCS screen) — fixed; and each VERIFY now publishes its result into
  the instruction global so it surfaces live. Same missing-`_INSTR` gap fixed in `scenario_p2/
  p3/p4` (ticket 05) proactively.
- **Heartbeat echoed the frozen RESULT**: `still running -- last: [STARTED]` was useless; now it
  echoes the last real progress line (the latest VERIFY).
- **Transient 504 aborted the whole run**: a single `HTTP 504` (DCS Lua thread briefly busy)
  returned exit 1 near the end. Now tolerates up to `--max-errors` (default 5) consecutive
  transient poll errors, retrying instead of dying.

## Acceptance criteria

- [x] All 5 auto-check injected, verdicts read (warehouse `ia (fly)` still pending flight).
- [x] Any FAIL root-caused and fixed.
- [x] Tier audited before running (4 of 5 retagged `auto-check`).
