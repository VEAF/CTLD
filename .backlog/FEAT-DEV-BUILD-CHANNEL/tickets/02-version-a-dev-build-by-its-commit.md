# 02 — A dev build says which commit it is

**Status:** todo
**Lot:** FEAT-DEV-BUILD-CHANNEL

## Problem

`--version` reports `ctld.VERSION`, hand-written in `src/CTLD_config.lua:5`. Every build of
`develop` would therefore claim `2.0.0-rc6` until the next release candidate, and a bug report
would name a version shared by a dozen different builds.

## Change

`merge_CTLD.ps1` takes an optional version suffix, used **only** by the dev workflow: the built
engine, and therefore `--version` and the install report, read `<ctld version>-<commit hash>`. A
local build stays `2.0.0-rc6`.

Two neighbouring behaviours were checked and need no change: `configVersion`
(`src/CTLD_config.yaml:5`) is a separate value, so version-gap detection is unaffected; and
`docs_version()` already maps any version containing a dash to the `dev` documentation.

## Acceptance

- [ ] A dev build reports `2.0.0-rc6-<hash>`; a local build reports `2.0.0-rc6`.
- [ ] Installing with a dev build puts that string in the install report and in the engine header.
- [ ] Opening a configuration authored with a dev build raises no version-gap popup.
- [ ] The release workflow's `--version` check (tag vs printed version) still passes.
