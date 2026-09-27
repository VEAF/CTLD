# 01 — Extract `CTLDAnchoredZone`, reconcile `CTLDLogisticZone`'s field names

**Status:** 🔄 in-progress

**Blocked by:** none.

## What to build

New `CTLDAnchoredZone = class()` in `CTLD_zone.lua` holding `_linkedUnit`, `_anchorUnitName`,
`dcsName`, `center`, plus `getCenter()`/`isDynamic()`/`isAlive()` — moved verbatim from
`CTLDTroopZone` (the version to keep, since its field names are already public/unprefixed).
`CTLDTroopZone = class(CTLDAnchoredZone)` and `CTLDLogisticZone = class(CTLDAnchoredZone)` both
inherit it. `CTLDLogisticZone`'s `_dcsZoneName`/`_center` are renamed to `dcsName`/`center`
throughout (5 references, all within `CTLD_zone.lua` — verified, no external caller uses the old
names).

## Watch out

- Behavior must be byte-for-byte unchanged — this is a pure move-and-rename, not a rewrite. Diff
  the moved methods against their two originals to confirm.
- `CTLDTroopZone:init()`/`CTLDLogisticZone:init()` must still accept the exact same constructor
  `data` shape callers already pass (`dcsName`/`center` for troop zones, `dcsZoneName`/`center` for
  logistic zones per its own doc comment — check whether the constructor's *external* parameter
  name for the Mission-Editor zone name field also needs to change, or only the internal storage
  field; if callers pass `dcsZoneName = ...` today, decide whether to keep accepting that
  constructor key name for compatibility even though the stored field becomes `self.dcsName`).
- Don't touch `CTLDZoneManager`, `_destroyFOB`, or any registration method — this ticket is
  confined to the two entity classes.
- Don't build the generic owner-registry or touch the truck use-case — both explicitly out of
  scope, see PRD.

## Acceptance

- `CTLDAnchoredZone` exists; `CTLDTroopZone`/`CTLDLogisticZone` both inherit from it.
- `getCenter()`/`isDynamic()`/`isAlive()` exist once, not twice.
- `CTLDLogisticZone`'s stored fields are `dcsName`/`center` (not `_dcsZoneName`/`_center`).
- Every existing test involving zone anchoring (ship-anchored troop zones, any logistic-zone
  anchor coverage) passes unchanged.
- `busted tests/ci/` passes with no change in pass count.
- `CTLD.lua` rebuilds and passes `luac5.1 -p`.
- `luacheck --config .luacheckrc src` stays at 0 warnings, 0 errors.

## Tests

None new — this is a refactor with unchanged observable behavior. `tests/ci/unit/
ship_troop_zone_anchor_spec.lua` and any existing `CTLDLogisticZone` anchor coverage are the
regression proof; locate and confirm both classes' existing anchor-behavior tests still pass
unchanged before considering this done.
