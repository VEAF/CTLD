# 02 — Make the 30 s sweep forget players whose slot is gone

**Status:** ✅ done

Ticket 01 stops the raise. It does not bring back the cleanup that the raise skipped: the departed
player stays in `_players`, the group's F10 menu is never torn down, and `mmgr:cancelPending` — the
#147 fix against a recycled groupId — is never called. Nothing recovers it, because
`_scanExistingPlayers` only ever adds.

## What changes

**`src/CTLD_player.lua`.**

1. Extract the body of `onPlayerLeaveUnit` ([:371](../../src/CTLD_player.lua#L371)) into
   `CTLDPlayerManager:_forgetPlayer(unitName)`, unchanged: group count over `_players`, menu
   teardown when `groupCount <= 1`, `mmgr:cancelPending(groupId)`, `self._players[unitName] = nil`,
   the INFO log. It returns early when `unitName` is not tracked.
   `onPlayerLeaveUnit` becomes: resolve the name (ticket 01), then `self:_forgetPlayer(unitName)`.

2. `_scanExistingPlayers` ([:285](../../src/CTLD_player.lua#L285)) gains a reverse pass, after the
   existing add loop. For each `unitName` in `_players`, evict when the slot is no longer held by
   a human:
   - `Unit.getByName(unitName)` returns nil, **or**
   - the unit does not `isExist()`, **or**
   - `getPlayerName()` returns nil (slot released, or taken over by AI).

   Every one of those reads goes through `pcall` — this pass runs against units DCS may be
   releasing right now, which is the whole point of the ticket. Collect the names first, then
   evict, and never mutate `_players` while iterating it.

   Log one INFO line with the count when the pass evicts anything, mirroring the existing
   `built menu for %d player(s) via scan`.

## Watch out

- **`_forgetPlayer` must stay the only teardown path.** Two copies of the group-count logic is how
  the multi-crew rule silently diverges.
- **Multi-crew is the case that matters**, and the group count runs over what is left in
  `_players` — so evict one name at a time, calling `_forgetPlayer` per name, rather than
  bulk-deleting then tearing down. Bulk deletion first would make the count read 0 and tear the
  menu down while a crew member is still flying.
- `getPlayerName()` returning nil is a legitimate eviction (AI took the slot), not an error. No
  warning log.
- The reschedule must survive a raising pass, and "last statement" does not achieve that: the
  pre-existing add loop reads `isExist()`/`getPlayerName()` unprotected, so one raise there ended
  the sweep for the whole mission. The pass is `_scanPlayersOnce`, called under `pcall` by
  `_scanExistingPlayers`, which owns the reschedule.
- Do not shorten the 30 s period to make the backstop feel faster. The event is still the fast
  path, and this pass now walks every tracked player.

## Acceptance

- [x] After `onPlayerLeaveUnit` receives a released initiator, the next `_scanExistingPlayers`
      removes the entry, tears the group's menu down and calls `cancelPending` — the same end
      state as a clean leave.
- [x] Multi-crew: two players on one groupId, both slots released; one sweep evicts both, the menu
      is torn down exactly once, and it is not torn down after the first eviction alone.
- [x] A player whose unit exists and still returns a player name is **not** evicted (negative
      control — without it, an over-eager sweep passes every other case).
- [x] `Unit.getByName` raising does not break the sweep: the pass completes and reschedules.
- [x] A raise in the **add** pass does not stop the sweep either — it still reschedules.
- [x] A healthy `onPlayerLeaveUnit` still cleans up immediately, without waiting for a sweep.
- [x] Local spec runner green (1199/1200 — the one failure is `static_watcher_spec` using `assert.matches`, which the local runner does not implement; it fails identically on a clean checkout). `luacheck` delegated to CI: the local install is broken (rocks under Lua 5.5).
