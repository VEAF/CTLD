Status: ready

# PRD — FEAT-USERCONFIG-API

## Problem Statement

`CTLD_userConfig.lua` is the file Mission Makers (MMs) edit to adapt CTLD to their mission.
It has two sections, but only one works:

- **Section 1 (YAML scalars)** works correctly: the MM uncomments a single line to override a
  scalar parameter. Safe, readable, no Lua expertise required.
- **Section 2 (complex tables)** is silently broken: it calls `CTLDConfig.get()` before
  `CTLD.lua` has defined `CTLDConfig`. DCS swallows the error; the section is a no-op.

Even if Section 2 worked, the approach is structurally hostile to MMs:

- Modifying a complex table (e.g. `spawnableCrates`) requires uncommenting and owning the
  **entire** 200-line default block. One missing comma breaks the mission.
- The commented defaults go stale whenever `CTLD_config.lua` changes (e.g. `isJTAC=true` was
  added to four entries but never reflected in `CTLD_userConfig.lua`).
- AA system crate entries (`"SAM mid range"`, `"SAM long range"`) do not exist in
  `spawnableCrates` at the time Section 2 would run — they are injected later by
  `CTLDCrateAssemblyManager` — so they cannot be patched even in theory.

Additionally, several specific parity bugs exist between `CTLD_config.lua` and the commented
examples in `CTLD_userConfig.lua`: missing `isJTAC=true` on four entries, missing `spawnAs` and
`specificParams` on drone JTAC entries, incorrect default values for parachute altitudes and
`JTAC_droneAltitude`, and a spurious `FOB Crate` entry that is auto-injected at runtime.

## Solution

Replace Section 2 with a **safe, surgical MM API**:

- The MM registers one or more callbacks in a `ctld.userSetup` list. Each callback receives the
  live `CTLDConfig` instance and may call helper functions to add, remove, or patch individual
  entries — without touching the rest of the defaults.
- Helper functions (`ctld.addCrate`, `ctld.removeCrate`, `ctld.patchCrate`, `ctld.addTroopGroup`,
  `ctld.removeTroopGroup`, `ctld.addTo`) operate surgically on the live config.
- A `ctld.logDefaults(settingName)` utility serialises any config table to `CTLD.log` in
  copy-pasteable Lua format so the MM can inspect the real defaults at runtime.
- `injectAACrates` is relocated from inside `_processSpawnableCrates` to `ctld.initialize()`,
  before the `ctld.userSetup` callbacks run. AA entries are therefore visible and patchable.
- All known parity bugs in `CTLD_userConfig.lua` (missing fields, wrong default values) are
  corrected as part of the template rewrite.
- Section 1 (YAML scalars) is unchanged. The two-trigger ME setup is preserved.

See ADR 0008 for the architectural rationale.

## User Stories

1. As a MM, I want to add a custom crate to the `"Support"` section without replacing the entire
   default catalogue, so that I only write what I change.
2. As a MM, I want to remove a default crate entry by its weight, so that units I don't want in
   my mission don't appear in the F10 menu.
3. As a MM, I want to patch a single field (e.g. `cratesRequired`) on an existing crate without
   rewriting the full entry, so that I make minimal edits.
4. As a MM, I want to add a custom infantry group template to the troops menu, so that my mission
   has unique squad compositions.
5. As a MM, I want to remove a default infantry group template by name, so that my troops menu
   is clean and relevant to my scenario.
6. As a MM, I want to add entries to simple array settings (`transportPilotNames`, `troopZones`,
   `wpZones`, `extractableGroups`, `logisticUnits`) without replacing the defaults, so that I
   append my mission-specific entries to the existing list.
7. As a MM, I want to patch a single aircraft capability (e.g. `maxTroopsOnboard` for `"Mi-8MT"`)
   without rewriting the full `capabilitiesByType` table, so that I use native Lua dict access.
8. As a MM, I want to add or modify AA system entries in `"SAM mid range"` or `"SAM long range"`,
   so that I can customise the AA catalogue even though those sections are auto-generated.
9. As a MM, I want to remove an AA system part crate by weight, so that I can suppress entries
   auto-injected from `CTLDCrateAssemblyManager.TEMPLATES`.
10. As a MM, I want to register multiple setup callbacks (e.g. a shared base config + a
    mission-specific override file), so that my config is composable across files.
11. As a MM, I want a syntax error in one callback to produce a clear warning rather than
    crashing the entire mission, so that the problem is diagnosed without losing other config.
12. As a MM, I want a duplicate crate weight to produce a visible error at startup, so that I
    catch an otherwise silent F10 menu corruption.
13. As a MM, I want to call `ctld.logDefaults("spawnableCrates")` from a ME trigger a few
    seconds after mission start, so that I see the exact current table in `CTLD.log` and can
    copy-paste entries to customise.
14. As a MM, I want `ctld.logDefaults` to output Lua-serialised syntax, so that I can paste the
    result directly into my `ctld.userSetup` callback.
15. As a MM, I want `CTLD_userConfig.lua` to document the schema (available fields + types) for
    each complex table with inline comments, so that I know what to write without consulting the
    source code.
16. As a MM, I want `CTLD_userConfig.lua` to include working examples for each helper function,
    so that I can copy-paste and adapt rather than writing from scratch.
17. As a MM, I want the template to document how to call `ctld.logDefaults` to inspect defaults,
    so that I can find the full default values without reading `CTLD_config.lua`.
18. As a MM, I want the commented default values in `CTLD_userConfig.lua` Section 1 (YAML) to
    match the real defaults in `CTLD_config.lua`, so that I am not misled when choosing what to
    override.
19. As a MM, I want crate entries that I add via `ctld.addCrate` to appear after the
    auto-injected AA entries in the F10 sub-menu, so that the official system parts are grouped
    first.
20. As a MM, I want `ctld.patchCrate` to perform a deep merge on nested fields such as
    `specificParams`, so that I can change a single drone orbit parameter without rewriting the
    whole sub-table.
21. As a developer, I want `injectAACrates` to run in `ctld.initialize()` before `ctld.userSetup`
    callbacks, so that the processing order is explicit and the crate manager's
    `_processSpawnableCrates` has no injection side-effects.
22. As a developer, I want all helper functions to reside in `src/CTLD_userSetup.lua` (merged
    after `CTLD_config.lua`), so that the MM API is isolated and testable independently.

## Implementation Decisions

- **`ctld.userSetup`** is a list (table) of callbacks. The MM appends to it with
  `table.insert(ctld.userSetup, function(cfg) ... end)`. A missing or nil `ctld.userSetup` is
  treated as `{}` (guard in bootstrap).

- **Execution point**: `ctld.initialize()` in `CTLD_bootstrap.lua` calls `injectAACrates`, then
  iterates `ctld.userSetup`, then initialises managers. Config is fully materialised before any
  manager runs.

- **`injectAACrates` relocation**: removed from `CTLDCrateManager:_processSpawnableCrates()`,
  called once from `ctld.initialize()` between `CTLDConfig:load()` and the `ctld.userSetup`
  loop. No staging tables needed.

- **`src/CTLD_userSetup.lua`** (new file, merged after `CTLD_config.lua`): defines
  `ctld.addCrate(section, entry)`, `ctld.removeCrate(weight)`, `ctld.patchCrate(weight, patch)`,
  `ctld.addTroopGroup(entry)`, `ctld.removeTroopGroup(name)`, `ctld.addTo(settingName, entry)`,
  `ctld.logDefaults(settingName)`.

- **`ctld.addCrate`**: appends to `cfg.settings["spawnableCrates"][section]`, creating the
  section silently if absent. Because `injectAACrates` runs before `ctld.userSetup`, AA entries
  already exist and MM additions naturally appear after them.

- **`ctld.removeCrate`**: searches all sections of `spawnableCrates` by `weight` and removes the
  matching entry. Works on both default and auto-injected AA entries.

- **`ctld.patchCrate`**: finds entry by `weight`, then merges the patch shallowly at the top
  level and one level deep for any table-valued fields (deep merge one level). Example:
  `ctld.patchCrate(1006.01, { specificParams = { alti = 5000 } })` updates only `alti` inside
  `specificParams`, preserving `speed`, `orbitRadiusNoLase`, `orbitRadiusOnLase`.

- **`ctld.addTroopGroup` / `ctld.removeTroopGroup`**: operate directly on
  `cfg.settings["loadableGroups"]` (no staging — `loadableGroups` has no auto-injection).

- **`ctld.addTo(settingName, entry)`**: generic append to any array-type setting
  (`transportPilotNames`, `troopZones`, `wpZones`, `extractableGroups`, `logisticUnits`).

- **`ctld.logDefaults(settingName)`**: serialises `ctld.gs(settingName)` to Lua syntax using the
  existing `ctld.utils.basicSerialize`, writes to `ctld.utils.log("INFO", ...)`. Intended to be
  called from a ME `DO SCRIPT` trigger a few seconds after mission start.

- **Error handling**: duplicate `weight` in `ctld.addCrate` or `ctld.removeCrate` targeting a
  nonexistent weight → `ctld.logWarning` + `trigger.action.outText` (following the existing
  pattern in `CTLD_crate.lua` and `CTLD_zone.lua`). Duplicate weight on add is fatal
  (irrecoverable menu corruption); missing weight on remove is a warning.

- **`CTLD_userConfig.lua` rewrite**: Section 2 replaced entirely. New structure:
  - Schema comment block per complex table: available fields, types, constraints.
  - Two or three worked examples per helper showing realistic MM use cases.
  - Procedure comment explaining how to call `ctld.logDefaults` to inspect full defaults.
  - Debug/recette block (`if _cfg.settings["debug"]`) removed (was test-only code).

- **Parity fixes**: `isJTAC=true` added to Hummer (1001.01), SKP-11 (1001.11), MQ-9 (1006.01),
  RQ-1A (1006.11). `spawnAs="AIRPLANE"` and `specificParams` added to both drone entries. YAML
  Section 1 corrected: `parachuteMinAltitudeCrates/Troops/Vehicles` → 152, `JTAC_droneAltitude`
  → 4000, `spawnableCratesModels["load"].canCargo` → true. FOB Crate entry removed (auto-injected).

- **`listToMerge.txt`**: `CTLD_userSetup.lua` inserted immediately after `CTLD_config.lua`.

## Testing Decisions

Good tests assert observable behaviour through public interfaces, not internal implementation.
For this lot the relevant public interfaces are: the helper functions themselves, and the
`spawnableCrates` / `loadableGroups` state after `ctld.userSetup` callbacks have run.

- **`tests/ci/unit/usersetup_spec.lua`** (new, L1): primary test file for `CTLD_userSetup.lua`.
  - `ctld.addCrate`: entry appears in correct section; section auto-created when absent; entry
    appended after pre-existing entries (simulating post-`injectAACrates` state).
  - `ctld.removeCrate`: entry removed by weight across sections; warning logged on unknown weight.
  - `ctld.patchCrate`: top-level and one-level-deep merge verified; other fields untouched.
  - `ctld.addTroopGroup`: entry appears in `loadableGroups`.
  - `ctld.removeTroopGroup`: entry removed by name; warning on unknown name.
  - `ctld.addTo`: entry appended to named array setting.
  - `ctld.logDefaults`: output contains serialised key-value pairs for known settings.
  - Duplicate weight: error logged, operation aborted.
  - Prior art: `tests/ci/unit/config_spec.lua`, `tests/ci/unit/crate_manager_spec.lua`.

- **`tests/ci/unit/config_spec.lua`** (extended, L1): `ctld.userSetup` dispatch.
  - Multiple callbacks execute in registration order.
  - `ctld.userSetup` absent or nil → no error (guard).
  - Mutations from callbacks are visible in `CTLDConfig.get().settings` after dispatch.

- **`tests/ci/unit/aasystem_spec.lua`** (extended, L1): `injectAACrates` relocation.
  - After calling `injectAACrates` on a `spawnableCrates` table, `"SAM mid range"` and
    `"SAM long range"` sections are populated.
  - A subsequent `ctld.addCrate("SAM mid range", entry)` appends after injected entries.

## Out of Scope

- **Unified startup report**: aggregating all init warnings (YAML, `ctld.userSetup`, crates,
  zones) into a single `outText` is tracked separately as `STARTUP-REPORT-UNIFIED` in
  `dev/roadmap.md`. High priority for the next lot after this one.
- **F10 debug menu entry** for `ctld.logDefaults` (post-MVP convenience).
- **Removing or replacing Section 1 (YAML scalars)**: no change to the YAML mechanism.
- **`ctld.dontInitialize` pattern**: not documented or promoted; the two-trigger ME setup
  (userConfig before CTLD) remains the only supported flow.
- **Build-time generation** of default reference blocks in `CTLD_userConfig.lua` from
  `CTLD_config.lua` (PowerShell parser): rejected as fragile. Runtime `ctld.logDefaults` is
  the reference mechanism.
- **Helpers for `spawnableCratesModels`**, `troopZoneSmokeColor`, `beaconIconColor`,
  `nbLimitSpawnedTroops`, `modTypes`: MMs access these directly via `cfg.settings[key]` (dict
  or trivial table). No helper needed.

## Further Notes

- ADR 0008 (`dev/adr/0008-userconfig-api-and-aa-injection-in-bootstrap.md`) captures the
  architectural rationale for relocating `injectAACrates` and the rejection of the staging-table
  alternative.
- `CONTEXT.md` updated: **Mission Maker (MM)** added to the glossary.
- After this lot merges, add `STARTUP-REPORT-UNIFIED` to `dev/roadmap.md` and prioritise it.
