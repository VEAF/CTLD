# Lot SCENE-PLUGINS — pluggable scenes + extract Metal FARP to CTLD_plugins

Status: 🧑 planned
Branch: feature/scene-plugins → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: [0006 pluggable scenes](../../dev/adr/0006-pluggable-scenes.md),
[0007 design-time asset validation](../../dev/adr/0007-design-time-asset-validation.md)

## Problem Statement

The `Metal FARP` scene depends on a DCS mod (`Farp_FG_Petit_Helipad`). Because scenes are merged
into the single `CTLD.lua` deliverable and every bundled scene runs for every mission,
`CTLDSceneManager:_auditAfterModValidator()` emits a WARN `outText` at **every mission start** —
even for the vast majority of missions that never use Metal FARP. The problem is not the mod check
itself but that a mod-dependent, niche scene is **imposed on everyone** with no opt-out.

## Solution

Make scenes **pluggable** and extract Metal FARP into a separate `VEAF/CTLD_plugins` repo (ADR
0006). A plugin scene is a single loadable `.lua`, self-registering, loaded from a mission-start
trigger *after* CTLD — so it only affects missions that opt in. Because the extracted scene is no
longer bundled, its mod-check WARN disappears for everyone else.

At the same time, replace the scene runtime audit with a **design-time hard-gate** (ADR 0007): a
busted test that fails if a scene spawns a DCS type absent from the vendored datamine set
(`tests/data/dcs_types.lua`) unioned with an optional per-scene mod whitelist. All built-in scenes
use base-game types already present in the set; the whitelist covers mod types (e.g.
`Farp_FG_Petit_Helipad`) in `CTLD_plugins`.

The key contract: a scene's source is **load-position-independent** — the same file works whether
merged into `CTLD.lua` or loaded as a plugin. This makes "copy a scene from CTLD to CTLD_plugins" a
brute-force copy with zero adaptation.

## Scope

**CTLD repo:**

- Make `CTLDPlayerManager.deferMenuSection` timing-insensitive (route to `registerMenuSection` when
  called after `_init`), so a scene with a radio submenu works identically built-in or as a plugin.
- Remove `CTLDSceneManager:_auditAfterModValidator()`, its call site (`CTLD_core.lua`), and the
  `requiresMod` runtime WARN. Sweep now-dead scene-audit bits (`model._disabled`,
  `_purgeDisabledScenes`; keep `isSceneEnabled`/`getScene`, simplified).
- Add a hard-gate busted scene test (datamine ∪ per-scene whitelist) covering all built-in scenes.
- Keep `requiresMod` as **machine-readable scene metadata** (feeds the test + docs; no longer a
  runtime WARN).
- Add a `requiresCtld` version-check convention in scene registration (compare `ctld.VERSION`,
  WARN if below).
- Remove `scenes/CTLD_metalFarpScene.lua` from `listToMerge.txt` and delete it from `src/`
  (its source moves to `CTLD_plugins`).
- Docs: mission-maker "loading a plugin scene" page + scene-authoring contract
  (load-position-independent, mission-start only); `CHANGELOG` [Unreleased] **Breaking**;
  2.0.0 migration-guide entry with the load snippet.

**CTLD_plugins repo (new):**

- Bootstrap: `plugins/<scene>/{src,tests,docs}`; vendored `tests/data/dcs_types.lua` (same pinned
  ref as CTLD); the hard-gate busted spec copied ~as-is; per-plugin build (a `listToMerge`-per-scene
  producing one UTF-8-no-BOM `.lua` with a header banner: version, `requiresCtld`, required mods);
  bilingual (EN/FR) mkdocs catalogue; CI/CD (busted hard-gate + dcs-bridge `auto` tier + build
  artifacts + publish catalogue + `.lua` release assets).
- Metal FARP plugin: the moved source + its mod whitelist + `requiresMod` metadata + `requiresCtld`.
- `_template_scene`: a reference plugin exercising **every** extension point — scene model, crate,
  i18n, and a radio submenu — to validate and document the contract.

## Non-goals

- Removing runtime asset validation for **crates / troops / AA / registry** — that is
  `ASSET-VALIDATION-REVAMP` (Lot B). `ModValidator` stays intact here.
- Mid-mission hot-loading of plugins (mission-start only).
- Extracting any scene other than Metal FARP (the rest stay built-in).
- Making crates/troops pluggable (possible future work).

## Load contract (plugin scene)

- The mission-maker loads the plugin `.lua` in a **MISSION START** trigger, **after** the CTLD load
  trigger (so before players slot in). The scene self-registers via
  `CTLDSceneManager.getInstance():registerSceneModel(...)`.
- Every extension point must work when the scene loads after CTLD init: scene model + crate
  (already handled by late `registerSceneModel`), i18n (load-time-agnostic assignment), radio menu
  (requires the `deferMenuSection` timing fix above).
