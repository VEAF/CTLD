# 03 — Troop/JTAC core cycle

Status: 📋 todo
Type: ia (live DCS, player drives — no F10 human step beyond setup)

## Scenarios

- `tests/dcs/pilotPassive/scenarioTroopsFullCycle_v2.lua` — needs a BLUE slot only; its stated
  "TRZ zone in mission" prerequisite is stale (step 2 builds its own `CTLDTroopGroup` directly,
  never looks up a real zone) — comment fixed. Used the `RUNNING: step=N` pattern but returned
  `STARTED` for incomplete steps (inconsistent with `run_ia_scenario.py`'s handling) — fixed to
  return `RUNNING` so the interactive runner re-injects correctly.
- `tests/dcs/pilotPassive/scenario_extract_menu.lua` — fully automatic (1 auto step), just
  needs CTLD initialized.
- `tests/dcs/pilotPassive/scenario_jtac_crate_pack.lua` — needs UH-1H BLUE on the ground + a
  RED target within JTAC auto-lase range (mission has `mt10_enemy_RED`/`Sol_g-2` — may need
  repositioning if too far).
- `tests/dcs/pilotPassive/scenario_feature_k_jtac_vehicle.lua` — same RED-target-in-range need.

Run all 4 via `tools/integration-runner/run_ia_scenario.py --scenario <name>` (built in ticket
02) — no AI needed for the loop.

## Acceptance criteria

- [ ] All 4 injected, verdicts read.
- [ ] Any FAIL root-caused (stale assertion vs current code, or real bug) and fixed.
