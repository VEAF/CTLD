# 01 — The country of the coalition, not USA or Russia

**Status:** ✅ done (PR #256)

Files: `src/CTLD_utils.lua` (new `ctld.utils.resolveCountryId`), `src/CTLD_crate.lua`, `src/CTLD_jtac.lua`, `src/CTLD_troop.lua`, `src/CTLD_beacon.lua`, `src/CTLD_vehicle.lua`, busted tests.

## What to do

- `ctld.utils.resolveCountryId(coalitionId, unit)`: the live unit's `getCountry()`; else the lowest id of `country.id` that `coalition.getCountryCoalition` places on `coalitionId`; else `country.id.USA` (blue) / `country.id.RUSSIA` (red).
- Replace every hardcoded default with it; the crate paths that hold the requesting aircraft pass its country.

## Done when

- busted: the helper's three steps in order; a Request Equipment click in a mission whose blue holds only CJTF Blue creates the crate under CJTF Blue; a crate created without a unit goes under a country of its coalition.
