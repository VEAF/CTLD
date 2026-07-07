# DCS data — vendored type-name set

`gen_dcs_types.py` produces `tests/data/dcs_types.lua`: the set of known stock DCS
type names (units + statics + heliports), extracted from
[`Quaggles/dcs-lua-datamine`](https://github.com/Quaggles/dcs-lua-datamine) pinned at
`DATAMINE_REF`.

- **Not shipped**: `tests/data/dcs_types.lua` is used only by the offline config linter
  (`tests/ci/unit/config_types_lint_spec.lua`); it is never added to
  `tools/build/listToMerge.txt`, so `CTLD_Next.lua` stays lean.
- **Extraction**: in the datamine dump each unit is `_G/db/Units/<Category>/<Type>/<TypeName>.lua`
  and the basename equals the DCS spawn `type` id — so the set is just those basenames
  (purely-numeric helper files excluded).

## Refresh (manual, needs network — CI does not run this)

```bash
python tools/dcs-data/gen_dcs_types.py   # from repo root
```

To pick up a newer DCS dump: bump `DATAMINE_REF` in `gen_dcs_types.py`, re-run, commit the
regenerated `tests/data/dcs_types.lua`.
