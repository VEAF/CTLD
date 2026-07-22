Status: 🧑 planned
Type: AFK

# 04 — DCS integration scenario

## What to build

Add a `tests/dcs/noPlayer/` scenario (tier `auto`) that verifies the end-to-end startup report
behavior against a live DCS mission.

The scenario injects a known-bad config (duplicate crate weight, same approach as the
`usersetup_spec` unit test), calls `ctld.startupReport.flush()` directly, then asserts:
- `CTLD_STARTUP_REPORT` banner is present in the `DCS.log` output (captured via `env.info` spy).
- The on-screen message matches the expected alarm format (captured via `trigger.action.outText`
  spy).

Prior art for the mock pattern: `noPlayer/F-117_reconDisabledScanShowsExplicitMessageNotSilent.lua`
(mocks `trigger.action.outTextForGroup`, captures message, asserts keywords).
Use `_template_noPlayer.lua` as the harness base.

Clean up all mocks and reset `ctld.startupReport` state at end of scenario.

## Acceptance criteria

- [ ] Scenario file exists under `tests/dcs/noPlayer/`, tagged `-- @tier: auto`.
- [ ] Scenario returns `PASS` against live DCS with the current CTLD build.
- [ ] `CTLD_STARTUP_REPORT` banner verified in log output.
- [ ] Alarm banner on-screen message verified.
- [ ] Scenario is included in the `--headless` sweep without breaking other scenarios.

## Blocked by

- 02 — Migrate CrateManager + ZoneManager
- 03 — Migrate UserSetup + CoreManager + ADR 0010
