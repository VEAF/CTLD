# FIX-PLAYER-EVENT-GUARDS — a released `event.initiator` aborts the player-leave cleanup

**Status:** 🔄 in-progress (implemented, PR pending)

Reported from a live VEAF multiplayer session on 2026-09-17 (mission built with veaf-tools,
running the rc9 bundle), found in `dcs.log`:

```
ERROR SCRIPTING: CTLDDCSEventBridge:onEvent handler error [onPlayerLeaveUnit / eventId=21]:
[string "l10n/DEFAULT/CTLD.lua"]:22698: attempt to call method 'getName' (a nil value)
```

Twice in one session, each time immediately after DCS released the slot:

| timestamp | preceding DCS line | delay |
|---|---|---|
| 19:27:16.610 | `ASYNCNET: onPlayerCoalition(5, )` | 1 ms |
| 19:35:50.708 | `ASYNCNET: release unit 1000314` | 1 ms |

So: a coalition change and a slot change. Both defects below are still present on `develop`
(rc10) — verified in `src/`, not in a released bundle.

## The deviation

`CTLDPlayerManager:onPlayerLeaveUnit` ([CTLD_player.lua:371](../../src/CTLD_player.lua#L371)):

```lua
local unit = event and event.initiator
if not unit then return end
local unitName  = unit:getName()   -- raises here
```

`event.initiator` is **not** nil — DCS hands over an object whose underlying unit it has already
released, so the method table is gone. `if not unit` guards against nil and nothing else.

### Why it matters beyond the red line

The bridge wraps each handler in `pcall`, so the raise is contained. But the handler aborts on its
third line, and everything below it never runs:

- `self._players[unitName] = nil` — the departed player is never forgotten;
- the F10 menu teardown for the group;
- `mmgr:cancelPending(groupId)` — added by #147 in rc10, precisely so that a rebuild left
  scheduled for the departing group cannot swallow or delay the **next** occupant's first menu
  build. DCS reuses that numeric groupId. The fix from #147 is therefore silently skipped on every
  slot change, which is the exact situation it was written for.

Nothing recovers the stale entry: `_scanExistingPlayers`
([CTLD_player.lua:285](../../src/CTLD_player.lua#L285)), which re-runs every 30 s forever, only
ever **adds**.

Two consequences in game:

- **Multi-crew**: `groupCount` ([:379](../../src/CTLD_player.lua#L379)) counts ghosts, so
  `groupCount <= 1` is never reached and the group's menu is never torn down.
- **Slot reuse**: the next occupant of a recycled groupId inherits whatever `cancelPending` was
  supposed to drop.

When a human immediately re-occupies the same unit, `onPlayerEnterUnit` overwrites the entry and
rebuilds the menu, which is why this has gone unnoticed.

### It is a family, not one line

Sweeping all 17 handlers registered on `CTLDDCSEventBridge`, **seven** call a method on
`event.initiator` with no guard beyond nil and no `pcall`:

| file | handler |
|---|---|
| `src/CTLD_player.lua` | `onPlayerLeaveUnit` (:371), `onPlayerEnterUnit` (:316), `onLand` (:409), `onTakeoff` (:454) |
| `src/CTLD_zone.lua` | `onDead` (:1169) |
| `src/CTLD_fob.lua` | `onDead` (:373) |
| `src/CTLD_core.lua` | `onAILand` (:650) |

`onPlayerEnterUnit` and `onAILand` reach for `isExist` first, which fails the same way when the
method table is gone.

The other six handlers are already correct — `onUnitDead`, `onTransportDead`, `onCrateDead`,
`CTLDCrateManager:onBirth`, `CTLDVehicleSpawner:onBirth`/`onDead`, `CTLDJTACManager:onBirth` — each
using `pcall` or `obj.isExist and obj:isExist()`. The practice is already in the codebase; it was
not applied everywhere.

## The fix

**One shared helper, not seven ad-hoc guards.** `ctld.utils.safeObjectName(obj)` returns the object's
name or nil, never raises — the single place that knows how a released DCS object misbehaves. The
seven handlers call it and return early on nil, matching what the six correct handlers already do
by hand. Named for objects, not units: `CTLDFOBManager:onDead` reads statics with it.

**A released object comes in two shapes, and the first pass only covered one.** Measured during
review: with the name guarded, `onPlayerEnterUnit` and `onAILand` *still* raised on an object that
answers `getName()` and fails on everything else — both read `isExist()` and `getPlayerName()`
outright, after the guard. `onTransportDead` already calls `pcall(u.isExist, u)` for this exact
reason. Those two follow it now, and both shapes are in the spec.

**Then the cleanup that the guard alone does not restore.** A guard turns the raise into a silent
no-op: the stale `_players` entry and the un-torn-down menu stay. So `onPlayerLeaveUnit`'s body
moves into `CTLDPlayerManager:_forgetPlayer(unitName)` (group count, teardown, `cancelPending`,
registry removal), and `_scanExistingPlayers` gains a reverse pass that calls it for every tracked
unitName whose unit no longer exists or no longer carries a player name. The event stays the fast
path; the 30 s sweep becomes the backstop it already pretends to be.

**A backstop must outlive its own mistakes.** The sweep's add loop reads `isExist()` and
`getPlayerName()` off units returned by `coalition.getPlayers()` without protection — code this lot
did not write and does not rewrite — and the reschedule was the last statement of the same
function. Anything raising in that loop therefore ended the sweep *for the rest of the mission*,
silently, which is the one failure mode a backstop cannot have. The pass moves into
`_scanPlayersOnce`; `_scanExistingPlayers` keeps the reschedule behind a `pcall` and logs a WARN.
Found in review, not by the field report.

## Definition of done

- A `PLAYER_LEAVE_UNIT` carrying a released initiator does not raise, on any of the seven handlers.
- After such an event, the next `_scanExistingPlayers` pass removes the stale `_players` entry,
  tears the group's menu down and calls `cancelPending` — i.e. the outcome is identical to a clean
  leave, one sweep later.
- Multi-crew unchanged: with two tracked players on one groupId, the first leave preserves the
  menu, the second tears it down. True whether the leave arrives by event or by sweep.
- A healthy `PLAYER_LEAVE_UNIT` behaves exactly as today.
- Local spec runner green (1199/1200; the lone failure is `static_watcher_spec`'s `assert.matches`,
  unimplemented in the local runner and failing identically on a clean checkout). `luacheck`
  delegated to CI — the local install is broken. `CTLD.lua` rebuilt and loading under Lua 5.1
  (`tests/ci/smoke/load_built_ctld.lua`).
- `CHANGELOG.md` **Fixed** entry.

## Testing decisions

The seam is the handler, called directly with a hand-built event — the same seam
`tests/ci/unit/player_spec.lua` already uses for the player manager, with its own mock unit/group
tables. A "released" initiator is a plain table with no methods: that is exactly what the runtime
handed us.

- Per-handler, **two shapes each**: an initiator with no methods at all, and one that answers
  `getName()` and raises on the rest (14 cases, enumerated from the registration list, not
  sampled). The second shape is what caught the two incomplete guards.
- The sweep reschedules itself even when its add pass raises.
- Cleanup: after a released-initiator leave, one sweep removes the entry, tears down the menu and
  calls `cancelPending`.
- Multi-crew: first leave keeps the menu, second tears it down — via the sweep, which is the path
  the bug broke.
- Negative control: a healthy leave still works, and the sweep does **not** evict a player whose
  unit is alive and still carries a player name. Without this one the sweep could evict everybody
  and every other test would still pass.

No live DCS scenario. The trigger is a DCS-side object lifetime we cannot schedule on demand, and
the observable is server-side registry state a busted spec reads directly. The reporting session's
`dcs.log` is the field evidence.

## Out of scope

- **`CTLDPlayerTracker`** — never instantiated since 2026-04-02, carries the same bare guards in
  its own `onPlayerEnterUnit`/`onPlayerLeaveUnit`. Deliberately untouched: it does not run, so it
  cannot be part of this bug, and deciding what to do with it is a design question raised
  separately in #150. Wiring it in as-is would reproduce this defect a second time.
- The `coalition.getGroups` sweep in `CTLDVehicleSpawner:_checkNativeLoading` — only its comment is
  corrected here (ticket 03), not its behaviour. That is #150's subject too.
- The six handlers that already guard correctly. They are the reference, not the work.

## Further Notes

- No ADR: applying an existing in-codebase practice to the handlers that missed it.
- Why the sweep rather than a second event subscription: `PLAYER_LEAVE_UNIT` is the only event
  that announces a departure, and it is the one arriving damaged. A backstop that does not depend
  on the event is the only thing that closes the hole.
