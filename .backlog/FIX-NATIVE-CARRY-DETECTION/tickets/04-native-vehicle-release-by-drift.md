# 04 — Native vehicle release detected by drift

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 1, 2, 11, 18, 20, 23.

## What to build

When DCS releases a native-carry vehicle (ramp unload or DCS parachute function), CTLD detects it
the way it already detects a released native crate: each tick, for every native-carry vehicle whose
transport still exists, the vehicle's offset in the transport's local frame is compared with the
reference memorised at load; a change of more than 1 m means DCS released it.

On release:

- the vehicle returns to `WAITING`, its live unit reference is recovered (the unit is **not**
  respawned) and the reverse lookup is restored;
- a JTAC vehicle resumes lasing;
- `OnVehicleUnloaded` is published with method `dcs_native` when the transport is on the ground and
  `parachute` when it is airborne (decided with the shared in-air helper);
- the vehicle's native tracking entry is cleared.

The unload routine separates the **published reason** from the **mechanism**: recovering the live
unit instead of respawning it depends on the vehicle having been native-carried, not on the reason
published. Virtual-carry unloads (menu, AI dropoff) are unchanged. The empty, comment-only exit
branch and its lint suppression are removed.

## Acceptance criteria

- [ ] A drift above 1 m releases the vehicle; a drift below does not.
- [ ] On the ground the event method is `dcs_native`; in flight it is `parachute`, and no second
      unit is created in either case.
- [ ] The vehicle is `WAITING` afterwards, tracked again by its live unit, and a JTAC vehicle
      resumes lasing.
- [ ] `OnVehicleUnloaded` keeps its existing payload shape.
- [ ] Virtual-carry unload and AI dropoff still respawn the vehicle as before.
- [ ] The dead exit branch and its `luacheck` suppression are gone; luacheck stays clean.
- [ ] Busted spec drives ticks with DCS doubles for ground release, in-flight release and no
      release.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

- [03 — Native vehicle entry](03-native-vehicle-entry-guards.md)
