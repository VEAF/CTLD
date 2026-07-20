# ctld-tools

CTLD configuration authoring & generation. Isolated **poetry** sub-project,
following the VMCT (VEAF-Mission-Creation-Tools) Python conventions: typer CLI,
ruamel.yaml, lupa/luadata for Lua, pytest + ruff + mypy.

## Commands (lot CTLD-TOOLS-CONFIG)

- `ctld-tools extract`  — one-shot: read `src/CTLD_config.lua` defaults and write `ctld-config.yaml`.
- `ctld-tools gen-config` — render the Lua defaults module from `ctld-config.yaml` (build step).

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
