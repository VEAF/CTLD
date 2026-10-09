# 02 — A failed creation is visible

**Status:** 🔄 in progress

Files: `src/CTLD_utils.lua` (`dynAddStatic`), `src/CTLD_crate.lua` (`_spawnStatic`, `_spawnUnpacked`, the menu unpack, the `_log` calls), i18n dictionaries, busted tests, `CHANGELOG.md`.

## What to do

- `dynAddStatic` returns false and the DCS error when `spawnAs` fails, instead of the object data.
- `_spawnStatic` logs a `WARNING` with the error and the country when no static results.
- `_spawnUnpacked` returns whether it created the group and tells the unpacking group when it did not; the menu unpack announces success only then.
- The `_log` calls of `src/CTLD_crate.lua` pass the level first.

## Done when

- busted: a Request Equipment click whose static creation raises tells the pilot and logs a `WARNING` holding the DCS error; an unpack whose group creation fails tells the group and does not announce success.
- `CHANGELOG.md` `[Unreleased]`.
