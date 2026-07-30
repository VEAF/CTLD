# ADR 0008 — userConfig API and AA injection relocated to bootstrap

## Status
**Superseded entirely by [ADR 0011](0011-complete-yaml-config-and-webapp-tooling.md) (2026-07-24).**
The `ctld.userSetup` API and `src/CTLD_userSetup.lua` described below are removed; the config is now one
complete YAML document resolved by a plain `or`. Kept for the historical record — do not implement from
this document.

Originally: Accepted

## Context

`CTLD_userConfig.lua` is the file Mission Makers (MMs) edit to adapt CTLD to their mission.
Before this decision, it had two sections:

- **Section 1 (YAML scalars)** — worked correctly: sets `ctld.yamlConfigDatas` before CTLD loads,
  parsed by `CTLDConfig:load()` at init.
- **Section 2 (complex tables)** — silently broken: called `CTLDConfig.get()` before CTLD.lua
  defined `CTLDConfig`, crashing without any visible error. Only the YAML section actually ran.

Additionally, `CTLDCrateAssemblyManager.injectAACrates()` was called from inside
`CTLDCrateManager:_processSpawnableCrates()`. This meant AA system crate entries ("SAM mid range",
"SAM long range") did not exist in `spawnableCrates` when `ctld.userSetup` ran, preventing MMs
from adding or removing AA-section entries directly.

The alternative considered was a staging-table pattern (`ctld._pendingCrateAdditions`,
`ctld._pendingCrateRemovals`) flushed after auto-injection inside `_processSpawnableCrates`.
This was rejected as unnecessary complexity that leaked internal init ordering into the public MM API.

## Decision

1. **Section 2 replaced by `ctld.userSetup`** — a list of callbacks registered by the MM in
   `CTLD_userConfig.lua` and executed by the bootstrap after `CTLDConfig:load()` and AA injection:

   ```lua
   ctld.userSetup = ctld.userSetup or {}
   table.insert(ctld.userSetup, function(cfg)
       ctld.addCrate("Support", { weight=2000.01, desc="My Unit", unit="Ural-375", side=1 })
       ctld.patchCrate(1001.01, { cratesRequired = 3 })
   end)
   ```

2. **`injectAACrates` relocated to `ctld.initialize()`** — called once, between
   `CTLDConfig:load()` and `ctld.userSetup` callbacks. Removed from
   `CTLDCrateManager:_processSpawnableCrates()`.

   Init sequence:
   ```
   CTLDConfig:load()                        -- defaults + YAML scalars
   injectAACrates(spawnableCrates)          -- AA entries visible to MM
   ctld.userSetup callbacks                 -- MM mutations (direct, no staging)
   managers init                            -- see complete, final config table
   ```

3. **Helper API in `src/CTLD_userSetup.lua`** — new module (merged between `CTLD_config.lua`
   and the bootstrap) exposing: `ctld.addCrate`, `ctld.removeCrate`, `ctld.patchCrate` (deep
   merge one level), `ctld.addTroopGroup`, `ctld.removeTroopGroup`, `ctld.addTo`,
   `ctld.logDefaults`.

## Consequences

- MMs no longer see a crash-at-load Section 2; the helper API is safe for Lua non-experts.
- AA entries are visible and patchable from `ctld.userSetup` without staging machinery.
- `_processSpawnableCrates` is simpler: no longer responsible for AA injection.
- `ctld.initialize()` is now the single place that controls the full config materialisation order.
- Existing missions that do not define `ctld.userSetup` are unaffected (guard: `or {}`).
- Section 1 (YAML) is unchanged: two-trigger ME setup (userConfig before CTLD) is preserved.
