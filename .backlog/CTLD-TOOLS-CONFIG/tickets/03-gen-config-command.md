# 03 — `gen-config` command: `ctld-config.yaml` → Lua defaults

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The **perennial** `gen-config` sub-command: reads `ctld-config.yaml`, emits the Lua defaults table
consumed by `CTLDConfig:load()`. Requirements:

- **Deterministic output** — stable key ordering and formatting, so regenerating without a YAML
  change yields a byte-identical file.
- **i18n re-emission** — wrap the `desc` / `name` fields (flagged in ticket 02) back into
  `ctld.tr("…")`. This is the only non-literal construct in the data.
- **Valid Lua 5.1** — output passes `luac5.1 -p`.

Pin here the generated file's name and the global/table name that `load()` will consume (ticket 05
wires it in).

## Acceptance criteria

- [ ] `gen-config` reads the YAML and writes deterministic Lua.
- [ ] `desc`/`name` re-emitted as `ctld.tr(...)`; all other values as literals.
- [ ] Output passes `luac5.1 -p`.
- [ ] Python `unittest` fixtures: small YAML → expected Lua (tr re-emission, nested tables, arrays,
      numeric precision, ordering); golden-file test over the committed `ctld-config.yaml`.
- [ ] Regenerating twice is byte-identical.

## Blocked by

Tickets 01, 02.
