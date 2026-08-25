# 02 — `createTroopZoneAtObject` — scripted pickup zone on any named object

**Status:** ✅ done

## Why

The only script-callable troop-zone constructor today, `createExtractZone`, never sets
`pickMaxStock`, so it can never produce a pickup-capable zone (`hasPickup()` stays `false`) — it
can only count an extraction. There is no way to add a `TRZ_…`-equivalent pickup zone at runtime
on something that doesn't exist yet when CTLD initializes (a scene-built FOB, a spawned FARP, a
ship). See the PRD for the full problem statement.

## What changes

- New `CTLDZoneManager:createTroopZoneAtObject(objectName, trzName)`, placed next to
  `createExtractZone` and following its exact style (`boolean` return, `ctld.utils.log` on every
  outcome).
- `trzName` parsed via `parseTRZ` (ticket 01) — coalition, `pickMaxStock`, `objectiveFlag`,
  `objectiveTarget` all come from the string, no separate parameters.
- A local (not shared) resolver tries, in order, until one matches: a Mission Editor trigger zone
  (`trigger.misc.getZone`), a unit or static (`Unit.getByName` / `StaticObject.getByName`), a
  group's first unit (`Group.getByName`), an airbase (`Airbase.getByName`).
- Conditional anchoring on the constructed `CTLDTroopZone`:
  - trigger zone match → `dcsName = objectName` (tracks a DCS Moving Zone via the existing
    `getCenter()` path, same as `createExtractZone`).
  - unit/static/group match → `linkedUnit = <resolved unit>` (tracks it if it moves, same
    mechanism as a ship-anchored troop zone).
  - airbase match → fixed position (no `dcsName`, no `linkedUnit`).
- Radius: the trigger zone's own `.radius` when matched that way; a new local constant
  (`200`) for every other match kind (no radius accessor exists on a unit/static/group/airbase in
  this codebase or the DCS API as far as it's verifiable from here).
- Failure handling, matching `createExtractZone`:
  - unparseable `trzName` → `false` + `ERROR` log, nothing registered.
  - `objectName` matches none of the four kinds → `false` + `ERROR` log, nothing registered.
  - `parsed.zoneName` already present in `_troopZones` → `false` + `WARN` log, nothing changed.
- No new removal function: `removeExtractZone(zoneName)` already clears any `_troopZones` entry
  by name and needs no change to work here.
- No new getter: `getTroopZone(zoneName)` already reads `_troopZones` and needs no change.
- `CHANGELOG.md` `[Unreleased]` entry (this ticket is the one that touches `src/`).

## Acceptance

- Resolving via each of the four object kinds (zone, unit, static, group, airbase) produces a
  zone with the coalition/stock/flag/target the `trzName` string specified.
- A zone anchored via `dcsName` (trigger-zone match) or `linkedUnit` (unit/static/group match)
  tracks the object's position across two evaluations if it moves; an airbase-matched zone stays
  at its captured position.
- Every match kind other than a trigger zone gets the new 200 m default radius; a trigger-zone
  match gets that zone's own radius.
- An unparseable `trzName`, an unresolvable `objectName`, and a duplicate `zoneName` each return
  `false`, log at the right level, and register nothing.
- `removeExtractZone` successfully tears down a zone created by `createTroopZoneAtObject`.
- `getTroopZone` returns a zone created this way.

## Tests

busted, new file `tests/ci/unit/troop_zone_scripted_api_spec.lua`, following the pattern of
`tests/ci/unit/ship_troop_zone_anchor_spec.lua`: `zm = setmetatable({ _troopZones = {},
_logisticZones = {} }, CTLDZoneManager)`, with `trigger.misc.getZone` / `Unit.getByName` /
`StaticObject.getByName` / `Group.getByName` / `Airbase.getByName` faked per test in `before_each`
and restored in `after_each`. Covers every case in Acceptance above, plus the anchor-tracking test
mirroring `ship_troop_zone_anchor_spec.lua`'s "tracks between two evaluations, with no re-init".

## Blocked by

- Ticket 01 (`parseTRZ` promoted to public)
