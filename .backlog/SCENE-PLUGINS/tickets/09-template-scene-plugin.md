# 09 — _template_scene reference plugin

Status: 🧑 planned
Type: AFK
Repo: CTLD_plugins

## What to build

A reference plugin `_template_scene` that exercises **every** scene extension point, so plugin
authors have a working, copy-from template and the load-position-independent contract is fully
validated end-to-end (ADR 0006). Analogous to `tests/dcs/_template_scenario.lua` in CTLD.

Must demonstrate all of:

- scene model + steps (`registerSceneModel`);
- a crate injected into Request Equipment;
- i18n keys (the 4 mandatory languages);
- a **radio submenu** (`deferMenuSection` + a refresh method) — this is the point that proves the
  SCENE-PLUGINS ticket 01 timing fix, since Metal FARP alone has no submenu;
- `requiresCtld` metadata;
- an (empty) mod whitelist showing the convention.

## Acceptance criteria

- [ ] Loaded from a mission-start trigger after CTLD, the template registers its scene, crate, i18n
      and **radio submenu** — the submenu appears for players (verified via dcs-bridge).
- [ ] Hard-gate test passes (all base-game types).
- [ ] Heavily commented as an authoring reference; documented in the catalogue as the starting point.
- [ ] Built `.lua` carries the header banner.

## Blocked by

01 (deferMenuSection timing fix — the submenu depends on it), 07 (repo scaffold).
