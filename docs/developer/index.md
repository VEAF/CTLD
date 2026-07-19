# Developer documentation

This section is the technical reference for working **on** CTLD — its architecture, subsystems,
build and test tooling, event model, internationalisation, and the development workflow used to
run the project. If you are integrating CTLD into a mission rather than modifying it, see the
Mission Maker guide instead.

## How this section is organised

| Page | What you will find |
| --- | --- |
| [Development workflow](workflow.md) | Backlog process, Git Flow, TDD, quality gates, authoring skills |
| [Architecture](architecture.md) | Repository layout, manager pattern, init sequence, internal libraries |
| [Subsystems](subsystems/index.md) | Scenes, crates, troops/JTAC, zones, vehicles, beacons, recon, menu, players, AA |
| [Events](events.md) | The internal event bus and the full event catalogue |
| [Internationalisation](i18n.md) | How i18n works, adding keys and languages, mission-maker overrides |
| [Building & testing](building-and-testing.md) | Build pipeline, busted, coverage, logging, debug config |
| [Integration testing](integration-testing.md) | Live-DCS test levels (L1–L6), the martyr setup, tiers, running scenarios |
| [Migration v1 → v2](migration-v1-v2.md) | Legacy wrapper principle, migration table, worked example |
| [API reference](api-reference.md) | Public methods of every manager |
| [Design spec](design-spec.md) | The rationale behind the v2 architecture |

## Architecture at a glance

CTLD v2 is a **modular, testable rewrite** of the original monolithic script. Pure Lua 5.1 source
lives under `src/` (one class per file) and is merged into the single deliverable `CTLD.lua` by a
PowerShell build.

The runtime uses a **singleton manager** pattern: one manager per domain, each obtained via
`Manager.getInstance()`. Managers never call each other's internals directly for cross-cutting
concerns — they communicate through the internal event bus, `EventDispatcher`.

```
CTLDCoreManager          ← orchestrator, owns the init sequence
CTLDPlayerManager        ← tracks connected players, owns the F10 menu
CTLDZoneManager          ← pickup / extract / waypoint / logistic zones
CTLDTroopManager         ← troops boarding / deploying / extracting
CTLDCrateManager         ← crate spawn / load / unload / assembly
CTLDVehicleSpawner       ← vehicle request / pack
CTLDFOBManager           ← FOB construction pipeline
CTLDBeaconManager        ← radio beacons
CTLDJTACManager          ← JTAC auto-lase / orbit
CTLDReconManager         ← recon layer + F10 map marks
CTLDCrateAssemblyManager ← AA system assembly
CTLDSceneManager         ← scene engine (FARP, FOB, minefield…)
CTLDDCSEventBridge       ← single DCS event handler, routes to managers
```

Configuration is **read-only** and accessed via `ctld.gs("paramName")` — never call
`config:getSetting()` directly.

See [Architecture](architecture.md) for the repository layout, the manager/singleton idiom, the
`CTLDCoreManager` init sequence, and the internal libraries.
