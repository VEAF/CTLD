# CATCH-UP-PILOT-SCENARIOS

**Status:** ✅ merged (PR #24). Compacted from `CATCH-UP-PILOT-SCENARIOS/` on 2026-08-01; the ticket files live on in git history.

Ran the never-executed `pilotPassive`/`pilotActive` scenarios. Audit found the "34 `ia`" was almost all mistagged: 66/66 now pass in a headless sweep (`--no-ai --reset-before-each`), real pilot burden ≈ 2 short menu flights (both PASS). Fixed a pile of test-harness defects + cross-scenario contamination (soft reset `_reset_state.lua`), + one product fix (`refreshMenuSection` flight-state override). Optional remainders: `auto-slow` AI battery (covered by F-176..182), mt16/warehouse, L6 manual (ticket 08).

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-noplayer-ia-outliers` | ✅ done | 01 — noPlayer `ia` outliers (quick F10 visual checks) |
| `02-l5-menu-visual` | ✅ done | 02 — L5 F10 menu visual (foundational) |
| `03-troop-jtac-core-cycle` | ✅ done | 03 — Troop/JTAC core cycle |
| `04-multigroup-weight-warehouse` | ✅ done (4/5 PASS; `scenario_warehouse_cycle` deferred — blocked on a missing DCS mod) | 04 — Multi-group / weight / warehouse |
| `05-fob-parachute-farp-recon` | ✅ done | 05 — FOB / parachute / FARP scenes / RECON |
| `06-ai-transport-zones` | ✅ done | 06 — AI transport / AI zones |
| `07-mt07-mt16-ai-battery` | ✅ done (mt15 PASS; AI battery + mt16 deferred as optional) | 07 — MT-07 to MT-16 full AI battery (heaviest) |
| `08-l6-manual-sequences` | 📋 todo | 08 — L6 manual sequences (checklist, no script) |

## PRD

## Lot CATCH-UP-PILOT-SCENARIOS — run the never-executed `ia`-tier scenarios

Status: ✅ done — 66/66 headless sweep green; only optional/manual remainders (see below)
Branch: test/catch-up-pilot-scenarios → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`). Sibling to
`FIX-LIVE-DCS-FAILURES` (closed) and `CLEANUP-LEGACY-DCS-TESTS` (planned).

### Problem Statement

Since the migration to VEAF-dcs-bridge (`DCS-BRIDGE-MCP`, `INTEGRATION-TEST-TAGS`), every live-DCS
validation actually run has stayed in the `auto`/`auto-check` tier (headless, no player needed).
The 34 `ia`-tier scenarios (`pilotPassive`/`pilotActive`, needing a live player-controlled unit —
dcs-bridge has no flight-control API) and the 4 `L6` manual sequences
(`tests/manual_test_sequences.md`) have **never been executed** — only one ad-hoc, unscripted
check (Feature Q whole-vehicle spawn) has ever put a human pilot in the loop, and that wasn't even
one of these scenario files.

This lot runs the full backlog once, groups it into pilot-sized sessions, and fixes whatever it
finds (stale assertions vs current code, or real regressions).

### Scope

- 34 `ia`-tier scenario files: 29 `pilotPassive/`, 3 `pilotActive/` (`scenario_warehouse_cycle.lua`
  physically lives in `pilotActive/` despite being `pilotPassive`-shaped — not touched here, out of
  scope), 2 `noPlayer/` outliers (`F-046`, `F-047`, which ask for a one-off visual F10 check).
- 4 `L6` manual sequences: MT-01, MT-02, MT-03, MT-06 (`tests/manual_test_sequences.md`).
- Each ticket is one pilot session: David runs `tools/integration-runner/run_ia_scenario.py
  --scenario <name>` from his own terminal (built during ticket 02 — injects, mirrors in-game
  instructions, polls to a verdict, no AI needed for the loop) and flies/does F10 actions
  himself, or follows the checklist for L6. Falls back to the `integration-testing` skill's
  manual `exec_lua` loop only for genuine visual-judgment scenarios or scenario debugging.

### Tickets — recommended order (fast/foundational first, heaviest batteries last)

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

### Outcome (2026-07-13)

The initial premise — "34 `ia` scenarios each needing a human pilot, ~3.5h" — was wrong. A full
audit + live validation showed almost all of them run headless:

- **66/66 green** in one headless sweep: `python tools/integration-runner/run_scenarios.py
  --no-ai --reset-before-each` (all `auto`/`auto-check`, noPlayer + pilotPassive), player just
  parked in a slot.
- **Real pilot burden ≈ 2 short flights** — the two menu-visual `ia (fly)` scenarios
  (`crate_menu`/`troop_menu_sol_vol_visual`), both already PASS.
- The catch-up surfaced + fixed a pile of **test-harness defects** (not CTLD product bugs):
  wholesale `ia`→`auto-check`/`auto-slow` retag, dead `ctld_test` refs, missing terminal
  verdicts (infinite loops), premature re-injection (retry guards), a mission-slot hard-code,
  compound-ID `_SCN_` var matching, and — the big one — cross-scenario contamination of CTLD's
  shared singletons, fixed with a per-scenario soft reset (`tests/dcs/_reset_state.lua`,
  `--reset-before-each`) covering player/menu + JTAC state. Also a real product fix:
  `CTLDTroopManager:refreshMenuSection` flight-state override.

**Optional / deferred remainders (not blocking):**
- `auto-slow` AI-heli battery (`scenario_ai_troops` + `mt07..mt14`) — minutes of real AI flight
  each; logic already covered fast by `noPlayer` F-176..182. Run on demand via `--tier auto-slow`.
- `scenario_mt16_countryside_farp` (`ia (menu)`) — manual, redundant with the auto
  `scenario_farp_countryside_spawn.lua`.
- `scenario_warehouse_cycle` (`ia (fly)`) — blocked on the missing `Farp_FG_Petit_Helipad` mod.
- Ticket 08 — the 4 `L6` manual checklist sequences (MT-01/02/03/06): genuine manual pilot work,
  left for a dedicated session (not scripted, no runner involvement).

### Non-goals

- `scenario_ai_transport.lua` (`noPlayer`, `auto` tier) — already covered, not `ia`.
- Fixing `CLEANUP-LEGACY-DCS-TESTS` relics — separate lot.
- Rewriting a scenario's tier or folder placement unless a run reveals it's wrong.

### Tier-audit finding (tickets 03–07) — COMPLETE

The `pilotActive/`/`pilotPassive/` → always `ia` default (from `INTEGRATION-TEST-TAGS`) was a
folder-blanket rule, not a per-file semantic check — and it was **wrong for all but 3 of the 34**.
A full static audit (tickets 03–05 read inline; tickets 06–07's 16 scenarios via a subagent that
read each in full) found that the vast majority never gate on the player's `inAir` or wait on an
F10 click — they drive AI helicopters + timers, or self-verify, needing only a BLUE slot for
position/country. **Final tally of the original 34 `ia`:**

- **`auto-check`** (no human, fast headless via `run_scenarios.py --no-ai` — player just occupies
  a slot, doesn't fly).
- **`auto-slow`** (no human either, but minutes to resolve — excluded from the fast `--no-ai`
  sweep, run with `--tier auto-slow --poll-timeout 900`): the AI-heli-flight battery
  (`scenario_ai_troops` + `mt07..mt14`) **and** the JTAC drone (`scenario_unpack_jtac_drone`,
  ~13 min of internal timers). Core logic of the AI battery already covered fast/headless by the
  `noPlayer` `aiTransport_featureT/U` tests (F-176..182), so that end-to-end tier is optional.

Current tier split across `pilotPassive/`+`pilotActive/`: **18 `auto-check`, 10 `auto-slow`,
4 `ia`**.
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
