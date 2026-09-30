# ADR 0022 — Native carry is detected from the DCS on-board cargo list, not from geometry

**Date:** 2026-10-01
**Status:** Accepted
**Lot:** `FIX-NATIVE-CARRY-DETECTION` (this ADR supersedes the geometric design the lot's PRD first
settled on, 2026-09-29).

## Context

CTLD decided whether a crate or a whole vehicle was "inside" a native-carry aircraft by testing its
position against a box in the aircraft's frame (the box DCS reports for the type, then a per-type
`aircraftHoldBox`), plus ground, speed and coalition guards, and detected the release by the item
drifting more than 1 m from where it sat. The box DCS reports is the model's UserBox, authored by
each module's designers: 41 m wide for the C-130J-30, the whole rotor disc for the Mi-8MT. It is far
larger than a cargo bay, so an item parked beside such an aircraft could count as carried.

A live session on 2026-09-30 (C-130J-30, loadmaster tablet) showed that DCS itself reports what is on
board: the aircraft's on-board cargo list holds the crate, and holds a companion object named
`CRG:<unit name>` for a whole vehicle, whose own unit stays alive and is moved into the hold. The
item leaves the list at the moment DCS releases it, on the ground or in flight (a vehicle released by
the native parachute left the list at release, then descended alive under its parachute, at about
9 m/s, to a normal landing).

## Decision

Native carry is read from that list. An item is in native carry exactly while it is on the list of
an aircraft CTLD watches, and it is released the moment it leaves the list. The box, the
`aircraftHoldBox` capability, the ground/speed/coalition entry guards, the drift reference and the
re-arm lock are not built; the drift-based release of native crates is replaced.

Items on the list that CTLD does not track (cargo created by the loadmaster tablet, editor crates
of an unknown type) are ignored, with a debug trace. If the list cannot be read for a type, CTLD
logs one warning for that type and does not watch it; there is no geometric fallback.

## Considered options

- **Geometric detection with a per-type hold box** (the first design). Rejected: it needs a tuned box
  for every type whose DCS box is oversized (only two types had values, and those were measured by
  eye or extracted from the EDM model), it can misfire for an item beside the aircraft, and it asks
  CTLD to guess what DCS already knows.
- **List for entry, drift for release.** Rejected: the list already reports the release, on the
  ground and in flight, so a drift reference and its threshold would be dead weight.

## Consequences

- Fewer knobs: no hold box to tune per aircraft, in the code, the schema, the editor or the docs.
- The design depends on the list being available and accurate for every native-cargo type. It was
  measured live on the C-130J-30 only; the other types (CH-47F, Mi-8MT, UH-1H, Mi-24P) are verified
  by the lot's live-validation ticket, and a type that fails is handled as a special case.
- Reverting to geometry later means rebuilding the box, the guards, the drift reference and the
  re-arm lock, which is why this is recorded.
