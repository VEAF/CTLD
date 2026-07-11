# 04 — Deploy managers: AA assembly, FOB events, pack vehicle

Status: ✅ done
Type: AFK

## What to build

Busted coverage for the crate-assembly, FOB-manager and pack-vehicle contracts.

Re-integrates relics:
- F-021 AA assembly complete (`tryUnpackOrRepair`/`_assemble`) → `OnAASystemDeployed` + crates destroyed
- F-022 AA assembly incomplete → no deployment
- F-023 AA repair (`_repair`) → `OnAASystemRepaired` + group replaced
- F-012 FOB deployed (`_registerDeployedFOB`) → `OnFOBDeployed` payload + `_objectToFOB` reverse lookup
- F-013 FOB `onDead`/`_destroyFOB` → integrity threshold + `OnFOBDestroyed` + cleanup
- F-099 `findPackableVehicles` + `packVehicle` → `OnVehiclePacked` + crates spawned

## Approach

Event capture via `EventDispatcher`. For AA/FOB/pack: stub spawn/destroy primitives
(`coalition.addStaticObject`, group spawn, `crate:destroy`) and assert events + registry effects.
NB (from audit): `OnAASystemRepaired` is published nowhere else — F-023 is its only coverage.
Pack vehicle now spawns crates via `spawnCratesAligned` and refreshes via deferred
`timer.scheduleFunction` — assert accordingly, not the stale relic assumptions.

## Acceptance criteria

- [ ] `luac5.1 -p` clean.
- [ ] AA: complete (deploy + crates consumed), incomplete (no deploy), repair (event) all asserted.
- [ ] FOB: deploy event + reverse lookup, destroy event + cleanup asserted.
- [ ] Pack vehicle: `findPackableVehicles` result + `packVehicle` event/crates asserted.
- [ ] `busted` job green.

## Blocked by

Ticket 01.
