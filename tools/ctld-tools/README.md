# ctld-tools

CTLD configuration authoring & generation. Isolated **poetry** sub-project, following the
VMCT (VEAF-Mission-Creation-Tools) Python conventions: typer CLI, ruamel.yaml, pytest +
ruff + mypy.

Since ADR 0011 this is a **UI-agnostic library** — the Mission-Maker surface is the lot-3
web app, a thin wrapper over these modules. The engine config is a **complete catalogue
YAML** (`src/CTLD_config.yaml`), embedded verbatim into `CTLD.lua` and parsed by the
runtime; nothing generates or reads a Lua *table* of defaults any more.

## Library

- `catalog.py` (`Catalog`) — load / get / set / add / remove / save a complete config YAML
  in full (round-trip via ruamel, over the `mm_facing` / `advanced` sections + top-level).
- `schema.py` (`Schema`) — typed access to the authoring metadata in
  `src/CTLD_config_schema.yaml` (`group` / `standard` / `choices` / `description`).
- `validate.py` — validate a complete catalogue: DCS unit types (datamine), unique crate
  weights, AA **mixedSet** consistency, schema `choices` enums.
- `versiongap.py` — diff an authored catalogue against the current default (new / removed /
  changed defaults) for the re-migration popup.
- `embed.py` — wrap a config YAML verbatim into a `ctld.<var>` Lua string module (reused by
  the build for `configDefault` and by the MM export for `configUser`).
- `oracle.py` — emit the flat engine defaults as the JSON round-trip parity oracle.
- `miz.py` — inject a `CTLD_userConfig.lua` into a `.miz` as a MISSION START trigger.
- `datamine.py` — the known DCS type set (Quaggles datamine dataset).

## Commands

Trimmed to what the build/CI need (no CLI UX investment):

- `ctld-tools embed --yaml src/CTLD_config.yaml --out src/CTLD_config_default_yaml.lua`
  — wrap the YAML into `ctld.configDefault` (build step; `--var configUser` for the MM export).
- `ctld-tools gen --yaml src/CTLD_config.yaml --out tests/ci/data/config_defaults.json`
  — regenerate the JSON parity oracle (run after any YAML change; drift-guarded by pytest).
- `ctld-tools validate --yaml a-config.yaml [--schema src/CTLD_config_schema.yaml]`
  — validate a complete config catalogue (exit non-zero on error).

## Develop

```bash
cd tools/ctld-tools
poetry install
poetry run ruff check ctld_tools tests
poetry run ruff format --check ctld_tools tests
poetry run mypy ctld_tools
poetry run pytest
```

Validation messages are **i18n (EN + FR)**: a tiny stdlib layer (`ctld_tools/i18n.py`, flat
JSON catalogs in `ctld_tools/data/locales/`). Language follows the OS locale; override with
`--lang en|fr` or `CTLD_LANG`. `en.json` is authoritative (missing keys fall back to EN, then
to the key itself).

**Settings schema** — `src/CTLD_config_schema.yaml` holds authoring metadata for settings
(functional `group`, `standard` flag, `choices` enum, bilingual `description`). Optional: a
setting with no entry is still editable, the UI falls back to a generic editor.

## Web app

`web/` is the Mission-Maker surface (Svelte 5 + Vite), served by FastAPI and bundled into the exe.
`npm run dev` proxies `/api` to a uvicorn on :8000; `npm run build` emits into
`ctld_tools/web/static/`.

The UI is organised by **functional family** — one navigation axis, where a family owns both its
scalar settings and its structured tables (see `web/src/lib/families.ts`). There is no
Parameters/Data split: that followed the *shape* of a value rather than its subject, and filed
`enableCrates` and `spawnableCrates` under different screens.

Two pieces of presentation metadata live in the frontend rather than in the schema, deliberately:

- **Labels** (`web/src/lib/labels.ts`) are derived from the key itself (`humanize`), with a short
  override map. Units are extracted from the schema `description` text, which already documents them
  (`Max height (m) …`) — never inferred from a key name.
- **Family fallback** (`familyOf`) derives a family from the key's spelling for the ~44 settings the
  schema has no `group:` for.

Both are stopgaps. The durable home for this metadata is `src/CTLD_config_schema.yaml` (adding the
missing `group:`, plus real `label:` / `unit:` fields), which would also let the doc tables be
generated from it — see `dev/roadmap.md`.

All user-facing strings sit in `web/src/lib/strings.ts` so the FR translation of the UI (the backend
i18n layer already exists) stays a mechanical substitution.
