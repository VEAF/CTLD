# Scenes & FOB

This page covers two related tools you configure as a mission maker: **scenes** (sequenced
deployments such as a FARP or a minefield that materialise when a pilot unpacks a crate) and the
**FOB** (a forward base pilots assemble from crates that becomes a working logistics zone).

Both are *deployed* by pilots from the cockpit. For the pilot-side actions — spawning, carrying and
unpacking crates, and packing a FARP back up — see [Crates](../pilot/crates.md) and
[Pack](../pilot/pack.md).

---

## Scenes

A **scene** is a sequenced, time-delayed deployment of several DCS objects (statics and/or ground
groups) that plays automatically when a pilot unpacks a designated crate. It lets you stage a
realistic build — a FARP materialising piece by piece, a minefield being laid out — with no
per-mission scripting: you either use a built-in scene or declare a scene model once.

### Built-in scenes

These ship with CTLD and are ready to offer to pilots. Each one self-declares its crate, so it
appears in the **Request Equipment** menu automatically once CTLD is loaded (no extra config).

| Scene name | Crates | What it deploys |
| --- | --- | --- |
| `FARP Alpha` | 1 | Full FARP: helipad, tent, ammo dump, fuel + repair trucks, security squad, decor. Warehouse stocked with 10 000 L of each fuel type. |
| `Countryside FARP` | 3 | Discreet Invisible-FARP heliport + tent, trucks, guard team, lights, windsock. Warehouse zeroed by default (visual FARP, no fuel service). Supports FARP pack. |
| `Metal FARP` | 1 | Metallic helipad (**requires the `Farp_FG_Petit_Helipad` mod**) + trucks, tent, ammo, lights. Warehouse stocked with 10 000 L of each fuel type. Supports FARP pack. |
| `mineField` | 1 | Lays a configurable grid of landmines ahead of the helicopter, marked on the F10 map. See [Minefield](minefield.md). |
| `FOB` | 3 | Forward Operating Base: an animated build that ends as a logistics zone. See [FOB](#fob-forward-operating-base) below. |

> `Metal FARP` needs the `Farp_FG_Petit_Helipad` external mod installed on **all** clients. CTLD
> cannot validate the mod at runtime, so it emits a warning at init and still shows the menu — only
> offer this scene if you are sure every client has the mod.

### How a scene is built

A scene model is a table with a `name`, an optional self-declared `crate`, and an ordered list of
`steps`. Each step is one of three kinds.

**Polar step — deterministic position.** The object spawns at a fixed distance and angle relative to
the helicopter's position and heading (snapshotted at unpack time).

| Field | Type | Description |
|---|---|---|
| `registryKey` | string | Key of the object to spawn (see [Objects](#objects-the-registry)) |
| `polar` | table | `{ distance=N, angle=N }` — distance in metres, angle in degrees clockwise from the aircraft heading (`0` = 12 o'clock) |
| `relativeHeadingInDegrees` | number | Heading of the spawned object relative to aircraft heading |
| `relativeAltitudeInMeters` | number | Altitude offset from helicopter altitude |
| `delayAfterPreviousStep` | number | Seconds to wait *before* this step runs |

**Axis step — random-axis position.** One or more objects spawn along a randomly chosen axis
radiating from the helicopter — natural-looking placement without a hard-coded bearing.

| Field | Type | Description |
|---|---|---|
| `registryKey` | string | Key of the object to spawn |
| `axis` | table | `{ count=N, safeDistance=N, spacing=N }` — object count, distance to the first object (m), spacing between objects (m) |
| `delayAfterPreviousStep` | number | Seconds to wait before this step runs |

**Func-only step — no spawn.** No object is spawned; only a callback runs. Use it for completion
messages, warehouse stocking, or post-build registration.

| Field | Type | Description |
|---|---|---|
| `delayAfterPreviousStep` | number | Seconds to wait before this step runs |
| `func` | function | Callback `function(ctx)` (see below) |

Coalition (BLUE/RED) and country are resolved automatically from the pilot who unpacked the crate.

### Step hooks

Any spawn step can also carry script hooks and a criticality flag:

| Field | Type | Description |
|---|---|---|
| `preFunc` | function | `function(ctx)` run **before** spawn. Return `false` to skip this step's spawn (the scene continues); call `ctx.scene:abort(reason)` to stop the whole scene. |
| `func` | function | `function(ctx)` run **after** spawn (or after a skipped spawn). |
| `critical` | boolean | If `true` and the spawn produces no object, the scene aborts rather than continuing with a broken partial build. |

Every hook receives a single context table `ctx`:

| `ctx` field | Description |
|---|---|
| `ctx.unit` | The trigger unit (the pilot's aircraft) |
| `ctx.spawnedObj` | The last DCS object spawned in this step (`nil` for func-only or skipped steps) |
| `ctx.step` | The current step table |
| `ctx.scene` | The scene instance — read/write `_refX` / `_refZ` / `_refAlt` (reference point), `_params`, etc. |

A scene model may also define `model.onComplete = function(scene) ... end`, called once the last
step finishes.

### Objects: the registry

Scene steps reference objects by a `registryKey` that resolves through **`CTLDObjectRegistry`** — a
catalog of enriched DCS descriptors (helipad frequency, static `shape_name`, multi-unit ground
formations, coalition-aware unit types). This replaces any fixed object list: you register the keys
your scene needs at load time, and shared keys are safe to declare from several scenes.

```lua
CTLDObjectRegistry.registerIfAbsent("FARP_Tent", {
    groupType  = "STATIC",
    namePrefix = "FARP_Tent",
    type       = "FARP Tent",
    category   = "Fortifications",
})
```

`registerIfAbsent` is a no-op when the key already exists, so scenes can co-declare common objects
(`SINGLE_HELIPAD`, `Fuel_Truck`, `FARP_Tent`, `ammo_cargo`, `Windsock`, `NF-2_LightOn`…) without
conflict. Verify any DCS `type` against the datamine dataset before relying on it.

### Declaring a custom scene

**Step 1 — register the objects** your steps use (as above), if they are not already in the
registry.

**Step 2 — declare the scene model** in a mission script loaded after CTLD. Self-declare a `crate`
table so the scene is offered in the Request Equipment menu automatically:

```lua
local myScene = {
    name = "My FARP",

    -- Auto-injected into the Request Equipment menu — no spawnableCrates entry needed.
    crate = {
        weight         = 1050.00,
        i18nKey        = "My FARP Crate",   -- display name (translation key)
        deployKey      = "Deploy My FARP",  -- menu label (translation key)
        cratesRequired = 1,
        side           = nil,               -- nil = both coalitions
    },

    steps = {
        -- polar step: helipad 100 m ahead, facing south relative to the helicopter
        { registryKey = "SINGLE_HELIPAD", polar = { distance = 100, angle = 0 },
          relativeHeadingInDegrees = 180, relativeAltitudeInMeters = 0, delayAfterPreviousStep = 0 },
        -- polar step: tent 130 m ahead-right, 3 s later
        { registryKey = "FARP_Tent", polar = { distance = 130, angle = 5 },
          relativeHeadingInDegrees = 90, relativeAltitudeInMeters = 0, delayAfterPreviousStep = 3 },
        -- axis step: scatter 3 ammo crates along a random axis
        { registryKey = "ammo_cargo", axis = { count = 3, safeDistance = 30, spacing = 8 },
          delayAfterPreviousStep = 5 },
        -- func-only step: completion message
        { delayAfterPreviousStep = 0,
          func = function(ctx)
              trigger.action.outText("FARP ready at " .. ctx.unit:getName(), 10)
              return true
          end },
    },
}

CTLDSceneManager.getInstance():registerSceneModel(myScene)
```

That is all that is required: pilots load the crate at a logistics zone, fly to the target, and
unpack — the scene plays automatically.

> **Migration note.** Earlier versions used an `objectsDescDbKey` field and a `func(unit,
> spawnedObj, step)` signature, and required a matching `spawnableCrates` entry with `unit =
> "<scene name>"`. The current API uses **`registryKey`**, a single **`func(ctx)`** context table,
> and a **self-declared `crate` table** on the model. Update older scene scripts accordingly.

### FARP pack

When `enableFARPRepack = true` (default), a pilot on the ground within **300 m** of a deployed FARP
scene that supports packing gets a **Pack Equipt → Pack `<scene name>`** entry under **Crate
Commands**. Packing it:

1. Captures the FARP warehouse state (fuel, and where applicable weapons/aircraft) via the scene's
   `onRepack` hook.
2. Destroys the deployed scene objects.
3. Spawns the required crates near the helicopter, carrying the warehouse snapshot.

When those crates are unpacked at a new location, the warehouse is restored to the captured levels
instead of the defaults.

```lua
cfg.settings["enableFARPRepack"] = false  -- default: true
```

**Scenes that support packing:** `Countryside FARP`, `Metal FARP`.

To make a **custom** scene packable, add an `onRepack(scene, repackData)` hook that records what
should be restored, and have your warehouse step check `ctx.scene._params.repackData` to decide
between restoring the snapshot and applying defaults:

```lua
myScene.onRepack = function(scene, repackData)
    local farpName = scene._params and scene._params.farpName
    if not farpName then return end
    local ab = Airbase.getByName(farpName)
    if not ab then return end
    local w = ab:getWarehouse()
    if not w then return end
    repackData.warehouseSnapshot = {
        liquid = { [0] = w:getLiquidAmount(0), [1] = w:getLiquidAmount(1),
                   [2] = w:getLiquidAmount(2), [3] = w:getLiquidAmount(3) },
    }
end
```

> The config key `enableFARPRepack` and the model hook `onRepack` keep their legacy names, but the
> in-game action is **pack** everywhere — the menu reads "Pack Equipt".

---

## FOB — Forward Operating Base

A FOB is a deployable forward base built from crates. Once built it registers automatically as a
logistics zone (pilots can spawn crates and vehicles from it) and, optionally, as a troop pickup
zone.

> **FOBs are the only way to create a new logistics zone at runtime.** If your mission needs
> logistics at a position decided during play, deploy a FOB rather than pre-placing an `LGZ_`
> trigger zone. See [Zone setup](zones.md).

The FOB is delivered as the built-in **`FOB`** scene: an animated ~120 s construction that ends by
registering the base. It requires **3 FOB crates** by default (set on the scene's `crate` table, not
a global setting).

### Build flow (pilot side)

1. The pilot loads the required FOB crates and flies to the target area.
2. Unpack is triggered from the F10 menu (**Crate Commands → Unpack Crate(s)** with FOB crates
   nearby). CTLD checks that all required crates are within **750 m** of each other and that the
   site is outside any active logistics zone and at least `fobMinDistanceFromZones` from existing
   zones.
3. The FOB scene plays; structures spawn in sequence.
4. On completion: a radio [beacon](../pilot/beacons.md) is dropped at the FOB centre, the area
   registers as a logistics zone, and — if `troopPickupAtFOB = true` — as a troop pickup zone.

Pilots can list active FOBs via **CTLD → FOBs List → List active FOBs**.

### FOB destruction

If enemy action destroys enough FOB structures that the surviving fraction drops below
`(1 - fobDestructionThreshold)`, the FOB is considered destroyed: its logistics zone is unregistered
immediately, its beacon is removed, and the `OnFOBDestroyed` event fires.

| `fobDestructionThreshold` | Structures that must survive | FOB lost when |
| --- | --- | --- |
| `0.5` (default) | > 50 % | ≥ 50 % destroyed |
| `0.75` | > 25 % | ≥ 75 % destroyed |
| `1.0` | > 0 % (any survivor) | all structures destroyed |

> Once destroyed, the FOB logistics zone is gone for the rest of the mission — there is no automatic
> rebuild. Pilots must deploy new FOB crates elsewhere to restore logistics in that area.

### Configuration

| Parameter | Default | Description |
|---|---|---|
| `enabledFOBBuilding` | `true` | Enable FOB construction and the FOB menu |
| `troopPickupAtFOB` | `true` | Register a deployed FOB as a troop pickup zone |
| `fobMinDistanceFromZones` | `500` | Minimum distance (m) from existing logistics zones to allow deployment |
| `fobLogisticZoneRadius` | `150` | Radius (m) of the logistics zone created around the FOB |
| `fobDestructionThreshold` | `0.5` | Fraction of scene objects destroyed before the FOB is lost (0.0–1.0) |
| `fobTroopPickupRadius` | `150` | Radius (m) within which troops can be picked up at a FOB |

```lua
cfg.settings["enabledFOBBuilding"]      = true
cfg.settings["troopPickupAtFOB"]        = true
cfg.settings["fobMinDistanceFromZones"] = 500
cfg.settings["fobLogisticZoneRadius"]   = 150
cfg.settings["fobDestructionThreshold"] = 0.5
cfg.settings["fobTroopPickupRadius"]    = 150
```

> The number of crates a FOB needs is **not** a global setting — it lives on the `FOB` scene's
> `crate.cratesRequired` field (default 3), and the build is self-timed by the scene. Older docs
> referenced `cratesRequiredForFOB` and `buildTimeFOB`; those settings no longer exist.

### Events

| Event | Fired when |
|---|---|
| `OnFOBDeployed` | FOB construction completed and the base is fully active |
| `OnFOBDestroyed` | FOB destroyed by enemy action |
