Status: 🧑 planned
Type: AFK

# 01 — Collector + flush() skeleton

## What to build

Add `ctld.startupReport` to `CTLD_utils.lua` — a table with two methods:

- `add(severity, source, message)` — appends an entry (`"ERROR"` or `"NOTICE"`) to an internal
  list. Never throws, never halts execution.
- `flush()` — consolidates all collected entries, writes to `DCS.log` under a
  `=== CTLD_STARTUP_REPORT ===` banner (always, even when clean), then emits a single
  `trigger.action.outText` only when issues exist:
  - No entries → writes `[OK] No issues detected.` to log, no outText.
  - NOTICE only → log + outText with full notice text.
  - ERROR present (± NOTICE) → log + outText with notices in full + a single alarm banner
    directing the MM to search `CTLD_STARTUP_REPORT` in `DCS.log`.
  - Resets the internal list after flush so a second flush sees only new entries.

Wire `ctld.startupReport.flush()` in `CTLD_bootstrap.lua` immediately after
`CTLDPlayerManager.getInstance():_scanExistingPlayers()`, before the final
`ctld.utils.log("INFO", "CTLD initialized.")`.

Create `tests/ci/unit/startup_report_spec.lua` covering:
- `flush()` empty → no outText called, log contains `[OK]`.
- `flush()` NOTICE only → outText called once with notice text.
- `flush()` ERROR only → outText called once with alarm banner.
- `flush()` ERROR + NOTICE → outText contains notices + alarm banner.
- `add()` after `flush()` → second `flush()` sees only new entries.
- Double `flush()` with no new entries after first → second is a clean `[OK]`.

Mock pattern: `spy.on(trigger.action, "outText")` + capture `env.info` calls — same approach as
`usersetup_spec.lua`.

## Acceptance criteria

- [ ] `ctld.startupReport.add()` and `flush()` exist in `CTLD_utils.lua`.
- [ ] `flush()` always writes `=== CTLD_STARTUP_REPORT ===` block to `DCS.log`.
- [ ] `flush()` emits at most one `trigger.action.outText` call per invocation.
- [ ] No outText when collector is empty.
- [ ] Collector resets after flush; second flush on empty → `[OK]`.
- [ ] `flush()` called at end of `ctld.initialize()` in `CTLD_bootstrap.lua`.
- [ ] All 6 busted cases in `startup_report_spec.lua` pass.
- [ ] `busted tests/ci/` clean, luacheck clean, CTLD.lua rebuilt.

## Blocked by

None — can start immediately.
