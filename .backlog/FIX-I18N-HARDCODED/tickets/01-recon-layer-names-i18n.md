Status: ready

# 01 — RECON layer names — wrap ctld.tr()

## What to build

The 7 RECON layer names (`"Infantry"`, `"Air Defense (AA)"`, `"Ground Vehicles"`,
`"Helicopters"`, `"Aircraft"`, `"Ships"`, `"FARP / FOB"`) are hardcoded literals in
`_defaultLayers` and injected directly into F10 menu labels and outText messages without
going through `ctld.tr()`. Wrap `layer.name` in `ctld.tr(layer.name)` at both use sites
in `CTLD_recon.lua` (the F10 label formatter and the layer-state outText). Add the 7 keys
to the EN dict and provide FR translations. The `_defaultLayers` table itself is unchanged —
EN strings serve as i18n keys.

## Acceptance criteria

- [ ] Both use sites of `layer.name` in `CTLD_recon.lua` wrap it in `ctld.tr(layer.name)`
- [ ] All 7 layer name keys exist in `CTLD_i18n_en.lua`
- [ ] All 7 keys are translated in `CTLD_i18n_fr.lua`
- [ ] `merge_CTLD.ps1` runs clean (dict sync finds 0 MISSING for these keys)
- [ ] busted unit test verifies `ctld.tr()` is invoked with each layer name at menu-build time
- [ ] `busted tests\ci\unit\` — 0 failures

## Blocked by

None — can start immediately.
