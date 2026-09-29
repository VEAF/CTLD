# 03 — Native vehicle entry: player units, any category, guarded

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 5, 6, 8, 13, 21, 22, 24.

## What to build

The native scan that turns a `WAITING` vehicle into a **native-carry** vehicle is rebuilt on the
same candidate rule as the crate scan and gains the guards native crates already have:

- Candidates are **player-controlled units** whose type declares a native cargo system, in **any
  category** (airplane or helicopter). AI units are never scanned. Whole-vehicle admission also
  requires the type to be whole-vehicle capable.
- A vehicle is admitted only when the transport is on the ground, its speed is at most 0.5 m/s,
  the vehicle's point is inside the transport's box (the DCS box for now; the hold box arrives in
  ticket 07), and the vehicle's coalition equals the transport's coalition.
- Type, weight and count are not re-checked by CTLD: DCS decides what a native cargo system
  accepts. A refused vehicle (wrong coalition) stays `WAITING`, silently.
- At load, the vehicle's offset in the transport's local frame is memorised as the drift
  reference, in the spawner's native tracking table (written today and never read).

The `OnVehicleLoaded` payload is unchanged.

## Acceptance criteria

- [ ] A player Mi-8MT or CH-47F (helicopters) is scanned; an AI-flown aircraft never is.
- [ ] A vehicle inside the box of a stationary grounded transport, same coalition, is loaded.
- [ ] The same vehicle is not loaded when the transport moves faster than 0.5 m/s, is airborne, or
      belongs to the other coalition.
- [ ] The drift reference is stored at load and available to the exit detection.
- [ ] The idle case (no waiting or native-carry vehicle) still returns before any scan.
- [ ] Busted spec drives one tick with DCS doubles for each case above.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

None - can start immediately.
