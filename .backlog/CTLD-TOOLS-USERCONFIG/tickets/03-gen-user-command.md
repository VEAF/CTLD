# 03 — `gen-user` command: operations → `CTLD_userConfig.lua`

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The `gen-user` sub-command: compiles the `user-config.yaml` operations into a `CTLD_userConfig.lua`
that registers one `ctld.userSetup` callback calling the helpers. Mapping (1:1 with
`FEAT-USERCONFIG-API`):

- `add` crate → `ctld.addCrate(section, entry)`
- `delete` crate → `ctld.removeCrate(weight)`
- `edit` crate → `ctld.patchCrate(weight, patch)`
- troop `add` / `delete` → `ctld.addTroopGroup` / `ctld.removeTroopGroup`
- array `add` → `ctld.addTo(setting, entry)`

`desc` / `name` wrapped in `ctld.tr("…")` (same convention as lot 2). The generated file preserves
the YAML-scalar Section-1 block from the `FEAT-USERCONFIG-API` template and loads before CTLD
(two-trigger ME setup). `gen-user` runs `validate` first and **refuses on any `error`**.

## Acceptance criteria

- [ ] Operations compiled 1:1 to the correct helpers, in the right sections.
- [ ] `desc`/`name` re-emitted as `ctld.tr(...)`; output passes `luac5.1 -p`.
- [ ] `gen-user` invokes `validate` and aborts on an `error`-severity finding.
- [ ] Generated file preserves the Section-1 YAML-scalar mechanism and the two-trigger load order.
- [ ] Python `unittest` golden: operation set → expected helper calls.

## Blocked by

Ticket 02. Requires `FEAT-USERCONFIG-API` merged (helper names/semantics).
