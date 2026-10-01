# 01 — F10 unload and parachute lists show virtual-carry vehicles only

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 3, 4.

## What to build

A vehicle in **native carry** never appears in the F10 *Unload Vehicles* list and never enables the
*Parachute Vehicle* entry. Only vehicles in **virtual carry** do. Today both entries list every
loaded vehicle, so using them on a native-carry vehicle would spawn a duplicate of a unit DCS still
holds inside the aircraft.

Virtual-carry behavior, the loaded-vehicle weight accounting and the menu empty states are
unchanged: when only native-carry vehicles are aboard, the unload submenu is hidden exactly as if
nothing were loaded.

## Acceptance criteria

- [x] With one native-carry vehicle aboard, the unload list is empty and the parachute entry stays
      disabled.
- [x] With one virtual-carry vehicle aboard, the unload list and the parachute entry behave as
      before.
- [x] With both kinds aboard, only the virtual-carry vehicle is listed and can be unloaded or
      parachuted.
- [x] The AI dropoff path that unloads a loaded vehicle is unchanged.
- [x] Busted spec covers the three cases through what the menu-facing list returns.
- [x] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

None - can start immediately.
