# CLEANUP-LEGACY-DCS-TESTS

**Status:** delivered. Compacted from `CLEANUP-LEGACY-DCS-TESTS/` on 2026-08-01; the ticket files live on in git history.

Purged 194 dead FullGas relics from `tests/dcs/noPlayer/` (dangling `dofile`, absent `ctld_test`, hardcoded paths). FullGas confirmed. 45 live dcs-bridge scenarios unaffected. PR #33.

## Tickets

_No ticket files._

## PRD

Status: ✅ merged

## CLEANUP-LEGACY-DCS-TESTS — Purge dead FullGas relics

### Problem Statement

194 `.lua` files in `tests/dcs/noPlayer/` were dead relics from the original FullGas test suite
(`DCS-CTLD_FG/recette/`). All contained hardcoded `C:/Users/Moi/` paths, dangling `dofile` calls
to an absent `recette/setup.lua`, and references to a `ctld_test` framework that was never
re-tooled at the VEAF bootstrap. None were executable.

### Solution

Purge all 194 dead files. FullGas confirmed none were worth resurrecting. 45 live scenarios
(created/migrated during DCS-BRIDGE-MCP and subsequent lots) are unaffected.

### Out of Scope

Re-tooling any legacy test into the dcs-bridge format — handled per-feature in dedicated lots.
