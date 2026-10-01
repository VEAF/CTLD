# ADR 0023 — Zones are designated by their registry key everywhere, including in event payloads

**Date:** 2026-10-01
**Status:** Accepted
**Lot:** `FIX-ZONE-REGISTRY-KEY` (extends [ADR 0020](0020-auto-discovered-zones-full-name-key.md)).

## Context

ADR 0020 moved the troop and logistic zone registries to the full DCS name as key, with no short-name
fallback. It updated the public accessors but missed two consumers of the registry: the F10 crate
request menu and the F10 troop embark menu still passed a zone's short name (`log1`, `dropzone1`) to
`getLogisticZone` / `getTroopZone`, which now return nil. Every crate request answered "not close
enough to friendly logistics" and every troop load from an auto-discovered zone answered "Zone not
found." (live DCS test, 2026-09-30).

The registry key is not one field: it is `dcsName` for an auto-discovered zone, but a FOB or a
unit-anchored logistic zone has no `dcsName` and is keyed by its own name. Event payloads were
inconsistent in the same way: `OnZoneSmokeRefreshed` carried `fullName` + `zoneName` for troop zones
but only a short `name` for logistic zones, and `OnTroopZoneUpdated` / `OnLogisticZoneUpdated` carried
the short name as `name`.

## Decision

A zone reports its registry key itself (`registryKey()` on the troop and logistic zone classes).
Anything that designates a zone — a menu callback argument, a lookup, an event payload — uses that key.
The short name stays a display label only.

Event payloads that describe a zone carry the registry key as `name`, in troop and logistic zone
entries alike, and in the `unitsAdded` / `unitsRemoved` lists. `fullName` and the troop-zone `zoneName`
payload fields are removed. No short-name field replaces them: nothing inside CTLD consumes one.

This breaks every mission script reading those payload fields. It is accepted for the same reason as
ADR 0020: CTLD has not shipped a stable public release (`2.0.0-rcN`).

## Considered options

- **Additive `key` field, keep `name` / `zoneName` / `fullName`.** Rejected: nothing would break, but
  two names would stay in every payload and a consumer would still have to know which to trust.
- **Capture the zone object in the menu callback instead of looking it up.** Rejected: a zone removed
  between menu build and click would be used unchecked; the lookup is what re-validates it.
- **Local `dcsName or zoneName` in each menu.** Rejected: duplicates the key rule at every consumer,
  which is how the two menus fell out of step with the registry in the first place.

## Consequences

- One rule, one place: adding a registration path means making `registryKey()` correct for it, and the
  round-trip test (`getXZone(zone:registryKey()) == zone` for every registration path) covers it.
- As with ADR 0020, the justification is time-bound to the release-candidate stage: once CTLD has a
  stable public release, a payload change of this shape needs a migration path.
