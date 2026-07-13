# 06 — AI transport / AI zones

Status: ✅ done
Type: **mixed auto-check / auto-slow** — none need a pilot; `scenario_ai_troops` needs real AI
flight so it's `auto-slow` (see ticket 07's note), the other 5 are fast `auto-check`.

## Scenarios

Audited via subagent (read all 6 in full). None gate on the player's `inAir` or wait on an F10
click — they drive an **AI** helicopter + timers; the player slot is used only for
position/country. The `MENU_NAME = "Recette CTLD"` submenu in the async ones is vestigial (built
but never awaited). All retagged `auto-check`; runnable headless via `run_scenarios.py --no-ai`.

- `scenario_ai_attack_enemy.lua` — auto/STARTED, spawns own RED/BLUE.
- `scenario_ai_goto_wpz.lua` — auto/STARTED, injects own mock WPZ.
- `scenario_ai_transport_visual.lua` — auto/STARTED. **Needs an active AIZ pickup zone with troop
  stock** — present in `Test_CTLDNEXT_01.miz` (AIZ_base_B_P_5 etc., verified live).
- `scenario_ai_troops.lua` — **`auto-slow`** (not fast auto-check): waits on the AI heli
  `heliai_troops` physically flying its route (`waitFor hasTroops`), minutes of real flight.
  Needs zones AIZ_base_B_P_5 / AIZ_front_B_D — present in the mission (verified live). Run via
  `--tier auto-slow`, not `--no-ai`.
- `scenario_feature_i_attack_enemy.lua` — RUNNING step machine, terminal PASS at step≥99. Spawns
  own enemies.
- `scenario_feature_i_goto_wpz.lua` — RUNNING step machine, terminal PASS. Injects own mock WPZ.

Mission content required by these IS present in `Test_CTLDNEXT_01.miz` (AI helis + AIZ/WPZ zones
confirmed via `exec_lua`). Note the audit flagged `scenario_ai_attack_enemy`/`scenario_ai_goto_wpz`
as duplicate `@scenario` IDs of `scenario_feature_i_attack_enemy`/`scenario_feature_i_goto_wpz`
(async vs step-machine versions of FI-ATK/FI-WPZ) — redundant coverage, not fixed here.

## Progress

The 5 `auto-check` all PASS in the full headless sweep (66/66, `--no-ai --reset-before-each`,
2026-07-13). Along the way: `ai_attack_enemy`/`ai_goto_wpz` needed a runner regex fix (compound
`_SCN_FI_ATK_RESULT` IDs), and `feature_i_attack_enemy` needed a step-2 retry (AI takes ~8s to
move). `scenario_ai_troops` is `auto-slow` (real AI flight) — covered fast by F-176..182, run on
demand via `--tier auto-slow`.

- [x] `scenario_ai_attack_enemy.lua`
- [x] `scenario_ai_goto_wpz.lua`
- [x] `scenario_ai_transport_visual.lua`
- [x] `scenario_feature_i_attack_enemy.lua`
- [x] `scenario_feature_i_goto_wpz.lua`
- [~] `scenario_ai_troops.lua` — `auto-slow`, optional (covered by F-176..182)

## Acceptance criteria

- [x] The 5 `auto-check` injected via `--no-ai`, verdicts read — all PASS.
- [~] `scenario_ai_troops` (`auto-slow`) — optional, covered by F-176..182.
- [x] Any FAIL root-caused and fixed.
- [x] Tier audited before running (5 `auto-check`, 1 `auto-slow`; none need a pilot).
