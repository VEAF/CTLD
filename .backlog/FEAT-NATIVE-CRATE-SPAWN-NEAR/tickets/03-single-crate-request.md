# 03 — The single crate of Request Equipment uses the same clearance

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FEAT-NATIVE-CRATE-SPAWN-NEAR](../PRD.md). [ADR 0024](../../../dev/adr/0024-native-crates-spawn-at-hull-clearance.md).
Stories 1, 2, 3, 9.

## What to build

A single crate chosen in Request Equipment, which today computes its own position next to the set path, appears
at the same declared sector and distance as a set of one. A type with no declared values keeps its current
position rule. Vehicles requested whole keep their rotor-aware offset, and crates dropped from the hold, scenes
and the vehicle unpack distance are untouched.

## Acceptance criteria

- [ ] A single crate for a declared type appears at the declared distance on the declared sector.
- [ ] A type with no declared values behaves as before.
- [ ] The whole-vehicle request, the unpack distance (50 m) and the drop-from-hold paths are unchanged (existing
      specs stay green).
- [ ] Busted spec covers the single crate path with doubles.
- [ ] `CHANGELOG.md` `[Unreleased]` entry of the lot covers it.

## Blocked by

- [02 — Layout for sets and pack](02-layout-for-sets-and-pack.md)
