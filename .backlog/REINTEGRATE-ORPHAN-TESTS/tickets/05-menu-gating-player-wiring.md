# 05 — Menu gating by config + player event wiring

Status: ✅ done
Type: AFK

## What to build

Busted coverage for F10 menu section gating (by config flag / transport capability) and the
player-manager event wiring.

Re-integrates relics:
- F-048 buildMenu all flags ON → all sections present
- F-049 `enableCrates`=false → Request Equipment/Crate Commands absent, Smoke/Beacons present
- F-050 `enabledRadioBeaconDrop`=false → Radio Beacons absent
- F-052 `JTAC_jtacStatusF10`=false → JTAC absent
- F-053 `enabledFOBBuilding`=false → List FOBs absent (under Crate)
- F-054 `enablePackingVehicles`=false → Pack Vehicle absent
- F-055 non-transport player → root + Check Cargo only; RECON/JTAC still present
- F-056 `canCarryVehicles`=true → Vehicle Commands present
- F-075 clearBranch + repopulate + refresh → new cmds present, old absent
- F-077 `refreshMenuForGroup` unknown group → `{success=false, refreshedCount=0}`
- F-088 `_loadUserConfig` ingests `ctld_config_user.customLoadableGroups`/`disableLoadableGroups`
- F-089 troop menu filters by disabled / side / capacity
- F-025 `OnVehicleLoaded/Unloaded` events → `player.loadedVehicles` updated

## Approach

Use the `pm:buildMenu(playerObj)` + `menu:_getNode(path)` pattern (confirmed working in
`troop_multi_spec`). Toggle `ctld.gs(configKey)` per test (save/restore). Section presence via
node lookup. NB: `refresh()` is debounced/async now — drive synchronous rebuilds via
`refreshMenuForGroup`. F-089: `buildMenu(unit,gid,opts)` is gone → target `refreshMenuSection`
(side filter at `CTLD_troop.lua:1858`).

## Acceptance criteria

- [ ] `luac5.1 -p` clean.
- [ ] Each config flag toggles the expected section on/off; non-transport & capacity gates asserted.
- [ ] `refreshMenuForGroup` unknown-group failure shape asserted.
- [ ] `_loadUserConfig` custom+disable ingestion asserted.
- [ ] Player `loadedVehicles` event wiring asserted.
- [ ] `busted` job green.

## Blocked by

Ticket 01.
