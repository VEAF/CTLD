# Vehicle system

The vehicle system moves **whole ground units** by air: a transport picks up a drivable
vehicle at a logistic zone, carries it, and sets it back down in the field — without ever
breaking it into crates. It is the counterpart to the crate pipeline (see [crates](crates.md)),
and it also underpins ground-JTAC spawning (see [Troop + JTAC lifecycle](troops-jtac.md)).

**Source:** `src/CTLD_vehicle.lua`
**Entity:** `CTLDVehicle`
**Singleton:** `CTLDVehicleSpawner`

`CTLDVehicleSpawner` follows the standard manager idiom (`X = class()` + `getInstance()` — see
[Architecture](../architecture.md)): a single `_instance`, allocated lazily on first
`CTLDVehicleSpawner.getInstance()`. `CTLDVehicle` is a plain entity created with `:new(data)`.

```lua
CTLDVehicle        = class()
CTLDVehicleSpawner = class()
CTLDVehicleSpawner._instance = nil

function CTLDVehicleSpawner.getInstance()
    if not CTLDVehicleSpawner._instance then
        local o = setmetatable({}, CTLDVehicleSpawner)
        o:init()
        CTLDVehicleSpawner._instance = o
    end
    return CTLDVehicleSpawner._instance
end
```

At `init()` the singleton registers its F10 menu section (`order = 30`), subscribes to the DCS
`S_EVENT_DEAD` bridge, subscribes to several bus events, and starts three periodic timers
(native-load detection, packing-landing refresh, hover hint).

## State machine

`CTLDVehicle.STATE` declares three states:

| State | Meaning |
| --- | --- |
| `WAITING` | On the ground, tracked, ready to be loaded |
| `LOADED` | Carried by a transport (DCS unit destroyed for `menu_ctld`, or physically linked for `dcs_native`) |
| `DELIVERED` | Declared but **not currently assigned** — reserved for a future dedicated delivered state |

The transitions actually performed by the current code are:

```
        spawn / register              loadVehicle
   (none) ───────────────► WAITING ──────────────► LOADED
                              ▲                        │
                              │      unloadVehicle     │
                              └────────────────────────┘
                              │   parachuteVehicle
                              └─── (drop, then respawn) ─► WAITING
```

Both `unloadVehicle` and `parachuteVehicle` return the vehicle to `WAITING` (not `DELIVERED`)
so it can be re-loaded once it is back on the ground. `setState(newState)` performs no
validation — callers own correctness.

## Load and unload methods

Load and unload each carry a `method` string:

| Direction | Method | Trigger |
| --- | --- | --- |
| Load | `menu_ctld` | Player picks a vehicle from the **Load / Extract Vehicles** F10 submenu; the DCS unit is destroyed on load |
| Load | `dcs_native` | A whole vehicle enters a native-cargo transport's bounding box (C-130 / Il-76 class); DCS keeps the unit physically linked |
| Unload | `menu_ctld` | Player picks a vehicle from **Unload Vehicles**; the unit is respawned near the transport |
| Unload | `dcs_native` | DCS has already placed the unit on the ground; CTLD only recovers the live reference |
| Unload | `parachute` | Airborne drop via **Parachute Vehicle** |

## Where a `WAITING` vehicle comes from

A loadable `CTLDVehicle` in `WAITING` state is registered from one of these paths:

| Source | Mechanism |
| --- | --- |
| MM pre-placed vehicle | INIT-D `scanMMVehicles()` scans both coalitions' `Group.Category.GROUND` groups and calls `_registerMMVehicleUnit(unit)` for each **live** unit whose type has a CTLD crate descriptor (`findDescriptorByUnitType`) |
| Late activation | `S_EVENT_BIRTH` → `onBirth` defers one frame → `_onBirthDeferred` → `_registerMMVehicleUnit` (or re-attaches a live unit reference to an existing vehicle after unload) |
| Programmatic spawn | `spawnVehicleForTransport(vehicleType, spawner, logisticZone)` spawns a fresh unit near a transport and registers it `WAITING` |
| Crate unpack | `spawnVehicleAt(spawnData, position)` / `registerJTACVehicle(...)` register a unit produced by the crate/JTAC unpack flow |

`_registerMMVehicleUnit` is idempotent: it skips a unit already present in the
`_unitToVehicle` reverse-lookup map.

### `spawnVehicleForTransport`

Spawns a drivable unit in the transport's **front sector** via `ctld.utils.dynAdd`, creates the
`CTLDVehicle` in `WAITING`, and publishes `OnVehicleSpawnedForTransport`. Group and unit names are
assigned as `CTLD_VEH_<type>_<id>` (with whitespace and slashes replaced by `_`), and preserved in
`spawnData` so the unit re-appears under the same name after any later unload. The JTAC ground path
(`spawnJTACFromDescriptor`) calls this, then `CTLDJTACManager:startLase(...)`.

> The Feature-Q "Request Equipment spawns a whole vehicle" branch exists in
> `CTLDCrateManager:refreshRequestEquipmentSection` but is currently inert: the menu builder sets
> `spawnAsVehicle = false` for every entry, so **Request Equipment (order 25) only ever spawns
> crates**. Whole-vehicle loading is driven by the dedicated Vehicle Commands menu against
> vehicles that are already `WAITING`.

## Load pipeline — `loadVehicle(vehicle, transport, player, method)`

1. Reject unless the vehicle is `WAITING`.
2. `menu_ctld` capacity guard: read `caps.maxWholeVehiclesOnboard` (default `1`) from the
   transport's `capabilitiesByType` entry, count `findLoadedVehicles(transport)`, and refuse
   with a player message if the hold is full. (`dcs_native` capacity is left to DCS.)
3. If the vehicle is a registered JTAC, suspend lasing (`setJTACInTransit`).
4. `menu_ctld`: destroy the DCS unit, publish `OnGroundUnitRemoved` (`reason = "loaded"`), and
   clear the reverse lookup. `dcs_native`: keep the unit alive but drop it from the reverse
   lookup so a stale `S_EVENT_DEAD` cannot misfire.
5. Record `loadMethod`, `loadTransportName`, `loadTime`; set state `LOADED`.
6. `menu_ctld` only: recompute the transport's internal cargo weight (`_updateVehicleCargo`) and
   send a confirmation message.
7. Publish `OnVehicleLoaded`.

The maximum pick-up distance is **not** enforced in `loadVehicle`; it is applied upstream in
`findLoadableVehicles` (≤ `maximumDistancePackableUnitsSearch`, default 200 m).

## Unload pipeline — `unloadVehicle(vehicle, transport, player, method, rearSector)`

1. Reject unless the vehicle is `LOADED`.
2. Compute a spawn position with `_computeSpawnPosition(transport, rearSector)`.
3. `menu_ctld` / `parachute`: respawn the unit near the transport with `ctld.utils.dynAdd`,
   reusing `spawnData.groupName` / `spawnData.unitName`. `dcs_native`: recover the live unit that
   DCS already placed via `Group.getByName(spawnData.groupName)`.
4. Set state back to `WAITING`; re-register the reverse lookup.
5. Non-`dcs_native`: recompute cargo weight. Resume JTAC lasing if applicable.
6. `menu_ctld` only: send a confirmation message.
7. Publish `OnVehicleUnloaded`.

> The dev-guide draft described unload as re-spawning through `CTLDObjectRegistry.spawnObject`;
> the current code respawns through `ctld.utils.dynAdd` and does not use the object registry here.

## Spawn positioning

`_computeSpawnPosition(transport, rearSector)` (public wrapper `computeSafeDropPos`) places the
unit in a ±45° sector of the transport heading — the **front** sector by default, or the **rear**
sector (`hdg + π`) when `rearSector` is true, which keeps the drop clear of an AI helicopter's
takeoff path. The radial offset comes from `_secureOffset`, the bounding-box diagonal
`sqrt(halfLen² + halfWid²) × 2 + 10` m, falling back to 60 m when `getDesc().box` is unavailable.

## DCS-native whole-vehicle loading — `_checkNativeLoading` (1 s tick)

For native-cargo transports the load is detected geometrically rather than through a menu.
Each tick:

- Collect `WAITING` vehicles with live units and `LOADED` vehicles whose `loadMethod == "dcs_native"`.
- Iterate `Group.Category.AIRPLANE` groups of both coalitions; for each unit that is
  `_isNativeCargoCapable` (its `capabilitiesByType` entry sets `canTransportWholeVehicle == true`),
  read `getTransformation()` and `getDesc().box`.
- For each `WAITING` vehicle, convert its world position into the transport's local frame
  (`_worldToLocal`) and test it against the box (`_isInBbox`). On entry, call
  `loadVehicle(veh, transport, nil, "dcs_native")` and record the transport in `_nativeTracked`
  to prevent a double-fire.

The bbox **exit** branch is present but currently a no-op (the loaded unit's position cannot be
queried once destroyed); native unload is handled through the `dcs_native` unload path rather than
this loop.

## Loadable filtering — `findLoadableVehicles` / `_isTypeLoadable`

`findLoadableVehicles(transport)` returns the `WAITING` vehicles a given transport may load,
applying three filters on top of the capability gate:

- The transport's `capabilitiesByType` entry must set `canTransportWholeVehicle`, else `{}`.
- **Coalition (GAP-Q1):** `veh.spawnData.coalitionId` must equal the transport coalition.
- **Type (GAP-Q2):** `_isTypeLoadable` requires `veh.vehicleType` to appear in the transport's
  `loadableVehiclesRED` (coalition 1) or `loadableVehiclesBLUE` (coalition 2) list.
- **Distance:** ≤ `maximumDistancePackableUnitsSearch`.

Vehicle unit references are resolved lazily inside the loop (`Group.getByName` can lag one frame
behind `coalition.addGroup`).

## Transport capabilities

Whole-vehicle behaviour is driven by the transport's `capabilitiesByType` entry
(`ctld.gs("capabilitiesByType")`), plus the per-player `canCarryVehicles` flag:

| Field | Effect |
| --- | --- |
| `canTransportWholeVehicle` | Enables whole-vehicle load/unload for this type |
| `maxWholeVehiclesOnboard` | Simultaneous whole-vehicle capacity (`0` = none) |
| `loadableVehiclesRED` / `loadableVehiclesBLUE` | DCS type names this aircraft may load, per coalition |
| `canParachuteDrop` | Enables the **Parachute Vehicle** entry |
| `useNativeDcsCargoSystem` | Marks the type as a native-cargo carrier |

## Packing a vehicle back into crates — `packVehicle`

`findPackableVehicles(transport)` lists CTLD-managed `WAITING` vehicles within
`maximumDistancePackableUnitsSearch` (only tracked vehicles — never arbitrary scene props).
`packVehicle(transportUnitName, packableUnitName, playerObj)`:

1. Resolve the descriptor for the unit type (`findDescriptorByUnitType`); refuse if none.
2. Silently deregister any JTAC on the unit, then `destroy()` it and publish `OnGroundUnitRemoved`
   (`reason = "packed"`).
3. Spawn `descriptor.cratesRequired` crates via `CTLDCrateManager:spawnCratesAligned(...)` with
   `CTLDCrate.SPAWN_METHOD.VEHICLE_PACK`, in the front sector (helicopter) or rear sector
   (native-cargo aircraft).
4. Publish `OnVehiclePacked`, then rebuild the player menu one frame later (to dodge the
   one-frame `coalition.getGroups()` lag after `destroy()`).

The landing-triggered pack-menu refresh (`_checkPackingLanding`, 3 s tick) is gated on
`ctld.gs("enablePackingVehicles")`.

## Parachute drop — `parachuteVehicle`

Requires `caps.canParachuteDrop`. Checks AGL against `parachuteMinAltitudeVehicles` (default 30 m)
and refuses if too low. Resolves the vehicle (explicit id, else the first vehicle loaded on that
transport), computes the landing point with `ctld.utils.calcDropPosition` using
`parachuteDescentRateVehicles` (default 8 m/s), sets the vehicle back to `WAITING`, publishes
`OnVehicleParachuting`, and after the descent delay respawns it at the landing position and
publishes `OnVehicleParachuteLanded` (resuming JTAC lasing if applicable).

## Cargo weight

`getLoadedVehicleWeight(transportUnitName)` sums `ctld.gs("groundVehicleWeights")` for `LOADED`,
`menu_ctld` vehicles only (default 2500 kg per unknown type); `dcs_native` weight is left to DCS.
`_updateVehicleCargo` delegates to `ctld.utils.updateTransportWeight`, which aggregates troops,
crates, and vehicles into a single `setUnitInternalCargo` call.

## F10 menu — `buildMenuSection`

Added only when the player unit has `canCarryVehicles`. It creates **Vehicle Commands**
(`order = 30`) with three dynamic branches:

- **Load / Extract Vehicles** — rebuilt by `refreshLoadSection`; disabled while airborne; lists
  the result of `findLoadableVehicles`. Selecting an entry calls `loadVehicle(..., "menu_ctld")`.
- **Unload Vehicles** — rebuilt by `refreshUnloadSection`; hidden when nothing is loaded, shows
  "Land to unload vehicles" while airborne, otherwise lists loaded vehicles.
- **Parachute Vehicle** — present only when `caps.canParachuteDrop`; enabled only when airborne
  with a vehicle loaded.

Refreshes are driven by the landing detector (`_checkPackingLanding`), the ground-unit
spawn/removal bus events (`OnGroundUnitSpawned` / `OnGroundUnitRemoved`), and the load/unload
events themselves. A hover-hint timer (`_checkVehicleHoverHint`, 5 s tick, 30 s per-player
cooldown) nudges a hovering carrier to land over a nearby `WAITING` vehicle.

## DCS event handling

- **`onDead` (`S_EVENT_DEAD`)** — if the dead unit is a tracked vehicle, remove it and publish
  `OnVehicleDead` + `OnGroundUnitRemoved`. Otherwise, if it is a transport that was carrying
  `LOADED` vehicles, each carried vehicle is considered lost: its JTAC is deregistered and
  `OnVehicleDead` is published for it.
- **`onBirth` (`S_EVENT_BIRTH`)** — see the late-activation source above.

## Events published

| Event | When |
| --- | --- |
| `OnVehicleSpawnedForTransport` | `spawnVehicleForTransport` created a `WAITING` vehicle |
| `OnVehicleLoaded` | Vehicle loaded into a transport |
| `OnVehicleUnloaded` | Vehicle unloaded / dropped from a transport |
| `OnVehicleDead` | Tracked vehicle destroyed, or lost with its transport |
| `OnVehiclePacked` | Vehicle packed back into crates |
| `OnVehicleParachuting` | Parachute drop started |
| `OnVehicleParachuteLanded` | Parachuted vehicle reached the ground |
| `OnGroundUnitSpawned` / `OnGroundUnitRemoved` | A tracked ground unit appeared / disappeared (drives menu refresh) |

See [Events](../events.md) for the full bus catalogue and payload shapes.
