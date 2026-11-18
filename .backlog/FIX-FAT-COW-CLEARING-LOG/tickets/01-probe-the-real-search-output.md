# 01 — Check the real output of the clearing search

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-FAT-COW-CLEARING-LOG](../PRD.md). Story 14. GitHub issue #299.

## What to build

A one-off, read-only probe of the real `Disposition.getSimpleZones`, run over the DCS bridge's HTTP API on the mission that is loaded (no mission reload, nothing created), so that the definition of a *well-formed candidate* used by ticket 02 rests on what DCS really returns and not on the code's assumption ("a candidate may be a vec2").

- Call the search near a point of the map far from the player, with the three clearances the cow uses (100, 50 and 30 m), a 300 m radius and 10 attempts, as `clearingAt` does.
- Record, for each call: whether the call succeeded, the type of what it returned, the number of candidates, and the exact shape of the first candidate (its type, its keys, vec2 or vec3, `x`/`z` or `x`/`y`).
- Say whether the points the code reads (a table with `x` and a `z`, else a `y`) are what DCS returns.
- If the real shape differs from that assumption, say what it is: ticket 02 then adjusts the definition of *well-formed* before it is written into the tests.

The probe script stays in the scratchpad; its output is pasted in this ticket. Nothing is committed but the ticket.

## Acceptance criteria

- [ ] The probe ran against the live mission and its output (return type, candidate count, shape of the first candidate, for each clearance) is recorded in this ticket.
- [ ] The ticket states whether the code's assumption about a candidate holds on the real output, and the definition of *well-formed* ticket 02 must use.
- [ ] No group, object, setting or timer was created or changed in the mission.

## Blocked by

None - can start immediately.
