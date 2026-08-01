# FIX-SHIP-ZONE-ANCHOR-PARITY — a troop zone carried by a ship is frozen at init

**Status:** done — the radius question is answered: **200 m**, v1's hardcoded value, as a named
constant in `CTLD_zone.lua`. `maximumDistancePackableUnitsSearch` governs a different search and
was never v1's value here, so keeping it would have been a second deviation, not a deliberate one.
No migration note: nothing for a mission maker to do.

Opened 2026-08-01, found while auditing the CTLD 2 ↔ VMCT integration
(`FEAT-VMCT-INTEGRATION` ticket 02). Independent of that lot: the defect exists for any mission whose
troop pickup point is a ship, VMCT or not.

## The deviation

A `troopZones` entry whose name matches no trigger zone falls back to a unit lookup — the documented
way to make a carrier a pickup point.

**v1** ([migration/source/CTLD.lua:10716](../../migration/source/CTLD.lua#L10716), `ctld.inPickupZone`)
resolves the position **on every check**: `trigger.misc.getZone(name)` first, and when that returns
nil, `ctld.getTransportUnit(name):getPoint()` with a hardcoded radius of 200 m ("should be big enough
for ship"). The zone follows the vessel.

**v2** ([CTLD_zone.lua:857](../../src/CTLD_zone.lua#L857), `_loadLegacyZones`) snapshots
`ship:getPoint()` once at init and stores it as the zone's `center`. `CTLDTroopZone:getCenter()`
([:335](../../src/CTLD_zone.lua#L335)) only knows two sources — a DCS trigger zone by `dcsName`, else
the stored `center`. It has **no** `linkedUnit` branch, unlike `CTLDLogisticZone:getCenter()`
([:387](../../src/CTLD_zone.lua#L387)) which resolves `linkedUnit > trigger zone > center`.

So a carrier steams away and its pickup point stays in the water where the mission started. Silently:
`CTLDTroopZone` even carries an `_anchorUnitName` field and an `isAnchored()` / `isAnchorAlive()`
pair ([:97](../../src/CTLD_zone.lua#L97), [:343](../../src/CTLD_zone.lua#L343)) — the anchor is known,
it just never reaches `getCenter()`.

This is an undeclared parity deviation, not a design decision: nothing in the docs, the ADRs or the
migration guide says a ship-borne pickup zone stopped following its ship. `FEAT-MOVING-ZONE` (PR #49)
established the opposite principle — a zone resolves its position lazily — and unified `getCenter()`
across zone types; this path was missed.

## What changes

- `CTLDTroopZone:getCenter()` gains a `linkedUnit` branch, in the same precedence order as
  `CTLDLogisticZone:getCenter()`: linked unit → trigger zone → stored centre.
- `_loadLegacyZones` passes the resolved ship as `linkedUnit` instead of snapshotting its point.
- Radius for a ship-backed zone: **200 m**, v1's value. It is currently
  `maximumDistancePackableUnitsSearch`, which is a second, separate deviation — fixing the anchor
  while leaving a different radius would only trade one for the other. If keeping the setting is
  preferred, that is a deliberate deviation and needs saying so in the migration guide.
- `isAnchorAlive()` already covers the ship's destruction; confirm a sunk carrier freezes the zone at
  its last position rather than crashing `getCenter()`.

## Definition of done

- A troop zone backed by a ship tracks that ship.
- `CHANGELOG.md` records it as a **fix** (restored v1 behaviour), not a change.
- No migration note: nothing for a mission maker to do, the old behaviour was the bug.
- The radius question is answered in writing, either way.

## Out of scope

- Discovering ships by type instead of by name — `FEAT-VMCT-INTEGRATION` ticket 02, which depends on
  this one.
- The logistic path, which is already correct.
