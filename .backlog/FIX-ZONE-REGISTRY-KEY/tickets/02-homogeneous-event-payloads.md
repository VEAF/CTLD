# 02 — Event payloads identify zones by registry key

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-ZONE-REGISTRY-KEY](../PRD.md). [ADR 0023](../../../dev/adr/0023-zones-designated-by-registry-key-everywhere.md).
Stories 9-12, 20.

## What to build

Every event payload that describes a zone identifies it the same way, in troop and logistic entries.

- `OnZoneSmokeRefreshed`, `OnTroopZoneUpdated`, `OnLogisticZoneUpdated`: each zone entry's `name` is
  the zone's registry key.
- The `unitsAdded` / `unitsRemoved` lists of the two `...ZoneUpdated` events carry the same `name`
  key (they currently use `zoneName` or `unitName` depending on the caller).
- The `fullName` field and the troop-zone `zoneName` payload field are removed. No short-name field is
  added. This is a deliberate breaking change for the release-candidate stage (ADR 0023).
- `docs/developer/events.md` and `events.fr.md` describe the new shapes. Any other doc quoting these
  payloads is updated in the same slice.

## Acceptance criteria

- [ ] One busted spec per payload (`OnZoneSmokeRefreshed`, `OnTroopZoneUpdated`,
      `OnLogisticZoneUpdated`) asserts `name` is the registry key for troop and logistic entries.
- [ ] A spec asserts the `unitsAdded` / `unitsRemoved` entries carry `name` and that `fullName` and the
      troop `zoneName` payload fields are gone.
- [ ] The only internal subscriber (the player menu refresh) still works; its existing specs pass.
- [ ] `events.md` and `events.fr.md` updated; luacheck clean; `busted tests/ci` green.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Changed` entry flagging the breaking payload change.

## Blocked by

- [01 — Zone registry key and the two F10 menu fixes](01-registry-key-and-menu-fix.md)
