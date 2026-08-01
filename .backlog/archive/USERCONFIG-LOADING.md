# USERCONFIG-LOADING

**Status:** delivered. Compacted from `USERCONFIG-LOADING/` on 2026-08-01; the ticket files live on in git history.

`CTLD_userConfig.lua` removed from build merge; new `CTLD_bootstrap.lua` keeps auto-start in deliverable; userConfig delivered in `dist/` as standalone MM template. PR #32.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-bootstrap-split` | ⬜ ready | 01 — Extract bootstrap and separate config template from the build |
| `02-release-and-docs` | ⬜ ready | 02 — Release pipeline and documentation update |

## PRD

Status: ⬜ ready

## USERCONFIG-LOADING — Separate user config template from the CTLD deliverable

### Problem Statement

Mission Makers cannot customise CTLD without modifying `CTLD.lua` directly. The user
configuration template (`CTLD_userConfig.lua`) is currently merged into `CTLD.lua` as the last
file in the build. This means:

- Every CTLD update overwrites the Mission Maker's configuration.
- The Mission Maker has no independent config file to version-control or share across missions.
- `CTLD_userConfig.lua` mixes two unrelated responsibilities: the MM-facing configuration
  template (a YAML string of override values) and the engine bootstrap (`ctld.initialize()` and
  its auto-start guard).

The file header already documents the intended usage ("load AFTER CTLD.lua in the mission via DO
SCRIPT FILE") but this is impossible in practice because the file is merged into the deliverable.

### Solution

Split `CTLD_userConfig.lua` into two separate files with single responsibilities:

1. **Engine bootstrap** — a new `CTLD_bootstrap.lua` added last to the build merge list.
   Contains `ctld.initialize()` and the `ctld.dontInitialize` auto-start guard. `CTLD.lua`
   continues to auto-start with factory defaults, preserving backward compatibility for all
   existing missions.

2. **MM configuration template** — `CTLD_userConfig.lua` removed from the merge list and
   delivered as a standalone file in `dist/`. Mission Makers who want to customise CTLD load
   it **before** `CTLD.lua` via a DO SCRIPT FILE trigger. Missions that do not load it
   continue to work unchanged (factory defaults apply).

Loading pattern after this lot:

| # | Trigger | File | Required? |
|---|---------|------|-----------|
| 1 | DO SCRIPT FILE | `CTLD_userConfig.lua` | Optional — only if customising |
| 2 | DO SCRIPT FILE | `CTLD.lua` | Always |

### User Stories

1. As a Mission Maker, I want a separate `CTLD_userConfig.lua` file that I can edit freely,
   so that updating `CTLD.lua` to a new version does not overwrite my configuration.

2. As a Mission Maker, I want to version-control my configuration independently of the CTLD
   deliverable, so that I can track my own changes without merging diffs against a generated
   file.

3. As a Mission Maker, I want CTLD to work out of the box with a single `DO SCRIPT FILE`
   trigger (no config file required), so that I can get started quickly without reading
   documentation.

4. As a Mission Maker, I want clear documentation explaining where to place the config trigger
   relative to the CTLD trigger, so that I do not accidentally load them in the wrong order.

5. As a Mission Maker using an existing mission, I want my current setup (loading only
   `CTLD.lua`) to keep working after this change with no modifications, so that upgrading
   CTLD does not break my mission.

6. As a developer releasing CTLD, I want `CTLD_userConfig.lua` to be included automatically
   in the GitHub Release alongside `CTLD.lua`, so that Mission Makers can download it as a
   ready-to-use template.

7. As a developer, I want the engine bootstrap (`ctld.initialize()`) to live in a dedicated
   source file rather than in the MM-facing template, so that the build structure reflects
   the responsibility of each file.

8. As a developer, I want the CI test loader to remain unaffected by this change, so that
   the unit test harness does not require updates.

9. As a developer writing documentation, I want the architecture docs to accurately reflect
   the new build structure (bootstrap file, userConfig out of merge), so that future
   contributors understand the correct module layout.

### Implementation Decisions

- **New `CTLD_bootstrap.lua`**: a new source file containing exactly the `ctld.initialize()`
  function definition and the `ctld.dontInitialize` auto-start guard block. It is added as
  the last entry in `listToMerge.txt`, after `legacy/legacy_api.lua`. No logic changes —
  this is a pure relocation of existing code.

- **`CTLD_userConfig.lua` removed from merge**: the file is removed from `listToMerge.txt`.
  It retains only the MM-facing content: the `if ctld == nil then ctld = {} end` guard and
  the `ctld.yamlConfigDatas = [[...]]` YAML template (all entries commented out by default).
  No YAML content changes.

- **Build script produces `dist/CTLD_userConfig.lua`**: `merge_CTLD.ps1` copies
  `src/CTLD_userConfig.lua` to `dist/CTLD_userConfig.lua` at each build, alongside the
  existing `dist/CTLD_asset_check.lua` output.

- **`release.yml` updated**: `dist\CTLD_userConfig.lua` added as a third artifact in the
  `gh release create` command.

- **`tests/ci/helpers/loader.lua` unchanged**: the CI loader already stops at
  `legacy/legacy_api.lua` and loads neither `CTLD_userConfig.lua` nor the bootstrap. Unit
  test behaviour is identical before and after.

- **Loading contract**: when `CTLD_userConfig.lua` is loaded before `CTLD.lua`,
  `ctld.yamlConfigDatas` is set in the global environment. `CTLDConfig:load()` (called inside
  `ctld.initialize()`, which runs at the end of `CTLD.lua`) reads the variable if present and
  applies the overrides. If the variable is absent (no userConfig loaded), factory defaults
  apply silently — no error, no warning.

- **`ctld.dontInitialize` flag unchanged**: the flag continues to suppress the auto-start
  when set to `true` before `CTLD.lua` is loaded. This use case is unaffected.

- **ADR not warranted**: the change is a straightforward file relocation with a clear
  motivation (separation of concerns). No surprising trade-off requiring future justification.

### Testing Decisions

Good tests for this lot verify the **observable loading contract**, not internal module
structure:

- Loading `CTLD.lua` alone → CTLD initialises with factory defaults (no error, no warning
  about missing `ctld.yamlConfigDatas` in non-debug mode).
- Loading a minimal `CTLD_userConfig.lua` stub (sets one override) before `CTLD.lua` →
  the override is reflected in `CTLDConfig.get():getSetting()` after init.
- `ctld.dontInitialize = true` set before `CTLD.lua` → `ctld.initialize()` is not called
  automatically; calling it manually produces a correctly initialised state.

These are already covered by the existing busted spec `tests/ci/unit/` (config loading) and
the CI loader behaviour. No new test files are required — the existing specs run against
`loader.lua`, which loads modules in the same order as the new build and will exercise the
bootstrap path implicitly.

Verify at the build level: `merge_CTLD.ps1` should fail (or warn) if `CTLD_bootstrap.lua`
is absent from `src/`, preventing a silent regression where the deliverable has no auto-start.

### Out of Scope

- Changing the YAML config format or any configuration parameter values.
- Migrating existing missions (they continue to work with a single `CTLD.lua` trigger).
- A more advanced configuration mechanism (JSON, external file, env-var injection).
- Documenting every individual config parameter — that is already covered by the comments
  inside `CTLD_userConfig.lua` itself.

### Further Notes

The `ctld.yamlConfigDatas` mechanism was designed from the start to support an optional
pre-load pattern: `CTLDConfig:load()` checks `if ctld.yamlConfigDatas then` and silently
skips the override block if the variable is nil. This lot merely makes the documented
intended usage physically possible by removing `CTLD_userConfig.lua` from the merge.

Documentation pages to update: `docs/mission-maker/configuration.md` and `.fr.md` (trigger
order table, description of auto-start), `docs/developer/architecture.md` (build structure
list), `docs/developer/building-and-testing.md` (merge order note),
`docs/developer/migration-v1-v2.md` (reference to userConfig as last merged file).
