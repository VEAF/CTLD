Status: ⬜ ready

# 02 — Fix F10 unpack menu refresh after AA system assembly

## What to build

After `CTLDCrateAssemblyManager:_assemble()` destroys the consumed crates, publish
`OnCrateCleared` for each destroyed crate so that `CTLDCrateManager:_refreshNearbyPlayers`
fires and rebuilds the F10 "Unpack Crate" submenu for all pilots within range.

The existing `OnCrateCleared` → `_refreshNearbyPlayers` wiring is already in place; the only
missing piece is the publication inside `_assemble()`. The payload must carry a `position`
field (used by the proximity filter). The `CTLDCrate` object being destroyed already holds
its position.

Deliver with a busted L1 unit test that calls a mocked `_assemble()` path and asserts
`OnCrateCleared` is published exactly once per consumed crate (N publications for N crates
destroyed across all parts).

## Acceptance criteria

- [ ] `_assemble()` publishes `OnCrateCleared` for every `CTLDCrate` it destroys, with a
      valid `position` in the payload
- [ ] After a successful assembly, the F10 unpack submenu is empty for all pilots within
      `unpackSearchRadius` of the assembly site (verified by reasoning: no registered crates
      of those types remain → `refreshUnpackSection` renders nothing)
- [ ] New busted L1 test stubs the event dispatcher and asserts N `OnCrateCleared`
      publications for a template consuming N crates total
- [ ] All existing `tests/ci/` pass (busted)
- [ ] luacheck clean on changed files
- [ ] `CTLD.lua` rebuilt via `merge_CTLD.ps1`

## Blocked by

None — can start immediately.
