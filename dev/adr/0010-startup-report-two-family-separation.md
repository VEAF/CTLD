# ADR 0010 — Startup Report and Two-Family Output Separation

**Date:** 2026-07-22
**Status:** Accepted
**Lot:** STARTUP-REPORT-UNIFIED

## Context

Before this lot, CTLD surfaced config and init issues through a mix of direct
`trigger.action.outText()` calls (scattered across managers), `ctld.utils.log()` writes to
`CTLD.log`, and `env.warning()` calls — with no consistent format, no aggregation, and no single
place for a Mission Maker to look. Some warnings never reached the screen at all. Debug/dev traces
and MM-facing config diagnostics were interleaved in the same output channels.

## Decision

Introduce a strict two-family separation for all CTLD output:

### Family 1 — Init/config diagnostics (MM-facing)

All config errors and non-blocking notices detected during `ctld.initialize()` are fed to
`ctld.startupReport.add(severity, source, message)`. A single `ctld.startupReport.flush()` call
at the very end of `ctld.initialize()` consolidates everything:

- Always writes a `=== CTLD_STARTUP_REPORT ===` block to `DCS.log` (searchable, predictable).
- Emits **at most one** `trigger.action.outText` per init, only when issues exist.
- Severity semantics:
  - `ERROR` — a config incoherence caused an entry to be skipped or a feature to degrade.
    Requires MM action. → alarm banner on screen directing to `DCS.log`.
  - `NOTICE` — a non-blocking informational reminder (mod requirement, optional hint).
    Shown in full on screen (useful to players too).

### Family 2 — Runtime/dev traces (developer-facing)

`ctld.utils.log()` writes to `CTLD.log` only. `env.warning()` / `env.info()` are used for
DCS-level tracing. These never produce `trigger.action.outText` calls.

### Hard convention

- No bare `trigger.action.outText()` calls in `src/` init code. All MM-facing startup output
  goes through `ctld.startupReport`.
- `tests/dcs/` scenarios use their return contract (`PASS`/`FAIL`/`ABORT`), never the startup
  report.
- The two families must never mix: a Family 1 entry must not embed a raw debug trace; a Family 2
  trace must not be routed to the startup report.

## Consequences

- A MM gets a single, consolidated startup report. Clean config = total silence on screen.
- Adding a new config validation requires only one `ctld.startupReport.add()` call — no extra
  plumbing, no new outText, no timer scheduling.
- Debug / dev output is completely separated from MM-facing diagnostics.
- The 5-second `timer.scheduleFunction` delay previously used by `CTLDCrateManager` to defer its
  outText is eliminated: `flush()` fires synchronously at end of init.
- Future lots adding new config checks must follow Family 1 for init-time diagnostics and Family 2
  for runtime traces.
