# 6. Pluggable scenes in a separate CTLD_plugins repo

Status: Accepted
Date: 2026-07-17

## Context

Scenes are merged into the single `CTLD.lua` deliverable (ADR 0001) and every bundled scene runs
for every mission. The `Metal FARP` scene depends on a DCS mod (`Farp_FG_Petit_Helipad`) that
cannot be auto-validated, so `CTLDSceneManager:_auditAfterModValidator()` emits a WARN `outText` at
**every** mission start — even for the vast majority of missions that never use it. The problem is
not the scene itself but that a mod-dependent, niche scene is **imposed** on everyone.

The engine already supports **late scene registration**: `registerSceneModel()` re-injects a
scene's crate descriptor when the crate manager is already initialised (the path used by dcs-bridge
injection). This makes an externally-loaded, self-registering scene technically feasible.

## Decision

Extract mod-dependent / niche scenes into a **separate `VEAF/CTLD_plugins` repository**, and make
scenes **pluggable**:

- A scene's source is **load-position-independent** — the same file works whether merged into
  `CTLD.lua` (built-in scene) or loaded from a mission-start trigger *after* CTLD (plugin scene).
- **One plugin = one scene** (plus its optional Lua deps), built to a single loadable `.lua`.
  "Plugin" is a distribution vehicle, not a gameplay concept — the domain term stays **Scene**.
- Loading is **mission-start only** (before players slot in). No mid-mission hot-load.
- A plugin declares a minimum CTLD version (`requiresCtld`); at load it compares against
  `ctld.VERSION` and emits a **WARN** (not a hard-fail) if below.
- `CTLD_plugins` has its own CI/CD: design-time asset validation (see ADR 0007), dcs-bridge
  integration tests, and a bilingual (EN/FR) mkdocs **catalogue** — mirroring CTLD's tooling and
  vendoring the same pinned datamine type set.

The first (initially only) extracted scene is **Metal FARP**. The canonical set (`farpScene`,
`fobScene`, `mineFieldScene`, and the base-game FARP variants `countrysideFarp`, `farpAlpha`)
stays built-in.

## Consequences

- **Breaking change**: missions using `Metal FARP` must now load the plugin `.lua` in a
  mission-start trigger after CTLD. Documented in the 2.0.0 migration guide + `CHANGELOG`.
- `CTLDPlayerManager.deferMenuSection` is made **timing-insensitive** (routes to
  `registerMenuSection` when called post-init) so a scene with a radio submenu works identically
  built-in or as a plugin.
- A new `_template_scene` plugin exercises **every** extension point (scene model, crate, i18n,
  radio menu) to validate and document the load-position-independent contract.
- The datamine type set is duplicated into `CTLD_plugins`, pinned to the same ref as CTLD; the sync
  is a documented maintenance step when CTLD bumps the ref.
