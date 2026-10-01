# 07 — Live validation in DCS

**Status:** ✅ done · **Type:** HITL

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 31, 32.

## What to build

Everything the lot could not verify with doubles is checked against a live mission, before the PR
opens (project rule: live tests come before the PR, not after).

1. **Automated live scenario (`auto-check` tier)** with the C-130J-30: a vehicle and a crate loaded
   natively (loadmaster tablet), unloaded on the ground, and released in flight. It checks the list
   contents, that CTLD follows each change, that the vehicle's unit stays alive and is not
   duplicated, and that a vehicle released in flight lands alive and returns to `WAITING`.
2. **Manual checklist, run by the user, on every native-cargo type the user owns** (C-130J-30,
   Mi-8MT, UH-1H; the CH-47F and the Mi-24P are not owned, so they stay unverified in game and are
   recorded as such in the PRD):
   - the on-board list exists and reports a crate and a whole vehicle loaded through the DCS cargo
     UI (a type that cannot be read must show the one-time warning);
   - something parked beside or under the aircraft (wing, rotor disc) is **never** counted;
   - several items aboard at once are tracked individually;
   - a native unload returns each item to its ground state, and a converting type (UH-1H, CH-47F)
     converts a crate exactly once;
   - a crate and a vehicle released in flight are reported as parachute releases and land.
3. **Open questions to settle:** the extra object `cr1-1-1` seen after a native crate unload; whether
   helicopters with native cargo accept a whole vehicle.
4. The outcome, and any type that must be handled as a special case, is recorded in the PRD, and its
   "unverified in game" list is updated to verified or refuted.

The DCS injection goes through the runner's HTTP path, not the MCP tool. No unit is spawned near a
live player aircraft.

## Acceptance criteria

- [ ] The C-130J-30 scenario passes against a live mission, or its failures are fixed and it is
      rerun.
- [ ] Every line of the manual checklist is ticked by the user for every owned native-cargo type
      (C-130J-30, Mi-8MT, UH-1H); the CH-47F and the Mi-24P are recorded as unverified in game.
- [ ] The PRD records the results and the status of each unverified assumption.

## Outcome

Done on 2026-10-01 with the C-130J-30, Mi-8MT and UH-1H; results recorded in the PRD ("Live validation results").
The automated `auto-check` scenario was replaced by an observer script
(`tests/dcs/dev/diag/diag_native_carry_observer.lua`) injected over HTTP: the loadmaster tablet cannot be driven from
a script, so the tester performed each step and the log was read after it. The CH-47F and the Mi-24P are not owned and
stay unverified in game.

## Blocked by

- [04 — Native vehicle release](04-native-vehicle-release-on-board-list.md)
- [05 — Transport lost without a death event](05-native-transport-lost-without-death-event.md)
- [06 — Native crate detection](06-crate-native-detection-on-board-list.md)
