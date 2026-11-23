# 06 — Live check in DCS

**Status:** 🟡 ready · **Type:** AFK, needs DCS running (Zip launches DCS; the session launches dcs-serve)

## Parent
[PRD](../PRD.md). Blocked by 01-05.

## What to build
A `noPlayer` live scenario over the DCS bridge on `Test_CTLDNEXT_01.miz`, in the manner of `scenario_create_before_destroy.lua`: a parachuted blue Standard Group lands with its template's types (#322); "HAWK Repair" is requested from a logistic zone and its crate appears (#324); two AA systems of the same type spawned in the same second both exist (#325). Everything cleaned up afterwards.

The Fat Cow is out of scope: used in game for weeks, considered tested (Zip, 2026-11-23).

## Acceptance criteria
- [ ] Each check PASS or FAIL with the DCS log lines that prove it.
- [ ] Nothing left in the mission afterwards.
- [ ] Result recorded in this ticket and the lot's index line.
