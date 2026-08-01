# 01 — anchor a ship-backed troop zone to its ship

**Status:** done

See the PRD for the v1 reference behaviour and the two call sites.

## What changes

1. `CTLDTroopZone:getCenter()` ([CTLD_zone.lua:335](../../src/CTLD_zone.lua#L335)): add the
   `linkedUnit` branch, matching `CTLDLogisticZone:getCenter()`
   ([:387](../../src/CTLD_zone.lua#L387)) — linked unit (if `isExist()`) → `trigger.misc.getZone` by
   `dcsName` → stored `center`.
2. `CTLDTroopZone:init()`: accept `data.linkedUnit`, as `CTLDLogisticZone:init()` does.
3. `_loadLegacyZones` ship fallback ([:857](../../src/CTLD_zone.lua#L857)): pass the resolved unit as
   `linkedUnit` instead of freezing `ship:getPoint()` into `center`. Keep the snapshot as the
   fallback value so a sunk ship leaves the zone at its last known position.
4. Radius: **200 m** (v1's hardcoded value), replacing `maximumDistancePackableUnitsSearch`.

## Watch out

- The polygon path in `isInZone` rebuilds absolute vertices from `getCenter()` + `_vertexOffsets`. A
  ship-backed zone has no vertices, so it takes the radius path — but check that the added branch
  does not change the vertex path's behaviour for TRZ zones with a moving anchor.
- Everything else calling `getCenter()` (smoke scheduler, `getTroopZoneAtPoint`, menu distance
  checks) then follows the ship for free. That is the intent; make sure the smoke scheduler does not
  cache a position from a previous pass.

## Acceptance

- Ship at position A at init, moved to B: `getTroopZoneAtPoint(B)` finds the zone, `A` does not.
- Troops can be loaded from the carrier after it has moved.
- Zones backed by a trigger zone, and TRZ zones with a Moving Zone anchor, are unaffected.
- Sinking the ship leaves the zone at its last position (no error from `getCenter()`).

## Tests

- busted: mock unit at A → zone centre A; move the mock to B → zone centre B, no re-init.
- busted: `isExist() == false` → centre stays at the last known point.
- busted: a trigger-zone-backed troop zone still resolves through `trigger.misc.getZone`.
- busted: the radius of a ship-backed zone is 200.
