# 02 — troop pickup zones on ships, without naming each ship

**Status:** todo

Sibling of 01, same shape, different zone family. Read 01 first.

## Why

`_loadLegacyZones` already supports a ship as a troop zone: when a `troopZones` entry's name matches
no trigger zone, it falls back to `Unit.getByName()` and snapshots the ship's position
([CTLD_zone.lua:857](../../src/CTLD_zone.lua#L857)). Two limits:

1. every ship must be named in the config, one by one;
2. the position is **snapshotted at init**, so a ship that moves leaves its pickup zone behind.

Point 2 turned out to be a parity defect, not a design choice — v1 re-resolves the position on every
check — and it is now `FIX-SHIP-ZONE-ANCHOR-PARITY`, independent of this lot. **Depends on it**: a
discovery that produces frozen zones is worse than no discovery.

VMCT worked around point 1 with `autoInitializeAllPickupZones()`: it walks every ship in the mission
and declares each one a pickup zone. Crude — *every* ship, no type filter — but it makes carrier ops
work.

## What changes

- A new **list** setting `troopZoneShipTypes` (empty by default), symmetric with `logisticUnitTypes`.
- At init, every existing unit whose type matches becomes a `CTLDTroopZone` anchored to the unit —
  reusing the anchoring `FIX-SHIP-ZONE-ANCHOR-PARITY` puts in `CTLDTroopZone:getCenter()`, not a
  second mechanism.
- Radius: the same one the parity fix settles on for a ship-backed zone (v1 uses a hardcoded 200 m).
  Do **not** reach for `maximumDistancePackableUnitsSearch` here — that would swap one deviation for
  another.
- Coalition from the object, unlimited stock, active.
- Same precedence rule as 01: an explicitly configured zone of the same name wins.
- Type validation: same two places as ticket 01 (`CTLDTypeCollector` block + `ctld-tools validate`).

## Acceptance

- A config listing `CVN_71` gives a working pickup point on that carrier, named nowhere.
- Troops can be loaded from the carrier after it has moved several kilometres.
- Empty / absent setting changes nothing.

## Tests

- busted: listed ship type → one troop zone; unlisted → none.
- busted: name collision with a configured `troopZones` entry → one zone, the configured one.
- (the "centre tracks the unit" test belongs to `FIX-SHIP-ZONE-ANCHOR-PARITY`, not here)
