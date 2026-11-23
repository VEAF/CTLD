# 06 — Live check in DCS

**Status:** ✅ done — live scenario PASS 10/10 (2026-11-23) · **Type:** AFK, needs DCS running (Zip launches DCS; the session launches dcs-serve)

## Parent
[PRD](../PRD.md). Blocked by 01-05.

## What to build
A `noPlayer` live scenario over the DCS bridge on `Test_CTLDNEXT_01.miz`, in the manner of `scenario_create_before_destroy.lua`: a parachuted blue Standard Group lands with its template's types (#322); "HAWK Repair" is requested from a logistic zone and its crate appears (#324); two AA systems of the same type spawned in the same second both exist (#325). Everything cleaned up afterwards.

The Fat Cow is out of scope: used in game for weeks, considered tested (Zip, 2026-11-23).

## Acceptance criteria
- [x] Each check PASS or FAIL with the DCS log lines that prove it.
- [x] Nothing left in the mission afterwards.
- [x] Result recorded in this ticket and the lot's index line.

## Result (2026-11-23)

`tests/dcs/noPlayer/scenario_vmct_review_findings.lua` on `Test_CTLDNEXT_01.miz`, one DCS launch shared with FEAT-VMCT-V1-PARITY: the mission loaded a `CTLD.lua` built from `develop` + this branch at `c027ea36` + `feat/FEAT-VMCT-V1-PARITY`. Runner: `[PASS] noPlayer/scenario_vmct_review_findings.lua -- 56.1s -- [VRF] PASS 10/10`.

DCS log lines (`[CTLD][INFO] [VRF] …`):

- #322: `landed Standard Group (Standard Group-1): Soldier M4 GRG ×6, Soldier M249 ×2, Paratrooper RPG-16 ×2`, identical to the template's expected list; `landed Mortar Squad (Mortar Squad-2): 2B11 mortar, Soldier M4 GRG` ×6 (mortars with their servants). PASS 1.0, 1.1, 1.2 ×2.
- #324: `PASS 2.0 Request Equipment lists HAWK Repair in the temporary zone`, `PASS 2.1 a HAWK Repair crate was brought out`, `PASS 2.2 the crate is a DCS static` (through the real menu callback).
- #325: `AA groups: Hawk ln_CTLD_AA_6, Hawk ln_CTLD_AA_18`, `PASS 3.0 both spawns accepted in the same second`, `PASS 3.1 two distinct group names`, `PASS 3.2 both systems exist in the world`.

No ERROR or WARN line in the DCS log during the run. Checked afterwards over dcs-serve: `groups=[] mockCrates=0 tempZone=false aaSystems=0 menu=false inTransit=false running=false`, nothing left in the mission.
