Status: ⬜ ready

# 01 — Enable "All crates" for FOB scene

## What to build

Remove `showSets = false` from the FOB scene crate descriptor so that the existing
`singleTypeSet` auto-generation kicks in when `enableAllCrates` is true and
`cratesRequired > 1`. The result is a "FOB Crate - All crates" entry appearing in
"Request Equipment" that spawns all 3 FOB crates in one click, consistent with
every other multi-crate equipment in the catalogue.

No other change is required — the auto-generation logic already handles this case.

## Acceptance criteria

- [ ] `fobScene.crate` no longer contains `showSets = false` (field absent or `true`)
- [ ] When `enableAllCrates` is true, "Request Equipment" shows a "FOB Crate - All crates"
      entry that spawns 3 crates at once
- [ ] When `enableAllCrates` is false, no "All crates" entry appears (existing guard unchanged)
- [ ] New busted L1 test: `_injectSceneCrate` with a scene crate of `cratesRequired = 3` and
      no `showSets` field generates a `singleTypeSet` with `multiple` length 3
- [ ] All existing `tests/ci/` pass
- [ ] `CTLD.lua` rebuilt via `merge_CTLD.ps1`

## Blocked by

None — can start immediately.
