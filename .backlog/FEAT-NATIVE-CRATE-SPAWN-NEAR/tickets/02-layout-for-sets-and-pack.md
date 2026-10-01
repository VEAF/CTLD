# 02 — Crate rows just clear of the hull for requested sets and packed vehicles

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-NATIVE-CRATE-SPAWN-NEAR](../PRD.md). [ADR 0024](../../../dev/adr/0024-native-crates-spawn-at-hull-clearance.md).
Stories 1-9, 12, 14, 18.

## What to build

Crates requested as a set and the crates produced by packing a vehicle appear in a row just clear of the
aircraft, when its type declares a sector and a distance.

- One pure function computes the positions: the crates stand in a row perpendicular to the sector axis, centred on
  the aircraft, at the declared distance (a `side` sector picks one side at random for the whole wave, within 60°
  to 120°); neighbours are `size/2 + gap + size/2` apart, using the size of the two crates concerned. A row holds
  as many crates as fit along the aircraft's own box; the next row is one step further out.
- The spawn entry for sets and packing uses it for a type with a declared sector and distance, and keeps today's
  radial layout, secure distance and spacing for any other type.
- The requesting aircraft's neighbours are respected: when the chosen side lands inside another aircraft's volume
  the other side is tried first, then the existing rotation as a last resort.
- The reply to the player (clock position and distance) describes the new position.

## Acceptance criteria

- [ ] For a declared type, the first crate is at the declared distance on the declared sector and the others in
      the same row, neighbours `size + gap` apart; none overlaps another.
- [ ] A set larger than a row wraps to a second row one step further out.
- [ ] Pack of a vehicle (4 crates) and a request set use the same layout.
- [ ] A type with no declared values spawns exactly as before (same distance, spacing and sector).
- [ ] A neighbour's volume on the chosen side moves the wave to the other side.
- [ ] Busted specs cover each rule above through the spawn entry with doubles.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Changed` entry.

## Blocked by

- [01 — Capability fields](01-capability-fields-and-defaults.md)
