# ctld-tools

CTLD configuration authoring & generation. Isolated **poetry** sub-project,
following the VMCT (VEAF-Mission-Creation-Tools) Python conventions: typer CLI,
ruamel.yaml, lupa/luadata for Lua, textual for the TUI, pytest + ruff + mypy.

## Commands

Engine config / reference (build side, use **lupa**):

- `ctld-tools extract`  — one-shot: read `src/CTLD_config.lua` defaults and write `ctld-config.yaml`.
- `ctld-tools gen-config` — render the Lua defaults module from `ctld-config.yaml` (build step).
- `ctld-tools gen-reference --src src --out ctld_tools/data/reference.json` — freeze the embedded
  reference bundle from `src/` (build step; the committed bundle is golden-tested for parity).

Mission Maker side (use the **embedded reference** by default; add `--src src` as a dev override):

- `ctld-tools tui [--yaml user-config.yaml]` — launch the interactive editor (textual). The MM path.
- `ctld-tools validate --yaml user-config.yaml` — check a user-config against the reference catalogue
  + DCS type set; reports errors with suggestions (exit non-zero on error).
- `ctld-tools gen-user --yaml user-config.yaml --out CTLD_userConfig.lua` — compile the
  add/remove/patch operations into `ctld.userSetup` helper calls (names resolved to weights).
- `ctld-tools gen-user --scaffold --out user-config.yaml` — write a commented starter.
- `ctld-tools inject --miz mission.miz --userconfig CTLD_userConfig.lua [--out out.miz]` — insert the
  generated Lua into a `.miz` as a first MISSION START trigger (idempotent).

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

The TUI and validation messages are **i18n (EN + FR)**: a tiny stdlib layer (`ctld_tools/i18n.py`,
flat JSON catalogs in `ctld_tools/data/locales/`) following the VMCT approach. Language follows the
OS locale; override with `--lang en|fr` or the `CTLD_LANG` environment variable. `en.json` is
authoritative (missing keys fall back to EN, then to the key itself).

**Settings schema** — `src/CTLD_config_schema.yaml` holds authoring metadata for scalar settings
(not consumed by the build). It is additive: add an entry only when a setting needs guidance, e.g.
`JTAC_lock: { choices: [all, vehicle, troop] }` makes the TUI offer a value picker. `gen-reference`
folds it into the embedded bundle. Reserved for a future `description:` key (per-setting help).
