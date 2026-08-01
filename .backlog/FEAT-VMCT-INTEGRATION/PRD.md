# FEAT-VMCT-INTEGRATION — what CTLD 2 must expose for the VEAF Mission Creation Tools

**Status:** open.

Opened 2026-08-01, from the CTLD 2 ↔ VMCT integration audit. VMCT (the VEAF mission build pipeline)
is switching its bundled CTLD from the v1 monolith to CTLD 2, in one move — no dual-engine period.
Two decisions on the VMCT side frame this lot:

- **Configuration leaves VMCT.** VMCT stops emitting `ctld.<key> = value` lines from `mission.yaml`.
  A mission carries a dedicated `ctld-config.yaml` (a complete snapshot, authored in `ctld-tools`)
  that the VMCT build injects as a MISSION START trigger before `CTLD.lua`. The ~170 hardcoded
  configuration lines in VMCT's `veaf.lua` become a short VEAF patch applied over
  `ctld.configDefault` at build time.
- **VMCT keeps only the low-level integration code** — the bridges by which VEAF's own runtime
  modules talk to CTLD.

Auditing those bridges one by one turned up three things CTLD 2 does not expose. Each is a gap on
its own merits, independent of VMCT: they are all "a caller that is not a player in a cockpit".

## The bridges, and where they land

| VMCT site | What it does today (v1) | CTLD 2 |
|---|---|---|
| `veafSpawnAircraft` ×3 | `ctld.JTACAutoLase` / `ctld.cleanupJTAC` | ✅ `CTLDJTACManager:autoLase()` / `:stopAutoLase()` |
| `veafGrass`, `veafSpawnGround`, `veafSpawnEffects` | `table.insert(ctld.logisticUnits, name)` | ✅ `CTLDZoneManager:registerFOBAsLogistic()` — already documented "external callers" |
| `veaf.lua` `autoInitializeAllLogistic()` | scans the mission, every carrier / FARP-ammo static becomes a logistic point | ❌ **ticket 01** |
| `veaf.lua` `autoInitializeAllPickupZones()` | every ship becomes a troop pickup point | ❌ **ticket 02** |
| `veafGrass` (FARP beacon), `veafSpawnGround` (FOB beacon) | `ctld.createRadioBeacon(point, coalition, country, name, battery, isFOB)` → `{vhf, uhf, fm}` | ❌ **ticket 03** |

The first two are 50 lines of scanning logic living in VMCT because v1 offered no hook. They are not
VEAF-specific: "treat every carrier as a logistic point" is what most mission makers want and what
they currently hand-write, ten unit names at a time, into `logisticUnits`. Moving them here deletes
the VMCT code rather than porting it.

Ticket 02 also uncovered an unrelated parity defect — a ship-backed troop zone is frozen at init —
which left this lot as `FIX-SHIP-ZONE-ANCHOR-PARITY` and **blocks** ticket 02.

The third is a real hole in the beacon surface: `CTLDBeaconManager:dropBeacon()` takes a `transport`
unit and a `player` name, so nothing outside a cockpit can place a beacon — even though the manager
already supports `overridePosition` and `isFOB`.

## Definition of done

- A mission can declare, in configuration, that units of given types are logistic points, without
  naming each one (ticket 01).
- The same for ship-borne troop pickup points (ticket 02).
- A script can create and remove a radio beacon at an arbitrary point and read back its assigned
  frequencies, with no player and no transport unit (ticket 03).
- Each addition is reachable from the config schema and documented for the Mission Maker in EN + FR.
- No VMCT-specific naming or behaviour enters `src/`.

## Out of scope

- Anything on the VMCT side: rewriting its bridges, generating `ctld-config.yaml`, retiring
  `veaf.ctld_initialize_replacement`. Tracked in the VMCT repo.
- Routing CTLD logs into VEAF's logger — VMCT does that by overriding `ctld.utils.log`, which needs
  nothing here.
- The v1 `logistic #001` / `pickzone #001` placeholder names VMCT used to inject. VMCT drops them;
  the `LGZ_` / `TRZ_` prefix discovery already covers that need.
