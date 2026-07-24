# Ticket 01 — Externalisation audit inventory (✅ scope validated by David 2026-07-24)

**Verdict:** externalise **A (7 mm-facing)** + **4 advanced** (`jtacLaserCodeMin/Max`,
`defaultVehicleWeight`, `fieldExtractTroopWeight`, `defaultZoneRadius`). Demoted to stays-code:
`minUnpackDistance`, `aaSpawnRadius`, `jtacOrbitSpeed`, `troopMarchSpeed`. Beacon freq pools stay
in code. Everything in section C stays in code.


Rule: **"would a mission-maker want to tune this per mission?"** yes → externalise (mm-facing or
advanced); no (internal timing / thresholds / workarounds / engine mechanics) → **stays-code**.
Conservative by default. Behaviour-preserving (same defaults). Nothing below is externalised until
this scope is validated.

## A. Recommended `mm-facing` (externalise → MM section) — 7

| file:line | proposed key | value | controls |
|---|---|---|---|
| CTLD_crate.lua:573,610 | `loadCrateSearchRadius` | 50 | radius to group/load crates from the Load Crate menu |
| CTLD_crate.lua:675,720,826 | `unpackSearchRadius` | 300 | radius to gather crates for unpack / List Nearby Crates |
| CTLD_aasystem.lua:147 | `aaRearmDistance` | 300 | max launcher-crate→system distance to rearm/repair |
| CTLD_aasystem.lua:148 | `aaAssemblyDistance` | 500 | max crate→reference distance to assemble an AA system |
| CTLD_fob.lua:213,216 | `fobCrateCollectionRadius` | 750 | radius within which FOB crates must be gathered |
| CTLD_beacon.lua:106 | `beaconRemovalRadius` | 500 | search radius for "Remove Closest Beacon" |
| CTLD_crate.lua:1503 | `slingCutDestroyHeight` | 40 | AGL above which cutting a slingload destroys the crate |

## B. Candidate `advanced` (externalise → advanced section) — 8, David to trim

| file:line | proposed key | value | controls |
|---|---|---|---|
| CTLD_crate.lua:753 | `minUnpackDistance` | 50 | min distance from transport to spawn an unpacked vehicle |
| CTLD_aasystem.lua:146 | `aaSpawnRadius` | 50 | circle radius placing AA units around the reference |
| CTLD_jtac.lua:186-187 | `jtacLaserCodeMin/Max` | 1111/1688 | assignable JTAC laser-code pool bounds |
| CTLD_jtac.lua:1192 | `jtacOrbitSpeed` | 100 km/h | flying-JTAC orbit speed fallback |
| CTLD_troop.lua:845 | `troopMarchSpeed` | 50 | speed of troops marching to a WPZ / attacking |
| CTLD_vehicle.lua:1434 | `defaultVehicleWeight` | 2500 | weight assumed for a vehicle absent from `groundVehicleWeights` |
| CTLD_troop.lua:1005 | `fieldExtractTroopWeight` | 130 | per-troop weight when extracting a field group w/o stored data |
| CTLD_zone.lua:652,810 | `defaultZoneRadius` | 500 | radius when a discovered TRZ/WPZ/AIZ zone lacks one |

## C. `stays-code` (NOT externalised — internal, ~35)

Rationale category → the swept constants that are engine mechanics, not MM knobs:

- **Poll/tick/reschedule cadences** — static watcher 1s, slot rescan 180s/30s, AI transport loop 2s,
  smoke tick 15s, LGZ poll 10s, crate-count watcher 5s, JTAC orbit 3s/60s, menu debounce 0.15s,
  player flight poll 0.5s/2-tick, vehicle load/pack/hover cadences, troop count watchers 5s.
- **LOS / geometry offsets** — JTAC LOS +2m, recon LOS 180m, recon moved-threshold 5m, JTAC moved 5m,
  assembly/FOB origin +100m ahead, FOB beacon offset 5m, vehicle spawn `_secureOffset` factor.
- **Native-cargo / physics thresholds** — native-load speed guard 0.5 m/s, unload drift 1.0m,
  in-flight AGL 5m, native-parachute poll 1s/120s/3m AGL, inAir stationary 0.5 m/s, soldier weight
  randomisation band, fast-rope buffer/speed.
- **Workaround delays** — beacon transmission start +1s, AI-land retry +1.5s.
- **Niche/derived** — beacon freq pools & power (VHF/UHF/FM ranges), radio power 1000, recon icon
  base sizes (already scaled by `reconIconScale`).

## Open borderline calls for David

- **beacon freq pools** (B or C?): a few MMs may want custom dropped-beacon frequency ranges. Left in
  C (stays-code) by default — promote to `advanced` if wanted.
- Any A/B row David wants demoted to C (keep the surface lean) or promoted A↔B.
