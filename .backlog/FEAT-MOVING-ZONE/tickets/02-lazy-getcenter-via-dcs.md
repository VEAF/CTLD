Status: ready

# 02 — Lazy `getCenter()` via `trigger.misc.getZone()` for LGZ_ and TRZ_

## What

Replace the position snapshot in `getCenter()` with a live call to `trigger.misc.getZone(name)`.
Store `self._dcsZoneName` (the ME zone name) at construction. On each `getCenter()` call, query
DCS for the current position. Fall back to `self._center` if the API returns nil.

Priority order in `getCenter()` (both `CTLDLogisticZone` and `CTLDTroopZone`):
1. `self._linkedUnit:getPoint()` if linkedUnit set and alive (LGZ legacy — unchanged)
2. `trigger.misc.getZone(self._dcsZoneName).point` if dcsZoneName set
3. `self._center` (static fallback)

For TRZ_: `dcsName` already exists in `CTLDTroopZone`. Use it as `_dcsZoneName`.
For LGZ_: add `_dcsZoneName` populated from the zone's DCS name in `_discoverLGZ()`.

For AIZ_ (config-based, not ME-prefix): `_dcsZoneName` already populated from `entry.dcsZoneName`
in `_loadAIZonesFromConfig()` — same field, no change needed in the config path.

## Scope

- `CTLDTroopZone:getCenter()`: use `self.dcsName` as the DCS zone name for the lookup.
- `CTLDLogisticZone:getCenter()`: add step 2 (trigger.misc.getZone) before the `_center` fallback.
- `CTLDLogisticZone:init`: accept and store `dcsZoneName` from constructor data.
- `_discoverLGZ()`: pass `dcsZoneName = name` to `CTLDLogisticZone:new()`.
- Busted tests: verify `getCenter()` returns the value from the mocked `trigger.misc.getZone`.
  Verify fallback to `_center` when mock returns nil.

## Definition of done

- `getCenter()` calls `trigger.misc.getZone()` at every invocation (no snapshot).
- Static zones: behavior identical to before (trigger returns fixed position).
- Fallback: `_center` used when `trigger.misc.getZone()` returns nil.
- luacheck clean.
