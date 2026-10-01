# 04 — Live calibration of the native loading range and the declared distances

**Status:** 🧑 waiting-human · **Type:** HITL

## Parent

[PRD — FEAT-NATIVE-CRATE-SPAWN-NEAR](../PRD.md). [ADR 0024](../../../dev/adr/0024-native-crates-spawn-at-hull-clearance.md).
Stories 6, 7, 19, 20.

## What to build

Everything doubles cannot prove is checked in a live mission before the PR opens.

1. **Native loading range** of the Mi-8MT and the UH-1H, measured with a runtime override of the declared
   distance (no rebuild): from a clear spot, request a light crate, move the aircraft or the override in small
   steps, and note the largest distance at which the DCS cargo UI loads it, and from where DCS measures (aircraft
   centre or hull).
2. **Declared distances confirmed or lowered:** a Pack of a four-crate vehicle and a request set on the Mi-8MT and
   the UH-1H spawn in a row beside the helicopter, none touching the hull, the skids or each other, and all four
   load through the DCS UI without moving. The C-130J-30 rear row is checked the same way.
3. The CH-47F and the Mi-24P are not owned: their values stay unverified in game and are recorded as such.
4. The outcome, any value lowered, and the measured range are recorded in the PRD and the ADR consequences.

Measurements start far and go closer in steps, with a light crate, on a clear site, one aircraft at a time; no
crate is spawned from a script near a live aircraft. The DCS injection goes through the runner's HTTP path.

## Acceptance criteria

- [ ] The loading range of the Mi-8MT and the UH-1H is recorded, with the point DCS measures from.
- [ ] Each declared distance of an owned type is confirmed reachable, or lowered and re-checked.
- [ ] A four-crate Pack on the Mi-8MT and on the UH-1H loads in full with no repositioning.
- [ ] The PRD records the results, and the CH-47F and Mi-24P as unverified in game.

## Blocked by

- [02 — Layout for sets and pack](02-layout-for-sets-and-pack.md)
- [03 — Single crate request](03-single-crate-request.md)
