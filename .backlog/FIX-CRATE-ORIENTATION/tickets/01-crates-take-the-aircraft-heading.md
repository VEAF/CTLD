# 01 — Crates take the heading of the aircraft that spawned or dropped them

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-CRATE-ORIENTATION](../PRD.md). Stories 1-13.

## What to build

Give the crate-creation routines an optional heading (zero when absent) and pass the aircraft's geographic heading from
every caller that has one: the wave and row spawns (requests and packs), the single crate of the radial rule, the
scene-pack crates, the unload (menu drop or any unload) and the slingload release. Crates with no aircraft (mission maker,
parachute landing, mission start) keep heading zero. The crate record stores the heading it was created with.

Tests first, in a new functional spec with doubles of an aircraft at a known heading and of the DCS static creation: one
case per path, plus the no-aircraft and unreadable-heading cases. Watch them fail, then implement.

Finish the lot: CHANGELOG, backlog index and statuses, PR (note that the visible effect is for the maintainer to confirm
in game).

## Acceptance criteria

- [ ] New cases fail before the change and pass after it (test committed first).
- [ ] No position, distance or size changes; existing spawn, layout, drop and parachute specs pass unchanged.
- [ ] CHANGELOG entry, index line `merged (PR #NN)`, statuses done; luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
