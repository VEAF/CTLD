# ctld-tools

CTLD configuration authoring & generation. Isolated **poetry** sub-project,
following the VMCT (VEAF-Mission-Creation-Tools) Python conventions: typer CLI,
ruamel.yaml, lupa/luadata for Lua, pytest + ruff + mypy.

## Commands

Engine config (build side):

- `ctld-tools extract`  — one-shot: read `src/CTLD_config.lua` defaults and write `ctld-config.yaml`.
- `ctld-tools gen-config` — render the Lua defaults module from `ctld-config.yaml` (build step).

Mission Maker side:

- `ctld-tools validate --yaml user-config.yaml --src src` — check a user-config against the reference
  catalogue + DCS type set; reports errors with suggestions (exit non-zero on error).
- `ctld-tools gen-user --yaml user-config.yaml --src src --out CTLD_userConfig.lua` — compile the
  add/remove/patch operations into `ctld.userSetup` helper calls (names resolved to weights).
- `ctld-tools gen-user --scaffold --out user-config.yaml` — write a commented starter.

## Develop

```bash
cd tools/ctld-tools
poetry install
poetry run ruff check ctld_tools
poetry run ruff format --check ctld_tools
poetry run mypy ctld_tools
poetry run pytest
```

`extract` uses **lupa** to run `CTLD_config.lua` in-process (build-time only; not shipped in the
MM `.exe`). The `ctld.tr` translator is stubbed to identity so i18n keys are preserved.
