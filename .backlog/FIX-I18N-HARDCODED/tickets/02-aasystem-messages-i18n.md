Status: ready

# 02 — AA system messages — wrap ctld.tr()

## What to build

Six `outTextForCoalition`/`outTextForGroup` calls in `CTLD_aasystem.lua` use raw
`string.format()` with hardcoded English strings, bypassing `ctld.tr()`. Replace each
with `ctld.tr()` converting `%s`/`%d` placeholders to the CTLD `%1`/`%2`/`%3` convention.
The six messages are: AA limit reached on deploy, AI auto-deploy success, player deploy
success, rearm success, repair failure (no target in range), repair success. Add all 6
keys to the EN dict and provide FR translations.

## Acceptance criteria

- [ ] All 6 `string.format()` calls replaced by `ctld.tr()` with correct `%1`/`%2`/`%3` placeholders
- [ ] All 6 keys exist in `CTLD_i18n_en.lua`
- [ ] All 6 keys are translated in `CTLD_i18n_fr.lua`
- [ ] `merge_CTLD.ps1` runs clean (dict sync finds 0 MISSING for these keys)
- [ ] busted unit test verifies `ctld.tr()` is called with each message key
- [ ] `busted tests\ci\unit\` — 0 failures

## Blocked by

None — can start immediately.
