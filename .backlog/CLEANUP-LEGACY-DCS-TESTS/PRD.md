Status: ✅ merged

# CLEANUP-LEGACY-DCS-TESTS — Purge dead FullGas relics

## Problem Statement

194 `.lua` files in `tests/dcs/noPlayer/` were dead relics from the original FullGas test suite
(`DCS-CTLD_FG/recette/`). All contained hardcoded `C:/Users/Moi/` paths, dangling `dofile` calls
to an absent `recette/setup.lua`, and references to a `ctld_test` framework that was never
re-tooled at the VEAF bootstrap. None were executable.

## Solution

Purge all 194 dead files. FullGas confirmed none were worth resurrecting. 45 live scenarios
(created/migrated during DCS-BRIDGE-MCP and subsequent lots) are unaffected.

## Out of Scope

Re-tooling any legacy test into the dcs-bridge format — handled per-feature in dedicated lots.
