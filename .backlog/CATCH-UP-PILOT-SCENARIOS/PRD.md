# Lot CATCH-UP-PILOT-SCENARIOS — run the never-executed `ia`-tier scenarios

Status: 🚧 in progress
Branch: test/catch-up-pilot-scenarios → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`). Sibling to
`FIX-LIVE-DCS-FAILURES` (closed) and `CLEANUP-LEGACY-DCS-TESTS` (planned).

## Problem Statement

Since the migration to VEAF-dcs-bridge (`DCS-BRIDGE-MCP`, `INTEGRATION-TEST-TAGS`), every live-DCS
validation actually run has stayed in the `auto`/`auto-check` tier (headless, no player needed).
The 34 `ia`-tier scenarios (`pilotPassive`/`pilotActive`, needing a live player-controlled unit —
dcs-bridge has no flight-control API) and the 4 `L6` manual sequences
(`tests/manual_test_sequences.md`) have **never been executed** — only one ad-hoc, unscripted
check (Feature Q whole-vehicle spawn) has ever put a human pilot in the loop, and that wasn't even
one of these scenario files.

This lot runs the full backlog once, groups it into pilot-sized sessions, and fixes whatever it
finds (stale assertions vs current code, or real regressions).

## Scope

- 34 `ia`-tier scenario files: 29 `pilotPassive/`, 3 `pilotActive/` (`scenario_warehouse_cycle.lua`
  physically lives in `pilotActive/` despite being `pilotPassive`-shaped — not touched here, out of
  scope), 2 `noPlayer/` outliers (`F-046`, `F-047`, which ask for a one-off visual F10 check).
- 4 `L6` manual sequences: MT-01, MT-02, MT-03, MT-06 (`tests/manual_test_sequences.md`).
- Each ticket is one pilot session: David runs `tools/integration-runner/run_ia_scenario.py
  --scenario <name>` from his own terminal (built during ticket 02 — injects, mirrors in-game
  instructions, polls to a verdict, no AI needed for the loop) and flies/does F10 actions
  himself, or follows the checklist for L6. Falls back to the `integration-testing` skill's
  manual `exec_lua` loop only for genuine visual-judgment scenarios or scenario debugging.

## Tickets — recommended order (fast/foundational first, heaviest batteries last)

| # | Group | Scenarios | Est. pilot time |
|---|-------|-----------|------------------|
| 01 | `noPlayer` `ia` outliers — quick F10 visual checks | F-046, F-047 | ~5 min |
| 02 | L5 F10 menu visual — foundational, other groups assume these menus are correct | `scenario_crate_menu_sol_vol_visual`, `scenario_troop_menu_sol_vol_visual` | ~15 min |
| 03 | Troop/JTAC core cycle — **all 4 turned out mistagged**, retagged `auto-check` (see ticket 03) | `scenarioTroopsFullCycle_v2`, `scenario_extract_menu`, `scenario_jtac_crate_pack`, `scenario_feature_k_jtac_vehicle` | ~20 min |
| 04 | Multi-group / weight / warehouse | `scenario_multigroup_transport`, `scenario_weight_aggregation`, `scenario_unpack_jtac_drone`, `scenario_warehouse_cycle`, `scenario_farp_repack` | ~25 min |
| 05 | FOB / parachute / FARP scenes / RECON | `scenario_fob_scene`, `scenario_p2_fob_parachute`, `scenario_p3_csfarp_parachute`, `scenario_p4_metal_farp`, `scenario_feature_f_recon_farp` | ~25 min |
| 06 | AI transport / AI zones | `scenario_ai_attack_enemy`, `scenario_ai_goto_wpz`, `scenario_ai_transport_visual`, `scenario_ai_troops`, `scenario_feature_i_attack_enemy`, `scenario_feature_i_goto_wpz` | ~25 min |
| 07 | MT-07 to MT-16 full AI battery (heaviest, 10 scripted scenarios) | `scenario_mt07_ai_troops` … `scenario_mt16_countryside_farp` | ~45 min |
| 08 | L6 manual sequences (checklist, no script) | MT-01, MT-02, MT-03, MT-06 | ~60 min (15 min/MT) |

Total estimate: ~3.5h of live-pilot time, splittable across sessions (one ticket = one sitting,
no need to do them back to back).

## Non-goals

- `scenario_ai_transport.lua` (`noPlayer`, `auto` tier) — already covered, not `ia`.
- Fixing `CLEANUP-LEGACY-DCS-TESTS` relics — separate lot.
- Rewriting a scenario's tier or folder placement unless a run reveals it's wrong.

## Tier-audit finding (tickets 03–07) — COMPLETE

The `pilotActive/`/`pilotPassive/` → always `ia` default (from `INTEGRATION-TEST-TAGS`) was a
folder-blanket rule, not a per-file semantic check — and it was **wrong for all but 3 of the 34**.
A full static audit (tickets 03–05 read inline; tickets 06–07's 16 scenarios via a subagent that
read each in full) found that the vast majority never gate on the player's `inAir` or wait on an
F10 click — they drive AI helicopters + timers, or self-verify, needing only a BLUE slot for
position/country. **Final tally of the original 34 `ia`:**

- **22 retagged `auto-check`** (no human, fast headless via `run_scenarios.py --no-ai` — player
  just occupies a slot, doesn't fly).
- **9 retagged `auto-slow`** (no human either, but need minutes of real AI-heli flight:
  `scenario_ai_troops` + `mt07..mt14`) — excluded from the fast `--no-ai` sweep, run explicitly
  with `--tier auto-slow --poll-timeout 900`. Core logic already covered fast/headless by the
  `noPlayer` `aiTransport_featureT/U` tests (F-176..182), so this heavy end-to-end tier is
  optional / low-priority.
- **3 genuine `ia`:**
  - `scenario_crate_menu_sol_vol_visual.lua` — `ia (fly)` (sol/vol/sol menu, PASS).
  - `scenario_troop_menu_sol_vol_visual.lua` — `ia (fly)` (sol/vol/sol menu, PASS).
  - `scenario_warehouse_cycle.lua` — `ia (fly)`, **deferred** (needs the `Farp_FG_Petit_Helipad`
    mod, absent).
  - `scenario_mt16_countryside_farp.lua` — `ia (menu)`, and **redundant** with the auto-tier
    `scenario_farp_countryside_spawn.lua`; never emits a terminal PASS. Optional manual UI check.

So after the catch-up, **the real pilot burden is 2 short menu-visual flights** (both already PASS),
not 34 scenarios. The rest is headless. See `tools/integration-runner/README.md`'s "What `ia`
actually asks of you" for the `(menu)`/`(fly)` qualifier convention.
