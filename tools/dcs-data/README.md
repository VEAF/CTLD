# DCS data — vendored type-name set

`gen_dcs_types.py` produces `tests/data/dcs_types.lua`: the set of known stock DCS
type names (units + statics + heliports), extracted from
[`Quaggles/dcs-lua-datamine`](https://github.com/Quaggles/dcs-lua-datamine) pinned at
`DATAMINE_REF`.

- **Not shipped**: `tests/data/dcs_types.lua` is used only by the offline config linter
  (`tests/ci/unit/config_types_lint_spec.lua`); it is never added to
  `tools/build/listToMerge.txt`, so `CTLD.lua` stays lean.
- **Extraction**: in the datamine dump each unit is `_G/db/Units/<Category>/<Type>/<TypeName>.lua`
  and the basename equals the DCS spawn `type` id — so the set is just those basenames
  (purely-numeric helper files excluded).

## Refresh (manual, needs network — CI does not run this)

```bash
python tools/dcs-data/gen_dcs_types.py   # from repo root
```

To pick up a newer DCS dump: bump `DATAMINE_REF` in `gen_dcs_types.py`, re-run, commit the
regenerated `tests/data/dcs_types.lua`.

## Crate spawn distances (`derive_crate_spawn.py`)

Recomputes the `crateSpawnDistance` declared for each native-cargo aircraft (ADR 0024): the static hull
pieces of the model's collision shell are cut at crate height above the ground, the largest distance from
the aircraft centre inside the type's sector is the hull radius, and the declared distance is that radius
plus 1.5 m. Run it after a DCS update to see whether a value moved.

```bash
export EDM_PARSER_DIR=/path/to/Blender_EDM_reverse/io_edm_importer   # holds edm_parser.py
export DCS_ROOT="/path/to/Eagle Dynamics/DCS World OpenBeta"
python tools/dcs-data/derive_crate_spawn.py
```

It prints, per type, the sector, the radius, the distance to declare and the collision shell the value
comes from. Neither the parser nor the shells are part of this repository; a type whose file is missing
is reported as skipped.
