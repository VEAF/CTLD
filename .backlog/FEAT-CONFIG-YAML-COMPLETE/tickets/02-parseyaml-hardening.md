# 02 — parseYAML hardening + round-trip parity test

Status: 📋 todo
Type: src + test

`CTLDConfig.parseYAML` must robustly parse the **full nested catalogue**, not just scalars, because
the whole config now arrives as a YAML string at runtime.

- **Harden** the parser for the constructs the real catalogue uses and today's naive parser trips on:
  quoted strings containing `:` (`desc: "SAM: long range"`), float-valued keys (crate weights like
  `2000.01`), i18n punctuation, deeply nested tables, lists of maps, empty values. Stay **Lua 5.1**
  (no 5.2+); keep it dependency-free.
- **Round-trip parity test (the gate)** — take the canonical `src/CTLD_config.yaml`, emit it as the
  runtime string, parse it via `CTLDConfig.parseYAML`, and assert the resulting table equals the
  reference default table (deep compare). This guards every future catalogue edit.
- Table-driven unit tests for each hardened construct (edge cases above), red-first.

Files: `src/CTLD_config.lua` (`parseYAML`, `to_type`, helpers), `tests/ci/**`. luacheck/lua5.1 clean.
Depends on: 01 (final catalogue shape).
