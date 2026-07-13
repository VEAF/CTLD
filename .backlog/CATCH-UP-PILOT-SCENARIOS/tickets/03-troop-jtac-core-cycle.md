# 03 — Troop/JTAC core cycle

Status: 🚧 in progress
Type: **auto-check** (all 4 retagged — see below; none actually need a pilot)

## Scenarios

All 4 were tagged `ia` by the `pilotPassive/` folder-blanket default, but none of them check
real flight state or wait on F10 — they only need a BLUE slot occupied (position/groupId), a
structural precondition, not piloting/judgment. Retagged `auto-check`; runnable via
`run_scenarios.py --no-ai` going forward, not just the interactive runner.

- `tests/dcs/pilotPassive/scenarioTroopsFullCycle_v2.lua` — its stated "TRZ zone in mission"
  prerequisite was stale (step 2 builds its own `CTLDTroopGroup` directly, never looks up a
  real zone) — verified live no such zone exists in `Test_CTLDNEXT_01.miz`, comment fixed. Used
  the `RUNNING: step=N` pattern but returned `STARTED` for incomplete steps (inconsistent with
  the return contract) — fixed to return `RUNNING`.
- `tests/dcs/pilotPassive/scenario_extract_menu.lua` — fully automatic (1 auto step, `STARTED`
  pattern), just needs CTLD initialized. Has vestigial "Recette CTLD" F10 menu scaffolding
  that's never actually wired to a command — dead code, left as-is (out of scope here).
- `tests/dcs/pilotPassive/scenario_jtac_crate_pack.lua` — spawns its own RED target 800m away
  and its own JTAC Hummer 80m away; never reads player position again after the initial spawn.
- `tests/dcs/pilotPassive/scenario_feature_k_jtac_vehicle.lua` — same self-contained spawn
  pattern; its header claimed "player must be on the ground" and "targets RED must be present"
  but neither is checked in code — comment corrected.

Also fixed `run_scenarios.py`/`run_ia_scenario.py` to re-inject the full source on a `RUNNING`
verdict (previously only `run_ia_scenario.py` did; `run_scenarios.py` failed it outright) — see
`tools/integration-runner/README.md`.

Run via `tools/integration-runner/run_ia_scenario.py --scenario <name>` (still works fine post
retag) or `run_scenarios.py --no-ai --scenario <name>` (now that they're `auto-check`).

## Progress

- [x] `scenario_jtac_crate_pack.lua` — PASS (confirmed live, David).
- [ ] `scenarioTroopsFullCycle_v2.lua`
- [ ] `scenario_extract_menu.lua`
- [ ] `scenario_feature_k_jtac_vehicle.lua`

## Acceptance criteria

- [ ] All 4 injected, verdicts read.
- [x] Any FAIL root-caused so far (stale assertion vs current code, or real bug) and fixed.
- [x] Tier mistagging found and corrected (all 4 → `auto-check`).
