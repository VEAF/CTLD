# 09 — Ship tuned hold boxes for the C-130J-30 and the Mi-8MT

**Status:** 🧑 waiting-human · **Type:** HITL

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 31, 32.

## What to build

The default configuration ships an `aircraftHoldBox` for the two types whose DCS box is far larger
than their cargo bay: the **C-130J-30** (DCS box 35.13 × 12.12 × 41.03 m, wings and tail included)
and the **Mi-8MT** (25.26 × 7.51 × 22.16 m, rotor disc included). No other type ships one.

The values are **tuned visually with the user** in a live mission: the box-drawing diagnostic is
adapted to draw a candidate hold box around the aircraft, the values are adjusted until the box
follows the cargo bay (the datamine's cargo volume dimensions are a starting point, not the answer,
because they carry no position in the aircraft frame), and the user confirms the result.

## Acceptance criteria

- [ ] A hold box for the C-130J-30 and one for the Mi-8MT are in the default configuration, each
      contained in that type's DCS box.
- [ ] The user has seen each candidate box drawn on the aircraft and confirmed it.
- [ ] The final values and how they were obtained are recorded in the PRD's "Further Notes".
- [ ] A busted spec asserts the defaults carry a hold box for exactly these two types.
- [ ] The generated defaults copy is refreshed by the normal build.
- [ ] `CHANGELOG.md` `[Unreleased]` has an `Added` entry (may share ticket 07's).

## Blocked by

- [07 — `aircraftHoldBox` capability](07-aircraft-hold-box-key.md)
- [08 — Crate detection uses the resolved box](08-crate-native-detection-hold-box.md)
