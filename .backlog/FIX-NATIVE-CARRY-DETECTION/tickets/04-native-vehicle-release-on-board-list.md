# 04 — Native vehicle release detected when it leaves the on-board cargo list

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). [ADR 0022](../../../dev/adr/0022-native-carry-detected-from-dcs-on-board-cargo-list.md).
Stories 1, 2, 9, 11, 18, 20, 23, 24.

## What to build

When DCS releases a native-carry vehicle (ramp unload or DCS parachute function), the vehicle
disappears from the on-board cargo list of its transport. CTLD detects that on the next tick.

On release:

- **On the ground** (shared in-air helper says the transport is not airborne): the vehicle returns
  to `WAITING` at once, its live unit reference is recovered (the unit is **not** respawned) and the
  reverse lookup is restored; a JTAC vehicle resumes lasing; `OnVehicleUnloaded` is published with
  method `dcs_native`.
- **In flight** (transport airborne): `OnVehicleUnloaded` is published with method `parachute` and
  the vehicle enters a new **falling** state. It returns to `WAITING` once it has landed, using the
  landing criterion the crate code already uses, now shared; its JTAC resumes lasing then. Its live
  unit is recovered, never respawned (measured: the unit stays alive all the way down).
- A vehicle destroyed or lost in water while falling is handled like any lost vehicle (removed from
  tracking, JTAC deregistered, `OnVehicleDead`).

The unload routine separates the **published reason** from the **mechanism**: recovering the live
unit instead of respawning it depends on the vehicle having been native-carried, not on the reason
published. CTLD's own (virtual) parachute still respawns the vehicle at its landing position;
virtual-carry unloads (menu, AI dropoff) are unchanged. The empty, comment-only exit branch and
its lint suppression are removed. A released vehicle cannot be reloaded by CTLD: it can be loaded
again only by reappearing on the list.

## Acceptance criteria

- [ ] A vehicle that leaves the list with the transport on the ground is `WAITING`, event method
      `dcs_native`, no second unit created, a JTAC resumes lasing.
- [ ] A vehicle that leaves the list with the transport airborne is published as `parachute`, is in
      the falling state, is not offered for loading, and becomes `WAITING` only after landing; a
      JTAC resumes then.
- [ ] Destroyed, water loss and transport gone while falling are covered.
- [ ] `OnVehicleUnloaded` keeps its existing payload shape.
- [ ] Virtual-carry unload, AI dropoff and the virtual parachute still respawn the vehicle as before.
- [ ] The dead exit branch and its `luacheck` suppression are gone; luacheck stays clean.
- [ ] Busted spec drives ticks with DCS doubles for ground release, in-flight release with landing,
      and no release.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

- [03 — Native vehicle entry](03-native-vehicle-entry-on-board-list.md)
