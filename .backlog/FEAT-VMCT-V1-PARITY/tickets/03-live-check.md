# 03 — Live check in DCS

**Status:** ✅ done (2026-11-23) · **Type:** AFK, needs DCS running (Zip launches DCS; the session launches dcs-serve)

## Parent
[PRD](../PRD.md). Blocked by 01, 02.

## What to build
A `noPlayer` live scenario over the DCS bridge on `Test_CTLDNEXT_01.miz`: an unpacked vehicle crate and an assembled AA system are created drivable by default (read back what DCS holds if the API exposes it; otherwise record what was passed to `dynAdd` / `coalition.addGroup` and say so), and the payloads of `OnCrateUnpacked` and `OnAASystemDeployed` carry `groupName` / `crateNames` matching real objects. Everything cleaned up afterwards.

## Acceptance criteria
- [ ] Each check PASS or FAIL with the DCS log lines that prove it.
- [ ] Nothing left in the mission afterwards.
- [ ] Result recorded in this ticket and the lot's index line.

## Result (2026-11-23)

Scenario `tests/dcs/noPlayer/scenario_vmct_v1_parity.lua` (tier `auto-check`), run with `tools/integration-runner/run_scenarios.py` on `Test_CTLDNEXT_01.miz`, on a `CTLD.lua` built from `develop` + this lot + `FIX-VMCT-REVIEW-FINDINGS` (one DCS launch for both live checks): **`[VPY] PASS 15/15`** in 9.2 s, every check logged in `dcs.log`.

- The setting is `true` by default (0.1).
- Vehicle crates unpacked by the parachute auto-unpack: one `OnCrateUnpacked` per crate, all naming the same group, which exists in DCS; its unit was handed to `coalition.addGroup` with `playerCanDrive = true` (1.0-1.4).
- KUB assembled: `OnAASystemDeployed.crateNames` is the two consumed crates, `groupName` exists in DCS, every unit handed with `playerCanDrive = true` (2.0-2.4).
- Rearm and repair: `crateNames` holds the launcher crate and the repair crate, and the new groups exist in DCS (3.1-4.2).

DCS has no getter for `playerCanDrive`: the scenario records what CTLD hands to `coalition.addGroup` (a wrapper around the real function, removed at the end) and checks that DCS created the group. Afterwards: no scenario crate, no AA system, no group left at the site.

A first run stopped after 7 checks: the mock transport had no `getPlayerName`, which the coalition messages call since issue #326 (sibling lot). A real `Unit` always has it; the mock now does too.
