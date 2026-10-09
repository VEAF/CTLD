# FIX-REVIEW-HYGIENE-B — scene packing, crate size fallback and scheduler exit

**Status:** ✅ done

Formalizes GitHub issues #253, #254 and #255, all three found by the same automated code review of `develop` at `affd2c9`.
Re-read against `develop` at `6010d52` (2026-10-09): the three defects are still present, the line numbers below are those of `6010d52`.
Follow-up of `FIX-REVIEW-HYGIENE-A`, and of the two lots the findings are about: `FEAT-NATIVE-CRATE-SPAWN-NEAR` (ADR 0024) and `FIX-SCHEDULER-SINGLE-ENTRY`.

## Problem Statement

**Scene packing ignores the crate placement rule (#253).**
ADR 0024 routes crate placement through `CTLDCrateManager:spawnCratesAligned`: a row just clear of the hull for a type that declares `crateSpawnSector` + `crateSpawnDistance`, the radial rule otherwise, with the anti-collision against other aircraft in both cases.
Request Equipment, Drop Crate(s) and Pack Vehicle go through it.
The "Pack *&lt;scene&gt;*" callback of `refreshPackEquiptSection` (`src/CTLD_crate.lua:1016-1031`) still calls `ctld.utils.getSpawnObjectPositions` directly, without axis nor avoidance list.
The crates of a packed FARP appear at a random bearing over 360°, at the generic distance, possibly inside a neighbouring aircraft's box.
A native-cargo pilot who has just packed a FARP cannot load it back through the DCS cargo window without repositioning around each crate, which is what ADR 0024 was written to remove.
The docs say the opposite: `docs/mission-maker/crates-catalogue.md` (and `.fr.md`) list **Pack Equipt** among the commands that spawn crates just clear of the hull, and the FARP pack is in that submenu.

The same callback starts with `trigger.action.outText("[PackCallback] ENTER " .. unitName, 8)` (`src/CTLD_crate.lua:990`): a debug line shown to **every player of the mission**, for 8 s, each time anyone packs a FARP.
It has been there since the repository import (2026-07-07); the legacy script has no such line.

**A crate model without `size` gets a row computed on an invented size (#255).**
The row's spacing and capacity come from the `size` of the crate model (`getCrateSize`, `src/CTLD_crate.lua:1798`), 1.5 m when the model declares none.
`load` and `dynamic` declare `size: 1.31` (measured `ammo_cargo`); `sling` (`container_cargo`, shape `bw_container_cargo`) declares nothing.
With `slingLoad: true`, `_crateModelKey` returns `sling` for every aircraft, so every crate of such a mission is laid out in a row computed for a 1.5 m crate, while the container is visibly larger: neighbours can overlap, a row holds more than fits, and the hull distance was derived for a crate the size of the `ammo_cargo`.
The test pins the fallback (`tests/ci/unit/crate_spawn_config_spec.lua:108` asserts 1.5 for `sling`) instead of checking the value is right.

**The scheduler has an entry and no exit (#254).**
`ctld.scheduler.schedule` records every pending id in `_pending`.
Six sites cancel a timer created through it by calling `timer.removeFunction` directly: `src/CTLD_menu.lua:159`, `:220`, `:226` and `src/CTLD_recon.lua:607`, `:692`, `:781`.
DCS forgets the timer, `_pending[id]` stays `true` for the rest of the mission.
`_pending` grows with every menu action that preempts an ambient rebuild, every group that loses its last occupant, every recon pass; `cancelAll()` then calls `timer.removeFunction` on thousands of dead ids and reports them as cancelled timers.
The guard spec only watches `timer.scheduleFunction(`, so nothing stops the next direct removal.

## Solution

- Scene packing goes through `spawnCratesAligned`, which also returns the crates it created so the caller can attach the FARP warehouse snapshot; the debug broadcast goes.
- The row layout requires a crate model with a declared size; a model without one keeps the radial rule.
- `ctld.scheduler.remove(id)` is the exit symmetric to `schedule`; the six sites use it; the guard spec watches `timer.removeFunction` too.

## Decisions

- **D1 — Scene packing joins ADR 0024 (not the other way round).**
  #253 offers the alternative: keep the generic rule for scenes and fix the doc instead.
  Rejected: the FARP crates are crates like any other for the pilot who must load them, and the doc already promises the row.
- **D2 — `spawnCratesAligned` returns the created crates as a third value.**
  `spawned, spawnInfo, crates`: existing callers that read two values are unaffected; the FARP branch sets `crate.metadata.warehouseSnapshot` on each.
- **D3 — A crate model without `size` keeps the radial rule; no size is invented.** *(confirmed by Zip, 2026-10-09)*
  #255 offers two steps: (1) measure `bw_container_cargo` in DCS and declare its `size` (with `configVersion` bump and catalogue shape), (2) make the fallback visible or refuse the row.
  Decision: step 2 only, as a refusal of the row, and the 1.5 m fallback removed (`getCrateSize` returns nil for a model without a size).
  Reason beyond the missing measurement: the row exists to put a crate within reach of the DCS cargo window for internal loading (ADR 0024), while a `slingLoad` crate is hooked under a hovering aircraft; a container 1.5 m from a parked helicopter's hull stands under its rotor disc.
  The radial rule is what sling missions had before ADR 0024.
  Measuring the container (step 1) is then only needed if sling missions should get the row, which is a separate decision.
- **D4 — `ctld.scheduler.remove(id)` tolerates a nil id and an id DCS no longer knows**, like `cancel(name)` (`pcall`).
  `register` and `cancel` use it too, so the guard counts exactly two `timer.removeFunction` calls in `src/`: `remove` and `cancelAll`.
- No i18n, no config key, no catalogue change (under D3 as recommended).
- **Legacy parity:** the legacy script has no row layout, no scene packing through a manager and no scheduler registry; nothing to preserve.

## Testing Decisions

- busted, written first and seen failing, through the existing seams: `tests/ci/functional/crate_spawn_layout_spec.lua` (spawn entry with doubles of the aircraft and of `spawnCrate`), `tests/ci/functional/crate_drop_placement_spec.lua` (Drop Crate(s) through the F10 menu), `tests/ci/unit/scheduler_spec.lua` (stubbed `timer`), `tests/ci/unit/scheduler_guard_spec.lua` (scan of the merge list).
- The live DCS check of the FARP pack is optional: the row itself is already verified live by `FEAT-NATIVE-CRATE-SPAWN-NEAR` ticket 04, and this lot only changes which entry point the FARP calls.

## Out of Scope

- Measuring `bw_container_cargo` and giving sling missions the row (see D3).
- Any change to the radial rule or to the row geometry.

## Further Notes

Source issues: #253, #254, #255. The PR closes them with `Fixes #253`, `Fixes #254`, `Fixes #255`.
