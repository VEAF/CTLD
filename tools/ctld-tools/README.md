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
  `src/CTLD_config_schema.yaml` (`group` / `standard` / `choices` / `label` / `description`, plus the
  reserved `families:` and `tableFields:` sections).
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
(functional `group`, `standard` flag, `choices` enum, `unit`, bilingual `label` and `description`),
plus two
reserved sections: `families:` and `tableFields:`. Optional: a setting with no entry is still
editable, the UI falls back to a generic editor and a name derived from the key.

## Web app

`web/` is the Mission-Maker surface (Svelte 5 + Vite), served by FastAPI and bundled into the exe.
`npm run dev` proxies `/api` to a uvicorn on :8000; `npm run build` emits into
`ctld_tools/web/static/`.

The UI is organised by **functional family** — one navigation axis, where a family owns both its
scalar settings and its structured tables (see `web/src/lib/families.ts`). There is no
Parameters/Data split: that followed the *shape* of a value rather than its subject, and filed
`enableCrates` and `spawnableCrates` under different screens.

Presentation metadata comes from `src/CTLD_config_schema.yaml`:

- **`families:`** (reserved section) — per-family bilingual `label` + `description`, plus `order` for
  the navigation. `web/src/lib/families.ts` keeps constants only as a fallback.
- **`label: { en, fr }`** per setting — the display name, shown instead of the raw config key (which
  stays visible beside it, since that is what the docs and forums name). A setting without one falls
  back to `humanize(key)` in `web/src/lib/labels.ts`, which is always English.

- **`unit:`** per numeric setting — the symbol shown next to the value (`m`, `s`, `min`, `m/s`, `kg`),
  untranslated. Each was traced to the Lua that consumes the value, never inferred from the key name;
  settings that are counters, codes, fractions or multipliers deliberately have none. The frontend
  still falls back to scraping the unit out of the description text when `unit:` is absent.

One thing is still derived in the frontend, for want of a source:

- **Family fallback** (`familyOf`) derives a family from the key's spelling for the ~44 settings the
  schema has no `group:` for, which shrinks the catch-all `Other` family from ~44 settings to 7.

Those missing `group:` entries are the remaining schema work — see `dev/roadmap.md`, which also lists
the runtime anomalies the unit-tracing sweep turned up.

The in-app help (`HelpPanel.svelte`) is generated from the schema and the open catalogue rather than
written as prose: setting and family counts, the family list with the schema's own descriptions, and
an inventory of every structured table with its size. Add a family or a table and the help describes
it with no prose to update.

### i18n

The UI is EN+FR. English is the frontend's base dictionary (`web/src/lib/strings.ts`) because it is
needed before any fetch — first paint and the boot-failure path; translations come from the same
backend catalogs as the CLI's messages (`ctld_tools/data/locales/*.json`, `web.*` keys) via
`GET /api/i18n`. `GET /api/schema?lang=` translates setting descriptions, table headings and family
metadata, so a language switch re-fetches the schema.

That EN duplication (frontend + catalog) is guarded: `web/src/lib/i18n.parity.test.ts` reads the
catalogs from disk and fails on any drift in keys, texts, placeholders or plural pairs. Adding a
string means editing `strings.ts` **and** both catalogs.

Backend tests that assert on language must pass `?lang=` explicitly — without it the endpoints follow
the OS locale, which differs between a dev machine and CI.
