# 03 — Live check in DCS

**Status:** 🟡 ready · **Type:** AFK, needs DCS running (Zip launches DCS; the session launches dcs-serve)

## Parent
[PRD](../PRD.md). Blocked by 01, 02.

## What to build
A `noPlayer` live scenario over the DCS bridge on `Test_CTLDNEXT_01.miz`: an unpacked vehicle crate and an assembled AA system are created drivable by default (read back what DCS holds if the API exposes it; otherwise record what was passed to `dynAdd` / `coalition.addGroup` and say so), and the payloads of `OnCrateUnpacked` and `OnAASystemDeployed` carry `groupName` / `crateNames` matching real objects. Everything cleaned up afterwards.

## Acceptance criteria
- [ ] Each check PASS or FAIL with the DCS log lines that prove it.
- [ ] Nothing left in the mission afterwards.
- [ ] Result recorded in this ticket and the lot's index line.
