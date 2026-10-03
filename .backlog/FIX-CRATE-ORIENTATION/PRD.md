# FIX-CRATE-ORIENTATION — crates stand parallel to the aircraft that spawned or dropped them

**Status:** ⬜ ready

Raised by the maintainer during the live check of `FIX-CRATE-DROP-PLACEMENT` on 2026-10-03 (UH-1H): a requested crate
was not parallel to the helicopter. Scope stated by the maintainer: every aircraft, not only helicopters.

## Problem Statement

Every crate CTLD creates is oriented due north: the heading is written as zero when the static object is created, and
again in the crate record, and the static is re-created with the same zero heading when a crate is dropped. Whatever the
aircraft's heading, the crate stands at an angle to it. The crate looks misplaced next to the aircraft (a row of crates
beside a helicopter, a crate behind a C-130), and a long crate model does not line up with the aircraft it was produced for.

## Solution

A crate created for an aircraft (requested, requested as a set, produced by packing, produced by a scene pack, dropped from
the menu, released below a slingload) takes the aircraft's heading, so it stands parallel to it. Crates with no aircraft
(placed by the mission maker, or landing from a parachute descent) keep their current heading.

## User Stories

1. As a pilot, I want a crate I request to stand parallel to my aircraft, so that it looks placed rather than dropped at
   random.
2. As a pilot, I want a set of crates I request to stand parallel to my aircraft, so that the row is tidy.
3. As a pilot, I want the crates produced by packing a vehicle to stand parallel to my aircraft, so that they match the
   others.
4. As a pilot, I want a crate I drop from the menu to stand parallel to my aircraft, so that it matches a requested one.
5. As a pilot, I want a crate released below a slingload to take my aircraft's heading, so that dropped crates are
   consistent.
6. As a pilot of any aircraft (helicopter or airplane), I want the same behaviour, so that no type is left out.
7. As a pilot, I want the crate to keep its position unchanged, so that only the orientation changes.
8. As a mission maker, I want a crate I place in the editor to keep its own orientation, so that my placements are
   untouched.
9. As a pilot, I want a crate that lands by parachute to be unaffected, so that this path does not change.
10. As a CTLD developer, I want the heading to be an optional input of crate creation, so that callers without an aircraft
    keep today's behaviour.
11. As a CTLD developer, I want the crate record to carry the heading it was created with, so that the record matches the
    world.
12. As a CTLD developer, I want an aircraft double without a position to give no heading rather than an error, so that
    nothing breaks where a heading cannot be read.
13. As a CTLD developer, I want a busted test per creation path, so that a path cannot silently go back to north.

## Implementation Decisions

- **Heading source:** the aircraft's geographic (true) heading, in radians, as the DCS static `heading` expects — the same
  reading the placement code already uses. A heading that cannot be read is treated as absent.
- **Optional input:** the static-creation routine, the crate-spawn routine and the static re-creation routine take an
  optional heading, zero when absent (today's value). The crate record stores it.
- **Callers with an aircraft** pass its heading: the wave spawn and the row spawn (requests and packs), the single
  crate of the radial rule, the scene-pack crates, the unload (a menu drop or any unload: the carrier captured before the
  state change) and the slingload release (the transport).
- **Callers without an aircraft** are unchanged: crates placed by the mission maker, crates landing from a parachute
  descent, crates detected at mission start.
- No change to any position, distance, size or anti-collision. No configuration, schema, catalogue or i18n change.
- Legacy parity: the legacy script also spawned crates with a fixed heading, so this is a deliberate improvement, not a
  parity matter.

## Testing Decisions

- A good test observes the heading handed to DCS when the static is created (and stored in the crate), not how it was
  obtained.
- Seam: a new functional spec with doubles of an aircraft at a known heading and of the DCS static creation. Cases written
  first and seen failing: a requested wave, a single crate through the radial rule, a packed wave, an unload (drop) and a
  slingload release each create the static at the aircraft's heading; the crate record carries it; a crate created with no
  aircraft keeps heading zero; an aircraft whose heading cannot be read gives zero.
- Existing spawn, layout, drop and parachute specs pass unchanged.
- Live DCS: not run for this lot; the visible effect (crate parallel to the aircraft) is for the maintainer to confirm in
  game.

## Out of Scope

- Rotating a crate by an angle other than the aircraft's heading (for example perpendicular for a side row).
- The orientation of vehicles, troops or scene objects.

## Further Notes

No GitHub issue or roadmap entry: raised in conversation on 2026-10-03.
