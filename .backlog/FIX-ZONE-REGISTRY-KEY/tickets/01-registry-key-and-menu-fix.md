# 01 — Zone registry key and the two F10 menu fixes

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-ZONE-REGISTRY-KEY](../PRD.md). [ADR 0023](../../../dev/adr/0023-zones-designated-by-registry-key-everywhere.md).
Stories 1-8, 13-15.

## What to build

Crate requests and troop loads from auto-discovered zones work again, through one rule: a zone
reports the key it is filed under, and the two menus hand that key to their callbacks.

- A troop zone and a logistic zone each answer `registryKey()`: the key the zone manager files the
  zone under (the DCS name when the zone has one, otherwise the zone's own name field: `zoneName`
  for troop zones, `name` for logistic zones).
- **Request Equipment** (single crates, sets, whole-vehicle entries) and **Load from <zone>** pass
  `registryKey()` as the callback's zone argument. The registry lookup stays in the callback, so the
  active / alive / in-zone checks still run at click time. The troop label keeps its short form; the Request Equipment zone submenu is labelled with the registry key
  (follow-up decided in PR review).
- Order of work: first a busted reproduction of each menu callback over an auto-discovered zone
  (both fail today: "not close enough to friendly logistics" and "Zone not found."), then the fix.
- A round-trip test covers every registration path (auto-discovered TRZ / LGZ / WPZ / EXZ, FOB troop
  and FOB logistic, logistic units, ship / unit-anchored troop zones, AIZ zones, scripted creation):
  looking a zone up by its own `registryKey()` returns that zone. A path where this does not hold is
  fixed here.

## Acceptance criteria

- [ ] Reproduction specs for the crate-request callback and the troop-load callback fail before the
      fix and pass after it.
- [ ] A crate request from an auto-discovered logistic zone spawns the crate; outside the zone, or in
      an inactive or destroyed zone, it is still refused.
- [ ] A troop load from an auto-discovered troop zone embarks the troops; a FOB troop zone still works.
- [ ] `registryKey()` exists on both zone classes and the round-trip test passes for every
      registration path listed above.
- [ ] The troop label still shows its short form (or the existing `displayName` override); the Request
      Equipment zone submenu shows the registry key.
- [ ] No i18n string added or changed; luacheck clean; `busted tests/ci` green.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

None - can start immediately.
