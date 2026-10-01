# 01 — Complete the missing scalar parameters when a configuration is opened

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-CTLD-TOOLS-CONFIG-COMPLETION](../PRD.md). [ADR 0011](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md)
Addendum 1 (the two config tiers). Stories 1, 2, 6, 8, 10, 12, 16, 18.

## What to build

The first end-to-end slice of **Config completion**, for the tier that is never ambiguous: scalar parameters.

When ctld-tools opens an existing configuration — a mission archive or a YAML file — every scalar parameter the
configuration lacks is added with its catalogue default, and the opening reports what was added. A value already
present is never changed. The completion is done by the tool's core, so the web app and the command line share it.

The web app shows a non-blocking summary of the additions when the configuration opens, with a way to undo any one
of them. Saving (and injecting) writes the catalogue's version tag into the configuration. A mission that has never
carried a CTLD configuration behaves as before.

## Acceptance criteria

- [x] Opening a stored configuration that lacks `crateSpawnGap` and `enableParachuteDrop` returns it with both
      added at their catalogue defaults, from a mission archive and from a YAML file alike.
- [x] A scalar the configuration already carries keeps its value, including when its catalogue default differs.
- [x] The opening returns a report listing each added parameter; the web app shows it as a non-blocking summary.
- [x] Undoing an addition in the summary removes that parameter again (and `validate` then reports it as it does
      today).
- [x] Saving or injecting writes the catalogue's version tag into the configuration.
- [x] A mission with no CTLD configuration opens exactly as before.
- [x] Lists and list entries are untouched by this ticket.
- [x] ctld-tools tests (core, web API, frontend), `ruff check`, `ruff format --check`, `npm run check` pass.

## Blocked by

None - can start immediately.
