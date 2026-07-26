# Backlog — CTLD

Local markdown backlog. One lot = one directory `<LOT-ID>/` (`PRD.md` + `tickets/`). This file is
the hand-maintained index. See `dev/agents/issue-tracker.md` for conventions and
`dev/agents/triage-labels.md` for the `Status:` vocabulary.

## Program — re-tooling CTLD on the VMCT model

The codebase is mature (v2.0.0). This program installs a professional process/tooling layer around
it and migrates DCS integration testing from Witchcraft to VEAF-dcs-bridge. PRDs and tickets are
authored **per lot, when the lot is started** (not in batch).

### Active lots

| Lot | Status | Description | Branch |
|-----|--------|-------------|--------|
| `CTLD-TOOLS-MM-UX` | merged (PR #68) | UI/UX pass on `ctld-tools.exe` for the non-technical Mission Maker + a visual identity rooted in the subject (DCS rotary-wing logistics). Drops the developer-vocabulary `Parameters`/`Data` split for **one navigation by functional family** (a family owns its settings *and* its tables), replaces raw config keys with human labels (units extracted from the existing schema descriptions, never guessed), boots straight onto the defaults, adds search across all 136 settings, reset-to-default + changed markers (new `GET /api/defaults`), a 3-step Load→Adjust→Inject strip with one primary action and an explicit save-state, and a plain-language validation panel. Cockpit/kneeboard theme (amber caution accent, NATO side colours). Deferred: UI i18n FR, enriching `CTLD_config_schema.yaml` with the ~44 missing `group:`. | `feature/ctld-tools-ux-redesign` |
| `TUI-EDIT-MODE-UX` | merged (PR #63) | Lever l'ambiguïté du modèle d'édition du TUI `ctld-tools` (retours FullGas 2026-07-23) : le TUI édite un **diff** (add/remove/patch contre le catalogue CTLD) mais l'UI le présente comme la liste effective. On garde le modèle diff (D2) et on rend l'UI explicite : copy + `…` sur les boutons catalogue, layout 2 axes (Catalogue / Ligne sélectionnée / Fichier) avec Éditer/Supprimer visibles + activation contextuelle, garde-fous anti-doublon remove **et** patch (prévention dans les pickers + block+message), feedback + auto-sélection, et **formulaire de modif complet pré-rempli** (valeurs actuelles + défaut CTLD en hint). | `feature/tui-edit-mode-ux` |
| `FIX-I18N-HARDCODED` | merged (PR #61) | Wrapper dans `ctld.tr()` les chaînes player-facing hardcodées : noms de couches RECON (7) + messages outText AA system (6). Audit codebase complet effectué — seules ces deux zones sont concernées. | `fix/i18n-hardcoded` |
| `BUILD-DICT-AI-TRANSLATE` | ✅ merged (PR #60) | Traduire automatiquement les stubs i18n vides via l'API Claude Haiku (local, si `ANTHROPIC_API_KEY` dispo) + câbler `ctld.i18n_auditAll()` dans `ctld.startupReport` pour signaler les clés vides au runtime. | `feature/build-dict-ai-translate` |
| `DOC-NAV-I18N` | ✅ merged (PR #53, #54) | Translate the mkdocs site navigation to French (`nav_translations` under the FR locale) and harmonise every FR page H1 to the `French (dcs-term)` convention with **English anchors** forced via `attr_list` (`# Caisses (crates) { #crates }`), keeping permalinks stable across EN/FR. Drops the obsolete "CTLD Next" name from the integration-testing H1 (EN + FR). Docs only, no `src/`. | `feature/doc-nav-i18n` |
| `FEAT-MOVING-ZONE` | ✅ merged (PR #49) | Resolve CTLD zone positions lazily via `trigger.misc.getZone()` so zones attached to a DCS Moving Zone follow their anchor unit. Covers all zone types (LGZ_, TRZ_, AIZ_, WPZ_), polygon support, anchor-death guard via `isAlive()`, `getCenter()` unified across all zone types. | `feature/feat-moving-zone` |
| `FEAT-USERCONFIG-API` | ✅ merged (PR #45) | Replace broken Section 2 of `CTLD_userConfig.lua` with a safe MM API (`ctld.userSetup` callbacks + helpers), relocate `injectAACrates` to bootstrap, fix all parity bugs in userConfig template. | `feature/userconfig-api` |
| `CTLD-TOOLS-CONFIG` | ✅ merged (PR #46) | Lot 2 of `ctld-tools` ([ADR 0009](../dev/adr/0009-external-yaml-authoring-ctld-tools.md)): engine defaults moved out of `CTLD_config.lua` into `src/CTLD_config.yaml` (source of truth, sectioned mm-facing/advanced); isolated poetry package `tools/ctld-tools` (typer/ruamel/lupa, VMCT stack) with `extract` + `gen-config`; committed generated `CTLD_config_defaults.lua` + parity/drift guards + `python-quality` CI. `load()` copies `ctld.__configDefaults`. | `feature/ctld-tools-config` |
| `CTLD-TOOLS-TUI-POLISH` | ✅ merged (PR #55) | Make the CTLD interface language (`i18n_lang`) a first-class MM setting (defaults + `ctld.tr` via `ctld.gs`, schema `choices`); it was a bare global, unsettable via user-config and absent from the picker. **+** bilingual **setting descriptions** in `CTLD_config_schema.yaml` (seeded from the config docs, 73 settings), shown and **searchable** in the "Set setting" picker; `FilterablePicker` gains `(value, label, search)` items. | `feature/ctld-tools-tui-polish` |
| `STARTUP-REPORT-UNIFIED` | ✅ merged (PR #56) | Unified startup report: `ctld.startupReport` collector in `CTLD_utils`, `flush()` at end of `ctld.initialize()`, two severity levels (ERROR/NOTICE), always writes `CTLD_STARTUP_REPORT` to `DCS.log`, single screen `outText` when issues exist. ADR 0010 for two-family separation. | `feature/startup-report-unified` |
| `BUILD-DICT-AUTOSYNC` | ✅ merged (PR #59) | Intégrer `generate_i18n_dicts.ps1 -Apply` dans `merge_CTLD.ps1` + hook `pre-push` cross-platform (bloquant sur MISSING, warn sur STALE) + doc activation dans `CLAUDE.md`. | `fix/build-dict-autosync` |
| `STARTUP-REPORT-INFO-LEVEL` | ✅ merged (PR #58) | Ajouter le niveau `INFO` au `ctld.startupReport` (log-only, sans écho écran) ; migrer INIT-E de `NOTICE` vers `INFO` pour supprimer le bruit des 25 placeholders `extractableGroups`. | `fix/startup-report-info-level` |
| `FIX-I18N-DICT-SYNC` | ✅ merged (PR #57) | Fix `$repoRoot` path bug in `generate_i18n_dicts.ps1` (1 level too shallow → looks in `tools/src/`, finds 0 keys); run `-Apply` to sync missing keys; fill FR translations for 60+ missing menu labels. | `fix/i18n-dict-sync` |
| `CTLD-TOOLS-TUI` | ✅ merged (PR #52) | Interactive **textual** TUI for `ctld-tools` ([ADR 0009](../dev/adr/0009-external-yaml-authoring-ctld-tools.md)): a MM console that structurally edits the `user-config.yaml`, validates live, and generates/injects — all in one screen, with filter-as-you-type pickers, add/remove/patch + edit/delete of entries, undo/redo, settings help (defaults + bool/enum lists via `src/CTLD_config_schema.yaml`), unsaved-changes guard and a `.miz` file browser. **Embedded reference** (bundled from `src/`) makes `--src` optional and moves **lupa build-time-only** (exe drops it). **i18n EN+FR** (OS locale + `--lang`). Runtime gains `ctld.patchTroopGroup`. Model separated from UI for pure unit tests + Pilot smoke. modTypes/companion out of scope (separate lot). | `feature/ctld-tools-tui` |
| `CTLD-TOOLS-MIZ-INJECT` | ✅ merged (PR #50) | `ctld-tools inject`: insert the generated `CTLD_userConfig.lua` into a `.miz` as a rank-1 MISSION START trigger (idempotent), patching `trig`/`trigrules` with index-shift + in-code `[idx]` rewrite (VMCT approach). Vendored `luadata`. Round-trip tested (valid Lua, single after re-inject); final validation = DCS load. | `feature/ctld-tools-miz-inject` |
| `CTLD-TOOLS-FINALIZE` | ✅ merged (PR #48) | Finalize `ctld-tools`: **gen-au-build** (`merge_CTLD.ps1` regenerates `CTLD_config_defaults.lua` via `ctld-tools`, now a git-ignored artifact; CI/release gain setup-python; drift check dropped) + build & attach **`ctld-tools.exe`** (separate isolated job, verified) + dedicated MM doc page `ctld-tools.md` (EN+FR). | `feature/ctld-tools-finalize` |
| `CTLD-TOOLS-USERCONFIG` | ✅ merged (PR #47) | Lot 3 of `ctld-tools` ([ADR 0009](../dev/adr/0009-external-yaml-authoring-ctld-tools.md)): MM volet — `validate` (user-config.yaml against the reference + datamine, clear report with suggestions) + `gen-user` (compile add/remove/patch ops into `CTLD_userConfig.lua` calling the `ctld.userSetup` helpers, targeting crates/troops **by name**) + `gen-user --scaffold`; embedded `dcs_types.json`; `ctld-tools.exe` attached to Releases (isolated). e2e-tested. | `feature/ctld-tools-userconfig` |
| `CTLD-TOOLS-FINALIZE` | ✅ merged (PR #48) | Finalize `ctld-tools`: **gen-au-build** (`merge_CTLD.ps1` regenerates `CTLD_config_defaults.lua` via `ctld-tools`, now a git-ignored artifact; CI/release gain setup-python; drift check dropped) + build & attach **`ctld-tools.exe`** (separate isolated job, verified) + dedicated MM doc page `ctld-tools.md` (EN+FR). | `feature/ctld-tools-finalize` |
| `DOC-README-CLEANUP` | ✅ merged (PR #21) | Fix README title, restructure Crate Operations sub-sections, relocate AA System Construction, replace Developer Guide with Documentation links. | — |
| `CATCH-UP-PILOT-SCENARIOS` | ✅ merged (PR #24) | Ran the never-executed `pilotPassive`/`pilotActive` scenarios. Audit found the "34 `ia`" was almost all mistagged: 66/66 now pass in a headless sweep (`--no-ai --reset-before-each`), real pilot burden ≈ 2 short menu flights (both PASS). Fixed a pile of test-harness defects + cross-scenario contamination (soft reset `_reset_state.lua`), + one product fix (`refreshMenuSection` flight-state override). Optional remainders: `auto-slow` AI battery (covered by F-176..182), mt16/warehouse, L6 manual (ticket 08). | — |
| `TOOLING-TEST-TAXONOMY` | ✅ merged (PR #29) | Formalise the test taxonomy post CATCH-UP-PILOT-SCENARIOS: update `CONTEXT.md` (tiers `human`/`auto-slow`/`disabled`, L1–L6 levels, headless sweep), create ADR 0006 (`disabled` pattern), fix mt08/mt14 Land waypoint to unblock `auto-slow`, fix stale `recette/` paths in MT-06. MT-08 PASS 12/12, MT-14 PASS. | — |
| `FIX-AI-C2-BUGS` | ✅ merged (PR #30) | Two bugs in the AI transport C2 (virtual stock) path: wrong activation guard when a physical vehicle is weight-rejected (Bug 1), and invalid typeName `M1025 HMMWV Armament` in example config causing silent Leopard-2 spawn (Bug 2a/2b). MT-08B PASS 7/7. | — |
| `USERCONFIG-LOADING` | ✅ merged (PR #32) | Separate `CTLD_userConfig.lua` from the build merge: new `CTLD_bootstrap.lua` keeps the engine auto-start in the deliverable; userConfig delivered in `dist/` as a standalone MM template loaded before `CTLD.lua`. Zero breaking change. | — |
| `TEST-PLUGIN-POSTINIT` | ✅ merged (PR #31) | L3 `noPlayer` `auto` scenario (F-124) verifying the post-init plugin contract: `registerSceneModel` after init, `deferMenuSection` direct routing (not queued), `requiresCtld` soft-fail. PASS 7/7. | — |
| `TEST-TYPENAME-VALIDATION` | ✅ merged (PR #36) | Extend `CTLDTypeCollector.collect()` to cover `aiZones[*].vehicleStock`, `capabilitiesByType[*].loadableVehiclesRED/BLUE`, and `aiZones[*].vehicleTypes` — closing the CI type-linter gap exposed by the `M1025 HMMWV Armament` silent-spawn bug. | — |
| `FIX-LGZ-POLL-NIL-ISFLYING` | ✅ merged (PR #37) | LGZ ground-position poll skips players with `_isFlying=nil` (never flown) — `== false` guard → `~= true`; regression test. Diagnosed via dcs-bridge 2026-07-19. | — |
| `FIX-PLUGIN-CRATE-INSTANT-REFRESH` | ✅ merged (PR #38) | Immediate Request Equipment refresh on post-init scene crate injection — eliminates the 10s delay between plugin load and crate appearing in menu. | — |
| `CHORE-DOC-GATES` | ✅ merged (PR #39) | Enforce CHANGELOG + backlog-index bookkeeping instead of relying on discipline: CI `changelog-guard` job failing a `src/`-touching PR with no `CHANGELOG.md` edit (escape hatch: `skip-changelog` label), + workflow rewording so the index update happens inside the delivering PR. Root-cause fix for #36/#37/#38 shipping without a CHANGELOG entry. | — |
| `DEV-LOCAL-MIZ` | ✅ merged (PR #40) | Kill the hardcoded `CTLD.lua` path in the shared martyr miz: MISSION START trigger loads via `CTLD_DEV_ROOT` env var (de-sanitized DCS), hardened with explicit on-screen failure; delete the dead `ctldLogPath` line. Relocated the live-DCS testing page into `docs/developer/` + martyr setup section + realigned `dcs-runtime-debug`. Stops the committed binary miz from carrying machine paths. | — |
| `RELEASE-RC-CHANNEL` | ✅ merged (PR #41) | Add a pre-release (rc) channel + `published-latest` floating tag to the tag-driven CD (porting VMCT's two mechanics): a `-rc`-suffixed version publishes a GitHub pre-release and leaves `published-latest` on the last stable; a plain `x.y.z` advances it. `release.yml` + rc-aware `release` skill. Enables cutting `2.0.0-rc1` then `2.0.0`. | — |

### Planned lots

**ctld-tools v2 pivot** ([ADR 0011](../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md),
2026-07-24) — supersedes ADR 0008 and ADR 0009 pts 2 & 3. Drops the ops/diff config model, the
`ctld.userSetup` runtime API, the Textual TUI **and** FullGas's tkinter GUI in favour of a
**complete-YAML config** resolved by a plain `or` and a **local web-app** tool (single console exe,
GUI on double-click). Groundwork now retired: `FEAT-USERCONFIG-API`, `CTLD-TOOLS-CONFIG`,
`CTLD-TOOLS-USERCONFIG`, `CTLD-TOOLS-TUI`, `CTLD-TOOLS-TUI-POLISH`, `TUI-EDIT-MODE-UX`, and the
`UX-CTLD-TOOLS-V2` branch. Delivered as three sequenced lots (logic-vs-interface boundary between 2 & 3):

| Lot | Status | Description | Branch |
|-----|--------|-------------|--------|
| `FEAT-CONFIG-YAML-COMPLETE` | merged (PR #65) | Lot 1/3 — runtime: complete `configUser or configDefault` YAML loading (no merge; missing = removed), harden `parseYAML` for the full catalogue + round-trip parity test, bake AA crates into the YAML (drop the runtime injection loop), version tag, remove `ctld.userSetup`/`CTLD_userSetup.lua`. | `feature/config-yaml-complete` |
| `CTLD-TOOLS-CORE` | ✅ merged (PR #66) | Lot 2/3 — UI-agnostic tool core: demolish ops model/TUI/tkinter/`reference.json`/`gen-config` + drop `lupa`; complete-catalogue load/edit/save + `validate` (schema + datamine + mixedSet) + version-gap diff; `embed` (YAML→Lua string, reused for `configDefault`/`configUser`) + JSON parity oracle; keep `miz`-inject + `datamine`; CLI trimmed to `embed`/`validate`/`gen`. Ships a **library**, no new UI. | `feature/ctld-tools-core` |
| `CTLD-TOOLS-WEBAPP` | ✅ merged (PR #67) | Lot 3/3 — local web app over the lot-2 core: schema-driven editors, 13 families (FullGas's 12 + Parachute) + Parameters/Data split fully editable (crates/troops/aircraft+datamine picker/zones/lists/weights + JSON fallback), live validate, native file dialogs, `.miz` inject, version-gap popup; single **console** PyInstaller exe that serves + opens the browser on double-click (VMCT `_is_double_clicked`), frontend built at CI. Closes the ctld-tools v2 program. | `feature/ctld-tools-webapp` |

Future candidates → [`dev/roadmap.md`](../dev/roadmap.md).

### Delivered (socle, this program)

| Lot | Description |
|-----|-------------|
| `REPO-BOOTSTRAP` | New VEAF repo, clean history, Git Flow `develop`/`master` |
| `PROCESS-SCAFFOLD` | Lean `CLAUDE.md`, `.backlog/`, `CONTEXT.md`, `dev/agents/`, `dcs-runtime-debug` skill, history cleanup |
| `CI-REVAMP` ✅ | CI on `develop`, single build source, coverage ratchet (59%/61.56%), gitleaks, hygiene (PR #1). |
| `CONTEXT-ADR` ✅ | Retroactive ADRs 0001–0005 in `dev/adr/` (PR #4). |
| `CLAUDE-AUTOMATIONS` ✅ | Project hooks (block protected paths, luacheck-on-edit) + subagents lua51/parity (PR #5). |
| `DCS-DATAMINE-VENDOR` ✅ | Vendored DCS type set (not shipped) + offline config type linter (PR #6). |
| `RELEASE` ✅ | `release` skill + `release.yml` (tag `published-v*`); release job moved out of ci.yml (PR #7). |
| `DOC-MKDOCS` ✅ | mkdocs-material infra (i18n EN+FR, mike) + `docs.yml` → gh-pages live at veaf.github.io/CTLD (PR #8). |
| `DOC-TECH` ✅ | Bilingual `docs/developer/` consolidation (20 EN + 20 FR pages) + workflow page; old sources + `migration/specs/` removed (PR #11). |
| `DOC-USER-ROLES` ✅ | Bilingual role split of the user guide → `docs/pilot/` + `docs/mission-maker/` (19 EN + 19 FR pages); monolith removed (PR #12). |
| `DCS-BRIDGE-MCP` ✅ | Migrate DCS integration testing from Witchcraft to VEAF-dcs-bridge: `.mcp.json` + project-local venv, scenario return contract, 79 scenarios + 4 templates migrated, `integration-testing` skill, Witchcraft fully retired (PR #14). Uncovered ~194 dead FullGas relics → `CLEANUP-LEGACY-DCS-TESTS`. |
| `INTEGRATION-TEST-TAGS` ✅ | `-- @tier: auto\|auto-check\|ia` header on the 79 scenarios + 4 templates (43/2/34 split); fixed F-122's unresolved verdict found during the classification audit (PR #15). |
| `INTEGRATION-TEST-RUNNER` ✅ | Dependency-free `tools/integration-runner/run_scenarios.py`: discovers + tier-filters scenarios, drives them over dcs-serve REST, polls async ones, writes a JUnit report; `--no-ai` mode runs every `auto`/`auto-check` scenario headlessly. 31 stdlib unit tests. Closes the DCS-bridge triptych. |
| `REINTEGRATE-ORPHAN-TESTS` ✅ | Rebuilt coverage for the 46 features tested only by dead FullGas relics — 6 busted tickets (158 tests, green in CI) + 1 live-DCS ticket (3 scenarios: BCN 30/30, RCN 10/10, VEH 22/22). 10 relics were false orphans (already covered); 6 deferred to FullGas (`dev/fullgas-report.md`). PR #20. |
| `POST-FULLGAS-FIXES` ✅ | Applied FullGas's review answers: Feature Q whole-vehicle spawn regression, AI-zone stock validation rewrite, U-108 heliport probe fixes, F-117/F-118 recon fixes, `coord_farp-1` mission static, README doc touch-ups. First full live run against real DCS (27/45) surfaced 18 failures, 8 fixed here as a side effect — remaining 10 → `FIX-LIVE-DCS-FAILURES`. PR #22. |
| `FIX-LIVE-DCS-FAILURES` ✅ | Triaged the 10 (of 18) failures from the first live run (2026-07-10) not already fixed by `POST-FULLGAS-FIXES` — all 10 turned out to be cross-scenario state contamination, cleared by a mission reload (48/48 green, no src/test change). Also closed the L4 gap on Feature Q's whole-vehicle Request Equipment menu. PR #23. |
| `SCENE-PLUGINS` ✅ | Pluggable scenes + extracted the mod-dependent Metal FARP into the new [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) repo (killing its every-mission-start WARN). Scenes are load-position-independent; scene asset validation moved to a design-time busted hard-gate (datamine ∪ `modTypes`); runtime scene audit removed; `requiresCtld` version check. ADRs [0006](../dev/adr/0006-pluggable-scenes.md)/[0007](../dev/adr/0007-design-time-asset-validation.md). CTLD PR #26; plugins repo bootstrapped (PR #1/#2). |
| `ASSET-VALIDATION-REVAMP` ✅ | Removed `CTLD_modValidator`'s runtime probe-spawn (no more spurious `S_EVENT_BIRTH`/destroy at mission start). Shared `CTLDTypeCollector` (fixes the GROUND `unitType` gate gap); `modTypes` config setting; optional dev-time asset-check companion (`dist/CTLD_asset_check.lua`, no-spawn lookup). ADR [0007](../dev/adr/0007-design-time-asset-validation.md). CTLD PR #27; plugins gate fix PR #3. |
| `CLEANUP-LEGACY-DCS-TESTS` ✅ | Purged 194 dead FullGas relics from `tests/dcs/noPlayer/` (dangling `dofile`, absent `ctld_test`, hardcoded paths). FullGas confirmed. 45 live dcs-bridge scenarios unaffected. PR #33. |
| `USERCONFIG-LOADING` ✅ | `CTLD_userConfig.lua` removed from build merge; new `CTLD_bootstrap.lua` keeps auto-start in deliverable; userConfig delivered in `dist/` as standalone MM template. PR #32. |

## Dropped lots

| Lot | Status | Reason |
|-----|--------|--------|
| `STYLUA-ADOPTION` | 🚫 wontfix | Adoption would reformat ~500 files for marginal benefit (code already consistent + luacheck-clean), and requires first untangling pre-existing CRLF blobs against a global `core.autocrlf=true`. Not worth it; `stylua.toml` removed. luacheck stays the sole Lua gate. |

## Archived lots

Completed lots are compacted under `archive/<LOT-ID>.md`.

| Lot | Description |
|-----|-------------|
| _(none yet)_ | |
