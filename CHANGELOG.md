# Changelog

All notable changes to DCS-CTLD Next are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

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
