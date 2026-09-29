# 08 — Native crate load detection uses the resolved box

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 37, 38.

## What to build

The crate load detection reads the same resolved box as the vehicle scan (hold box when configured,
otherwise the DCS box), through the shared rule from ticket 07. The crate behaviors around it are
unchanged: ground and speed guard, 0.5 m entry margin, conversion for types that convert native
loads, drift-based release.

**One deliberate exception:** the check that keeps a freshly spawned crate out of a neighbouring
aircraft's volume keeps using the full DCS box, because its purpose is to avoid the whole envelope,
wings included.

Crate behavior therefore changes only for types that ship a hold box.

## Acceptance criteria

- [ ] A crate inside the resolved box is detected as native carry; a crate inside the DCS box but
      outside the hold box is not.
- [ ] For a type without a hold box, crate detection is byte-for-byte unchanged in behavior.
- [ ] The spawn-time neighbour check still uses the full DCS box.
- [ ] Existing crate specs stay green; new busted cases cover the hold box.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Changed` entry.

## Blocked by

- [07 — `aircraftHoldBox` capability](07-aircraft-hold-box-key.md)
