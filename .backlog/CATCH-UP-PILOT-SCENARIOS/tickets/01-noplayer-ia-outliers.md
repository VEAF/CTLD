# 01 — noPlayer `ia` outliers (quick F10 visual checks)

Status: ✅ done
Type: ia (live DCS, F10 visual confirmation)

## Scenarios

- `tests/dcs/noPlayer/F-046_doubleRefreshIdempotentMenuLooksIdenticalAfterSeco.lua`
- `tests/dcs/noPlayer/F-047_enableFOBMidMissionClearBranchPackVehicles11ItemsP.lua`

Both live in `noPlayer/` but are tagged `ia` because they ask for a one-off visual F10 check the
code itself can't verify — no flight required, just a player slot occupied.

## Resolution (2026-07-12, live with David, UH-1H)

- **F-046**: injected as-is, confirmed live — menu identical after second `refresh()`. PASS.
- **F-047**: originally referenced dead menu paths (`{"CTLD Commands","FOB"}`,
  `{"CTLD Commands","Pack Vehicles"}`) — `"CTLD Commands"` and `"Pack Vehicles"` are marked
  `STALE` in the i18n files (`CTLD_i18n_en.lua:284-285`), left over from a pre-rename menu
  structure. Rewrote to the current tree (`{root, fobSub}` = `{"CTLD","FOBs List"}`,
  `{root, cratesSub, packSub}` = `{"CTLD","Crate Commands","Pack Equipt"}`, per
  `src/CTLD_fob.lua:519-521` and `src/CTLD_crate.lua:916-918`).
  - First re-run: `FOBs List` appeared, but `Pack Equipt` didn't — the node already exists,
    created `enabled=false` by production code at slot-in (no packable vehicle nearby), and
    `clearBranch` alone doesn't flip `enabled` (see `src/CTLD_crate.lua:941` comment). Added the
    missing `menu:setBranchEnabled({root, cratesSub, packSub}, true)` (mirrors
    `refreshPackEquiptSection`'s own approach at `CTLD_crate.lua:949`).
  - Second re-run: both branches confirmed live — FOBs List visible, Pack Equipt shows 9 items +
    Next Page (11 total). PASS.

Note: the pagination behavior itself (9 items + Next Page) is already covered headlessly by
`U-052`; this scenario's remaining value is confirming `setBranchEnabled`/`clearBranch` behave
correctly against a *live-managed* branch, not a synthetic one.

## Acceptance criteria

- [x] Both injected via the `integration-testing` skill loop, verdict read.
- [x] Any FAIL root-caused (stale assertion vs current code, or real bug) and fixed.
