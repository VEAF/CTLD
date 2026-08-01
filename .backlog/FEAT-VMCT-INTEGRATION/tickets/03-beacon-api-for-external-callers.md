# 03 — public beacon API for a caller that is not a pilot

**Status:** done

## Why

Every way to create a beacon in CTLD 2 goes through
`CTLDBeaconManager:dropBeacon(transport, player, isFOB, overridePosition)`
([CTLD_beacon.lua:324](../../src/CTLD_beacon.lua#L324)). It reads the coalition and the country off
`transport`, offsets the spawn from the aircraft's bounding box, announces the drop to the coalition
and publishes `OnBeaconDropped` with a `player` field. A script that builds a FARP or a FOB has no
transport and no player, so it cannot place a beacon at all — even though the method already accepts
an `overridePosition` and an `isFOB` flag, i.e. it is nine tenths of the way there.

v1 exposed exactly this: `ctld.createRadioBeacon(point, coalition, country, name, batteryLife, isFOB)`
returning `{ vhf, uhf, fm }`, plus `ctld.spawnRadioBeaconUnit()`. Both are used by VMCT to put a
beacon on a scripted FARP and to show pilots its three frequencies. The legacy wrapper file offers
`ctld.createRadioBeaconAtZone` only — a zone, not a point, and no return value.

## What changes

- `CTLDBeaconManager:createAtPoint(point, coalitionId, countryId, opts)` where `opts` carries
  `name`, `batteryMinutes` (`-1` = never expires, as `isFOB` does today) and `isFOB`.
- Returns the `CTLDBeacon`, whose `vhf` / `uhf` / `fm` fields are the caller's answer. Returns `nil`
  on failure, as `dropBeacon` does.
- `dropBeacon` becomes a thin caller of it: resolve coalition/country/position from the transport,
  then delegate. No duplicated spawn/frequency/battery logic.
- The coalition-wide `outText` and the `OnBeaconDropped` publish stay in `dropBeacon`, not in
  `createAtPoint`: a scripted beacon should not announce itself as a pilot drop, and the event
  payload has a `player` field that would be meaningless. If a script wants an event, that is a
  separate `OnBeaconCreated` — do **not** add it speculatively.
- Pair it with a public removal by name (`removeBeacon(name)`), so a caller that creates a beacon on
  a FOB can drop it when the FOB dies. `removeClosestBeacon` is player-shaped for the same reason.
- Respect `enabledRadioBeaconDrop`? **No** — that setting gates the pilot-facing menu action. A
  scripted beacon placed by a mission's own logic is not a player drop. State this in the docstring,
  because the asymmetry will look like a bug to the next reader.

## Acceptance

- A script places a beacon at an arbitrary point with no unit in the mission, reads back its three
  frequencies, and removes it by name.
- The beacon transmits, appears on the map layers, and expires on its battery exactly as a dropped
  one does.
- `dropBeacon` behaviour is unchanged — same announcement, same event, same offset when on the ground.

## Tests

- busted: `createAtPoint` returns a beacon carrying three non-nil, non-colliding frequencies.
- busted: two successive calls get different frequencies from the pool; removing the first frees its
  frequencies back.
- busted: `createAtPoint` publishes no `OnBeaconDropped` and emits no `outTextForCoalition`.
- busted: `dropBeacon` still does both.
- Integration (L3, `auto`): a beacon created by injected Lua is audible/visible in a live mission.
