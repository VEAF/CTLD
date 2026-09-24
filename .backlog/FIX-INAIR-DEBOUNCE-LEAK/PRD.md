# FIX-INAIR-DEBOUNCE-LEAK — clear the flight-state debounce record when a player is forgotten

**Status:** ✅ done (PR #192).

Closes [GitHub issue #156](https://github.com/VEAF/CTLD/issues/156) ("The flight-state debounce
record outlives the player, and the next occupant inherits it", davidp57/Zip, found via an
automated review of the PR vendoring rc11 into VEAF-Mission-Creation-Tools) on merge. The
reporter's own issue text already resolves root cause, fix, and desired test outcome; a brief
`grill-with-docs` pass this session confirmed nothing else remains open — read the decisions below
as settled.

## Problem Statement

A Mission Maker's transport slot can be occupied by different pilots over the course of a mission
(DCS reuses unit names). When a new occupant takes the same slot on the ground, right after a
previous occupant left it while airborne, they get an unsolicited F10 menu wipe-and-rebuild about a
second into their slot — a state transition that never actually happened to them. A player who
opens the F10 menu in that first second can click an entry that gets rebuilt out from under them.

## Solution

`CTLDPlayerManager`'s flight-state poller keeps a per-unit-name debounce record
(`confirmed`/`pending`/`ticks`) to detect takeoff/landing faster than DCS's own events. Nothing
ever clears this record when a player leaves — so a new occupant of a reused unit name inherits
the previous occupant's `confirmed` flight state, and the poller treats the mismatch against the
new occupant's *real* (correct) state as a genuine transition, debounces it, and fires a menu
rebuild that should never have happened. The fix clears the record in the same shared teardown
path that already clears the manager's other per-unit-name table when a player is forgotten.

## User Stories

1. As a Mission Maker running a transport slot that gets reassigned between pilots over a mission,
   I want a new occupant's F10 menu to reflect only their own real state, so that nothing rebuilds
   underneath them based on a previous, unrelated occupant's history.
2. As a pilot taking a transport slot on the ground, I want my F10 menu to stay stable in my first
   seconds in the seat, so that a menu entry I click has not just been silently rebuilt under me.
3. As a pilot who just landed or taken off, I want the flight-state poller's fast detection (faster
   than DCS's own delayed takeoff/landing events) to keep working exactly as it does today, so that
   this fix does not regress the responsiveness it exists to provide.
4. As a developer maintaining `CTLDPlayerManager`, I want every per-unit-name table this manager
   owns to be cleared through the same shared teardown path, so that a future per-unit cache added
   to this manager has an obvious, established place to hook its own cleanup.
5. As a developer investigating this fix later, I want the audit of other per-unit-name tables
   across `src/` (performed once, this session) recorded, so that I don't have to redo it or wonder
   whether it was skipped.

## Implementation Decisions

- `CTLDPlayerManager`'s shared player-teardown path (used by both the `PLAYER_LEAVE_UNIT` handler
  and the manager's own recovery sweep) is extended to clear the flight-state debounce record for
  the forgotten unit name, alongside the player registry entry it already clears there. Both
  per-unit-name tables this manager owns are now cleared through the exact same path, so neither
  can drift out of sync with the other again.
- No change to the poller's own cadence or debounce threshold (a 0.5 s poll interval, 2 consecutive
  matching ticks before committing a state change) — those are correct today; only the
  stale-carryover defect is fixed.
- **Scope audit (performed this session, do not redo)**: every other per-unit-name table in `src/`
  was checked for the same defect class. `CTLD_core.lua`'s AI-transport-vehicle tracking belongs to
  a completely separate lifecycle (AI units, not players) and is unaffected. `CTLD_troop.lua`'s
  in-transit-troops table is a list, not a flag; even if its key outlived a full disembarkation, an
  empty list is functionally identical to an absent one for every place that reads it, so it carries
  no misleading stale value the way the debounce record's `confirmed` flag does. Neither is the
  same bug, and neither is touched by this fix. This audit does not extend to manager classes not
  yet examined for an unrelated defect (see Out of Scope).

## Testing Decisions

- Only external behaviour is tested — what the debounce record looks like after the manager forgets
  a player, not the poller's internal tick-counting mechanics.
- `tests/ci/unit/player_spec.lua` already has a suite exercising this manager's player-enter and
  player-leave paths, including an existing assertion that the player registry entry is gone after
  a simulated leave. The new test sits alongside it: seed a fake, populated debounce record for the
  mocked unit first (so the test proves an existing entry gets cleared, not merely a coincidentally
  absent one), trigger the same simulated leave, and assert the debounce record is gone too —
  matching this suite's own established style of asserting directly on the manager's internal state.
  No new test file or seam is introduced.

## Out of Scope

- Auditing manager classes elsewhere in `src/` (crates, vehicles, JTAC, etc.) for an unrelated
  per-unit-table lifecycle defect of their own — the two candidates surfaced this session were
  checked and ruled out; anything else is a fresh investigation, not part of this fix.
- Any change to the flight-state poller's timing constants.

## Further Notes

No ADR: no new domain term is introduced, and the fix does not meet the bar of being hard to
reverse, surprising without context, or the result of a genuine trade-off — it mirrors an
already-established pattern (the player registry's own clear-on-forget) in the same function.
