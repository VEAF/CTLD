# Migration v1 → v2

CTLD v2 is a modular rewrite, but the public v1 surface is preserved. Missions that call the
original `ctld.*` global functions from a **DO SCRIPT** trigger keep working unchanged — every v1
entry point survives as a thin wrapper that forwards to the corresponding v2 manager and logs a
deprecation warning. This page explains the wrapper principle, gives the full v1 → v2 mapping, and
shows how to port the one construct that is *not* wrapped: the catch-all callback.

## Wrapper principle

All 22 v1 global functions (`ctld.spawnGroupAtTrigger`, `ctld.JTACAutoLase`, …) live in
`src/legacy/legacy_api.lua`. Each wrapper does two things:

- forwards the call, argument-for-argument, to the equivalent v2 manager method obtained via
  `Manager.getInstance()`;
- logs a deprecation warning at `WARN` level through `ctld.logWarning()`, so it appears in both
  `DCS.log` and `CTLD.log`.

There is no behaviour change — the wrapper is a pure delegate. Legacy missions run as-is; the
warnings are a nudge to migrate, not an error.

```lua
--- @deprecated Use CTLDJTACManager:autoLase()
function ctld.JTACAutoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
    ctld.logWarning("DEPRECATED: ctld.JTACAutoLase — use CTLDJTACManager:autoLase()")
    CTLDJTACManager.getInstance():autoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
end
```

The legacy file is loaded last (after all managers, just before `CTLD_userConfig.lua`) so every
target manager is defined by the time a wrapper can be called.

## Migration table

Replace each v1 `ctld.*` call with the v2 form on the right. Argument order and names below match
the actual wrapper signatures in `src/legacy/legacy_api.lua` — some legacy documentation quoted a
different order.

### Troops / transport — `CTLDTroopManager`

| v1 call | v2 equivalent |
| --- | --- |
| `ctld.spawnGroupAtTrigger(side, number, triggerName, searchRadius)` | `CTLDTroopManager.getInstance():spawnGroupAtTrigger(side, number, triggerName, searchRadius)` |
| `ctld.spawnGroupAtPoint(side, number, point, searchRadius)` | `CTLDTroopManager.getInstance():spawnGroupAtPoint(side, number, point, searchRadius)` |
| `ctld.preLoadTransport(unitName, number, troops)` | `CTLDTroopManager.getInstance():preLoadTransport(unitName, number, troops)` |
| `ctld.loadTransport(unitName)` | `CTLDTroopManager.getInstance():loadTransport(unitName)` |
| `ctld.unloadTransport(unitName)` | `CTLDTroopManager.getInstance():unloadTransport(unitName)` |
| `ctld.unloadInProximityToEnemy(unitName, distance)` | `CTLDTroopManager.getInstance():unloadInProximityToEnemy(unitName, distance)` |

### Zones — `CTLDZoneManager`

| v1 call | v2 equivalent |
| --- | --- |
| `ctld.activatePickupZone(zoneName)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zoneName, true)` |
| `ctld.deactivatePickupZone(zoneName)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zoneName, false)` |
| `ctld.changeRemainingGroupsForPickupZone(zoneName, amount)` | `CTLDZoneManager.getInstance():changeRemainingGroups(zoneName, amount)` |
| `ctld.activateWaypointZone(zoneName)` | `CTLDZoneManager.getInstance():activateWaypointZone(zoneName)` |
| `ctld.deactivateWaypointZone(zoneName)` | `CTLDZoneManager.getInstance():deactivateWaypointZone(zoneName)` |
| `ctld.createExtractZone(zone, flagNumber, smoke)` | `CTLDZoneManager.getInstance():createExtractZone(zone, flagNumber, smoke)` |
| `ctld.removeExtractZone(zone, flagNumber)` | `CTLDZoneManager.getInstance():removeExtractZone(zone, flagNumber)` |
| `ctld.countDroppedGroupsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager.getInstance():startGroupCountWatcher(zone, blueFlag, redFlag)` |
| `ctld.countDroppedUnitsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager.getInstance():startUnitCountWatcher(zone, blueFlag, redFlag)` |

Two zone operations have no v1 predecessor and are only reachable through the v2 API:

| New in v2 | Purpose |
| --- | --- |
| `CTLDZoneManager.getInstance():activateLogisticZone(name)` | Enable a logistic (crate-spawn) zone |
| `CTLDZoneManager.getInstance():deactivateLogisticZone(name)` | Disable a logistic zone |

> **Note.** `activatePickupZone` / `deactivatePickupZone` and the two dropped-count helpers do not
> map to same-named v2 methods. Pickup activation is now a single toggle,
> `setTroopZoneActive(name, active)`, and the count helpers were moved to `CTLDTroopManager` as
> `startGroupCountWatcher` / `startUnitCountWatcher`.

### Crates — `CTLDCrateManager`

| v1 call | v2 equivalent |
| --- | --- |
| `ctld.spawnCrateAtZone(side, weight, zone)` | `CTLDCrateManager.getInstance():spawnCrateAtZone(side, weight, zone)` |
| `ctld.spawnCrateAtPoint(side, weight, point, hdg)` | `CTLDCrateManager.getInstance():spawnCrateAtPoint(side, weight, point, hdg)` |
| `ctld.cratesInZone(zone, flagNumber)` | `CTLDCrateManager.getInstance():startCrateCountWatcher(zone, flagNumber)` |

### Beacons — `CTLDBeaconManager`

| v1 call | v2 equivalent |
| --- | --- |
| `ctld.createRadioBeaconAtZone(zone, coalition, batteryLife, name)` | `CTLDBeaconManager.getInstance():createAtZone(zone, coalition, batteryLife, name)` |

### JTAC — `CTLDJTACManager`

| v1 call | v2 equivalent |
| --- | --- |
| `ctld.JTACAutoLase(group, code, smoke, lock, colour, radio)` | `CTLDJTACManager.getInstance():autoLase(group, code, smoke, lock, colour, radio)` |
| `ctld.JTACStart(group, code, smoke, lock, colour, radio)` | `CTLDJTACManager.getInstance():startLase(group, code, smoke, lock, colour, radio)` |
| `ctld.JTACAutoLaseStop(group)` | `CTLDJTACManager.getInstance():stopAutoLase(group)` |

## Replacing `ctld.addCallback`

`ctld.addCallback` is the one v1 construct that is **not** wrapped. v1 registered a single
catch-all handler that received every event and demultiplexed on a numeric id:

```lua
-- v1
ctld.addCallback(function(event)
    if event.id == ctld.events.S_EVENT_CRATE_SPAWNED then
        -- handle
    end
end)
```

v2 replaces this with targeted subscriptions on the internal event bus. Subscribe by event name
through `EventDispatcher`; only the matching handler fires, and any number of subscribers can
listen for the same event:

```lua
-- v2
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    -- evt.crateName, evt.coalition, evt.spawnedBy, evt.position
end)
```

This removes the `if/elseif` chain, avoids running unrelated handlers, and lets independent features
subscribe to the same event without interfering. See [Events](events.md) for the full event
catalogue and payload shapes.

## Complete migration example

A representative v1 **DO SCRIPT** and its v2 equivalent.

**v1:**

```lua
ctld.spawnGroupAtTrigger(coalition.side.BLUE, 10, "LZ_NORTH", 100)
ctld.JTACAutoLase("ENEMY_ARMOUR", 1688, true)
ctld.addCallback(function(e)
    if e.id == ctld.events.S_EVENT_TROOPS_DEPLOYED then
        trigger.action.outText("Troops landed!", 10)
    end
end)
```

**v2:**

```lua
local tm   = CTLDTroopManager.getInstance()
local jtac = CTLDJTACManager.getInstance()
local ed   = EventDispatcher.getInstance()

tm:spawnGroupAtTrigger(coalition.side.BLUE, 10, "LZ_NORTH", 100)
jtac:autoLase("ENEMY_ARMOUR", 1688, true)
ed:subscribe("OnTroopsDeployed", function(evt)
    trigger.action.outText("Troops landed!", 10)
end)
```

## Pack vehicle (new in v2)

v1 had no working pack-vehicle path. v2 adds it on `CTLDVehicleSpawner`, driven from the F10 menu
but also callable directly:

```lua
-- Find CTLD-managed vehicles in WAITING state within pack range of a transport.
-- Returns an array of { unitName = string, descriptor = table }.
local vehicles = CTLDVehicleSpawner.getInstance():findPackableVehicles(transportUnit)

-- Pack one: destroys the vehicle DCS unit, spawns the required crates near the transport,
-- and publishes OnVehiclePacked.
CTLDVehicleSpawner.getInstance():packVehicle(transportName, vehicleName, playerObj)
```

`findPackableVehicles` only returns CTLD-managed vehicles that are in the `WAITING` state, so scene
props (guards, workers, static decoration) never pollute the result. The F10 **Pack Vehicle**
submenu is populated automatically when a transport lands within
`ctld.gs("maximumDistancePackableUnitsSearch")` of a packable vehicle.

---

See [Architecture](architecture.md) for the manager / singleton idiom these calls rely on, and the
[API reference](api-reference.md) for the full method surface of each manager.
