# 01 — Clear `_inAirDebounce[unitName]` when a player is forgotten

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

`CTLDPlayerManager:_forgetPlayer(unitName)` already clears the player registry entry
(`self._players[unitName] = nil`) — the shared teardown path used by both the `PLAYER_LEAVE_UNIT`
handler and the manager's own recovery sweep. Extend it to also clear the flight-state poller's
per-unit debounce record (`self._inAirDebounce[unitName] = nil`) in the same place, so a unit name
DCS later reuses for a different occupant starts with no inherited flight-state history.

## Watch out

- This is the only change needed — do not touch the poller's own cadence/threshold constants, and
  do not extend the fix to any other manager class. A scope audit this session already checked
  `CTLD_core.lua`'s AI-transport-vehicle table and `CTLD_troop.lua`'s in-transit-troops table for
  the same defect class and ruled both out (see the PRD) — don't redo that audit or second-guess it
  without new evidence.
- Clear it unconditionally, the same way `self._players[unitName] = nil` is unconditional — no
  guard needed; nil-ing an absent key is a no-op.

## Acceptance

- After `_forgetPlayer(unitName)` runs, `self._inAirDebounce[unitName]` is `nil`, whether or not an
  entry existed beforehand.
- A unit name reoccupied after its previous occupant was airborne gets no menu rebuild from the
  poller while the new occupant's own flight state stays stable (the outcome the issue itself
  asks a spec to assert).
- No change to the poller's detection speed or debounce behavior for a continuously-occupied unit.

## Tests

`tests/ci/unit/player_spec.lua`'s existing `describe("onPlayerLeaveUnit()", ...)` block (inside
`describe("CTLDPlayerManager onPlayerEnterUnit + onPlayerLeaveUnit", ...)`) already simulates a
player entering then leaving a mocked unit, and already asserts the player registry entry is gone
after leave. Add a sibling test in that same block: seed `mgr._inAirDebounce["mock_pilot"]` with a
fake populated record (`{confirmed = true, pending = nil, ticks = 0}`) before the simulated leave,
then assert it is `nil` afterward — proving the leave path clears a genuinely populated entry, not
a coincidentally absent one. No new test file or seam.
