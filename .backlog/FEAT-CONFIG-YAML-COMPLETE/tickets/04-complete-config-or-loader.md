# 04 — Complete-config `or` loader

Status: ✅ done
Type: src + test

> **Scope notes (done):**
> - **Malformed policy = hard error** (decided; documented in the PRD). `load()` raises on a present
>   but empty-parsing `configUser`; no silent fallback (ctld-tools validates before export).
> - **i18n labels** — the parsed YAML holds literal `desc`/`name`; `load()` re-applies `ctld.tr()`
>   recursively (mirrors gen-config `_I18N_FIELDS`) so labels stay translated. Without this, parsing
>   the string would regress non-EN menus.
> - **`TEMPLATES` kept** (AA source for `injectAACrates`) — its removal is ticket 05, as planned.
> - **`gen-config` kept** until lot 2 (per PRD): `CTLD_config_defaults.lua` is dropped from the
>   `CTLD.lua` merge (livrable uses `ctld.configDefault`) but still generated as the round-trip parity
>   **oracle** and the **static source** the i18n dict sync scans for `desc`/`name` keys (the loader
>   translates those at runtime via `tr(v)`, invisible to static analysis).

`CTLDConfig:load()` shifts to the complete-config model: resolve the winning YAML and parse it whole.

- Resolve **`ctld.configUser or ctld.configDefault`** (names per PRD) → parse the winner via
  `parseYAML` → copy into `self.settings`. **No merge** of user over default; the winner is
  authoritative in full (a missing element is absent at runtime).
- **Remove the old paths**: the `ctld.yamlConfigDatas` scalar-merge branch and the
  `__configDefaults` copy-from-generated-table path. The `TEMPLATES` / backward-compat sequence tied
  to the ops model goes (userSetup removal itself is 06).
- Legacy parity: with **no** `configUser`, the loaded settings must equal today's defaults exactly
  (the `configDefault`-only path is behaviour-identical).

Tests (red-first): default-only load equals reference; a `configUser` snapshot fully replaces
(including an **omitted** element → absent); malformed `configUser` → clear error, falls back per
policy (define: hard error vs default — decide in this ticket, document in the PRD).

Files: `src/CTLD_config.lua` (`load`), `tests/ci/**`. luacheck/lua5.1 clean.
Depends on: 02, 03.
