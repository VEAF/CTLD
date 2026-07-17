# Scene engine

**Source:** `src/CTLD_sceneManager.lua`, `src/scenes/*.lua`
**Classes:** `CtldScene` (one running instance), `CTLDSceneManager` (singleton registry + engine)

`CTLDSceneManager` executes time-sequenced deployments of DCS statics and ground groups from a
declarative **model**. It is the backend for every FARP, FOB and minefield deployment: a scene
model lists ordered *steps*, and the engine spawns each step's objects relative to a position
snapshot, waiting a configurable delay between them.

Scene models live one per file under `src/scenes/` and self-register at load time via
`CTLDSceneManager.getInstance():registerSceneModel(model)`. `CTLDSceneManager:_registerBuiltins()`
is intentionally empty — there is no hard-coded model list.

## Internal data model

```
CtldScene (one instance per active deployment)
  ├── _name        : "<modelName>#<counter>"  (unique per deployment)
  ├── _modelName   : original model name (used for registry / pack lookups)
  ├── _unit        : trigger DCS Unit (or a mock unit for playSceneAtPos)
  ├── _steps       : model.steps (shared reference)
  ├── _stepIndex   : current step pointer (0 before the first step)
  ├── _timeMarker  : absolute timer.getTime() target for the next step
  ├── _spawnedObjs : { DCSObject, … }  (every object spawned so far)
  ├── _params      : runtime bag forwarded to step funcs (e.g. farpName, repackData)
  ├── _onComplete  : callback fired after the last step (or model.onComplete)
  ├── _aborted     : true once abort() is called
  ├── _coalitionId / _countryId       : snapshot at init
  └── _refX / _refZ / _refAlt / _refHdgRad / _magDecDeg : position + heading snapshot

CTLDSceneManager (singleton, via getInstance())
  ├── _models[modelName] : registered model tables
  └── _active[sceneName] : CtldScene instances currently deployed
```

`_models` is keyed by model name; `_active` is keyed by the per-deployment `_name`
(`"<modelName>#<counter>"`), so several instances of the same model can be active at once. Both
tables are in-memory only — `_active` does not survive a mission restart or a full CTLD
re-injection during development.

The reference position and heading are captured **once** in `CtldScene:init()` from the trigger
unit (`unit:getPoint()` and `ctld.utils.getHeadingInRadians`). Every subsequent step is positioned
relative to that snapshot, so the scene deploys coherently even if the unit moves or leaves. A
step's `func` may overwrite `_refX` / `_refZ` / `_refAlt` on `ctx.scene` before later spawn steps
run.

## Step execution

The step machine is driven by `timer.scheduleFunction`. `CtldScene:_execute()` schedules the first
step after `steps[1].delayAfterPreviousStep` seconds; `_runNextStep()` then executes the current
step and schedules the next. Each step is one of three shapes:

| Step type | Key fields | Behaviour |
| --- | --- | --- |
| **polar** | `polar = { distance, angle }`, `relativeHeadingInDegrees`, `relativeAltitudeInMeters`, `registryKey` | Deterministic world position derived from the snapshot via `ctld.utils.getRelativeCoords`. |
| **axis** | `axis = { count, safeDistance, spacing }`, `registryKey` | A random axis around the unit; `count` objects distributed along it via `ctld.utils.getSpawnObjectPositions`. |
| **func** | `func = function(ctx) … end` | No spawn — runs the callback only (post-spawn hook / custom placement). |

Every step also carries `delayAfterPreviousStep` (seconds): after step *N* runs, the engine waits
that many seconds before step *N+1*. The same field on step 1 is the initial delay from the
trigger.

For a spawning step (`registryKey` present, spawn not skipped), `_runNextStep()`:

1. Runs the optional **`preFunc(ctx)`** with `ctx = { unit, step, scene }`. Returning `false`
   skips this step's spawn (the scene continues); calling `ctx.scene:abort(reason)` stops the
   scene entirely.
2. Looks up the descriptor with `CTLDObjectRegistry.get(step.registryKey)` and auto-injects
   `circleRadius` when the descriptor uses a `circle` formation.
3. Spawns via **`CTLDObjectRegistry.spawnObject(registryKey, coalitionId, countryId, x, z, hdg, overrides)`**
   — the engine never calls `coalition.addStaticObject` / `coalition.addGroup` directly (a
   `func`-only step may, as the countryside FARP does for its boundary tyres).
4. Appends every spawned object to `_spawnedObjs`.
5. If `step.critical` is set and nothing spawned, calls `abort()` rather than continuing with a
   broken partial scene.
6. Runs the optional **`func(ctx)`** with `ctx = { unit, spawnedObj, step, scene }`, where
   `spawnedObj` is the last object spawned this step (`nil` for a skipped or `func`-only step).

Both hooks are wrapped in `pcall`; an error is logged (`ERROR`) and the scene proceeds. When the
last step finishes, `_onComplete(scene)` fires (also under `pcall`). A model may set
`model.onComplete`; a caller-supplied callback to `playScene` overrides it.

### Entry points

| Method | Use |
| --- | --- |
| `playScene(unit, modelName, params, onComplete)` | Start a scene from a live trigger unit. Rejects a nil/dead unit, an unknown model, or a `_disabled` model. |
| `playSceneAtPos(modelName, pos, coalitionId, countryId, params)` | Start a scene with no live unit (e.g. parachute auto-unpack). Builds a minimal mock unit at `pos` facing north and delegates to `playScene`. |

Both register the new `CtldScene` in `_active` before executing.

## FARP pack flow

Packing tears a deployed FARP scene back down into crates while preserving its warehouse state.
The flow is split across the scene manager and [`CTLDCrateManager`](crates.md):

```
Player selects "Pack Equipt → Pack <scene>"
  └── CTLDCrateManager:refreshPackEquiptSection(playerObj)
        └── CTLDSceneManager:findNearbyRepackableScenes(transport:getPoint(), 300)
              └── returns _active scenes within radius whose model defines onRepack
        └── on click, per scene:
              1. sc = CTLDSceneManager._active[sceneName]
              2. repackData = CTLDSceneManager:packScene(sc)
                    ├── model.onRepack(sc, repackData)   ← snapshot warehouse into repackData
                    ├── destroy every obj in sc._spawnedObjs
                    └── _active[sc._name] = nil
              3. spawn cratesRequired crates via CTLDCrateManager:spawnCrate(...)
                    └── crate.metadata.warehouseSnapshot = repackData.warehouseSnapshot

On crate unpack at a new site (auto-unpack path in CTLDCrateManager):
  └── sm:getModel(desc.unit) resolves the scene model
        └── CTLDSceneManager:playSceneAtPos(desc.unit, centroid, coa, cId, { repackData = … })
              └── warehouse step reads ctx.scene._params.repackData.warehouseSnapshot to restore fuel/inventory
```

`packScene(scene)` takes only the scene instance; `onRepack(scene, repackData)` is where a model
writes its `repackData.warehouseSnapshot`. The snapshot travels on the crate through
`crate.metadata.warehouseSnapshot` and is threaded back into the new scene's `_params.repackData`
so the warehouse-stocking step can restore liquids and inventory instead of zeroing them.

The relevant identifiers (`onRepack`, `findNearbyRepackableScenes`, `packScene`, `repackData`,
`warehouseSnapshot`) keep their spelling in code; the F10 label is `ctld.tr("Pack %1", …)`.

## Adding a new scene (dev checklist)

1. Create `src/scenes/CTLD_myScene.lua`: a local model table with `name` and `steps`, ending with
   `CTLDSceneManager.getInstance():registerSceneModel(myScene)`.
2. Declare the crate on the model itself — `myScene.crate = { weight, i18nKey, deployKey,
   cratesRequired, side, … }`. It is auto-injected into the Request Equipment menu by
   `CTLDCrateManager:_processSpawnableCrates` / `_injectSceneCrate`; there is no `unit = "…"` entry
   to add in `CTLD_userConfig.lua`.
3. Register any DCS objects the steps reference with `CTLDObjectRegistry.registerIfAbsent(key,
   descriptor)` and point each step's `registryKey` at them.
4. Add the file to `tools/build/listToMerge.txt` (scenes are listed **after** all managers so the
   crate auto-injection resolves) and add the matching `dofile` line to `tests/helpers/loader.lua`.
5. If the scene deploys a mod-based helipad FARP with a warehouse, add a `func`-only final step
   that stocks it via `w:setLiquidAmount(fuelType, qty)` (fuel types `0`–`3`: jet fuel, aviation
   gasoline, MW50, diesel). Read levels with `w:getLiquidAmount(fuelType)`, never `getLiquid`.
   Invisible FARP airbases return `nil` from `getWarehouse()`, so guard for it.
6. For pack support, implement `myScene.onRepack(scene, repackData)` that reads
   `w:getLiquidAmount(...)` and `w:getInventory()` into `repackData.warehouseSnapshot`.
7. To make the scene deployable as a FOB, set `fobCompatible = true` **inside the `crate` table**
   (`myScene.crate.fobCompatible`). A FOB scene typically also supplies a custom
   `crate.unpack = function(unit, unitName, sceneName) … end` delegating to `CTLDFOBManager`.
8. If the scene spawns a **mod** (non-stock) type, list it in `myScene.modTypes = { "Type_Name" }`
   (the design-time asset gate accepts it while staying strict on every other type) and set
   `myScene.requiresMod = "<human label>"` for the catalogue. Optionally set
   `myScene.requiresCtld = "X.Y.Z"` to warn on an incompatible CTLD.

`src/scenes/CTLD_countrysideFarpScene.lua` is the reference implementation (Invisible FARP +
warehouse stocking + `onRepack`); `src/scenes/CTLD_fobScene.lua` shows the FOB variant.

## Plugin scenes (load-position-independent)

A scene's source is **load-position-independent**: the same file works whether merged into
`CTLD.lua` (built-in) or loaded from a mission-start trigger **after** CTLD (a plugin, distributed
by [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins)). Mod-dependent or niche scenes ship
as plugins so a mission only pays for them if it opts in.

This works because every extension point tolerates being invoked after CTLD init:

- `registerSceneModel` injects the crate immediately if `CTLDCrateManager` is already initialised;
- i18n assignments are plain table writes (order-independent);
- `CTLDPlayerManager.deferMenuSection` routes to the live manager (`registerMenuSection`) when
  called post-init instead of queuing into the drained pre-init queue.

Contract for a plugin scene: load at **mission start only** (before players slot in), declare
`requiresCtld`, and declare any mod types in `modTypes`. The `_template` reference scene in
CTLD_plugins exercises every extension point (including a radio submenu).

## Asset validation (design-time)

Scene DCS types are validated at **dev/CI time**, not at runtime (ADR 0007). The busted hard-gate
`tests/ci/unit/scene_asset_gate_spec.lua` collects the types each scene spawns (STATIC `desc.type`,
GROUND `desc.units[].type`) and fails on any type absent from the vendored datamine set
(`tests/data/dcs_types.lua`) ∪ the union of every scene's `modTypes`. `modTypes` is additive, so a
typo in a stock type is still caught even in a descriptor that also uses a whitelisted mod type.

The old runtime audit (`_auditAfterModValidator`, `model._disabled`, `_purgeDisabledScenes`) was
removed; `CTLDModValidator` (crates/troops) is unchanged. `isSceneEnabled(name)` now simply reports
whether the model is registered.
