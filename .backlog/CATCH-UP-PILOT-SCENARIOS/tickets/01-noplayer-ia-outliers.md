# 01 — noPlayer `ia` outliers (quick F10 visual checks)

Status: 📋 todo
Type: ia (live DCS, F10 visual confirmation)

## Scenarios

- `tests/dcs/noPlayer/F-046_doubleRefreshIdempotentMenuLooksIdenticalAfterSeco.lua`
- `tests/dcs/noPlayer/F-047_enableFOBMidMissionClearBranchPackVehicles11ItemsP.lua`

Both live in `noPlayer/` but are tagged `ia` because they ask for a one-off visual F10 check the
code itself can't verify — no flight required, just a player slot occupied.

## Acceptance criteria

- [ ] Both injected via the `integration-testing` skill loop, verdict read.
- [ ] Any FAIL root-caused (stale assertion vs current code, or real bug) and fixed.
