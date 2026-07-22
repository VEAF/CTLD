# Changelog

All notable changes to DCS-CTLD Next are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Fixed — hardcoded i18n strings in RECON menus and AA system (FIX-I18N-HARDCODED)

- **`CTLD_recon.lua`**: RECON submenu layer names (Infantry, Air Defense (AA), Ground Vehicles,
  Helicopters, Aircraft, Ships, FARP / FOB) now pass through `ctld.tr()` — previously always
  displayed in English regardless of the active language.
- **`CTLD_aasystem.lua`**: 6 player-facing `outText` messages replaced with `ctld.tr()` calls
  (deploy limit, AI/player deploy confirmation, rearm, repair limit, repair confirmation).
- **`CTLD_i18n_en.lua`**: 7 RECON layer name keys added to the EN dictionary.
- **`CTLD_i18n_fr.lua`**: FR translations for all 7 layer names and all 6 AA system messages.

### Added — i18n auto-translate + startup-report wiring (BUILD-DICT-AI-TRANSLATE)

- **`translate_i18n.py`** (`tools/build/`): fills empty i18n stubs via the Claude Haiku API
  (one batch call per language: FR, ES, KO). Runs automatically during `merge_CTLD.ps1` when
  `ANTHROPIC_API_KEY` is set locally; skipped silently in CI. Non-blocking: any API or Python
  error prints a WARNING and the build continues. Requires `pip install anthropic` once.
- **`ctld.initialize()`**: audits the active language dictionary after boot; adds an `INFO`
  entry to `ctld.startupReport` when untranslated stubs remain, so mission makers can see
  the count in `DCS.log`. No screen output (INFO severity).

### Added — i18n dict auto-sync in build + pre-push hook (BUILD-DICT-AUTOSYNC)

- **`merge_CTLD.ps1`**: calls `generate_i18n_dicts.ps1 -Apply` automatically after gen-config,
  before the merge loop. Missing keys are added as empty stubs; build continues regardless.
- **`.githooks/pre-push`**: cross-platform bash hook (detects `pwsh` then `powershell`,
  skips gracefully if neither available). Blocks push on MISSING keys; warns on STALE keys.
- **`CLAUDE.md`**: documents `git config core.hooksPath .githooks` for hook activation.

### Fixed — startup report INFO level (STARTUP-REPORT-INFO-LEVEL)

- **`ctld.startupReport`** : ajout du niveau `INFO` — log-only, aucun `outText` écran.
  `[OK]` n'est écrit que si le collecteur est totalement vide (toutes sévérités confondues).
- **INIT-E** (`CTLDCoreManager._initExtractableGroups`) : sévérité `NOTICE` → `INFO`.
  Les 25 noms fictifs `extract1`–`extract25` de la config par défaut ne génèrent plus
  aucun message à l'écran ; les entrées restent visibles dans `DCS.log` sous
  `CTLD_STARTUP_REPORT` pour un MM qui consulte le log.
- **ADR 0010** amendé : table des sévérités étendue à trois niveaux (ERROR / NOTICE / INFO).

### Fixed — i18n dictionary sync (FIX-I18N-DICT-SYNC)

- **`generate_i18n_dicts.ps1`**: fixed `$repoRoot` path (was one level too shallow — `tools/`
  instead of repo root — causing the script to scan `tools/src/` and silently report "0 keys").
  Now matches the `merge_CTLD.ps1` pattern: `Resolve-Path (Join-Path $scriptDir "..\..")`.
- **72 missing keys synced** to all four dictionaries (EN/FR/ES/KO). EN values filled from the
  key itself; ES/KO remain empty stubs per policy.
- **62 FR translations** filled in for all newly-synced keys, including all primary menu labels
  (`Troop Commands` → `Commandes de troupes`, `Crate Commands` → `Commandes de caisses`,
  `Vehicle Commands` → `Commandes de véhicules`, `Request Equipment` → `Demander de l'équipement`,
  `Smoke` → `Fumée`, etc.) and all pilot-facing messages. Dictionary versions bumped 1.8 → 1.9.

### Added — unified startup report (STARTUP-REPORT-UNIFIED)

- **`ctld.startupReport`** collector in `CTLD_utils`: `add(severity, source, message)` feeds
  init/config diagnostics from any manager; `flush()` called once at end of `ctld.initialize()`
  consolidates everything.
- **`DCS.log` banner**: `=== CTLD_STARTUP_REPORT ===` always written at startup — searchable,
  even on a clean config (`[OK] No issues detected.`).
- **Single `outText`** on screen when issues exist: NOTICE entries shown in full (player-facing
  too); ERROR entries produce a single alarm banner directing the MM to search
  `CTLD_STARTUP_REPORT` in `DCS.log`. Clean config = total silence.
- **Migration**: `CTLDCrateManager` (invalid mixedSet), `CTLDZoneManager` (zone validation),
  `ctld.addCrate` (duplicate weight), `ctld.runUserSetup` (callback failures),
  `CTLDCoreManager` INIT-E (missing extractableGroup) all routed through the collector.
  The 5-second `timer.scheduleFunction` delay on crate errors is eliminated.
- **ADR 0010**: two-family separation — Family 1 (init/config) via `ctld.startupReport`,
  Family 2 (runtime/dev) via `ctld.utils.log`. No bare `outText` in `src/` init code.
- **i18n**: alarm banner and INIT-E notice translated EN + FR (ES/KO stubs).

### Fixed — interface language is now a real setting (CTLD-TOOLS-TUI-POLISH)

- `i18n_lang` (the CTLD interface language, en/fr/es/ko) can now be set from the
  user-config. `ctld.tr` resolves the active language via `ctld.gs("i18n_lang")`
  (user-config wins), falling back to the module global `ctld.i18n_lang` (the legacy
  "edit CTLD_i18n.lua" method still works), then `"en"`. Previously it was a bare global
  read only by `tr`, so setting it from the user-config silently did nothing. It is
  surfaced in the ctld-tools TUI with a value list via the schema (`default: en`,
  `choices: [en, fr, es, ko]`) — deliberately **not** added to the engine defaults, so
  the legacy global keeps working.
- **Setting descriptions in the TUI**: `CTLD_config_schema.yaml` now carries a bilingual
  `description` per setting (seeded from the mission-maker config docs, 73 settings). The
  "Set setting" picker shows each setting's description in the current language and lets
  you **search by it** (filter matches name *and* description). The schema is embedded in
  the reference bundle; it is now the source of truth for these descriptions.
- **Double-click launches the TUI**: run with no command in an interactive terminal —
  including a double-click of `ctld-tools.exe` from Explorer — now opens the TUI directly
  (VMCT approach). Docs note the Windows **Unblock** step for a downloaded `.exe`.

### Tooling — ctld-tools: interactive TUI + embedded reference (CTLD-TOOLS-TUI)

- **`ctld-tools tui`**: a full-screen **textual** console for Mission Makers — a structured editor of
  the `user-config.yaml` (settings / crates / troops / arrays) with **filter-as-you-type pickers**
  (DCS types, catalogue crates/troops), **live validation**, and **save / generate / inject** in one
  place. Generation is refused while any validation error remains.
- **Actions**: three buttons — **Add / Remove / Patch** — each followed by a type chooser (only the
  valid object kinds), then a guided form. **Edit** a tree entry (`e`) reopens its form pre-filled to
  fix it in place; **delete** (with confirmation); **undo / redo** (Ctrl+Z / Ctrl+Y). **Patch** now
  works on troop groups too.
- **Settings help**: Set setting picks from the ~108 scalar settings via a filterable picker, showing
  and pre-filling each setting's default; an unknown setting is flagged (warning, with a suggestion).
  The embedded reference bundle now carries the scalar settings and their defaults. Boolean and
  fixed-value settings are chosen from a **list** (true/false, or an enum such as `JTAC_lock`); the
  allowed values come from a new authoring schema `src/CTLD_config_schema.yaml` (additive, not used
  by the build), folded into the embedded bundle.
- **Unsaved-changes guard**: quitting the TUI with unsaved edits asks for confirmation and shows how
  long ago the last save was.
- **Crate weight uniqueness on patch**: validation now also flags a `patch` that re-weights a crate
  onto an already-used weight (previously only `add` was checked); `gen-user` maps a patch's
  `weight_kg` to the runtime `weight` key, as `add` already did.
- **Fixed file names**: Save always writes the same `user-config.yaml` and Generate the canonical
  `CTLD_userConfig.lua` beside it (no path prompt); the TUI **auto-loads** `user-config.yaml` on
  start if it exists. Inject opens a **file browser** (DirectoryTree filtered to `.miz`) to pick the
  mission.
- **Internationalisation (EN + FR)**: the TUI and the validation messages follow the **OS language**;
  force it with `--lang` or `CTLD_LANG`. Tiny stdlib layer (flat JSON catalogs, `data/locales/`),
  modelled on VMCT.
- **Runtime**: new `ctld.patchTroopGroup(name, patch)` helper in `CTLD_userSetup.lua` (mirrors
  `patchCrate`), so a troop group can be patched by name from the `user-config`.
- **Embedded reference**: the catalogue is now bundled in the tool (`ctld_tools/data/reference.json`,
  generated from `src/` by the new `gen-reference` build step and committed, golden-tested for
  parity). `Reference.from_embedded()` is the default for `validate` / `gen-user` / `tui`, so the MM
  needs **only the `.exe`** — no CTLD `src/`. `--src` stays as a dev override.
- **lupa is now build-time-only** (moved to the `dev` group, imported lazily): the MM `.exe` ships
  without lupa or the native Lua binary. Only `gen-reference` / `gen-config` / `extract` use it.
- Edit logic (`EditModel`) and the picker filter are pure modules, unit-tested independently of the
  textual UI; a Pilot smoke test proves the UI↔model wiring. See [ADR 0009](dev/adr/0009-external-yaml-authoring-ctld-tools.md).
- Docs: `mission-maker/ctld-tools.md` (EN + FR) gains the interactive-editor section and the
  embedded-reference note (`--src` no longer required).

### Tooling — ctld-tools: automatic `.miz` injection (CTLD-TOOLS-MIZ-INJECT)

- **`ctld-tools inject`**: inserts a generated `CTLD_userConfig.lua` into a `.miz` as a **MISSION
  START trigger placed first** (runs before the CTLD trigger), **idempotently** (re-injection
  updates the same trigger, matched by comment). The mission `trig`/`trigrules` tables are patched
  in place — existing triggers are shifted and their in-code `[idx]` self-references rewritten (the
  VMCT mission-builder approach).
- Vendored `luadata` (parse/serialize the Lua `mission`, indices kept as dict keys) under
  `ctld_tools/vendor/` (excluded from lint/type/coverage). Tested end to end: injected mission
  reparses, is valid Lua, and re-injection stays single. **Final validation is a load in DCS.**
- Docs: `mission-maker/ctld-tools.md` (EN + FR) gains the injection flow, with a back-up + test-in-DCS
  warning.

### Feature — Anchored zones via DCS Moving Zone (FEAT-MOVING-ZONE)

- `CTLDLogisticZone` and `CTLDTroopZone`: `getCenter()` now calls `trigger.misc.getZone()` at
  every invocation — Moving Zones (trigger zones attached to a unit in the ME) follow their anchor
  unit live; fixed zones are transparent (same behavior).
- Zone discovery (`_discoverTRZ` / `_discoverLGZ`): detect `linkUnit` in
  `env.mission.triggers.zones` at init and resolve the anchor unit name via `coalition.getGroups()`.
- `isDynamic()` / `isAlive()` extended on both zone entity types to cover Moving Zone anchors;
  `isAlive()` returns false when the anchor unit is destroyed.
- Polygon Moving Zones: vertex relative offsets stored at init, reconstructed to absolute
  coordinates from the live center in `isInZone()`.
- `CTLDTroopZone:isDynamic()` and `isAlive()` added (previously absent).

### Tooling — ctld-tools finalize: gen-au-build, `.exe` distribution, MM docs (CTLD-TOOLS-FINALIZE)

- **gen-au-build**: `merge_CTLD.ps1` now regenerates `src/CTLD_config_defaults.lua` from
  `CTLD_config.yaml` via `ctld-tools` on **every build** — it is a git-ignored artifact, no longer
  committed. The `build` + `busted` CI jobs and `release.yml` gain `setup-python` + poetry; the drift
  check is dropped (the file is always fresh). Dev workflow is now simply "edit the YAML, rebuild".
- **`ctld-tools.exe`** is built (PyInstaller, lupa + datamine bundled) and attached to each Release
  by a **separate `build-exe` job**, isolated so a packaging issue never blocks the `CTLD.lua`
  release. Verified end to end (the exe runs `validate` with the embedded Lua runtime + type set).
- **Docs**: dedicated `mission-maker/ctld-tools.md` page (EN + FR), with the full `user-config.yaml`
  format, commands and examples (block + flow), linked in the site nav.

### Tooling — Mission Maker YAML authoring: `validate` + `gen-user` (CTLD-TOOLS-USERCONFIG)

- **`ctld-tools` gains the MM volet**: `validate` (checks a `user-config.yaml` against the reference
  catalogue + embedded DCS type set, reporting errors with suggestions) and `gen-user` (compiles
  `add` / `remove` / `patch` operations into a `CTLD_userConfig.lua` calling the `ctld.userSetup`
  helpers). Mission Makers target crates and troop groups **by name** — ctld-tools resolves names to
  the unique weight the runtime uses, and flags unknown/ambiguous names.
- **`gen-user --scaffold`** writes a commented starter `user-config.yaml` (block + flow styles).
- **Embedded datamine**: a machine-readable DCS type set (`dcs_types.json`) is bundled in the
  package (kept in sync with `tests/data/dcs_types.lua`) for offline `unit` validation.
- **Distribution**: `release.yml` builds and attaches **`ctld-tools.exe`** (PyInstaller), isolated so
  a packaging hiccup never blocks the `CTLD.lua` release.
- Docs: `mission-maker/configuration.md` (EN + FR) present the YAML authoring flow as recommended.

### Tooling — engine config as YAML source of truth + `ctld-tools` (CTLD-TOOLS-CONFIG)

- **Engine defaults moved out of Lua into `src/CTLD_config.yaml`** (sectioned MM-facing / advanced),
  now the single source of truth. `CTLDConfig:load()` copies a generated `ctld.__configDefaults`
  table (`src/CTLD_config_defaults.lua`) instead of writing ~800 lines of defaults inline; the
  `TEMPLATES` block and the user-YAML merge are unchanged. No in-game behaviour change.
- **New `ctld-tools` Python package** (isolated poetry sub-project `tools/ctld-tools/`, following the
  VMCT stack: typer, ruamel.yaml, lupa, pytest + ruff + mypy): `extract` (one-shot Lua→YAML) and
  `gen-config` (YAML→Lua, re-emitting `ctld.tr()` on desc/name). See ADR 0009.
- **CI**: new `python-quality` workflow (ruff + mypy + pytest). Parity is guarded by a frozen
  reference (yaml→lua→settings == original, with a distinctive translator proving the `ctld.tr`
  wrappers) and a drift check (committed generated Lua == fresh `gen-config`).
- The generated `CTLD_config_defaults.lua` is committed (VEAF pattern) and merged after the
  `CTLD_i18n_*` modules (it calls `ctld.tr` at load time).

### Feature — safe Mission Maker config API `ctld.userSetup` (FEAT-USERCONFIG-API)

- **New `ctld.userSetup` API**: Mission Makers customise the complex config tables from setup
  callbacks instead of the silently-broken Section 2 of `CTLD_userConfig.lua` (which called
  `CTLDConfig.get()` before CTLD had defined it). Helpers on `ctld`: `addCrate`, `removeCrate`,
  `patchCrate` (deep-merge one level), `addTroopGroup`, `removeTroopGroup`, `addTo`, `logDefaults`.
  Each callback runs guarded, so a failing one warns without aborting the others or the mission.
- **`injectAACrates` relocated** from `CTLDCrateManager:_processSpawnableCrates()` to
  `ctld.initialize()` (before the userSetup callbacks), so the AA-system crate sections are visible
  and patchable from a callback. `ctld.initialize()` is now the single place that materialises the
  full config: defaults → AA injection → userSetup callbacks → managers.
- **`CTLD_userConfig.lua` template rewritten**: the broken Section 2 (direct `CTLDConfig.get()`
  edits) is replaced by documented `ctld.userSetup` examples + per-table field schemas; the
  test-only debug block (with its hardcoded `aiZones`) is removed; Section 1 scalar defaults
  corrected (`parachuteMinAltitude*` = 152, `JTAC_droneAltitude` = 4000).
- **Docs**: `mission-maker/configuration.md` (EN + FR) updated to the callback-based flow.

### Tooling — release pre-release channel + `published-latest` (RELEASE-RC-CHANNEL)

- **`release.yml`**: a `-rc`-suffixed version (e.g. `published-v2.0.0-rc1`) now publishes the GitHub
  Release as a **pre-release**, and a new floating **`published-latest`** tag tracks the last
  **stable** release (advanced only by a non-rc release; a pre-release leaves it on the previous
  stable). Trigger model unchanged (tag-driven `published-v*`); `published-latest` is not matched by
  that glob, so it does not re-trigger the workflow.
- **`release` skill**: rc-aware — supports an `x.y.z-rcN` target, keeps `## [Unreleased]` open for a
  pre-release (only a stable release freezes it to `## [x.y.z] — date`), and documents the CD effect
  of an rc vs stable tag.
- **Docs**: `developer/workflow.md` (EN+FR) gains a "Release process" section describing the
  tag-driven flow and the rc/stable channels; corrected the stale "releases promoted to master"
  wording (`master` is not wired to release automation).

### Tooling — dev-local martyr load via `CTLD_DEV_ROOT` (DEV-LOCAL-MIZ)

- **Test mission (`Test_CTLDNEXT_01.miz`, the "martyr")**: the MISSION START trigger now loads
  `CTLD.lua` from a per-developer `CTLD_DEV_ROOT` environment variable instead of a hardcoded
  absolute path. The committed `.miz` no longer carries any machine-specific path (no more git
  noise / leaked personal paths). The trigger is hardened to fail loudly (log + on-screen) on a
  sanitized DCS install, an unset variable, or a bad path. The dead `ctldLogPath = "C:/CTLD.lua"`
  line is removed.
- **Docs**: the live-DCS testing page (`integration-testing`, L1–L6) moved into `docs/developer/`
  and gained a "Loading your build into the test mission (martyr)" section (de-sanitize DCS,
  `setx CTLD_DEV_ROOT`, restart DCS). The `dcs-runtime-debug` skill's `CTLD.log` section is
  realigned onto on-demand `diag_enable_ctld_log.lua` injection (it no longer references a
  `ctldLogPath` set in the `.miz`).

### Tooling — CHANGELOG guard + index-in-PR convention (CHORE-DOC-GATES)

- **New CI job `changelog-guard`**: a pull request that touches `src/**` must also update
  `CHANGELOG.md`, or the check fails. Escape hatch: label the PR `skip-changelog`. Runs on pull
  requests only. Root-cause fix for three lots that merged without a CHANGELOG entry (#36/#37/#38).
- **Workflow docs**: `CLAUDE.md` and `dev/agents/issue-tracker.md` now state that a lot's
  `.backlog/README.md` index line is set to `merged (PR #NN)` **within the delivering PR** (covered
  by review), never left `pending merge` for a separate post-merge commit. The PR template's
  CHANGELOG checkbox points to the `skip-changelog` escape hatch.

### Bug fixes — plugin crate instant refresh (FIX-PLUGIN-CRATE-INSTANT-REFRESH)

- **Fix**: a scene crate injected after init (`_injectSceneCrate`, e.g. a post-init scene
  plugin) now refreshes the transport players' Request Equipment menu immediately instead of
  waiting for the next 10s poll cycle — the crate appears in the menu as soon as the plugin
  loads.

### Bug fixes — LGZ ground poll nil `_isFlying` (FIX-LGZ-POLL-NIL-ISFLYING)

- **Fix**: the LGZ ground-position poll no longer skips players that have never flown
  (`_isFlying == nil`). Guard changed from `== false` to `~= true`, so a nil flight state is
  treated as ground. Regression test added; diagnosed via dcs-bridge (2026-07-19).

### Config validation — extend type collector coverage (TEST-TYPENAME-VALIDATION)

- **`CTLDTypeCollector.collect()`** extended to cover `aiZones[*].vehicleStock`,
  `capabilitiesByType[*].loadableVehiclesRED/BLUE`, and `aiZones[*].vehicleTypes` — closing the
  CI type-linter gap that let the invalid `"M1025 HMMWV Armament"` typeName through to a silent
  DCS spawn substitution.

### Build — separate user config template from deliverable (USERCONFIG-LOADING)

- **`CTLD_userConfig.lua` removed from the build merge**: the MM configuration template is no
  longer embedded in `CTLD.lua`. It is delivered as a standalone file in `dist/` for Mission
  Makers to customise and load via a `DO SCRIPT FILE` trigger **before** `CTLD.lua`.
- **New `CTLD_bootstrap.lua`**: the engine bootstrap (`ctld.initialize()` + auto-start guard)
  extracted into its own source file, merged last into `CTLD.lua`. `CTLD.lua` continues to
  auto-start with factory defaults — no breaking change for existing missions.
- **`dist/CTLD_userConfig.lua`** produced by the build script alongside `CTLD.lua`.

### DCS integration testing — plugin post-init contract (TEST-PLUGIN-POSTINIT)

- **F-124** (`noPlayer`, tier `auto`): new L3 scenario verifying the SCENE-PLUGINS post-init
  contract end-to-end in live DCS — `registerSceneModel` called after init adds the model to the
  scene registry; `deferMenuSection` called after init routes directly into `_menuSections` without
  queuing in `_deferredSections`; `requiresCtld` version mismatch logs WARN but still registers
  the model (soft-fail).

### Bug fixes — AI transport C2 (virtual stock) path

- **Fix (Bug 1)**: C2 virtual-stock path no longer activates when a physical vehicle is
  present in the pickup zone but exceeds the helicopter's weight limit. Guard changed from
  `not physicalLoaded` to `not physicalLoaded and not physicalPresent`, matching the
  existing code comment.
- **Fix (Bug 2a)**: invalid DCS typeName `"M1025 HMMWV Armament"` replaced by
  `"M1045 HMMWV TOW"` in the example `vehicleStock` config and all documentation. The
  former caused a silent DCS Leopard-2 substitution at vehicle spawn time.
- **Test**: `F-176` updated to reflect `M1045 HMMWV TOW`; `scenario_mt08b_weight_exceeded`
  (`auto-slow`) added as end-to-end regression — confirms no spawn at dropoff when C1
  rejects the physical vehicle on weight. PASS 7/7.

### Tooling — test taxonomy formalisation

- **Docs**: `CONTEXT.md` Testing terms section rewritten with canonical tier definitions
  (`auto`, `auto-check`, `auto-slow`, `human`, `disabled`), banned aliases (`ia`, `--no-ai`),
  L1–L6 level table, and headless sweep definition.
- **ADR 0006**: documents the `disabled` tier quarantine pattern for scenarios blocked by
  external DCS issues (pathfinding, missing mod).
- **Fix**: `mt08` and `mt14` Land waypoints moved to open flat terrain away from urban areas;
  both scenarios retagged `disabled` → `auto-slow`. MT-08 PASS 12/12, MT-14 PASS.
- **Fix**: stale `recette/` paths in `tests/manual_test_sequences.md` (MT-06 prerequisites)
  corrected to `tests/dcs/util/`.

### Asset validation — no more runtime probe (ASSET-VALIDATION-REVAMP)

- **BREAKING (behavioural)**: CTLD no longer probe-spawns objects at mission start to validate DCS
  type names. `CTLD_modValidator` is removed. The probe wasted resources and fired real
  `S_EVENT_BIRTH`/destroy events that custom mission handlers could observe (ADR 0007).
- **New**: `CTLDTypeCollector` — one source of truth for the DCS types a mission configures
  (registry incl. GROUND `unitType(coalitionId)`, `spawnableCrates`, AA templates, `loadableGroups`)
  and the declared mod types. Fixes a gap where GROUND group unit types were skipped by the scene
  asset gate.
- **New**: optional dev-time **asset-check companion** (`CTLD_asset_check.lua`, a release asset) — a
  mission maker loads it after CTLD during development and it WARNs on unknown configured types (pure
  lookup, no spawning). See [Validating your config](docs/mission-maker/asset-validation.md).
- **New**: `modTypes` config setting to declare a mission's own non-stock (mod) types.
- Custom troop `componentTypes` are used as-is at runtime (no more probe fallback to a standard
  soldier); validity is a dev-time concern now.

### Scenes — pluggable scenes (SCENE-PLUGINS)

- **BREAKING**: the **Metal FARP** scene is no longer bundled in `CTLD.lua`. It is now an opt-in
  **plugin** in the new [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) repository.
  Missions that use Metal FARP must load its plugin `.lua` from a **mission-start trigger, after
  CTLD** (see the [Scenes & FOB guide](docs/mission-maker/scenes-fob.md#plugin-scenes) and the
  [migration guide](docs/developer/migration-v1-v2.md)). This removes the mod-dependent scene — and
  the warning it printed at every mission start — from the core deliverable.
- **Scenes are now load-position-independent**: the same scene source works whether merged into
  `CTLD.lua` or loaded as a plugin after CTLD. `CTLDPlayerManager.deferMenuSection` routes to the
  live manager when called after init, so a plugin scene's radio submenu still attaches.
- **Change**: scene DCS-asset validation moved from a runtime probe to a **design-time busted
  hard-gate** (datamine set ∪ per-scene `modTypes`). The runtime scene audit
  (`_auditAfterModValidator`) and its `requiresMod` warning were removed; `CTLD_modValidator`
  (crates/troops) is unchanged. A scene may declare `requiresCtld` to warn on an incompatible CTLD.

### Docs — README cleanup

- **Fix**: README H1 renamed from the stale `DCS-CTLD Next` temporary-repo title to `CTLD`.
- **Restructure**: `Pack Equipt` and `Virtual Slingload` demoted from `##` to `###` and moved
  inside `Crate Operations` (their parent workflow, and already grouped under **Crate Commands**
  in the F10 menu); `AA System Construction` relocated to immediately follow `Crate Operations`.
- **Restructure**: `Developer Guide` (a prose block duplicating the published docs site) replaced
  by a `Documentation` section linking directly to the pilot, mission maker and developer guides.
- Table of Contents updated to match the new section hierarchy.

### Bug fixes (FullGas review round)

- **Fix**: whole-vehicle spawn from the **Request Equipment** menu (Feature Q) was silently
  disabled — `refreshRequestEquipmentSection` hardcoded `spawnAsVehicle=false` after a DCS-cargo
  refactor dropped the loadable-vehicle detection. Restored: a transport with
  `canTransportWholeVehicle` again spawns a whole vehicle for its loadable types.
- **Fix**: AI-zone stock validation — dropoff-only zones no longer receive a bogus
  `pickMaxStock`, and an invalid `troopStock` (a legacy scalar like `0`/`-1`/`10`, or an empty
  table, instead of a `{[templateName]=N}` table) now emits a clear config WARN.

### DCS integration testing — first live validation

- **Fix**: `missions/Test_CTLDNEXT_01.miz`'s embedded `beacon.ogg` (420KB) broke the DCS Mission
  Editor's own unpacker on load (`VFS_open_write: Can't create file ...beacon.ogg`) — replaced
  with a 4-byte stub (source preserved at `assets/beacon.ogg`; no test scenario depends on
  audio). Root cause is a DCS Mission Editor bug, not a zip-structure issue (verified: intact
  archive, explicit zip directory entries made no difference).
- **Fix**: `Test_CTLDNEXT_01.miz`'s startup trigger now loads `CTLD.lua` from a real path, sets
  a valid `ctldLogPath`, and injects `dcs-bridge.lua` (replacing the old Witchcraft injection)
  with the `dcsBridge = { host, port }` config `dcs-bridge.lua` needs to actually connect to
  `dcs-serve` (undocumented gotcha — flagged upstream as `VEAF-dcs-bridge` `LOT-013`).
- **Fix**: `tools/integration-runner/run_scenarios.py` crashed on Windows consoles (`cp1252`)
  when a scenario's verdict message contained non-ASCII characters — `stdout`/`stderr` now
  forced to UTF-8.
- `integration-testing` skill documents the `dcsBridge` port-config prerequisite and the
  DCS-editor `beacon.ogg`-class bug (large embedded `l10n/DEFAULT/` resources).
- First full live run (`--no-ai`, 45 scenarios) against a real DCS mission: 27/45 passed after a
  mission reload cleared cross-scenario state contamination between 4 vehicle/JTAC-family
  scenarios (F-120/F-121/F-122/F-123); 18 failures total. 8 were fixed by the FullGas review
  round above; the remaining 10 (`FIX-LIVE-DCS-FAILURES` lot) turned out to be the same class of
  cross-scenario state contamination, not real bugs — a fresh mission reload cleared all of them
  (48/48 `auto`/`auto-check` scenarios green, confirmed on two consecutive fresh runs).

### DCS integration testing — pilot-scenario catch-up (`CATCH-UP-PILOT-SCENARIOS`)

- **Fix**: `CTLDTroopManager:refreshMenuSection` always computed flight state live via
  `_isInAir(unit)`, unlike `CTLDCrateManager:refreshCrateFlightSection` which accepts an
  `overrideInAir` param so `onTakeoff`/`onLand` can force the correct state immediately
  (`S_EVENT_LAND`/`TAKEOFF` fire before `ctld.utils.inAir()`'s speed/AGL threshold settles).
  Found live: right after landing, "Parachute Troops" stayed visible and "Disembark Troops"
  stayed hidden. `refreshMenuSection` now takes the same `overrideInAir` param, wired through
  `onTakeoff`/`onLand`/the flight-state poller.
- Added `tools/integration-runner/run_ia_scenario.py`: an interactive terminal runner for
  `ia`-tier `pilotActive`/`pilotPassive` scenarios that self-verify (most of them) — no AI
  needed to drive the injection/polling loop, just a live pilot. Re-running the same command
  resets any stuck state first (crash recovery), instead of requiring a DCS restart.
- Bumped `HUMAN_TIMEOUT_S` 300s→3600s in the two L5 menu-visual scenarios and the
  `_template_pilotActive.lua` template — 5 minutes was a source of false FAILs, not a useful
  safety net, for a step that's meant to be answered at a real pilot's pace.
- **Mistagging found**: `scenarioTroopsFullCycle_v2.lua`, `scenario_extract_menu.lua`,
  `scenario_jtac_crate_pack.lua`, `scenario_feature_k_jtac_vehicle.lua` were all tagged `ia` by
  the `pilotPassive/` folder-blanket default, but none check real flight state or wait on F10 —
  only a BLUE slot occupied for position/groupId. Retagged `auto-check`, now runnable via
  `run_scenarios.py --no-ai` too. `run_scenarios.py` gained the same `RUNNING`-verdict
  re-injection support `run_ia_scenario.py` already had (previously it failed `RUNNING`
  outright, assuming a physical action was always needed).
- **Fix**: `scenarioTroopsFullCycle_v2.lua`'s step 7 (destroys 4 targets on a timer, validates
  JTAC reacquisition) had no guard against re-entry while its ~50s monitoring window was still
  running — `run_ia_scenario.py` re-injecting every 2s on `RUNNING` raced a second concurrent
  destroy/snapshot timer against the first, corrupting the claim log. Added a re-entry guard
  and exposed `_SCN_TFC_CLEANUP` (this scenario had no external-reset hook at all; a `FAIL`
  inside `check()` left `_G[STEP_N]` stuck re-validating stale data on any re-run).
- **Fix**: `run_ia_scenario.py` only printed progress when the verdict *token* changed — a
  multi-step `RUNNING` scenario's message advances every step while the token stays `RUNNING`
  throughout, so a long-but-healthy step looked indistinguishable from a hang. Now prints on
  any message change.
- **Tier audit (ticket 04)**: `scenario_multigroup_transport`, `scenario_weight_aggregation`,
  `scenario_unpack_jtac_drone`, `scenario_farp_repack` retagged `ia`→`auto-check` (none need
  piloting — just a BLUE slot). Only `scenario_warehouse_cycle` remains genuine `ia (fly)`.
- **Fix**: `scenario_farp_repack.lua` referenced the dead FullGas `ctld_test` framework (nil,
  same cause as the 194 relics) — replaced with a local `getTransport()`. It also never emitted
  a terminal verdict (looped 1→2→99→1 forever under the re-inject loop) — added a `_done` flag
  so the summary step returns `PASS`. Plus a premature-reinjection retry guard (step 2 waited
  for `playSceneAtPos` to register the scene instead of a false immediate `fail()`).
- **Fix**: `scenario_unpack_jtac_drone.lua` V3/V4 asserted the drone had *no* target after its
  spawned RED unit was destroyed — but a mission RED unit (`Sol_g-2`, 4135m) is inside the
  drone's lase range, so it correctly re-tasks. Rewrote V3/V4 to assert the drone no longer
  lases the *specific destroyed unit* (re-tasking to any other in-range enemy is correct CTLD
  behaviour). Also exposed `_SCN_JTACDRONE_INSTR` (it only printed to the DCS screen) and made
  each VERIFY publish its result there for live CLI progress; same missing-`_INSTR` gap fixed
  in `scenario_p2_fob_parachute` / `p3_csfarp_parachute` / `p4_metal_farp`.
- `run_ia_scenario.py` gained an elapsed `[mm:ss]` stamp on every line, a periodic heartbeat
  (`--heartbeat`, default 30s) echoing the last real progress line, and tolerance for transient
  poll errors (`--max-errors`, default 5) so a single HTTP 504 mid-run no longer aborts a
  13-minute scenario.

### CI / tooling

- **CI covers `develop`** — pushes to `develop` and PRs targeting `develop` now run the full
  pipeline (previously only `master`/`feature_*`).
- **Single build source** — the CI build job calls `tools/build/merge_CTLD.ps1` instead of a
  duplicated inline merge, so `CTLD.lua` is produced one canonical way.
- **Coverage ratchet** — the busted job measures coverage and enforces a floor that only ever
  rises (`COVERAGE_FLOOR`).
- **Secret scanning** — gitleaks runs on push and PR.
- **Formatting** — added `stylua.toml`; CI enforcement is deferred to a dedicated stylua-adoption
  lot (style-config sign-off + reviewed baseline reformat) rather than a noisy report-only job.
- **Repo hygiene** — `dependabot.yml` (github-actions), `CODEOWNERS`, issue/PR templates.
- **Bumped GitHub Actions** — `actions/checkout` and `actions/upload-artifact` v4 → v7.
- **Removed the broken `docs` job** — docs publication moves to the DOC-MKDOCS lot (no `mkdocs.yml`
  exists yet).

### Documentation (internal)

- **Architecture Decision Records** — added `dev/adr/` with the key retroactive decisions of the
  v2.0.0 rewrite (modular tree + build, OOP Manager/Entity, MIST removal, legacy API, repack→pack).

### Documentation

- **Docs publishing infrastructure** — `mkdocs.yml` (material, `mkdocs-static-i18n` EN default + FR,
  `mike` versioning) + a `docs.yml` workflow deploying to the repo's `gh-pages` (`develop` → `dev`,
  `master` → `latest`). Content restructure/translation is deferred to the DOC-TECH / DOC-USER-ROLES lots.
- **Developer documentation refonte (DOC-TECH)** — consolidated `docs/dev-guide.md`,
  `docs/api-reference.md` and `migration/specs/` into a single, coherent, **bilingual (EN + FR)**
  `docs/developer/` section: `index`, `workflow` (new — backlog process, Git Flow, TDD, quality
  gates, authoring skills), `architecture`, ten `subsystems/` pages, `events`, `i18n`,
  `building-and-testing`, `migration-v1-v2`, `api-reference`, `design-spec`. Every page was
  verified against current `src/` and corrected for drift (stale method names, TRZ naming, dead
  states, `Repack`→`pack`, etc.). Old sources and `migration/specs/` removed; broken links and
  gaps fixed; `mkdocs build --strict` is clean.
- **User guide split by role (DOC-USER-ROLES)** — split the 2062-line monolithic
  `docs/missionmaker_guide.md` into two **bilingual (EN + FR)** role-based sections:
  `docs/pilot/` (in-flight F10 operations — troop transport, crates, vehicles, sling-load,
  parachute, JTAC, recon, beacons, smoke, pack) and `docs/mission-maker/` (Mission Editor + config
  setup — configuration, zones, scenes & FOB, crate catalogue, minefield, translations, legacy API).
  Mixed sections were reorganised by subsection (config → mission-maker, F10 actions → pilot).
  Every page was verified against current `src/` and corrected for drift (menu paths
  `F10 → CTLD → …`, stale config keys, dead request-vehicle branch, AA template counts, legacy
  wrapper signatures, no `EXZ` prefix, etc.). The monolith removed; nav gains Pilot + Mission Maker
  sections; broken links fixed; `mkdocs build --strict` clean.
- **Completed FR coverage** — added the missing French versions of the site home (`docs/index.fr.md`)
  and the Integration Testing page (`docs/recette-procedure.fr.md`), so the FR site no longer falls
  back to English on any page.

### Fixed

- **Stale i18n header comments** — `src/CTLD_i18n*.lua` headers said translation version `1.7`
  (actual `1.8`) and referenced regenerating a non-existent "loader"; corrected to match the code.

### Release

- **Release process** — a `release` skill (consolidates the CHANGELOG into community-oriented
  `RELEASE_NOTES.md`, bumps `ctld.VERSION`, opens a `release/x.y.z` PR) and a dedicated
  `release.yml` workflow triggered by the `published-v*` tag (rebuilds `CTLD.lua` and publishes
  the GitHub Release). The old `release` job and `v*` trigger were moved out of `ci.yml`.

### Tooling

- **Offline config type linter** — a vendored set of known DCS type names
  (`tests/data/dcs_types.lua`, generated from Quaggles/dcs-lua-datamine by
  `tools/dcs-data/gen_dcs_types.py`, not shipped) + a busted spec that reports configured type
  names not in the stock set (likely typos). Runtime `CTLD_modValidator` is unchanged.

### DCS integration testing

- **Migrated from Witchcraft to VEAF-dcs-bridge** — `tests/dcs/` scenarios now inject via
  `dcs-client mcp` / `exec_lua` (project `.mcp.json`) instead of the Witchcraft Node.js bridge.
- **Return contract** — every scenario returns (and mirrors into `_G["_SCN_<ID>_RESULT"]`) a
  parsable verdict: `PASS[ <p>/<t>]`, `FAIL[ <f>/<t>]: <reasons>`, `ABORT: <msg>`, `RUNNING[:
  <detail>]`, or `STARTED` for async scenarios. Documented in the new `integration-testing` skill.
- **79 scenarios migrated** to the new contract (`noPlayer`, `pilotActive`, `pilotPassive`); the
  four `_template_*.lua` templates updated to match.
- **`integration-testing` skill** added, replacing `.claude/witchcraft-workflow.md` (removed).
  The `.vscode/tasks.json` Witchcraft task is also removed.
- **Dev setup** — `tools/dcs-bridge/install.ps1` installs VEAF-dcs-bridge into a project-local,
  gitignored venv (`tools/dcs-bridge/venv/`); `.mcp.json` references it via
  `${CLAUDE_PROJECT_DIR}` so the `dcs-bridge` MCP server works from a fresh checkout without
  relying on the system PATH.
- Note: `tests/dcs/noPlayer/` still contains ~194 legacy FullGas scenarios (dangling
  `DCS-CTLD_FG/recette/setup.lua` reference, no `ctld_test` framework) predating this migration —
  out of scope here, tracked as `CLEANUP-LEGACY-DCS-TESTS`.
- **`@tier` tagging** — every one of the 79 scenarios and the four `_template_*.lua` templates
  now carries a `-- @tier: auto | auto-check | ia` header (43 `auto`, 2 `auto-check`, 34 `ia`),
  documented in the `integration-testing` skill. Lets `INTEGRATION-TEST-RUNNER`'s "run without
  AI" mode select scenarios that don't need a player or human/AI judgment.
- **Headless runner** — `tools/integration-runner/run_scenarios.py` (stdlib-only, no
  install step) discovers scenarios, filters by `@tier`/folder/name, drives them over
  `dcs-serve`'s REST API, polls async (`STARTED`) scenarios to resolution, and writes a JUnit
  XML report. `--no-ai` runs every `auto`/`auto-check` scenario headlessly against a live DCS
  mission; 31 stdlib unit tests cover the parsing/filtering/polling logic without needing
  `dcs-serve`. Closes the three-lot DCS-bridge triptych
  (`DCS-BRIDGE-MCP` → `INTEGRATION-TEST-TAGS` → `INTEGRATION-TEST-RUNNER`).
- **Fix**: `F-122` (JTAC lifecycle on loadVehicle/unloadVehicle) never resolved its verdict —
  a leftover gap from a migration agent cut off mid-file; now returns a proper `PASS`/`FAIL`.

### Claude Code automations (project)

- **Protective hooks** — a PreToolUse hook blocks edits to `migration/source/**` and the generated
  `CTLD.lua`; a PostToolUse hook runs luacheck on edited `src/` Lua (best-effort). See
  `tools/hooks/README.md`.
- **Review subagents** — `lua51-compliance-reviewer` and `legacy-parity-checker` under `.claude/agents/`.

---

## [2.0.0] — 2026-07-06

Complete ground-up modular rewrite of DCS-CTLD as a maintainable, testable, and extensible Lua project.
Single-file deliverable (`CTLD.lua`) produced by the build system from `src/`.
Backward compatible with missions using the v1 scripting API via the legacy compatibility layer.

### Architecture

- **Modular source tree** — `src/` split into ~32 focused files concatenated by `tools/build/merge_CTLD.ps1`.
  Order controlled by `tools/build/listToMerge.txt`.
- **OOP everywhere** — all entities use `src/core/class.lua` prototype system:
  `CTLDCrate`, `CTLDTroopGroup`, `CTLDPlayer`, `CTLDBeacon`, `CTLDJTACDetector`, and all managers.
- **MIST removed** — all `mist.*` calls replaced by `ctld.utils.*`; no external dependency.
- **Legacy API** — `src/legacy/legacy_api.lua` provides 22 thin wrappers for v1 mission scripts
  (`ctld.addTroops`, `ctld.addCrates`, etc.). Drop-in for existing missions.
- **Single event bridge** — `CTLDDCSEventBridge`: one `world.addEventHandler` with internal
  delegation via `bridge:register()`. No more scattered handler registrations.
- **Version constant** — `ctld.VERSION = "2.0.0"` injected at build time into the output header.

### Features added / rewritten

- **`capabilitiesByType`** — unified per-aircraft capability table replaces the legacy per-feature
  boolean globals. Controls crates, troops, parachute, slingload, whole-vehicle transport,
  DCS native cargo integration, and slot/weight limits per aircraft type.
- **`convertNativeLoadToCTLD`** — per-aircraft flag: when `true`, a DCS-native cargo load is
  immediately converted to a CTLD-managed crate (ghost slot prevention). Required for UH-1H,
  CH-47Fbl1. Leave `false` for C-130 / Il-76 which retain DCS native cargo for ground ops and
  use the DCS native parachute function (provides 3D parachute animation on crates).
- **Scene system** — `CTLDSceneManager` + 9 built-in scenes (FARP Alpha, Countryside FARP,
  Metal FARP, FOB, Minefield…). Polar and axis step types. Mission maker can define custom scenes.
- **FARP Repack** — pack a deployed FARP back into crates; warehouse fuel snapshot preserved
  and restored at next unpack. Controlled by `enableFARPRepack`.
- **Mod Validation Guard** — `CTLDModValidator` probes all DCS type names declared in config at
  mission start. Scenes that depend on missing mod types are automatically disabled with a WARN
  outText. `step.critical = true` on a scene step aborts the scene if the spawn returns nil.
  `requiresMod` scene field triggers a WARN for mod types that cannot be auto-validated
  (heliport-type objects: DCS returns identical API values whether the mod is installed or not).
- **AI Zone config** (Feature S) — `cfg.settings["aiZones"]` table replaces brittle naming
  convention. Full control of pickup/dropoff zones, troop/vehicle stock, templates, drop mode.
- **AI Zone stock per template/type** (Feature T) — `troopStock`/`vehicleStock` per template
  name; rotation algorithm favours highest-stock eligible templates.
- **AA System construction** (Feature U) — `CTLDCrateAssemblyManager` spawns AA systems
  (HAWK, Patriot…) without crate assembly steps; AI transport integration.
- **Vehicle Pack** — pack a ground vehicle into crates at any logistics zone; unpack at
  destination for reassembly.
- **Native DCS Cargo (C-130 / Il-76)** — detection of vehicles in cargo bay bounding box;
  whole-vehicle transport without crate workflow.
- **Virtual Slingload** — hover detection, overspeed loss, release / cut menus. No DCS sling
  physics bugs.
- **Virtual Parachute** — inertia + lateral drift simulation for crates, troops, and vehicles.
  Per-aircraft altitude gates. Distinct from DCS native parachute (C-130).
- **Radio Beacons** — VHF/UHF/FM, battery timer, F10 map layer, `CTLDBeaconManager`.
- **JTAC Auto-Lase** — `CTLDJTACDetector` with laser pool (`LASER_CODE_MIN=1111..LASER_CODE_MAX=1688`),
  toggleStandby, orbit task for air JTACs.
- **Zone validation** — `_validateZoneNames()` with i18n error messages (EN/FR/ES/KO).
  Checks TRZ/LGZ/WPZ/AIZ naming, stock coherence, cargoType/vehicle transport gates.
- **i18n** — `ctld.tr()` runtime engine; EN reference + FR/ES/KO translations;
  `generate_i18n_dicts.ps1` drift detector.

### Quality

- **`.luacheckrc`** — static analysis config; `std = "lua51"`, all DCS globals declared.
- **Lua 5.1 strict** — codebase audited for Lua 5.2+ constructs (`goto`, `table.move`,
  `math.type`, `<const>`, `utf8.*`). All replaced with Lua 5.1 equivalents.
- **Nil-safety guards** — `getGroupId`, `isExist`, `getUnits`, `coalition.getGroups`,
  `Group.getByName` call sites hardened.
- **Dead code removed** — `isParachuting`, `parachuteStartAltitude`, `estimatedLandingTime`
  fields; unused `hoverStatus` and player SMK tables.
- **pcall result checks** — all `pcall()` return values checked; silent failures now log WARN.
- **Named constants** — `LASER_CODE_MIN/MAX` (CTLD_jtac.lua), `BEACON_REMOVAL_RADIUS`
  (CTLD_beacon.lua) replace hardcoded literals.
- **Menu cleanup fix** — `missionCommands.removeItemForGroup` now uses opaque `_dcsHandle`
  (was silently ignored when passed `{item.name}`).
- **inAir logic fix** — corrected inverted nil-transport guard in `CTLD_vehicle.lua`.

### CI / Tooling

- **GitHub Actions** — lint, build, busted, release artifact on tag `v*`, MkDocs deploy to
  GitHub Pages on push to master.
- **busted test suite** — `tests/ci/` L1/L2 unit tests with DCS stub environment
  (`tests/helpers/`). Coverage: config, utils, crate manager, troop group, JTAC, beacon, player.
- **DCS integration scenarios** — `tests/dcs/` Witchcraft-injected scenarios for
  pilotPassive (noPlayer) and interactive recettes.
- **Build header** — `merge_CTLD.ps1` injects version, date, and source URL into
  `CTLD.lua` output.

### Documentation

- `docs/missionmaker_guide.md` — 16 sections covering all features, zone setup, per-aircraft
  config, parachute behavior per aircraft type (C-130 native vs UH-1H/CH-47 CTLD menu), slingload,
  scenes, AI zones, scripting API, events.
- `docs/dev-guide.md` — architecture, module split, OOP pattern, event system, testing guide.
- `docs/api-reference.md` — full public API reference.
- MkDocs site deployed to GitHub Pages.

### Migration from v1

See [docs/missionmaker_guide.md §9 — Legacy API compatibility](docs/missionmaker_guide.md) and
`migration/` for the full modernization plan and per-feature spec sheets.

Key breaking changes:
- `ctld.debug = true` no longer sufficient — use `cfg.settings["debug"] = true`.
- Per-aircraft config moved to `capabilitiesByType` table (replaces `ctld.dynamicTransports` etc.).
- Zone naming for AI zones replaced by `cfg.settings["aiZones"]` config table.
- `repack` terminology replaced by `pack` everywhere (methods, config keys, menus).

---

## [1.x] — Legacy (pre-rewrite)

See `migration/MODERNIZATION-PLAN.md` for the full history of the v1 codebase and the
decision log for each architectural change made during the v2 rewrite.
