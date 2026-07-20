# 01 — Machine-readable DCS type-set export for the validator

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

`validate` (ticket 02) needs the known DCS type names, today available only as Lua
(`tests/data/dcs_types.lua`, used by the busted linter). Add a **machine-readable export** (JSON or
txt) of the same set to `tools/dcs-data/gen_dcs_types.py`, generated from the same datamine source,
and embed it in the `ctld-tools` package so the validator reads it directly (no Lua parsing in
Python).

The Lua `tests/data/dcs_types.lua` and the new export must stay generated from the one source and
in sync (same `DATAMINE_REF`).

## Acceptance criteria

- [ ] `gen_dcs_types.py` emits a machine-readable type-set export alongside the Lua file.
- [ ] Export embedded in / consumed by the `ctld-tools` package.
- [ ] Lua file and export provably from the same source (same ref); README updated.
- [ ] No change to the busted linter's behaviour.

## Blocked by

`CTLD-TOOLS-CONFIG` (package exists). Coordinate: the busted type linter already encodes the
collection logic (`config_types_lint_spec.lua`).
