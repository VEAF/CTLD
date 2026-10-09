# 02 — Packing a scene places its crates by the common rule

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-REVIEW-HYGIENE-B](../PRD.md). Source: GitHub issue #253. Decisions D1, D2.

Files: `src/CTLD_crate.lua` (`spawnCratesAligned`, `_spawnCratesInRow`, the "Pack *&lt;scene&gt;*" callback of `refreshPackEquiptSection`), `tests/ci/functional/` (a scene-pack spec, or the existing pack spec if one covers the callback), `docs/developer/subsystems/crates.md` (+ `.fr.md`) if it lists the callers of `spawnCratesAligned`.

## What to build

- `spawnCratesAligned` returns a third value, the list of `CTLDCrate` it created, from both the row branch (`_spawnCratesInRow`) and the radial branch.
- The scene pack callback builds `cratesRequired` descriptors and calls `spawnCratesAligned(descriptors, t, t:getCoalition(), t:getName(), CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)` in place of the direct `ctld.utils.getSpawnObjectPositions` + `spawnCrate` loop, then sets `metadata.warehouseSnapshot` on each returned crate.
- The `trigger.action.outText("[PackCallback] ENTER ...")` broadcast (`src/CTLD_crate.lua:990`) is removed; the `ctld.utils.log` line above it stays.

## Acceptance criteria

- [x] busted, written first and seen failing, driving the F10 "Pack *&lt;scene&gt;*" command: for a type that declares a plan (UH-1H, side 3.0 m), the crates of the packed scene stand in a row at the declared distance; for a type without one, the radial routine receives the other aircraft's volumes (as in `crate_drop_placement_spec`); every created crate carries the warehouse snapshot; nothing is sent through `trigger.action.outText`.
- [x] Request Equipment, Drop Crate(s) and Pack Vehicle specs pass unchanged.
- [x] `CHANGELOG.md` `[Unreleased]` (with ticket 03 and 01: one entry per issue).
- [x] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
