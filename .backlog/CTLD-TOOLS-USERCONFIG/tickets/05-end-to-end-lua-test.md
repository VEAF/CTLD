# 05 — End-to-end runtime test (lua5.1)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The whole-chain guard: take a `user-config.yaml`, run `gen-user`, then execute the generated
`CTLD_userConfig.lua` under **`lua5.1`** against the **real** `ctld.userSetup` helpers (from
`FEAT-USERCONFIG-API`) plus the config reference, run the init/dispatch, and **deep-equal** the
resulting `settings` against the expected post-operation state.

Reuses lot 2's `lua5.1` subprocess pattern; **skips cleanly** when `lua5.1` is absent locally (present
in CI). This proves yaml → lua → runtime end to end, and that the compiled calls match the helper
semantics (themselves busted-tested by `FEAT-USERCONFIG-API`).

## Acceptance criteria

- [ ] Generated `CTLD_userConfig.lua` executed under `lua5.1` against the real helpers + reference.
- [ ] `settings` deep-equals the expected post-operation state (add/delete/edit/addTo all covered).
- [ ] Skips cleanly without `lua5.1`; runs in CI.
- [ ] Readable diff on divergence.

## Blocked by

Ticket 03. Requires `FEAT-USERCONFIG-API` + `CTLD-TOOLS-CONFIG` merged.
