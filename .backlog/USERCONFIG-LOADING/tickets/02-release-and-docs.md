Status: ⬜ ready

# 02 — Release pipeline and documentation update

## What to build

Add `dist/CTLD_userConfig.lua` as a third release artifact in the GitHub Release workflow,
so Mission Makers can download the config template directly from each release.

Update the Mission Maker documentation to reflect the new loading pattern:
- Trigger order table: `CTLD_userConfig.lua` (optional, first) then `CTLD.lua` (always, second)
- Description updated to explain that `CTLD.lua` auto-starts with factory defaults and that
  the config file is optional

Update the developer documentation to reflect the new build structure:
- Architecture page: build merge list updated (bootstrap file replaces userConfig entry)
- Building-and-testing page: merge order note corrected
- Migration v1→v2 page: reference to userConfig as last-merged file corrected

## Acceptance criteria

- [ ] `release.yml` includes `dist\CTLD_userConfig.lua` in the `gh release create` command
- [ ] `docs/mission-maker/configuration.md` trigger order table shows userConfig before CTLD.lua, marked optional
- [ ] `docs/mission-maker/configuration.fr.md` updated identically (FR)
- [ ] `docs/developer/architecture.md` build structure list reflects `CTLD_bootstrap.lua` (not userConfig) as last merged file
- [ ] `docs/developer/building-and-testing.md` merge order note updated
- [ ] `docs/developer/migration-v1-v2.md` reference to userConfig corrected

## Blocked by

- Ticket 01 — bootstrap split must be complete first
