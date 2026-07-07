# Events

CTLD has **two distinct event channels**, and they never overlap:

| Channel | Class | Carries | Source page |
| --- | --- | --- | --- |
| Business events | `EventDispatcher` | CTLD domain events (`OnCrateLoaded`, `OnTroopsDeployed`, …) | this page |
| DCS engine events | `CTLDDCSEventBridge` | Raw `S_EVENT_*` from the simulator | see [Architecture](architecture.md) |

`EventDispatcher` is the internal pub/sub bus that managers use to signal domain
changes to each other and to external mission scripts. DCS engine events (`S_EVENT_DEAD`,
`S_EVENT_BIRTH`, …) **never** pass through it — they arrive via `CTLDDCSEventBridge`, are
handled by the relevant manager, and only then re-emitted as business events where useful.

## The `EventDispatcher` API

`EventDispatcher` is a singleton declared in `src/CTLD_core.lua`. Obtain it with
`getInstance()`; there is no `:new()` entry point for it.

```lua
local ed = EventDispatcher.getInstance()
```

### `subscribe(eventName, callback)`

Registers a callback for a named event. The callback receives the event payload table as
its single argument.

```lua
EventDispatcher.getInstance():subscribe("OnCrateLoaded", function(evt)
    -- evt.crateName, evt.carrierUnitName, evt.coalition, ...
end)
```

The same callback may be registered more than once; each registration produces one
additional call on publish. Callers are responsible for avoiding accidental duplicate
subscriptions. A non-function `callback` is silently ignored.

### `unsubscribe(eventName, callback)`

Removes a previously registered callback. The `callback` argument must be the **exact same
function reference** used at subscribe time (keep a local reference if you intend to
unsubscribe). Only the last-registered matching occurrence is removed per call.

```lua
local function onLoaded(evt) --[[ ... ]] end
local ed = EventDispatcher.getInstance()
ed:subscribe("OnCrateLoaded", onLoaded)
-- later:
ed:unsubscribe("OnCrateLoaded", onLoaded)
```

### `unsubscribeAll(eventName)`

Drops every subscriber for one event — used on module teardown.

```lua
EventDispatcher.getInstance():unsubscribeAll("OnCrateLoaded")
```

### `publish(eventName, payload)`

Dispatches `payload` to every subscriber of `eventName`.

```lua
EventDispatcher.getInstance():publish("OnMySomethingHappened", {
    unitName  = "UH-1H-1",
    coalition = coalition.side.BLUE,
    timestamp = timer.getAbsTime(),
})
```

Two guarantees matter for authors:

- **Callback isolation.** Each subscriber is invoked in a `pcall`. A callback that errors is
  logged (`ERROR`, `EventDispatcher:publish [<event>] callback error: …`) and does **not**
  abort the remaining subscribers.
- **Re-entrancy safety.** The subscriber list is copied before iteration, so a callback may
  safely `subscribe` or `unsubscribe` during dispatch without affecting the in-flight
  dispatch.

Publishing an event with no subscribers is a no-op (cheap early return).

### Payload convention

By convention every CTLD event carries a `timestamp` field set to `timer.getAbsTime()`.
Beyond that, fields are event-specific — see the catalogue below. Managers publish through
thin private helpers (`CTLDCrateManager:_publish`, `CTLDJTACManager:_publishEvent`) that
forward to `EventDispatcher:publish`; subscribers see no difference.

### Migrating from the v1 callback

v1 used a single catch-all `ctld.addCallback` with an `if event.id == …` chain. v2 replaces
it with targeted subscriptions — see
[Migration v1 → v2](migration-v1-v2.md) for the full worked example.

```lua
-- v2: one subscription per event of interest, no id dispatch chain
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    -- evt.crateName, evt.coalition, evt.spawnedBy, evt.position
end)
```

## Event catalogue

Events are grouped by publishing domain. Every payload also carries `timestamp` (omitted
from the tables unless it is the only field). "Published by" names the manager and the
method(s) that emit the event, verified against `src/`.

Almost all event names use the `On<Something>` convention. The two exceptions are the RECON
FARP events (`ReconFarpDetected`, `ReconFarpLost`), which have no `On` prefix — subscribe to
them by their exact names.

### Beacon events (5)

#### `OnBeaconDropped`
A radio beacon is deployed (by a player or from a zone).

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | Player name, or `"MissionMaker"` if from a zone |
| `playerUnit` | Unit or nil | DCS Unit object |
| `coalition` | number | Coalition ID |
| `beacon` | table | Full beacon payload (see note) |

`beacon` sub-table: `{ beaconName, name, position (vec3), mgrsCoords, frequencies { vhf, uhf, fm }, battery { remainingTime, wasInfinite, duration, infinite } }`

**Published by**: `CTLDBeaconManager:dropBeacon()`, `:createAtZone()`

#### `OnBeaconRemoved`
A player manually removes the closest beacon.

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `beacon` | table | `{ beaconName, name, position, mgrsCoords, frequencies, battery, distance }` |
| `reason` | string | `"manual"` |
| `frequenciesFreed` | table | `{ vhf, uhf, fm }` |

**Published by**: `CTLDBeaconManager:removeClosestBeacon()`

#### `OnBeaconDestroyed`
A beacon's battery runs out, or its DCS units are destroyed.

| Field | Type | Description |
| --- | --- | --- |
| `beacon` | table | `{ beaconName, name, position, mgrsCoords, frequencies, battery, unitsAlive, durationAlive }` |
| `reason` | string | `"battery"` or `"units"` |
| `frequenciesFreed` | table | `{ vhf, uhf, fm }` |

**Published by**: `CTLDBeaconManager:_refreshAll()` (periodic tick — battery depleted or too few radio units alive)

#### `OnBeaconRefreshed`
Emitted on each beacon-manager tick with a summary of all active beacons.

| Field | Type | Description |
| --- | --- | --- |
| `beacons` | table | Array of beacon payload tables |
| `totalBeaconsRefreshed` | number | |
| `totalBeaconsDestroyed` | number | Beacons destroyed this tick |

**Published by**: `CTLDBeaconManager:_refreshAll()`

#### `OnBeaconLayerToggled`
A player toggles the beacon F10 map layer.

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `previousState` | bool | |
| `newState` | bool | |
| `action` | string | `"enabled"` or `"disabled"` |
| `beaconsDisplayed` | table | Array of beacons now displayed |
| `totalBeaconsDisplayed` | number | |

**Published by**: `CTLDBeaconManager:toggleLayer()`

### Crate events (10)

#### `OnCrateSpawned`
Any crate appears on the map.

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | Internal crate object |
| `crateName` | string | Unique crate identifier |
| `descriptor` | table | Crate descriptor |
| `position` | vec3 | |
| `coalition` | number | |
| `spawnedBy` | string or nil | Player / mission-maker name |
| `spawnMethod` | string | `"request_crate"`, `"parachute_drop"`, `"slingload_cut"`, `"mm_late_activation"`, … |

**Published by**: `CTLDCrateManager:spawnCrate()`, `:unloadCrate()`, `:cutSlingload()`, `:parachuteCrates()`

#### `OnCrateLoaded`
A crate is picked up (slingload or DCS native cargo).

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `carrierUnitName` | string | Transport unit name |
| `coalition` | number | |
| `descriptor` | table | |
| `trigger` | string | `"slingload"` or `"dcs_native"` |
| `method` | string or nil | `"dcs_native"` (absent for slingload) |

**Published by**: `CTLDCrateManager:loadCrate()`, `:checkHoverStatus()`, `:_checkNativeDCSCargo()`

#### `OnCrateUnloaded`
A crate is dropped or unloaded (not unpacked).

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `descriptor` | table | |
| `method` | string or nil | `"dcs_native"` if native, absent for slingload |

**Published by**: `CTLDCrateManager:unloadCrate()`, `:dropCrate()`, `:cutSlingload()`, `:_checkNativeDCSCargo()`

#### `OnCrateLost`
A crate is destroyed by overspeed slingload or cut-slingload impact.

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `transport` | Unit | The carrying aircraft |
| `trigger` | string | `"slingload_overspeed"` or `"slingload_cut_impact"` |

**Published by**: `CTLDCrateManager:checkHoverStatus()`, `:cutSlingload()`

#### `OnCrateCleared`
A crate is removed from the world (unpacked, destroyed, or loaded natively).

| Field | Type | Description |
| --- | --- | --- |
| `crateName` | string | |
| `position` | vec3 | Last known position |
| `coalition` | number | |
| `descriptor` | table | |
| `reason` | string | `"destroyed"`, `"unpacked"`, or `"loaded"` |

**Published by**: `CTLDCrateManager:cutSlingload()`, `:loadCrate()`, `:unpackCrate()`, `:destroyCrate()`

#### `OnCrateUnpacked`
A crate is successfully unpacked (assembled into equipment).

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | Unpack location |
| `coalition` | number | |
| `carrierUnitName` | string or nil | Unit performing the unpack |

**Published by**: `CTLDCrateManager:unpackCrate()`

#### `OnCrateDestroyed`
A crate is destroyed on high-altitude drop impact (distinct from slingload loss).

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `reason` | string | `"drop_impact"` |

**Published by**: `CTLDCrateManager:dropCrate()` (impact path)

#### `OnCrateParachuting`
A crate is released in parachute-drop mode.

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `dropPosition` | vec3 | Position at release |
| `landingPosition` | vec3 | Estimated landing position |
| `altitude` | number | AGL in metres |
| `descentTime` | number | Estimated seconds to landing |
| `carrierUnitName` | string | |
| `player` | string | |

**Published by**: `CTLDCrateManager:parachuteCrates()`

#### `OnCrateParachuteLanded`
A parachuted crate lands (async, after the descent poll).

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | Landing position |
| `coalition` | number | |
| `startAltitude` | number | AGL at release |

**Published by**: `CTLDCrateManager:parachuteCrates()` (landing-poll callback)

#### `OnMMCrateDetected`
A mission-maker pre-placed crate is registered (including on late activation).

| Field | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | |
| `coalition` | number | |

**Published by**: `CTLDCrateManager:registerMMCrate()`

### Vehicle events (9)

#### `OnVehicleSpawnedForTransport`
A vehicle is spawned in `WAITING` state, ready for transport (Request Equipment).

| Field | Type | Description |
| --- | --- | --- |
| `vehicleId` | string | Internal CTLD vehicle ID |
| `vehicle` | Unit | DCS Unit object |
| `vehicleType` | string | DCS type name |
| `spawner` | string or nil | Player name |
| `logisticZone` | table or nil | Zone where spawned |
| `spawnMethod` | string | `"request_vehicle"` |
| `position` | vec3 | |

**Published by**: `CTLDVehicleSpawner:spawnVehicleForTransport()`

#### `OnVehicleLoaded`
A vehicle is loaded into a transport.

| Field | Type | Description |
| --- | --- | --- |
| `vehicleId` | string | |
| `ctldVehicleObject` | CTLDVehicle | |
| `dcsUnitObject` | Unit or nil | Present if native load |
| `vehicleType` | string | |
| `transportUnitObject` | Unit | |
| `player` | string | |
| `method` | string | `"slingload"` or `"dcs_native"` |
| `spawnMethod` | string | |
| `position` | vec3 | |
| `transportPosition` | vec3 | |

**Published by**: `CTLDVehicleSpawner:loadVehicle()`

#### `OnVehicleUnloaded`
A vehicle is unloaded from a transport. Same fields as `OnVehicleLoaded`.

**Published by**: `CTLDVehicleSpawner:unloadVehicle()`

#### `OnVehiclePacked`
A vehicle is packed into crates.

| Field | Type | Description |
| --- | --- | --- |
| `vehicleType` | string | |
| `descriptor` | table | Crate descriptor used |
| `transport` | string | Transport unit name |
| `player` | string or nil | |
| `cratesSpawned` | number | Number of crates spawned |

**Published by**: `CTLDVehicleSpawner:packVehicle()`

#### `OnVehicleParachuting`
A vehicle is released in parachute mode.

| Field | Type | Description |
| --- | --- | --- |
| `vehicle` | CTLDVehicle | |
| `transport` | string | Transport unit name |
| `player` | string | |
| `altitude` | number | AGL in metres |
| `dropPosition` | vec3 | |
| `estimatedLandingPos` | vec3 | |
| `estimatedLandingTime` | number | `timer.getAbsTime() + descentTime` |

**Published by**: `CTLDVehicleSpawner:parachuteVehicle()`

#### `OnVehicleParachuteLanded`
A parachuted vehicle lands.

| Field | Type | Description |
| --- | --- | --- |
| `vehicle` | CTLDVehicle | |
| `position` | vec3 | |
| `transport` | string | |
| `player` | string | |
| `startAltitude` | number | AGL at release |

**Published by**: `CTLDVehicleSpawner:parachuteVehicle()` (landing callback)

#### `OnVehicleDead`
A tracked CTLD vehicle is destroyed.

| Field | Type | Description |
| --- | --- | --- |
| `vehicleId` | string | |
| `vehicle` | Unit | `S_EVENT_DEAD` initiator |
| `vehicleType` | string | |
| `coalition` | number or nil | |
| `position` | vec3 | |
| `durationAlive` | number | Seconds since spawn |

**Published by**: `CTLDVehicleSpawner:onDead()` (`S_EVENT_DEAD` handler)

#### `OnGroundUnitSpawned` / `OnGroundUnitRemoved`
A CTLD-tracked ground unit appears or disappears. These two are cross-cutting — both the
vehicle spawner and the crate manager publish `OnGroundUnitSpawned`.

| Field | Type | Description |
| --- | --- | --- |
| `vehicleType` | string | DCS type name |
| `position` | vec3 | |
| `coalitionId` | number | (`OnGroundUnitSpawned` only) |
| `reason` | string | (`OnGroundUnitRemoved` only) `"loaded"`, `"packed"`, `"dead"` |

**Published by**:

- `OnGroundUnitSpawned`: `CTLDVehicleSpawner:_spawnGroundUnit()`, `CTLDCrateManager:_spawnUnpacked()`
- `OnGroundUnitRemoved`: `CTLDVehicleSpawner:loadVehicle()`, `:onDead()`, `:packVehicle()`

### Troop events (2)

#### `OnTroopsDeployed`
Troops are deployed by parachute.

| Field | Type | Description |
| --- | --- | --- |
| `troops` | CTLDTroopGroup | |
| `carrierUnitName` | string | |
| `player` | string | |
| `trigger` | string | `"parachute"` |
| `destination` | table | `{ type="combat", troopZone=nil }` |

**Published by**: `CTLDTroopManager:parachuteTroops()`

#### `OnTroopsParachuteLanded`
Parachuted troops land (async, after the descent timer).

| Field | Type | Description |
| --- | --- | --- |
| `troops` | CTLDTroopGroup | |
| `spawnedGroup` | Group | DCS group spawned on the ground |
| `positions` | table | Array of vec3, one per soldier |
| `transport` | string | |
| `player` | string | |
| `startAltitude` | number | |

**Published by**: `CTLDTroopManager:parachuteTroops()` (landing callback)

### JTAC events (8)

#### `OnJTACSpawned`
A JTAC is spawned — vehicle, drone, or infantry soldier within a troop group.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.groupId` | number | |
| `jtac.unitName` | string | |
| `jtac.unitId` | number or nil | |
| `jtac.unitType` | string or nil | |
| `jtac.coalition` | number | |
| `jtac.position` | vec3 or nil | |
| `jtac.isFlying` | bool | `true` for drone JTACs |
| `jtac.isInfantry` | bool | |
| `jtac.route` | table or nil | Drone patrol route |
| `spawner` | string | Player unit name or `"MissionMaker"` |
| `laserCode` | number | Assigned laser code (`0` if none) |
| `smokeEnabled` | bool | |
| `smokeColor` | string or nil | |
| `lockMode` | string | JTAC lock-mode setting |
| `radio` | table or nil | `{ freq, modulation }` |

**Published by**: `CTLDJTACManager:spawnJTAC()`, `:startLaseTroopUnit()` (infantry JTAC)

#### `OnJTACInTransit`
A vehicle JTAC is embarked into a transport.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `transport` | Unit | |

**Published by**: `CTLDJTACManager:setJTACInTransit()`

#### `OnJTACLaseStart`
A JTAC acquires a target and begins lasing.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.unitName` | string | |
| `jtac.position` | vec3 | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.unitId` | number | |
| `target.unitType` | string | |
| `target.coalition` | number | |
| `target.position` | vec3 | |
| `target.priority` | number | Target priority score |
| `target.selectionMethod` | string | `"auto_nearest"` or `"manual"` |
| `target.wasManuallySelected` | bool | |
| `laserCode` | number | |
| `lockMode` | string | |
| `distance` | number | Metres from JTAC to target |
| `lineOfSight` | bool | LOS confirmed at time of lock |
| `radio` | table or nil | |
| `message` | string or nil | Status message shown to player |

**Published by**: `CTLDJTACManager:_autoLaseLoop()` (on acquisition)

#### `OnJTACTargetLased`
Emitted each lase cycle while a JTAC is actively lasing.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.unitName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | Corrected position for drones |
| `laserCode` | number | |

**Published by**: `CTLDJTACManager:_autoLaseLoop()` (each cycle)

#### `OnJTACLaseStop`
A JTAC stops lasing.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `jtac.laserCode` | number | |
| `target.unitName` | string or nil | |
| `target.unitType` | string | |
| `target.lastKnownPosition` | vec3 | |
| `reason` | string | `"target_dead"`, `"out_of_range"`, `"manual"` |

**Published by**: `CTLDJTACManager:_stopLaseAndPublish()`

#### `OnJTACOrbitStart`
A drone JTAC starts its orbit over a target.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | |

**Published by**: `CTLDJTACManager:_updateOrbit()`

#### `OnJTACSmokeTarget`
A JTAC smokes its current target on player request.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | |
| `smokePosition` | vec3 | Actual smoke spawn point |
| `smokeColor` | number | `trigger.smokeColor.*` constant |

**Published by**: `CTLDJTACManager:requestSmoke()`

#### `OnJTACDead`
A JTAC is destroyed in combat.

| Field | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `jtac.laserCode` | number | |
| `killer` | table or nil | `{ unitName, playerName }` |
| `lastTarget` | table or nil | Last lased target |

**Published by**: `CTLDJTACManager:killJTAC()` (`S_EVENT_DEAD` handler)

> Packing a JTAC vehicle is **not** a death — `OnJTACDead` does not fire when a JTAC
> vehicle is re-embarked.

### RECON events (8)

#### `ReconFarpDetected`
A player in RECON detects an enemy FARP or FOB. (No `On` prefix — historic name.)

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | Player name |
| `playerUnit` | Unit | DCS Unit object |
| `coalition` | number | Enemy coalition ID |
| `playerCoalition` | number | Player's coalition ID |
| `position` | vec3 | FARP/FOB position |
| `id` | string | Internal mark ID (matched by `ReconFarpLost`) |

**Published by**: `CTLDReconManager:_syncFarpMarks()`

#### `ReconFarpLost`
A previously detected enemy FARP/FOB leaves the scan radius or is destroyed. (No `On`
prefix.)

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `id` | string | Mark ID matching the `ReconFarpDetected` event |

**Published by**: `CTLDReconManager:_syncFarpMarks()`

#### `OnReconScan`
A player performs a RECON scan.

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `position` | vec3 | Scanner position |
| `altitude` | number | AGL in metres |
| `searchRadius` | number | Metres |
| `activeLayers` | table | Array of active layer descriptors |
| `targets` | table | Array of detected targets |
| `targetsByLayer` | table | Map `layerId → targets` |
| `totalTargetsDetected` | number | |
| `totalMarksCreated` | number | |

**Published by**: `CTLDReconManager:scan()`

#### `OnReconScanRefresh`
Emitted each auto-refresh cycle with delta information.

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `position` | vec3 | |
| `altitude` | number | |
| `activeLayers` | table | |
| `targets` | table | All current targets |
| `newTargets` | table | Newly detected this cycle |
| `movedTargets` | table | Targets that moved |
| `lostTargets` | table | Targets that disappeared |
| `totalTargetsCurrent` | number | |
| `totalTargetsNew` | number | |
| `totalTargetsMoved` | number | |
| `totalTargetsLost` | number | |

**Published by**: `CTLDReconManager:_doRefresh()` (auto-refresh timer)

#### `OnReconHideTargets`
A player stops RECON and all marks are removed.

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `marksRemoved` | table | Array of removed mark records |
| `totalMarksRemoved` | number | |
| `refreshStopped` | bool | Whether auto-refresh was running |

**Published by**: `CTLDReconManager:stopScan()`

#### `OnReconLayerToggled`
A player enables/disables a RECON detection layer.

| Field | Type | Description |
| --- | --- | --- |
| `layerId` | string | e.g. `"infantry"`, `"ground_vehicles"` |
| `layerName` | string | Human-readable layer name |
| `visible` | bool | New state |
| `coalition` | number | |
| `player` | string | |

**Published by**: `CTLDReconManager:toggleLayer()`

#### `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled`
A player enables or disables RECON auto-refresh.

| Field | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `previousState` | bool | |
| `newState` | bool | |
| `targetsCount` | number | Current target count |
| `refreshInterval` | number | Seconds between refreshes |

**Published by**: `CTLDReconManager:enableAutoRefresh()`, `:disableAutoRefresh()`

### FOB events (2)

#### `OnFOBDeployed`
A FOB is fully assembled and deployed.

| Field | Type | Description |
| --- | --- | --- |
| `fob.fobId` | string | |
| `fob.name` | string | |
| `fob.coalitionId` | number | |
| `cratesUsed` | table | Array of crates consumed |
| `totalCratesUsed` | number | |
| `position` | vec3 | |
| `sceneObjects` | table | DCS StaticObjects spawned |
| `logisticZone` | table | Created LGZ `{ name, radius, type="static" }` |
| `player` | string | Player unit name who triggered deployment |

**Published by**: `CTLDFOBManager:_registerDeployedFOB()`

#### `OnFOBDestroyed`
A FOB's integrity drops below the destruction threshold.

| Field | Type | Description |
| --- | --- | --- |
| `fob.fobId` | string | |
| `fob.name` | string | |
| `fob.coalitionId` | number | |
| `position` | vec3 | |
| `destruction.killerUnit` | Unit or nil | |
| `destruction.killerCoalition` | number or nil | |
| `destruction.objectsDestroyed` | number | |
| `destruction.objectsTotal` | number | |
| `destruction.destructionThreshold` | number | Config `fobDestructionThreshold` (default `0.5`) |
| `destruction.integrityPercent` | number | `0.0`–`1.0` at time of event |
| `logisticZone` | table | `{ name, wasActive=true }` |
| `durationAlive` | number | Seconds from deployment to destruction |

**Published by**: `CTLDFOBManager:_destroyFOB()` (from the `S_EVENT_DEAD` handler `onDead()`)

### AA system events (3)

#### `OnAASystemDeployed`
An AA system is fully assembled.

| Field | Type | Description |
| --- | --- | --- |
| `systemName` | string | `"HAWK"`, `"PATRIOT"`, … |
| `groupName` | string | DCS group name |
| `heli` | Unit or nil | `nil` if AI-deployed |
| `coalition` | number | |
| `position` | vec3 | |

**Published by**: `CTLDCrateAssemblyManager:spawnSystemAt()`, `:_assemble()`

#### `OnAASystemRearmed`
A launcher is added to an existing AA system.

| Field | Type | Description |
| --- | --- | --- |
| `systemName` | string | |
| `groupName` | string | |
| `heli` | Unit | |
| `coalition` | number | |

**Published by**: `CTLDCrateAssemblyManager:_rearm()`

#### `OnAASystemRepaired`
A full AA system is repaired and re-spawned. Same fields as `OnAASystemRearmed`.

**Published by**: `CTLDCrateAssemblyManager:_repair()`

### Zone events (2)

#### `OnZoneSmokeRefreshed`
Emitted on each smoke-refresh timer cycle.

| Field | Type | Description |
| --- | --- | --- |
| `troopZones` | table | Array of troop-zone payload tables |
| `logisticZones` | table | Array of logistic-zone payload tables |
| `refreshInterval` | number | Seconds |

**Published by**: `CTLDZoneManager:_scheduleSmoke()` (periodic timer)

#### `OnLogisticZoneUpdated`
Dynamic zone units are added or removed.

| Field | Type | Description |
| --- | --- | --- |
| `zones` | table | All zones after update |
| `unitsAdded` | table | Newly registered units |
| `unitsRemoved` | table | Units that left the zone |

**Published by**: `CTLDZoneManager:_publishLogisticZoneUpdated()`

### Catalogue summary

| Domain | Count |
| --- | --- |
| Beacon | 5 |
| Crate | 10 |
| Vehicle | 9 |
| Troop | 2 |
| JTAC | 8 |
| RECON | 8 |
| FOB | 2 |
| AA System | 3 |
| Zone | 2 |
| **Total** | **49** |

Roughly ten events have internal subscribers (menu refresh and cross-manager coordination);
the rest are published purely for mission-maker consumption and have no internal listeners
until you subscribe to them.

## The DCS event bridge (for contrast)

DCS engine events do **not** flow through `EventDispatcher`. A single
`CTLDDCSEventBridge` singleton registers one `world.addEventHandler` and routes each
`S_EVENT_*` to the managers that registered for it, via
`bridge:register(target, eventId, "methodName")`. The bridge does no filtering beyond the
event id — each manager filters internally. See [Architecture](architecture.md) for the
`CTLDDCSEventBridge` design.

The engine events currently handled, and by whom:

| DCS event | Handler(s) |
| --- | --- |
| `S_EVENT_PLAYER_ENTER_UNIT` | `CTLDPlayerTracker:onPlayerEnterUnit()`, `CTLDPlayerManager:onPlayerEnterUnit()` |
| `S_EVENT_PLAYER_LEAVE_UNIT` | `CTLDPlayerTracker:onPlayerLeaveUnit()`, `CTLDPlayerManager:onPlayerLeaveUnit()` |
| `S_EVENT_BIRTH` | `CTLDPlayerTracker:onBirth()`, `CTLDCrateManager:onBirth()`, `CTLDJTACManager:onBirth()`, `CTLDVehicleSpawner:onBirth()` |
| `S_EVENT_LAND` | `CTLDPlayerManager:onLand()`, `CTLDCoreManager:onAILand()` |
| `S_EVENT_TAKEOFF` | `CTLDPlayerManager:onTakeoff()` |
| `S_EVENT_DEAD` | `CTLDTroopManager:onUnitDead()` + `:onTransportDead()`, `CTLDVehicleSpawner:onDead()`, `CTLDCrateManager:onCrateDead()`, `CTLDFOBManager:onDead()`, `CTLDZoneManager:onDead()` |

> **`S_EVENT_STATIC_DEAD` — a synthetic event.** `S_EVENT_DEAD` is unreliable for static and
> base objects. `CTLDStaticWatcher` polls registered objects on a 1 s timer and, when one
> disappears, dispatches a synthetic `S_EVENT_STATIC_DEAD` (payload `{ id, meta }`) through
> `EventDispatcher`. It rides the business bus but is neither a DCS engine event nor an
> `On*` domain event.
