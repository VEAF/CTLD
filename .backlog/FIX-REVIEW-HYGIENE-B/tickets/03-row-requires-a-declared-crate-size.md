# 03 — The row layout requires a crate model with a declared size

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-REVIEW-HYGIENE-B](../PRD.md). Source: GitHub issue #255 (its step 2). Decision D3.

Files: `src/CTLD_crate.lua` (`getCrateSize`, `spawnCratesAligned`, `getCrateDropPositions`), `tests/ci/unit/crate_spawn_config_spec.lua`, `tests/ci/functional/crate_spawn_layout_spec.lua`, `tests/ci/functional/crate_drop_placement_spec.lua`, `docs/mission-maker/crates-catalogue.md` (+ `.fr.md`), `docs/developer/subsystems/crates.md` (+ `.fr.md`), `dev/adr/0024-native-crates-spawn-at-hull-clearance.md` (consequences).

## What to build

- `getCrateSize(modelKey)` returns nil when the model declares no positive `size`; the 1.5 m `_DEFAULT_CRATE_SIZE` goes.
- `spawnCratesAligned` takes the row only when the type has a plan **and** the crate model it uses has a size; otherwise the radial rule.
- `getCrateDropPositions` takes the row only when every dropped crate's model has a size; otherwise the radial rule for the whole wave.
- Docs (EN + FR): a model without `size` keeps the radial rule; with the default catalogue that is every crate of a `slingLoad: true` mission. The ADR 0024 consequences say the same.

## Acceptance criteria

- [x] busted, written first and seen failing: with `slingLoad: true` and a type that declares a plan, a requested wave and a dropped crate take the radial rule; a mission-maker `size` on `sling` brings the row back; the spec that pinned 1.5 m for `sling` now asserts that `sling` has no size.
- [x] Existing row specs (`load`, `dynamic` at 1.31 m) pass unchanged.
- [x] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
