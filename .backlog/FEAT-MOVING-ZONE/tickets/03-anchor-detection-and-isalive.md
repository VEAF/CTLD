Status: ready

# 03 — Moving Zone anchor detection at init + `isAlive()` / `isDynamic()` extension

## What

At zone discovery time, read `zd.linkUnit` from `env.mission.triggers.zones`. If present, the
zone is a Moving Zone anchored to a unit. Resolve the unit name by iterating
`coalition.getGroups()` (lazy, per zone with a linkUnit). Store the name as `_anchorUnitName`
in the zone entity.

Extend `isAlive()` and `isDynamic()` on both `CTLDLogisticZone` and `CTLDTroopZone`:
- `isDynamic()`: returns true if `_linkedUnit ~= nil` OR `_anchorUnitName ~= nil`
- `isAlive()`: if `_anchorUnitName` set → `Unit.getByName(_anchorUnitName) ~= nil and :isExist()`

## Scope

- Local helper `_resolveUnitNameById(unitId)` in `CTLDZoneManager`: iterates
  `coalition.getGroups(side)` for all sides, returns unit name or nil.
- `_discoverLGZ()`: if `zd.linkUnit`, call helper, pass `anchorUnitName` to `CTLDLogisticZone:new()`.
- `_discoverTRZ()`: same, pass `anchorUnitName` to `CTLDTroopZone:new()`.
- `CTLDLogisticZone:init`: store `self._anchorUnitName = data.anchorUnitName or nil`.
- `CTLDTroopZone:init`: same.
- `CTLDLogisticZone:isDynamic()`: updated.
- `CTLDLogisticZone:isAlive()`: updated.
- `CTLDTroopZone:isDynamic()`: new method.
- `CTLDTroopZone:isAlive()`: new method (currently always true implicitly).
- Busted tests: mocked `coalition.getGroups`, `Unit.getByName` — verify resolution, isDynamic,
  isAlive true/false.

## Definition of done

- Zones with `linkUnit` in the .miz populate `_anchorUnitName`.
- `isDynamic()` returns true for anchored zones on both entity types.
- `isAlive()` returns false when the mock anchor unit is dead/nil.
- luacheck clean.
