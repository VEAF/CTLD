# 07 — MT-07 to MT-16 full AI battery (heaviest)

Status: 🚧 in progress
Type: **mostly `auto-slow`** — mt07..14 need real AI-heli flight (no pilot, but minutes each →
`auto-slow`, excluded from `--no-ai`); mt15 is fast `auto-check`; mt16 is genuine `ia (menu)`.

## Scenarios

Audited via subagent (read all 10 in full). MT-07..15 drive an **AI** helicopter + timers, no
player piloting or F10-wait. Required mission content (AI helis `heliai_troops`..`heliai_mt14`,
zones `AIZ_*`/`WPZ_mt10_B`) is all present in `Test_CTLDNEXT_01.miz` (verified live via `exec_lua`).

- `scenario_mt07_ai_troops.lua` … `scenario_mt14_ai_aa_system.lua` — **`auto-slow`** (8 files).
  Discovered live on MT-14: they wait on the `heliai_*` AI heli physically flying a multi-WP
  route to its pickup/dropoff zone (minutes of real flight), so the fast `--no-ai` 2s-reinject
  loop spams and stalls. Retagged `auto-slow` — run with `--tier auto-slow --poll-timeout 900`,
  player parked in a slot. Their core logic is already covered fast/headless by the `noPlayer`
  `aiTransport_featureT/U` tests (F-176..182, green in the first sweep); these are the heavier
  end-to-end complement. Mix of STARTED and RUNNING-step-machine, all with a reachable terminal
  PASS (no loop bug).
  - mt10 additionally needs the live RED group `mt10_enemy_RED` in LOS/range (present).
  - mt12/13/14 have a *negative* assumption: their AIZ pickup zone must contain **no** DCS
    vehicle group, else the physical-scan path pre-empts the virtual-stock path being tested.
- `scenario_mt15_request_vehicle_pure.lua` — `auto-check` (fast: no AI flight, pure API calls).
  **Fixed**: hard-coded the slot name `Batumi_UH-1H_0-1` (only existed in one map) at 3 call
  sites → now resolves the first BLUE player dynamically via a local `getTransport()`.
- `scenario_mt16_countryside_farp.lua` — **stays `ia (menu)`**: genuinely interactive (land near
  crate, F10 → Unpack → Deploy, visual confirm) and never emits a terminal PASS (always
  `RUNNING: SETUP OK`). **Redundant** with `tests/dcs/noPlayer/scenario_farp_countryside_spawn.lua`
  (auto tier) which already covers the programmatic Countryside FARP deploy headlessly — this one
  only adds the manual F10-unpack UI path. Also **fixed** its dead `ctld_test.cleanup()/
  getTransport()` refs (→ local `getTransport()`) and its file/ID header mismatch (said
  `scenario_mt15_countryside_farp.lua`).

## Progress

- [ ] mt07 · mt08 · mt09 · mt10 · mt11 · mt12 · mt13 · mt14 (`auto-slow`, via `--tier auto-slow`)
- [ ] mt15 (`auto-check`, via `--no-ai`)
- [ ] mt16 (`ia (menu)`, manual — optional given the auto duplicate)

## Acceptance criteria

- [ ] mt15 injected via `--no-ai`, verdict read.
- [ ] mt07..14 run via `--tier auto-slow` (or deferred as covered by F-176..182), verdicts read.
- [ ] Any FAIL root-caused and fixed.
- [x] Tier audited (8 `auto-slow`, 1 `auto-check`, mt16 `ia (menu)`).
