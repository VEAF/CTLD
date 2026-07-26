# 03 — One navigation by functional family

**Status:** done

## Goal

Remove the `Parameters` / `Data` split (finding 1) and the `Other` dumping ground (finding 8). One
list of functional families; a family owns its settings **and** its structured tables.

## Work

`src/lib/model.ts` / `families.ts`:

- `classify()` no longer returns two screens. It returns, per family: the scalar setting keys
  (split standard/advanced) and the structured keys that belong to it.
- `DATA_FAMILY` — which family each structured key belongs to. Derived from the domain, not from
  the value's shape:
  - `crates` ← `spawnableCrates`, `spawnableCratesModels`, `logisticUnits`, `groundVehicleWeights`
  - `troops` ← `loadableGroups`, `extractableGroups`, `nbLimitSpawnedTroops`
  - `aircraft` ← `capabilitiesByType`, `transportPilotNames`
  - `zones` ← `troopZones`, `wpZones`, `AIZones`, `aiZones`
  - `beacon` ← `beaconIconColor`
  - anything else → `other`
- `familyOf(key, schema)` — schema `group:` wins; otherwise derive from the key prefix
  (`JTAC_*`→jtac, `parachute*`→parachute, `*_WEIGHT`→soldier_weights, `beacon*`→beacon,
  `smoke*`→smoke, `fob*`/`FOB*`→fob, `recon*`→recon, `aa*`/`AASystem*`→aa, `jtac*`→jtac);
  otherwise `other`. Purely name-derived — no invented semantics.
- Two new families (`aircraft`, `zones`) get labels + the family order becomes explicit
  (domain order, not alphabetical): general, aircraft, crates, troops, zones, boarding, fob, jtac,
  recon, aa, beacon, smoke, mines, parachute, soldier_weights, other.
- A per-family icon (inline SVG, no icon dependency) so the rail is scannable.

The family panel renders, in order: its standard settings, its advanced settings (collapsed,
ticket 05), then each of its structured tables under a titled card.

## Done when

- The strings "Parameters" and "Data" appear nowhere in the UI.
- `Other` contains only keys no rule can place; assert in a test that the real key set leaves it
  small.
- Unit tests cover `familyOf` (schema wins, each prefix rule, fallback) and the structured mapping.
- Existing `App.test.ts` expectations are updated to the single navigation.
