# 01 — UH-1H realism fix + Mi-8MT whole-vehicle completion

**Status:** ✅ done

## What changes

`src/CTLD_config.yaml`, `capabilitiesByType`:

- `UH-1H`: `canTransportWholeVehicle: true` → `false`; `maxTroopsOnboard: 8` → `10`.
- `Mi-8MT`: add `maxVehicleWeight: 3000`, `loadableVehiclesBLUE` (`M1045 HMMWV TOW`,
  `M1043 HMMWV Armament`, `Hummer`), `loadableVehiclesRED` (`BRDM-2`, `BTR_D`); raise
  `maxWholeVehiclesOnboard` from `0` to `1`.

Regenerate the derived artifacts:

```powershell
poetry -C tools\ctld-tools run ctld-tools gen --yaml src\CTLD_config.yaml --out tests\ci\data\config_defaults.json
powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1
```

`tests/ci/unit/player_spec.lua`, `CTLDPlayerManager _detectCapabilities` describe block: the
`UH-1H: canCarryVehicles == true (CTLD config)` case flips to `is_false`, comment corrected.

## Watch out

- `Mi-8MT.maxVehicleWeight` must be a lift-capacity figure (external sling-load rating), not the
  airframe's MTOW — every sibling entry in this table already follows that convention
  (`UH-1H`: 1360, `CH-47Fbl1`: 11000, `C-130J-30`/`Hercules`: 20000 — all lift capacity, not MTOW).
- Do not touch `Mi-8MT.maxTroopsOnboard` or `canParachuteDrop` — out of scope.
- `tests/ci/data/config_defaults.json` is generated, never hand-edited — `config_spec.lua` diffs
  the real parsed config against it.

## Acceptance

- `capabilitiesByType.UH-1H.canTransportWholeVehicle == false` and `.maxTroopsOnboard == 10` in
  the built config.
- `capabilitiesByType.Mi-8MT.canTransportWholeVehicle == true` with a functional
  `maxWholeVehiclesOnboard >= 1`, a non-nil `maxVehicleWeight`, and both loadable-vehicle lists.
- `tools/lua-test/run_specs.ps1` (or CI's `busted`) green, including `config_spec.lua` (the
  regenerated oracle matches) and `player_spec.lua`'s corrected `UH-1H` case.

## Tests

`tests/ci/unit/player_spec.lua` (existing seam, corrected assertion) +
`tests/ci/unit/config_spec.lua` (existing oracle-diff seam, exercised by regenerating
`config_defaults.json`). No new spec file — both seams already existed and already covered this
shape of change; nothing new to seam here.
