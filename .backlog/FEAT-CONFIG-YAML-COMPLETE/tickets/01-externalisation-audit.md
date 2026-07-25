# 01 — Externalisation audit + scope checkpoint

Status: 📋 todo
Type: audit/discovery + src + schema

Define the definitive catalogue that lots 2 & 3 will edit: sweep `src/` for every hardcoded
config-like knob **not already** in `src/CTLD_config.yaml`, and classify each.

- **Sweep** — enumerate literal constants / tables that condition behaviour or data: module-local
  constants (e.g. `CTLD_aasystem.lua` `_SPAWN_RADIUS`/`_REARM_DIST`/`_ASSEMBLY_DIST`), magic numbers
  in managers, any settings read as globals rather than via `ctld.gs(...)`. Exclude genuine engine
  identifiers (e.g. `CTLD_objectRegistry` `shape_name`/`namePrefix` — DCS shape ids, not settings).
- **Classify** each candidate: `mm-facing` → YAML + schema; `advanced` → YAML advanced section +
  schema; `stays-code` (engine internal). Rule: **"would a mission-maker want to tune this per
  mission?"** Conservative — do not inflate the config surface.
- **CHECKPOINT** — produce the classified inventory table and **stop for David's validation of the
  scope** before any externalisation lands.
- **Externalise** the validated `mm-facing`/`advanced` knobs into `src/CTLD_config.yaml` +
  `src/CTLD_config_schema.yaml`, replacing the hardcoded reads with `ctld.gs(...)`.
  **Behaviour-preserving**: identical defaults; parity guarded by existing tests + a per-knob
  assertion that `ctld.gs("<knob>")` equals the former literal.

Files: `src/CTLD_config.yaml`, `src/CTLD_config_schema.yaml`, the swept `src/*.lua`. Tests: busted
assertions on the externalised defaults; luacheck/lua5.1 clean.
