# 01 — Guard the seven handlers that call a method on a released `event.initiator`

**Status:** ✅ done

See the PRD for the field trace. Short version: DCS delivers `S_EVENT_PLAYER_LEAVE_UNIT` with an
`initiator` whose unit it has already released, so `unit:getName()` raises. `if not unit` only
guards nil.

## What changes

**`src/CTLD_utils.lua`** — new helper:

```lua
--- Return a DCS object's name, or nil if it cannot be read.
-- DCS hands released objects to event handlers: `event.initiator` is non-nil but its
-- method table is gone, so `obj:getName()` raises "attempt to call method (a nil value)".
-- @param obj table  a DCS Unit/StaticObject, possibly already released
-- @return string or nil
function ctld.utils.safeObjectName(obj)
```

Returns nil when `obj` is nil, when `obj.getName` is not callable, or when the call raises.
Returns nil for an empty-string name too — an unusable name is the same as none.

**The seven call sites** each replace their bare read with the helper and return early on nil:

| file | handler | line |
|---|---|---|
| `src/CTLD_player.lua` | `onPlayerLeaveUnit` | 371 |
| `src/CTLD_player.lua` | `onPlayerEnterUnit` | 316 |
| `src/CTLD_player.lua` | `onLand` | 409 |
| `src/CTLD_player.lua` | `onTakeoff` | 454 |
| `src/CTLD_zone.lua` | `onDead` | 1169 |
| `src/CTLD_fob.lua` | `onDead` | 373 |
| `src/CTLD_core.lua` | `onAILand` | 650 |

`onPlayerEnterUnit` and `onAILand` also call `isExist()` and `getPlayerName()`: moving them behind
the name guard is **not** enough, measured in review — a released object can answer `getName()` and
raise on everything else, and both handlers still raised. Those two reads are `pcall`'d, the way
`CTLDTroopManager:onTransportDead` already does it.

`CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- **The guard alone is not the fix.** It converts a raise into a silent no-op, and the stale
  `_players` entry stays. Ticket 02 is what restores the cleanup — do not close this lot on 01.
- Do **not** touch the six handlers that already guard correctly (`onUnitDead`,
  `onTransportDead`, `onCrateDead`, `CTLDCrateManager:onBirth`,
  `CTLDVehicleSpawner:onBirth`/`onDead`, `CTLDJTACManager:onBirth`). They are the reference for
  the shape of the fix, not part of it — rewriting them onto the helper would be an opportunistic
  refactor.
- Do **not** touch `CTLDPlayerTracker` (`src/CTLD_core.lua:308-329`), which has the same bare
  guards. It is never instantiated, so it cannot produce this bug; see #150.
- `ctld.utils.log` must not be called from inside the helper — it would fire on every AI death
  event that carries a released object, which is routine, not an anomaly.

## Acceptance

- [x] `ctld.utils.safeObjectName` returns nil (no raise) for: nil, `{}`, an object whose `getName`
      raises, and an object returning `""`. Returns the name for a healthy object.
- [x] Each of the seven handlers returns without raising for **both** shapes of a released
      object: `{ initiator = {} }`, and an initiator answering `getName()` while raising on every
      other method.
- [x] A healthy event still reaches each handler's existing behaviour unchanged.
- [x] Local spec runner green (1199/1200 — the one failure is `static_watcher_spec` using `assert.matches`, which the local runner does not implement; it fails identically on a clean checkout). `luacheck` delegated to CI: the local install is broken (rocks under Lua 5.5).
