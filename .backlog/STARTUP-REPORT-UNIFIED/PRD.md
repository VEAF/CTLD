Status: ready

# PRD — STARTUP-REPORT-UNIFIED

> Unified startup report: aggregate all config warnings and errors produced during CTLD init into a
> single structured report, always visible without debug mode.
> Cadré via grill-with-docs (2026-07-21).

## Problem Statement

When a Mission Maker loads a CTLD mission, config issues (invalid crate weights, zone
incoherences, missing mods, failed userSetup callbacks…) are surfaced through scattered
`trigger.action.outText()` calls fired at different points during init. Each manager raises its own
popup, with no consistent format, no aggregation, and no single place to look. Some warnings never
reach the screen at all — they are silently swallowed into `CTLD.log`, which the MM has no easy
way to find or search.

The result: a MM faces either a cascade of unrelated popups on a broken config, or complete silence
on issues that should be visible. There is no way to know whether CTLD loaded cleanly without
inspecting developer logs.

## Solution

Introduce `ctld.startupReport` — a passive collector embedded in `CTLD_utils` — that all managers
feed during init. A single `flush()` call at the very end of `ctld.initialize()` consolidates
everything into:

- A structured block in `DCS.log` under a searchable `CTLD_STARTUP_REPORT` banner (always written,
  even when clean).
- A single `outText` on screen when issues exist, formatted by severity:
  - **NOTICE only**: notices shown in full — they are player-facing too (e.g. "install mod X").
  - **ERROR (± NOTICE)**: notices in full + a single alarm banner pointing MM to `DCS.log`.
  - **No issues**: total silence.

CTLD never aborts init on an error — loading continues in degraded mode and the MM gets the
maximum information possible from however far init progressed.

## User Stories

1. As a Mission Maker, I want CTLD to stay silent at startup when my config is correct, so that I
   am not distracted by noise on a working mission.
2. As a Mission Maker, I want all config errors detected during CTLD init to appear in a single
   consolidated report, so that I can fix multiple issues in one pass without reloading repeatedly.
3. As a Mission Maker, I want the startup report to be available in `DCS.log` under a predictable
   searchable header (`CTLD_STARTUP_REPORT`), so that I can find it immediately without knowing
   which manager produced it.
4. As a Mission Maker, I want errors to produce a single highly visible screen message pointing me
   to `DCS.log`, so that I am not overwhelmed by verbose output on screen.
5. As a Mission Maker, I want notices (non-blocking reminders such as mod requirements) to appear
   in full on screen, so that players in my mission also see them without needing to read logs.
6. As a Mission Maker, I want the startup report to be in the CTLD language I configured (EN/FR/…),
   so that I can read it in my own language.
7. As a Mission Maker, I want CTLD to continue loading even when errors are detected, so that the
   report covers as many issues as possible in a single mission start.
8. As a Mission Maker, I want to distinguish between blocking config errors (entries that were
   skipped, features that are degraded) and non-blocking notices (informational reminders), so that
   I know what requires immediate action.
9. As a Mission Maker, I want future CTLD versions to surface new config checks through the same
   unified report without requiring me to learn a new interface, so that the diagnostic experience
   remains consistent.
10. As a developer, I want a single `ctld.startupReport.add()` call to be sufficient to surface a
    new config check, so that adding new validations requires no extra plumbing.
11. As a developer, I want startup config messages and debug/dev traces to never mix, so that the
    MM's startup report is never polluted with internal diagnostic output.
12. As a developer, I want the startup report collector to be testable in isolation via busted unit
    tests, so that flush behaviour can be verified without DCS.

## Implementation Decisions

- **Collector location**: `ctld.startupReport` is implemented as a table with `add()` and `flush()`
  methods inside `CTLD_utils.lua`. No new source file is introduced.

- **API**:
  ```
  ctld.startupReport.add(severity, source, message)
    severity : "ERROR" | "NOTICE"
    source   : human-readable manager name (e.g. "CrateManager", "ZoneManager")
    message  : already-translated string — caller's responsibility (ctld.tr() at call site,
               consistent with the existing CTLD translation pattern)
  ```

- **`flush()` timing**: called once, explicitly, at the very end of `ctld.initialize()`, after
  `CTLDPlayerManager:_scanExistingPlayers()` — ensuring every manager and every MM-scan phase has
  had the opportunity to add entries before the report is emitted.

- **`flush()` behaviour**:
  - Always writes to `DCS.log` under a `=== CTLD_STARTUP_REPORT ===` banner. If no entries:
    writes `[OK] No issues detected.` and returns (no outText).
  - NOTICE-only: writes the full report to `DCS.log` and shows the notices in full via a single
    `outText`.
  - ERROR present (± NOTICE): writes the full report to `DCS.log`, shows notices in full + a
    single alarm banner `outText` directing MM to search `CTLD_STARTUP_REPORT` in `DCS.log`.

- **Severity semantics**:
  - `ERROR`: a config incoherence was detected; the offending entry was skipped or the feature
    operates in degraded mode. Requires MM action.
  - `NOTICE`: a non-blocking informational reminder (mod requirement, optional config hint). Useful
    to players as well as the MM.

- **Init non-blocking**: `ctld.startupReport.add()` never throws, never halts execution. Detection
  logic inside each manager is unchanged — only the output channel changes (from direct `outText`
  to `add()`).

- **Migration scope**:
  - `CTLDCrateManager._processSpawnableCrates()`: replace the `timer.scheduleFunction` + `outText`
    block with `ctld.startupReport.add("ERROR", …)` calls.
  - `CTLDZoneManager` zone validation flush: replace the `outText` call with
    `ctld.startupReport.add()` calls (ERROR for errors, NOTICE for warnings).
  - `ctld.addCrate()` duplicate-weight path: replace `outText` with
    `ctld.startupReport.add("ERROR", …)`.
  - `CTLDCoreManager` INIT-E: replace log-only "extractableGroup not found, skipped" with
    `ctld.startupReport.add("NOTICE", …)`.
  - `ctld.runUserSetup()` callback failures: replace log-only paths with
    `ctld.startupReport.add("ERROR", …)`.

- **Two-family separation** (→ ADR 0010):
  - Family 1 — init/config: `ctld.startupReport.add()` exclusively.
  - Family 2 — runtime/dev: `ctld.utils.log()` → `CTLD.log` exclusively, never mixed.
  - Convention: no `trigger.action.outText()` calls directly in `src/` init code — all MM-facing
    startup output goes through the startup report. `tests/dcs/` scenarios use their return
    contract (`PASS`/`FAIL`/`ABORT`), never the startup report.

- **ADR 0010**: documents the two-family separation as a hard architectural convention (hard to
  reverse, surprising without context, result of a real trade-off between dev freedom and MM
  diagnostic clarity).

## Testing Decisions

Good tests verify externally observable behaviour: what appears in `DCS.log` / on screen, not
how `_entries` is structured internally.

- **`tests/ci/unit/startup_report_spec.lua`** (new):
  - `flush()` with empty collector → no outText called, DCS.log contains `[OK]`.
  - `flush()` with NOTICE only → outText called once with notice text.
  - `flush()` with ERROR only → outText called once with alarm banner.
  - `flush()` with ERROR + NOTICE → outText contains both notice text and alarm banner.
  - `add()` after `flush()` → second `flush()` sees only new entries (collector resets).
  - Mock pattern: `spy.on(trigger.action, "outText")` + capture `env.info` calls — same approach
    as `usersetup_spec.lua`.

- **Extensions to existing specs**:
  - `crate_manager_spec.lua`: `_processSpawnableCrates` with invalid entry → `ctld.startupReport`
    receives an `ERROR` entry, no direct `outText` from the manager.
  - `usersetup_spec.lua`: duplicate weight path → `ctld.startupReport` receives `ERROR`, not
    `ctld.logWarning` alone.
  - `zone_manager_spec.lua`: invalid zone → `ctld.startupReport` receives `ERROR`.

- **DCS integration** (`tests/dcs/noPlayer/`, tier `auto`):
  - One scenario injects a known-bad config (duplicate crate weight), triggers `flush()`, and
    verifies that `CTLD_STARTUP_REPORT` is present in `DCS.log` and the on-screen message matches
    the expected alarm format.
  - Prior art: `noPlayer/F-117_reconDisabledScanShowsExplicitMessageNotSilent.lua` for the pattern
    of verifying a screen message from a config-driven path.

## Out of Scope

- Modifying the detection logic of any manager (validation algorithms are unchanged — only the
  output channel changes).
- Adding new config validations beyond migrating existing ones.
- A "CTLD disabled on ERROR" mode — CTLD always continues in degraded mode.
- Debug / dev traces (`ctld.utils.log` family) — these remain in `CTLD.log` only.
- `modTypes` / asset validation at runtime — already handled design-time per ADR 0007.

## Further Notes

- Prerequisite: `FEAT-USERCONFIG-API` (PR #45) — already merged.
- The `timer.scheduleFunction(..., +5s)` delay currently used by `CTLDCrateManager` to defer its
  `outText` is eliminated: `flush()` is called synchronously at end of init, after all managers
  have registered their entries.
- i18n: all message strings passed to `add()` must go through `ctld.tr()` at the call site.
  New translation keys will be needed for messages currently using hardcoded English strings.
- The `CTLD_STARTUP_REPORT` banner in `DCS.log` is the primary diagnostic surface; the screen
  `outText` is a notification only.
