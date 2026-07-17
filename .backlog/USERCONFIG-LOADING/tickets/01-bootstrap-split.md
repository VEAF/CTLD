Status: ⬜ ready

# 01 — Extract bootstrap and separate config template from the build

## What to build

Create a new `CTLD_bootstrap.lua` source file by relocating the engine bootstrap code
(the `ctld.initialize()` function definition and the `ctld.dontInitialize` auto-start guard)
out of `CTLD_userConfig.lua` into this new file. Add it as the last entry in the build merge
list (after `legacy/legacy_api.lua`), so `CTLD.lua` continues to auto-start with factory
defaults — zero behavioural change for existing missions.

Strip `CTLD_userConfig.lua` down to MM-facing content only: the `ctld` nil-guard and the
`ctld.yamlConfigDatas` YAML template. Remove it from the build merge list so it is no longer
embedded in `CTLD.lua`.

Update the build script to copy `src/CTLD_userConfig.lua` to `dist/CTLD_userConfig.lua` as
part of every build, producing it as a standalone deliverable alongside `CTLD.lua`.

## Acceptance criteria

- [ ] `CTLD_bootstrap.lua` exists in `src/` and is the last file in the merge list
- [ ] `CTLD_userConfig.lua` is absent from the merge list
- [ ] `CTLD.lua` built from the new list auto-starts CTLD with factory defaults (no regression)
- [ ] `dist/CTLD_userConfig.lua` is produced by the build script
- [ ] Loading `dist/CTLD_userConfig.lua` before `CTLD.lua` (setting one YAML override) results in that override being applied after init
- [ ] `ctld.dontInitialize = true` set before `CTLD.lua` still suppresses auto-start
- [ ] `busted tests/ci/` passes unchanged (CI loader unaffected)
- [ ] CHANGELOG `[Unreleased]` updated

## Blocked by

None — can start immediately.
