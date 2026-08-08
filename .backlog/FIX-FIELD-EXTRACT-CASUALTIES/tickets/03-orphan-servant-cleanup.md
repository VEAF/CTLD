Status: ready

# 03 — Despawn orphaned mortar servant on reaching zero logical troops

## Parent

`.backlog/FIX-FIELD-EXTRACT-CASUALTIES/PRD.md`

## What to build

**Scope widened during implementation**: `onUnitDead` is registered on the DCS event bridge as a
raw `S_EVENT_DEAD` handler (`bridge:register(tm, world.event.S_EVENT_DEAD, "onUnitDead")`,
`CTLD_core.lua`), which calls it as `onUnitDead(event)` — yet the function is written to receive
`unitName` (a string) directly, and never unwraps `event.initiator:getName()` the way every other
`S_EVENT_DEAD` handler in this codebase does (`onTransportDead`, `CTLDVehicleSpawner:onDead`,
`CTLDZoneManager:onDead`, `CTLDFOBManager:onDead`). In production this means `onUnitDead` never
matches a real dead unit — `_findGroupByAliveUnit` always misses — so it is currently a no-op, and
so is the JTAC deregistration-on-death path that depends on it (`CTLD_jtac.lua:778`). Without
fixing this, ticket 03's reactive cleanup would pass its unit tests (which call the method
directly) but never actually fire in a live mission. Fixed here as part of the same change, since
it is the same function and the same handler.

Fix `onUnitDead` to accept the DCS `event` table and extract `local unitName =
event.initiator:getName()` first (guarding for a nil/missing initiator), matching the existing
pattern used by `onTransportDead` and the other bridge-registered `onDead` handlers. The rest of
the function keeps operating on `unitName` as before.

Then, extend `onUnitDead`: after removing the dead unit from a *deployed* (dropped, not
in-transit) group's live view, use the shared logical-count helper (ticket 01) to check whether
the group's logical count is now 0 while its DCS group still has units (i.e. only `SVNT_*`
servants remain alive — the mortar operator died, the servant did not).

If so, destroy the residual DCS group immediately and purge it from `_droppedGroups[coalition]`
and `_droppedTemplates[groupName]` — the same purge already performed by `_removeFromDropped`. Do
not change the existing JTAC-deregistration behavior already present in `onUnitDead` (beyond
fixing the event-unwrap that was preventing it from firing at all).

## Acceptance criteria

- [ ] `onUnitDead` accepts a DCS `event` table (as the bridge actually calls it) and extracts the
      dead unit's name from `event.initiator`; a missing/nil `event.initiator` is a safe no-op.
- [ ] A dropped group where the last real troop-role unit dies while a `SVNT_` unit remains alive
      triggers `group:destroy()` and removal from both `_droppedGroups` and `_droppedTemplates`.
- [ ] A dropped group where a non-last real troop-role unit dies (other real troops still alive)
      triggers neither `destroy()` nor removal — the group stays on the field as today.
- [ ] A dropped group with no `SVNT_` units at all behaves exactly as today when its last unit
      dies (no new code path engaged).
- [ ] JTAC deregistration on death (`deregisterJTAC`) actually fires given a real `event` shape —
      covering both the pre-existing behavior this fix unblocks and ticket 03's own logic.
- [ ] `busted tests/ci/` passes clean; `luacheck --config .luacheckrc src/` clean.

## Blocked by

- `01-logical-count-fix-and-filtering.md` (needs the shared logical-count helper).
