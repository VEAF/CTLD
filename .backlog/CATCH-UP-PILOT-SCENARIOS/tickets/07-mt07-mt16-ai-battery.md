# 07 — MT-07 to MT-16 full AI battery (heaviest)

Status: 🚧 in progress
Type: **mostly auto-check** — 9 of 10 retagged (AI-heli driven); only mt16 is genuine `ia (menu)`.

## Scenarios

Audited via subagent (read all 10 in full). MT-07..15 drive an **AI** helicopter + timers, no
player piloting or F10-wait — retagged `auto-check`. Required mission content (AI helis
`heliai_troops`..`heliai_mt14`, zones `AIZ_*`/`WPZ_mt10_B`) is all present in
`Test_CTLDNEXT_01.miz` (verified live via `exec_lua`). Runnable headless via `run_scenarios.py
--no-ai`.

- `scenario_mt07_ai_troops.lua` … `scenario_mt14_ai_aa_system.lua` — `auto-check`. Mix of
  STARTED and RUNNING-step-machine, all with reachable terminal PASS (no loop bug).
  - mt10 additionally needs the live RED group `mt10_enemy_RED` in LOS/range (present).
  - mt12/13/14 have a *negative* assumption: their AIZ pickup zone must contain **no** DCS
    vehicle group, else the physical-scan path pre-empts the virtual-stock path being tested.
- `scenario_mt15_request_vehicle_pure.lua` — `auto-check`. **Fixed**: hard-coded the slot name
  `Batumi_UH-1H_0-1` (only existed in one map) at 3 call sites → now resolves the first BLUE
  player dynamically via a local `getTransport()`.
- `scenario_mt16_countryside_farp.lua` — **stays `ia (menu)`**: genuinely interactive (land near
  crate, F10 → Unpack → Deploy, visual confirm) and never emits a terminal PASS (always
  `RUNNING: SETUP OK`). **Redundant** with `tests/dcs/noPlayer/scenario_farp_countryside_spawn.lua`
  (auto tier) which already covers the programmatic Countryside FARP deploy headlessly — this one
  only adds the manual F10-unpack UI path. Also **fixed** its dead `ctld_test.cleanup()/
  getTransport()` refs (→ local `getTransport()`) and its file/ID header mismatch (said
  `scenario_mt15_countryside_farp.lua`).

## Progress

- [ ] mt07 · mt08 · mt09 · mt10 · mt11 · mt12 · mt13 · mt14 · mt15 (auto-check)
- [ ] mt16 (`ia (menu)`, manual — optional given the auto duplicate)

## Acceptance criteria

- [ ] All auto-check MT scenarios injected, verdicts read.
- [ ] Any FAIL root-caused and fixed.
- [x] Tier audited before running (9/10 retagged `auto-check`; mt16 stays `ia (menu)`).
