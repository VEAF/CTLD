# FIX-SPAWN-COUNTRY-FALLBACK — objects created under a country that is in no coalition, silently

**Status:** 🔄 in progress

Reported by VMCT on 2026-10-09 (VMCT lot `FIX-CAMPAIGN-MISSION-1-FINDINGS`, ticket 05), measured in DCS on a VEAF campaign mission running CTLD 2.0.0-rc12, and still so on `develop` at `affd2c9c`.
David chose to fix the cause in CTLD rather than add USA and Russia to the coalitions of every VMCT mission.

## What happened

The mission's blue coalition holds only CJTF Blue (country id 80), red only CJTF Red (81) — every VEAF campaign mission built by VMCT is like that.
A CH-47F pilot landed in an active logistic zone picks a crate in Request Equipment, and nothing appears.
Replayed through the fiddle hook: `CTLDCrateManager:spawnCrate(descriptor, pos, coalition.side.BLUE, unitName, CTLDCrate.SPAWN_METHOD.MENU_CTLD, nil, "dynamic")` returns nil.
`coalition.getCountryCoalition(country.id.USA)` is 0 in that mission, and `coalition.addStaticObject(country.id.USA, data)` raises; the same static under `country.id.CJTF_BLUE` is created.

## Causes

1. **A hardcoded country.** When a spawn site has no country, it takes `country.id.USA` for blue and `country.id.RUSSIA` for red, whether or not that country is in the coalition:
   - `src/CTLD_crate.lua` `_spawnStatic` (every crate created without a country: Request Equipment, crate sets, crates returning to the ground, mission-maker crates), the menu unpack, the landed-crate unpack;
   - `src/CTLD_jtac.lua` `deployAirJTAC`;
   - `src/CTLD_troop.lua` `spawnGroupAtPoint`;
   - `src/CTLD_beacon.lua` the zone beacon of the scripted API;
   - `src/CTLD_vehicle.lua` `registerJTACVehicle` (`or 2`, USA's id).
   The crate paths that know the requesting aircraft (`spawnCratesAligned`, `_spawnCratesInRow`, the single-crate request) pass no country although they hold the unit.
2. **The failure is swallowed.** `ctld.utils.spawnAs` returns the `pcall` result of `coalition.addStaticObject`, and `ctld.utils.dynAddStatic` ignores it and returns the object data as if created.
   `_spawnStatic` then finds no static and returns nil without a word: the DCS error is logged nowhere.
   The `_log(msg, "WARNING")` calls of `src/CTLD_crate.lua` pass their arguments in the wrong order (`ctld.utils.log(level, fmt, ...)`), so their level is the message.
3. **An unpack that creates nothing says it succeeded.** `_spawnUnpacked` logs a failed spawn but tells nobody, and the menu unpack then announces "unpacked successfully!".

On `develop` the Request Equipment menu already tells the pilot when nothing came out (`FIX-REQUEST-EQUIPMENT-SILENT-FAILURE`, after rc12), but without the cause.

## Decision

One helper, `ctld.utils.resolveCountryId(coalitionId, unit)`, used at every site: the unit's country when there is a live unit; else the lowest country id that `coalition.getCountryCoalition` places on that coalition; only then USA for blue, Russia for red.

## Done when

- A blue coalition without USA gets its crate under the requesting unit's country, and a site without a unit under a country of that coalition.
- No `country.id.USA` / `country.id.RUSSIA` default remains outside the helper.
- A failed static or group creation logs a `WARNING` naming the DCS error and the country, and the requesting group is told.
- busted tests for each; `CHANGELOG.md` `[Unreleased]`; a release VMCT vendors.

## Tickets

1. [01 — the country of the coalition](tickets/01-country-of-the-coalition.md)
2. [02 — a failed creation is visible](tickets/02-failed-creation-visible.md)
