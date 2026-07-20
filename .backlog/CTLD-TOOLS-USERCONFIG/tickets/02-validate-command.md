# 02 — `validate` command + report

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The `validate` sub-command: takes a `user-config.yaml`, the embedded **config reference**
(`ctld-config.yaml` from lot 2) and the embedded **DCS type set** (ticket 01), and produces a
**structured report** of findings — each with severity (`error` / `warning`), location, message and a
**suggested fix**.

Rules:

- YAML well-formed.
- `edit` / `delete` target an existing `weight` (crate) or troop-group name.
- `add` `weight` does not collide with an existing entry (fatal per `FEAT-USERCONFIG-API`).
- Every `unit` is a known DCS type name.
- Array-setting operations target a known array setting (`transportPilotNames`, `troopZones`,
  `wpZones`, `extractableGroups`, `logisticUnits`).

Suggested fixes are heuristic (nearest existing `weight`, closest known type name). `error`-severity
findings will block `gen-user` (ticket 03); `warning`s do not.

## Acceptance criteria

- [ ] `validate <file>` prints a clear report; exit code non-zero on any `error`.
- [ ] All rules above enforced; each maps to a finding with a suggested fix.
- [ ] Error vs warning severity separated.
- [ ] Fully offline (no DCS, no network).
- [ ] Python `unittest`: valid config → clean; one fixture per error class → expected finding.

## Blocked by

Ticket 01.
