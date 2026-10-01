# 03 — Make the configuration and catalogue versions visible

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-CTLD-TOOLS-CONFIG-COMPLETION](../PRD.md). [ADR 0011](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md)
Addendum 1. Stories 13, 14, 15, 17, 27.

## What to build

The version stops being invisible. The catalogue version (independent of the CTLD release number) is shown where a
Mission Maker or a maintainer looks when something is out of date:

- **The tool's header** shows the version the opened configuration was written against and the version the tool's
  catalogue carries; the opening summary repeats both.
- **The engine's start-up notice** for absent parameters adds the configuration's version and the CTLD catalogue
  version, so a screenshot of the notice is enough to understand the cause. The text is new and goes through the
  usual translation and dictionary regeneration; the engine still defaults a missing parameter.
- **`validate`** prints both versions when they differ.

## Acceptance criteria

- [x] The header shows both versions and flags a difference.
- [x] The opening summary shows both versions.
- [x] The start-up notice for absent parameters names the configuration's version and the catalogue version, for a
      snapshot that lacks parameters; a complete configuration shows no notice, as today.
- [x] A hand-written configuration that never met the tool still starts, defaults the parameter and shows the notice.
- [x] `validate` prints both versions when they differ and nothing extra when they are equal.
- [x] The new notice text has its dictionary entries (build regenerates them); the i18n guard passes.
- [x] `busted tests/ci/`, luacheck, ctld-tools tests, `ruff check`, `ruff format --check`, `npm run check` pass.

## Blocked by

- [02 — Complete the missing fields of list entries](02-complete-list-entry-fields.md)
