# ADR 0024 — Crates requested for a native-cargo aircraft spawn just clear of its hull, on the side the aircraft is loaded from

**Date:** 2026-10-01
**Status:** Accepted
**Lot:** `FEAT-NATIVE-CRATE-SPAWN-NEAR`.

## Context

A crate requested from Request Equipment, or produced by packing a vehicle, spawned at the secure
distance of the requesting aircraft plus 5 m. That distance is the horizontal diagonal of the box DCS
reports for the type (`getDesc().box`, the model's UserBox, rotor disc included), and each further crate
was another 5 m out. For a Mi-8MT the first crate stood 23 m away and the second 28 m. DCS loads a crate
through its native cargo UI only when it is close to the aircraft: in a live session on 2026-10-01 a crate
at 23 to 28 m answered "FAILED TO LOAD CARGO" and one at about 5 m loaded. A pilot had to move the
helicopter to every crate.

The collision shell of each model (the `*_collision.edm` files shipped with DCS) gives the real hull. Cut
at the height of a crate (1.3 m), it is far smaller than the UserBox: the Mi-8MT hull reaches 2.5 m to the
side and 3.6 m behind, the UH-1H 1.5 m and 4.0 m, against 18 m and 14 m for the UserBox rule. A heavy
static spawned overlapping a hull can detonate (a C-130 was lost that way on 2026-09-16), so a spawn
closer than today must be derived from the real hull and never guessed.

## Decision

An aircraft type may declare, in `capabilitiesByType`, where its crates spawn: a **sector** (`rear`,
`side` or `front`, the existing front and rear rules plus a new side one) and a **distance** from the
aircraft centre to the first crate. Each value is the radius of the hull at crate height over that sector
plus a 1.5 m margin, computed from the model's collision shell (the UserBox only when a model has no
collision shell it can be read from) and then checked in a live mission.

- Helicopters with native cargo spawn crates on the **side** (a random side for the whole wave, bearings
  60° to 120°), where the hull is narrowest: UH-1H 3.0 m, CH-47Fbl1 3.7 m, Mi-8MT 4.0 m, Mi-24P 5.1 m.
- The C-130J-30 keeps the **rear** sector (the ramp side; its tablet loads a crate from 33 m): 11.3 m.
- The crates of one wave stand **in a row** at that distance, perpendicular to the sector axis and centred
  on the aircraft, so every crate is as close as the first. Neighbours are `crate size + 0.5 m` apart
  (centre to centre), the crate size being its largest horizontal extent from a per-model table (1.31 m for
  `ammo_cargo`, 1.5 m for an unknown model). A row holds as many crates as fit along the aircraft's own
  box; the next row is one step further out.
- A type with no declared sector and distance keeps today's rule, unchanged.
- Only crates requested or produced by packing are concerned. Vehicles keep their rotor-aware offset, a
  vehicle assembled from crates still appears 50 m or more from the aircraft, and `getSecureDistanceFromUnit`,
  used by troops and scenes, is not touched.

## Considered options

- **Keep the UserBox rule and only shrink the +5 m margin.** Rejected: the UserBox includes the rotor disc
  (and, for the UH-1H, a tail 8.9 m long), so even with no margin the crates stay 10 to 18 m away.
- **A single global distance for every aircraft.** Rejected: a distance short enough for a UH-1H would
  overlap a C-130's hull, and one safe for the C-130 is out of range for every helicopter.
- **Radial layout with a smaller spacing.** Rejected: crate n would still be n steps farther out and leave
  the native load range.
- **Reading the crate size live from its UserBox.** Rejected: DCS gives it only after the static exists, so
  the first crate of a model could not be placed with it.
- **Rear sector for helicopters.** Rejected: the tail (and its rotor) makes the rear the farthest side
  (UH-1H 5.5 m, Mi-24P 9.8 m, against 3.0 m and 5.1 m on the side).

## Consequences

- A pilot of a native-cargo helicopter requests crates and loads them without repositioning the aircraft.
- The values depend on the collision shells of the installed DCS version; a script keeps them
  reproducible, and a model update can be re-measured.
- The UH-1H (3.0 m), Mi-8MT (4.0 m) and C-130J-30 (11.3 m) values were confirmed in game on 2026-10-01: rows of
  crates load through the DCS cargo UI without moving the aircraft (a crate at about 8 m also loaded on the
  Mi-8MT, one at 23 m was refused). What limits a load beyond that is the cabin capacity (Mi-8MT three crates,
  UH-1H one), not the distance, and DCS does not enforce the weight shown in the resources window.
- The CH-47F and the Mi-24P values come from their collision shell only (the project owner has neither
  module): unverified in game.
- Reverting to the UserBox rule is a configuration change (remove the fields), not a code change.

## Addendum 1 — Drop Crate(s) follows the same rule (2026-10-03, lot `FIX-CRATE-DROP-PLACEMENT`)

The decision above only reached crates requested or produced by packing. **Drop Crate(s)** kept the older radial rule
(the secure distance plus 5 m, no anti-collision), so on a native-cargo helicopter a crate dropped from the F10 menu
landed 20 m or more away, outside the range from which DCS loads a crate through its cargo UI, and could land inside
another aircraft's volume. It now uses the same placement: a row at the declared distance for a type that declares
a plan, the radial rule otherwise, both with the anti-collision, one crate size per crate.

A dropped row is placed `crateDropExtraDistance` (default 2 m, setting added in catalogue 2.2.0) farther than a
requested one, **for a type with a plan only** (the radial rule already stands crates 20 m or more away). The aircraft
has just landed and must be able to taxi away, or lift off for a helicopter, without touching the crates it has just
dropped; the requested row is unchanged. The value is bounded by the loading range (8 m loaded, 23 m refused on the
Mi-8MT): with the declared distances (UH-1H 3.0 m, Mi-8MT 4.0 m) a dropped row stands at 5.0 and 6.0 m. The default
is a first estimate: it has not been confirmed in game yet, and `0` restores the requested position.
