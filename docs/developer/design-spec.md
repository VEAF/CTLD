# Design spec

This page is the **design rationale** for CTLD v2 — the *why* behind the architecture, not the
*how*. It records the goals the rewrite set for itself and the decisions taken to meet them. For
the concrete shape of the code — repository layout, the manager/singleton idiom, the init
sequence and the internal libraries — see [Architecture](architecture.md); for the public surface
of each manager see the [API reference](api-reference.md).

Where a decision below is formally recorded as an Architecture Decision Record, the ADR number is
cited so the durable reasoning and its alternatives can be traced in `dev/adr/`.

## Where CTLD v2 came from

The original CTLD (Combat Troop and Logistics Drop) is a single procedural Lua file of roughly
12 000 lines. It works, and it is the **functional reference** for the rewrite — the monolith is
kept read-only under `migration/source/` and any v2 change must preserve identical in-game
behaviour unless a deviation is explicitly requested.

But as a single flat namespace it is hard to reason about, hard to test in isolation, and hard to
extend without risking regressions elsewhere. CTLD v2 is a modular, testable rewrite that keeps
that behaviour while giving each functional domain its own boundary.

## Design goals

| Goal | What it means | How it is met |
| --- | --- | --- |
| **Legacy parity** | Reproduce every v1 feature; identical in-game behaviour by default | `migration/source/` is the immutable reference; deviations are opt-in |
| **Modularity** | One functional domain per class, with explicit dependencies | Manager + Entity pattern, one class per file under `src/` |
| **Maintainability** | Code that stays readable as it grows | Size budgets: `CTLDCoreManager` under ~500 lines, each class under ~800 |
| **Testability** | Logic that can be exercised without a running mission | Pure Lua 5.1 modules loaded under busted with DCS stubs |
| **Reproducible deliverable** | One file to ship, built the same way every time | PowerShell merge of `src/` into a single `CTLD.lua` |
| **Room to grow** | New content without editing core files | Data-driven scene engine, self-registering scenes, dynamic menus |

These goals constrain the runtime: everything must run inside the DCS Scripting Engine on **Lua
5.1**, using only the official simulator scripting API.

## Core design decisions

### Modular source, single deliverable (ADR 0001)

CTLD ships as one file because that is what a mission maker loads. Developing in one file is the
problem the rewrite exists to solve. The design splits the two concerns: authoring happens in
`src/` (one class per file, foundations in `src/core/`, scene data in `src/scenes/`, deprecated v1
shims in `src/legacy/`); a PowerShell build under `tools/build/` concatenates those files in a
fixed dependency order into `CTLD.lua`.

The build order is authoritative — foundations first, then domain managers, then scenes, then the
`CTLD_core.lua` orchestrator, then the legacy shims, with user configuration merged last so it can
override everything. `CTLD.lua` is a generated artefact and is never hand-edited. See
[Architecture](architecture.md) for the layout and [Building & testing](building-and-testing.md)
for the pipeline.

### Manager + Entity objects (ADR 0002)

Each domain is modelled as a pair: an **Entity** class describing a single thing
(`CTLDCrate`, `CTLDTroopGroup`, `CTLDVehicle`, `CTLDBeacon`, `CTLDJTAC`, `CTLDPlayer`,
`CTLDTroopZone`, `CTLDLogisticZone`, `CtldScene`) and a **Manager** singleton that owns the
registry and the domain logic (`CTLDCrateManager`, `CTLDTroopManager`, …). Entities are instanced
N times; managers exist once and are reached through `getInstance()`.

This split keeps state where it belongs — per-thing data on the entity, cross-cutting policy on
the manager — and makes each manager independently testable. The class system itself is a minimal
single-inheritance micro-framework (`X = class()`); the idiom and the singleton factory are
described in [Architecture](architecture.md#manager-singleton-idiom). Coalition handling is
unified across managers rather than reinvented per domain.

### An in-house utility layer instead of MIST (ADR 0003)

The v1 script leaned on MIST for spawning, geometry and helpers. v2 drops that dependency in
favour of a small in-house utility layer (`ctld.utils.*`, backed by `src/CTLD_utils.lua`). The
motivation is control and footprint: CTLD needs a well-defined handful of helpers
(`dynAddStatic`, `dynAddGroup`, geometry, unique-id allocation, F10 drawing), and owning them
avoids shipping and version-tracking a large external library inside the single deliverable. Calls
such as the former `mist.dynAddStatic()` in the minefield scene are replaced by
`CTLDUtils.dynAddStatic()`.

### A legacy compatibility layer (ADR 0004)

Existing v1 missions call into the old procedural API. To let those missions run on v2 without
being rewritten, thin delegating shims live in `src/legacy/legacy_api.lua` and forward to the new
managers. They are deprecated by design — a migration aid, not a supported surface. The migration
path and a worked example are in [Migration v1 → v2](migration-v1-v2.md).

### One packing verb: "pack" (ADR 0005)

v1 used two different verbs for the same vehicle-to-crate operation, which confused both users and
code. v2 unifies on a single verb, **pack**, consistently across config keys, F10 menu labels,
method names and comments. This is a project-wide convention, not just a rename of one function.

## Layered dependencies

Managers form a dependency layering rather than a mesh: zero-dependency foundations (config, i18n,
the object registry) at the bottom, domain managers in the middle, and `CTLDCoreManager` as the
orchestrator on top. `CTLDPlayerManager` sits just below the core because it fans out to every
functional manager when it builds a player's menus.

The purpose of the layering is to keep the initialisation order well-defined and to prevent
circular dependencies: a manager may depend on those below it, never on those above. The concrete
ordering and the phased init sequence are documented in
[Architecture](architecture.md#ctldcoremanager-init-sequence); this page only states the principle
behind it.

## The scene engine

Physical constructions — FARPs, FOBs, minefields, multi-crate AA systems — are the part of CTLD
most likely to grow. The design isolates that growth behind a **data-driven scene engine** so that
adding new content never means editing core logic.

- A **scene** is a data file under `src/scenes/`: a model naming the objects to spawn, their
  relative positions (polar offsets from the trigger unit), per-step delays and optional post-spawn
  callbacks. `CTLDSceneManager` is the registry of models; `CtldScene` is a running deployment
  instance.
- Object spawn descriptors are held in `CTLDObjectRegistry` (`src/core/CTLD_objectRegistry.lua`),
  which stores **descriptors, not instances**. Scenes register their components at load time using
  a register-if-absent call, so several scenes can safely share the same descriptor.
- **Self-registration**: a scene file registers itself with `CTLDSceneManager` as its last line, so
  merely adding the file to the build makes the scene available — no central table to edit.
- **Auto-injection**: `CTLDCrateManager` walks the registered scene models and injects each
  scene's crate into the crate menu automatically. A new scene appears as a requestable crate with
  no entry in configuration.

Multi-crate AA systems (HAWK, Patriot, NASAMS, BUK, KUB, S-300) follow the same principle: their
physical assembly is delegated to the scene engine, while `CTLDCrateAssemblyManager` owns the
runtime registry of assembled systems, the rearm/repair logic and the per-coalition limits. The AA
system templates are carried **inline** in `src/CTLD_aasystem.lua` rather than as separate scene
files. The scene-authoring workflow is covered in [Scene engine](subsystems/scenes.md).

## Zones: separation of concerns

v1 had one generic zone concept doing several unrelated jobs. v2 splits it along its real
responsibilities:

| Prefix | Entity | Purpose |
| --- | --- | --- |
| `TRZ_` | `CTLDTroopZone` | Troop pickup + extraction objective (replaces the v1 pickup/extract zones) |
| `WPZ_` | `CTLDTroopZone` | Waypoint zone — deployed troops walk to its centre |
| `LGZ_` | `CTLDLogisticZone` | Logistic point for crate requests and vehicle spawning |

Two decisions drive this shape:

- **A logistic zone is a DCS trigger zone**, not an anchor tied to a static object as in v1. This
  makes zones first-class mission-editor entities and lets a FOB register itself as a dynamic
  logistic zone at runtime.
- **Unpacking is allowed anywhere.** The v1 "far enough from a logistic zone" restriction is
  removed; a crate can be unpacked wherever it is dropped. This simplifies the mental model for
  pilots and removes a class of confusing rejections.

Legacy zone prefixes are still recognised for unmigrated missions but are deprecated. The full
naming schema, fields and validations live in the mission-maker documentation.

## Vehicle transport redesign (EVO-09)

The most significant behavioural design change is how vehicles move. v1 offered a *virtual* vehicle
load from a pickup zone — a workaround from an era when DCS had no native cargo load/unload and CTLD
had no pack feature. Both of those now exist, so the workaround is retired.

The redesign draws a clean line:

- **Pickup zones carry troops only.** The virtual vehicle-transport variables and generator
  functions are removed.
- **Vehicles are pre-placed on the map** by the mission maker as ordinary DCS units. What is placed
  is what is available — the mission maker controls quantity directly, which is more realistic than
  a synthetic pool.

Two transport workflows replace the old one:

```
Workflow A — direct load  (aircraft with native dynamic cargo, e.g. C-130)
  vehicle on map → native DCS load → native DCS unload

Workflow B — pack / unpack  (vehicle too heavy or bulky for direct load)
  vehicle on map → pack (object destroyed, N crates spawned)
                 → load  (native DCS or CTLD menu)
                 → unload (native DCS or CTLD menu)
                 → unpack (crates destroyed, vehicle respawned)
```

`CTLDVehicleSpawner` owns Workflow B exclusively; Workflow A is handled natively by DCS with no CTLD
involvement. Splitting a vehicle into N crates is deliberate — it lets several aircraft cooperate,
each carrying part of the load.

## Dynamic, context-built menus

Each functional class builds its own F10 menu block through a `buildMenu(player)` method rather
than a central menu builder assembling everything. The player manager creates the CTLD root menu
and delegates each block to the manager that owns it, gated by that domain's config and by the
aircraft's capabilities (transport vs. non-transport, whether it can carry vehicles). Keeping menu
construction next to the logic it exposes means a domain's menu can never drift out of sync with
what the domain actually supports.

Menus are also built **on demand** where the available options are contextual. The static "Unpack
Crate" command of v1 is replaced by **Unpack Any Crate**, a submenu rebuilt at click time from the
crates actually near the aircraft (EVO-01). Menu pagination thresholds and the full F10 tree are
detailed in [F10 menu system](subsystems/menu.md).

## Config and i18n access

Two conventions keep cross-cutting access uniform and read-only:

| Shortcut | Expands to | Use |
| --- | --- | --- |
| `ctld.gs("param")` | `CTLDConfig.getInstance():getSetting("param")` | Read a configuration value |
| `ctld.tr("key", ...)` | `CTLDi18n.getInstance():translate("key", ...)` | Translate a display string |

Configuration is **read-only at runtime** and always reached through `ctld.gs(...)`; managers never
call `config:getSetting()` directly and never mutate config. Every user-facing string goes through
`ctld.tr(...)` so that all four shipped languages stay in step. The internationalisation model is
described in [Internationalisation](i18n.md).

## Further reading

- [Architecture](architecture.md) — layout, manager/singleton idiom, init sequence, internal libraries
- [Subsystems](subsystems/index.md) — scenes, crates, zones, menus and the rest of the domain detail
- [API reference](api-reference.md) — the public methods of every manager
- [Migration v1 → v2](migration-v1-v2.md) — the legacy compatibility layer in practice
