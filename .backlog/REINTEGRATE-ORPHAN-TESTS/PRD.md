# Lot REINTEGRATE-ORPHAN-TESTS — rebuild coverage lost with the dead FullGas relics

Status: 🚧 in progress
Branch: feature/reintegrate-orphan-tests → PR (pending) → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`). Precedes and unblocks the
planned `CLEANUP-LEGACY-DCS-TESTS` purge.

## Problem Statement

`tests/dcs/noPlayer/` still holds ~194 dead FullGas relics (no `-- @tier:` header, `dofile` of
`C:/Users/Moi/.../DCS-CTLD_FG/recette/setup.lua`, absent `ctld_test` framework). The planned
`CLEANUP-LEGACY-DCS-TESTS` lot would purge them. But a coverage audit (cross-referencing the
tagged `@tier` scenarios and the busted `tests/ci/` suite by *tested symbol/assertion*, not by
file name) found that **62 features are covered ONLY by these relics** — and of those, **46 are
genuine gaps**: the behaviour is alive in `src/` but tested nowhere active. Purging without
re-integrating would silently lock in that coverage loss (it is already lost *de facto* — the
relics execute nothing — but the purge would make it permanent).

Crucially these are mostly *live-DCS-flavoured* behaviours (events, manager contracts, scene
structures, legacy wrappers) — not covered by the entity-level busted specs that exist today.

## Audit result (62 orphan features)

- **GAP (46)** — alive in `src/`, uncovered → re-integrate here.
- **COVERED (10)** — false orphans (covered under another name), relic is safe to purge, no test
  action: F-024, F-026, F-042, F-072, F-073, F-074, F-076, F-081, F-082, F-111.
- **FULLGAS (6)** — deep refactor / human visual check, original-author intent required → hand to
  FullGas (see `dev/fullgas-report.md`), NOT guessed here:
  - F-010 `hideScan`→`stopScan` renamed, mark-removal contract to settle
  - F-020 vehicle parachute refactored to `parachuteVehicle()` (already covered by `parachute_spec`)
  - F-044 / F-090 `fobScene` redesigned 4→21 steps, structure assertions stale
  - F-093 FOB unpack: `_onFOBBuilt` gone + beacon now offset −5 m from the centroid
  - F-100 `spawnCrate`: two crates physically visible on the F10 map → human visual check (tier `ia`)

## Solution

**Busted-first.** Everything mockable against the DCS stubs → busted (`tests/ci/`, runs in CI,
fast, deterministic). Only behaviour that needs the real DCS engine (real object spawn, world
events, `dcs_native` unit handling) stays as a live-DCS tagged scenario.

Busted cannot be run locally (the Lua-for-Windows luarocks is too old to parse busted's modern
dependency constraints). We rely on CI as the runner (same posture as luacheck), with local
syntax validation via `luac5.1 -p`. The pilot ticket (01) is pushed first to validate the busted
pattern in CI before the remaining lots are written.

## Tickets (one per coherent test lot)

| # | Scope | Relics | Cible |
|---|-------|--------|-------|
| 01 | Crate lifecycle + events (PILOT) | F-027, F-028, F-029, F-030, F-031, F-032, F-041 | busted |
| 02 | Legacy API wrappers (routing + deprecation) | F-094, F-095, F-096, F-097, F-098 | busted |
| 03 | Scene structures + minefields | F-043, F-091, F-083, F-084, F-085, F-087 | busted |
| 04 | Deploy managers: AA assembly, FOB events, pack vehicle | F-021, F-022, F-023, F-012, F-013, F-099 | busted |
| 05 | Menu gating by config + player event wiring | F-048/049/050/052/053/054/055/056/075/077/088/089, F-025 | busted |
| 06 | JTAC config/deregister + recon auto-refresh | F-110, F-112, F-011 | busted |
| 07 | Live-DCS coverage (real engine) | F-006, F-007, F-092, F-009, F-018, F-019 | scénario `@tier` |

## User Stories

1. As a maintainer, I want the behaviours currently tested only by dead relics to have live,
   running coverage, so that `CLEANUP-LEGACY-DCS-TESTS` can purge the relics without losing
   anything.
2. As a developer, I want that coverage in busted/CI wherever possible, so it runs on every push
   without a live DCS session.

## Non-goals

- Purging the relics themselves — that's `CLEANUP-LEGACY-DCS-TESTS`, after this lot.
- The 6 FULLGAS items — deferred to FullGas (documented in `dev/fullgas-report.md`).
- Re-testing the 10 COVERED features — already covered elsewhere.
- Raising the coverage ratchet as a goal in itself (it will rise as a side effect; the gate must
  still pass).
