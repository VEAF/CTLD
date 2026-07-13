# 05 — FOB / parachute / FARP scenes / RECON

Status: 🚧 in progress
Type: **auto-check** — all 5 audited (per the ticket 03/04 lesson) and retagged; none pilot.

## Scenarios

All 5 were tagged `ia` by the `pilotPassive/` folder default but none check flight state or wait
on F10 — each spawns its own crates/scenes relative to the player position and verifies via
internal timers, needing only a BLUE slot occupied. Retagged `auto-check`.

- `scenario_fob_scene.lua` — RUNNING step machine. **Same terminal-verdict bug as farp_repack**
  (step 99 reset `_G[STEP_VAR]=1` but returned `RUNNING`, looping 1→2→99→1 forever). Fixed with
  a `_done` flag → `PASS`.
- `scenario_p2_fob_parachute.lua` — STARTED, self-contained; missing-`_INSTR` fixed in ticket 04.
- `scenario_p3_csfarp_parachute.lua` — STARTED, self-contained; missing-`_INSTR` fixed in ticket 04.
- `scenario_p4_metal_farp.lua` — STARTED; already handles the `Farp_FG_Petit_Helipad` mod being
  absent gracefully (skips the warehouse checks, PASSes) — so unlike `scenario_warehouse_cycle`
  it runs fine without the mod. Missing-`_INSTR` fixed in ticket 04.
- `scenario_feature_f_recon_farp.lua` — RUNNING step machine; already emits a terminal `PASS`
  (no loop bug).

Run via `run_ia_scenario.py --scenario <name>` or `run_scenarios.py --no-ai`.

## Progress

- [ ] `scenario_fob_scene.lua`
- [ ] `scenario_p2_fob_parachute.lua`
- [ ] `scenario_p3_csfarp_parachute.lua`
- [ ] `scenario_p4_metal_farp.lua`
- [ ] `scenario_feature_f_recon_farp.lua`

## Acceptance criteria

- [ ] All 5 injected, verdicts read.
- [ ] Any FAIL root-caused and fixed.
- [x] Tier audited before running (all 5 retagged `auto-check`).
