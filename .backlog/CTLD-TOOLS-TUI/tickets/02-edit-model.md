# 02 — User-config edit model (pure, testable)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The **edit model** that holds the `user-config` state and all logic, independent of textual — so the
TUI is a thin view over it and the logic is unit-tested without widgets.

- State = the parsed `user-config` (settings / crates add/remove/patch / troops add/remove / arrays).
- Operations: add/remove/patch a crate, add/remove a troop group, set a scalar setting, append an
  array entry — each mutates the state.
- **Live validation**: after each op, run the existing `validate` against the (embedded by default)
  reference + DCS types; expose findings (severity, message, suggestion).
- Expose whether generation is allowed (no `error`-severity findings).
- Load from / save to a `user-config.yaml` (clean rewrite, no comment preservation).

## Acceptance criteria

- [ ] Each operation applied to the state yields the expected state.
- [ ] Findings recomputed live; generation blocked while any `error` exists.
- [ ] Load an existing yaml → state; save state → yaml round-trips the operations.
- [ ] Pure module (no textual import); pytest covers every operation + validation gating.

## Blocked by

Ticket 01 (embedded reference is the default resolver).
