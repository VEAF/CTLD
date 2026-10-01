# 04 — Live calibration of the native loading range and the declared distances

**Status:** ✅ done · **Type:** HITL

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

## Outcome (live, 2026-10-01)

- **Mi-8MT, 4.0 m side:** a row of four crates stood 4.10 to 4.85 m from the centre, 1.82 m apart; three
  loaded through the DCS cargo UI without moving, the fourth was refused because the cabin holds three
  crates (capacity, not distance). The weight shown in the resources window is not enforced by DCS.
- **Native loading range (Mi-8MT):** a crate at about 8 m loaded; a crate at 23 m was refused for its
  distance. The upper bound between 8 and 23 m and the point DCS measures from were not narrowed: the
  declared value is the closest safe distance, so the bound does not change it.
- **UH-1H, 3.0 m side:** two crates stood at 3.11 and 3.14 m; one loaded, the other was refused because the
  UH-1H takes a single crate (capacity, not distance).
- **C-130J-30, 11.3 m rear:** three crates stood in a row at 11.31 m (1.81 m apart) and all three loaded
  through the DCS UI without moving the aircraft.
- **No declared value was lowered.** The CH-47F (3.7 m) and the Mi-24P (5.1 m) stay unverified in game: the
  project owner has neither module.

## Acceptance criteria

- [x] The loading range of the Mi-8MT is recorded (8 m loads, 23 m refused); the point DCS measures from was not
      isolated and does not change the declared values. The UH-1H loads at 3.1 m.
- [x] Each declared distance of an owned type is confirmed reachable (UH-1H, Mi-8MT, C-130J-30); none lowered.
- [x] The rows load without repositioning, up to what each cabin holds (Mi-8MT three, UH-1H one, C-130J-30
      three tested).
- [x] The PRD records the results, and the CH-47F and Mi-24P as unverified in game.

## Blocked by

- [02 — Layout for sets and pack](02-layout-for-sets-and-pack.md)
- [03 — Single crate request](03-single-crate-request.md)
