Status: ready

# 03 — Despawn orphaned mortar servant on reaching zero logical troops

## Parent

`.backlog/FIX-FIELD-EXTRACT-CASUALTIES/PRD.md`

## What to build

Extend `onUnitDead`: after removing the dead unit from a *deployed* (dropped, not in-transit)
group's live view, use the shared logical-count helper (ticket 01) to check whether the group's
logical count is now 0 while its DCS group still has units (i.e. only `SVNT_*` servants remain
alive — the mortar operator died, the servant did not).

If so, destroy the residual DCS group immediately and purge it from `_droppedGroups[coalition]`
and `_droppedTemplates[groupName]` — the same purge already performed by `_removeFromDropped`. Do
not change the existing JTAC-deregistration behavior already present in `onUnitDead`.

## Acceptance criteria

- [ ] A dropped group where the last real troop-role unit dies while a `SVNT_` unit remains alive
      triggers `group:destroy()` and removal from both `_droppedGroups` and `_droppedTemplates`.
- [ ] A dropped group where a non-last real troop-role unit dies (other real troops still alive)
      triggers neither `destroy()` nor removal — the group stays on the field as today.
- [ ] A dropped group with no `SVNT_` units at all behaves exactly as today when its last unit
      dies (no new code path engaged).
- [ ] Existing JTAC-deregistration behavior in `onUnitDead` is unaffected.
- [ ] `busted tests/ci/` passes clean; `luacheck --config .luacheckrc src/` clean.

## Blocked by

- `01-logical-count-fix-and-filtering.md` (needs the shared logical-count helper).
