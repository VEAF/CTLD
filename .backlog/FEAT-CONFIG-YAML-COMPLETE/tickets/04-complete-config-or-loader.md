# 04 — Complete-config `or` loader

Status: 📋 todo
Type: src + test

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
