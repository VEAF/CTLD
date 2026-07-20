# 04 — `gen-user --scaffold` + reconcile the `dist/` template

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

`gen-user --scaffold`: emit a **commented `user-config.yaml` skeleton** documenting the operations
(`add` / `delete` / `edit`), the fields each entry accepts, and two or three worked examples per
operation. The scaffold is itself a valid config that `validate` accepts and `gen-user` compiles.

Reconcile the delivery: the hand-edited `dist/CTLD_userConfig.lua` template shipped by
`USERCONFIG-LOADING` is **superseded** by the scaffold. The build stops shipping a hand-maintained
Lua template; there must be **one** documented starting point (the YAML scaffold), not two. Update
`merge_CTLD.ps1` / `dist/` handling accordingly.

## Acceptance criteria

- [ ] `gen-user --scaffold` produces a commented `user-config.yaml` with per-operation examples.
- [ ] Smoke test: the scaffold passes `validate` and compiles via `gen-user` with no error.
- [ ] `dist/CTLD_userConfig.lua` hand-template role removed/reconciled; single documented entry point.
- [ ] `USERCONFIG-LOADING` behaviour otherwise preserved (two-trigger ME setup still supported).

## Blocked by

Ticket 03.
