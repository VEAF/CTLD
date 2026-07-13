# 02 — L5 F10 menu visual (foundational)

Status: ✅ done
Type: ia (live DCS, player F10 actions on demand)

## Scenarios

- `tests/dcs/pilotActive/scenario_crate_menu_sol_vol_visual.lua`
- `tests/dcs/pilotActive/scenario_troop_menu_sol_vol_visual.lua`

Confirms the Crate/Troop Commands F10 menu structure on ground / in flight / after landing.
Run first: later groups assume these base menus are correct.

## Progress (2026-07-13, live with David, UH-1H)

- **Crate menu (CMFV-VIS): PASS 5/5.** Fixed a real instruction bug along the way: step C's
  checklist listed "Pack Equipt VISIBLE" as expected *after* step B already packed the vehicle
  — contradictory (once packed, nothing's left to pack, so it correctly disappears). Corrected
  the wording in the scenario file.
- **Troop menu (TMFV): PASS 5/5** (re-confirmed live by David alone via the new
  `run_ia_scenario.py`, no AI in the loop). `CTLDTroopManager:refreshMenuSection` always
  computed `inAir` live via `_isInAir(unit)`, unlike `CTLDCrateManager:refreshCrateFlightSection`
  which accepts an `overrideInAir` param so `onTakeoff`/`onLand` can force the correct state
  immediately (`S_EVENT_LAND` fires before `inAir()`'s speed/AGL threshold settles). Fixed:
  `refreshMenuSection` now accepts the same `overrideInAir` param, wired through
  `onTakeoff`/`onLand`/the flight-state poller (`CTLD_player.lua`) and the scenario's own S3/S5
  checks. 3 new busted tests in `tests/ci/unit/menu_gating_spec.lua`
  (`refreshMenuSection — overrideInAir forces state`).
- Built `tools/integration-runner/run_ia_scenario.py`: an interactive terminal runner for
  `ia`-tier `pilotActive`/`pilotPassive` scenarios that self-verify (most of them) — injects,
  mirrors in-game instructions to the terminal, polls to a verdict, no AI needed for the
  loop. Re-running the same command resets stuck state (crash recovery) instead of requiring
  a DCS restart. Also bumped `HUMAN_TIMEOUT_S` 300→3600s in both scenarios + the pilotActive
  template (was a real source of stress/false FAILs, not a useful safety net at 5 min). Use
  this for tickets 03–08 instead of the manual `exec_lua` loop.

## Acceptance criteria

- [x] Crate menu (CMFV-VIS): injected, all steps PASS (ground/flight/ground-restored).
- [x] Troop menu (TMFV): re-run live with the `overrideInAir` fix, confirm F-185 PASS.
- [x] Any FAIL root-caused and fixed.
