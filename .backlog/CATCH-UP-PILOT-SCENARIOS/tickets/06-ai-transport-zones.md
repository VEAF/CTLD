# 06 — AI transport / AI zones

Status: 🚧 in progress
Type: **auto-check** — all 6 retagged (full static audit, no per-scenario surprises). No piloting.

## Scenarios

Audited via subagent (read all 6 in full). None gate on the player's `inAir` or wait on an F10
click — they drive an **AI** helicopter + timers; the player slot is used only for
position/country. The `MENU_NAME = "Recette CTLD"` submenu in the async ones is vestigial (built
but never awaited). All retagged `auto-check`; runnable headless via `run_scenarios.py --no-ai`.

- `scenario_ai_attack_enemy.lua` — auto/STARTED, spawns own RED/BLUE.
- `scenario_ai_goto_wpz.lua` — auto/STARTED, injects own mock WPZ.
- `scenario_ai_transport_visual.lua` — auto/STARTED. **Needs an active AIZ pickup zone with troop
  stock** — present in `Test_CTLDNEXT_01.miz` (AIZ_base_B_P_5 etc., verified live).
- `scenario_ai_troops.lua` — auto/STARTED. Needs AI heli `heliai_troops` + zones AIZ_base_B_P_5 /
  AIZ_front_B_D — all present in the mission (verified live).
- `scenario_feature_i_attack_enemy.lua` — RUNNING step machine, terminal PASS at step≥99. Spawns
  own enemies.
- `scenario_feature_i_goto_wpz.lua` — RUNNING step machine, terminal PASS. Injects own mock WPZ.

Mission content required by these IS present in `Test_CTLDNEXT_01.miz` (AI helis + AIZ/WPZ zones
confirmed via `exec_lua`). Note the audit flagged `scenario_ai_attack_enemy`/`scenario_ai_goto_wpz`
as duplicate `@scenario` IDs of `scenario_feature_i_attack_enemy`/`scenario_feature_i_goto_wpz`
(async vs step-machine versions of FI-ATK/FI-WPZ) — redundant coverage, not fixed here.

## Progress

- [ ] `scenario_ai_attack_enemy.lua`
- [ ] `scenario_ai_goto_wpz.lua`
- [ ] `scenario_ai_transport_visual.lua`
- [ ] `scenario_ai_troops.lua`
- [ ] `scenario_feature_i_attack_enemy.lua`
- [ ] `scenario_feature_i_goto_wpz.lua`

## Acceptance criteria

- [ ] All 6 injected, verdicts read.
- [ ] Any FAIL root-caused and fixed.
- [x] Tier audited before running (all 6 retagged `auto-check`).
