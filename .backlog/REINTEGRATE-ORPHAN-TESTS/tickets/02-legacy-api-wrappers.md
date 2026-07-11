# 02 — Legacy API wrappers: routing + deprecation

Status: ✅ done
Type: AFK

## What to build

Busted coverage for the `src/legacy/legacy_api.lua` wrappers — each must route to its modern
target and emit a deprecation warning. Pure logic, fully mockable.

Re-integrates relics:
- F-094 Troops wrappers (6 fn) — routing + deprecation warning
- F-095 Zones wrappers (10 fn) — routing (e.g. `activatePickupZone`→`setTroopZoneActive`)
- F-096 Crates wrappers (3 fn) + `spawnCrateAtZone` functional
- F-097 `createRadioBeaconAtZone` → `createAtZone` + deprecation warning
- F-098 JTAC wrappers (3 fn) — routing (e.g. `JTACAutoLase`→`autoLase`)

## Approach

For each wrapper: stub the modern target method (spy), call the legacy fn, assert the target was
called with the right args and that a deprecation warning was logged. Confirm signatures against
`src/legacy/legacy_api.lua` (relics point at the old `src/compat/` path — dead).

## Acceptance criteria

- [ ] `luac5.1 -p` clean.
- [ ] Every wrapper listed above asserted: routes to correct target + args preserved.
- [ ] Deprecation warning path exercised at least once per wrapper family.
- [ ] `busted` job green.

## Blocked by

Ticket 01 (pattern validation).
