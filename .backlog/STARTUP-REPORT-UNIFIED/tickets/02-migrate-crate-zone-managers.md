Status: 🧑 planned
Type: AFK

# 02 — Migrate CrateManager + ZoneManager to startup report

## What to build

Replace direct `trigger.action.outText` calls in two managers with `ctld.startupReport.add()`:

**`CTLD_crate.lua` — `_processSpawnableCrates()`:**
Remove the `timer.scheduleFunction(..., +5s)` + `outText` block. For each warning already
collected in the `warnings` table, call `ctld.startupReport.add("ERROR", "CrateManager", msg)`.
The 5-second scheduling delay is eliminated: `flush()` fires synchronously at end of init, after
all managers have had their opportunity to register entries.

**`CTLD_zone.lua` — zone validation flush:**
Replace the `trigger.action.outText(report, 30)` block with individual `add()` calls:
- Each error → `add("ERROR", "ZoneManager", e)`
- Each warning → `add("NOTICE", "ZoneManager", w)`
Keep the `ctld.utils.log` / `env.warning` calls (Family 2 — runtime/dev traces, unchanged).

Extend `tests/ci/unit/crate_manager_spec.lua`: `_processSpawnableCrates` with invalid entry →
`ctld.startupReport` receives an `ERROR` entry, no direct `outText` from the manager.

Extend `tests/ci/unit/zone_manager_spec.lua`: invalid zone config → `ctld.startupReport`
receives an `ERROR` entry.

## Acceptance criteria

- [ ] No `timer.scheduleFunction` + `outText` block remains in `_processSpawnableCrates()`.
- [ ] No direct `trigger.action.outText` remains in `CTLDZoneManager` zone validation path.
- [ ] `crate_manager_spec` extended case: ERROR entry in `ctld.startupReport`, no direct outText.
- [ ] `zone_manager_spec` extended case: ERROR entry in `ctld.startupReport`.
- [ ] `busted tests/ci/` clean, luacheck clean, CTLD.lua rebuilt.

## Blocked by

- 01 — Collector + flush() skeleton
