# Legacy API

If you already have a mission built on **CTLD v1**, its `DO SCRIPT` triggers and helper
scripts keep working under v2. CTLD ships thin compatibility wrappers that reproduce the v1
`ctld.*` global functions and forward each call to the matching v2 manager.

## The compatibility promise

- **22 v1 functions are wrapped.** Each one delegates internally to a v2 manager, so your
  existing calls behave as they did in v1.
- **Every call logs a deprecation warning** to `ctld.log` (and DCS.log). The wrappers are
  supported in v2 but will be **removed in v3** — plan to migrate before then.
- **`ctld.addCallback` is *not* wrapped.** v1 callbacks have no drop-in replacement; use the
  v2 event system instead (see [Callbacks](#callbacks) below).

For new missions, prefer the v2 managers directly. The full mapping and migration steps live
in the developer docs — this page only covers what a mission maker with a v1 script needs.

> See the [Migration v1 → v2](../developer/migration-v1-v2.md) guide for the complete
> function-by-function migration path.

## Troops and transport

| v1 function | Delegates to |
|---|---|
| `ctld.spawnGroupAtTrigger(groupSide, number, triggerName, searchRadius)` | `CTLDTroopManager:spawnGroupAtTrigger()` |
| `ctld.spawnGroupAtPoint(groupSide, number, point, searchRadius)` | `CTLDTroopManager:spawnGroupAtPoint()` |
| `ctld.preLoadTransport(unitName, number, troops)` | `CTLDTroopManager:preLoadTransport()` |
| `ctld.loadTransport(unitName)` | `CTLDTroopManager:loadTransport()` |
| `ctld.unloadTransport(unitName)` | `CTLDTroopManager:unloadTransport()` |
| `ctld.unloadInProximityToEnemy(unitName, distance)` | `CTLDTroopManager:unloadInProximityToEnemy()` |

**Example — spawn troops from a `DO SCRIPT`:**

```lua
ctld.spawnGroupAtTrigger(coalition.side.BLUE, 6, "LZ_NORTH", 1000)
```

## Pickup, waypoint and extract zones

| v1 function | Delegates to |
|---|---|
| `ctld.activatePickupZone(zoneName)` | `CTLDZoneManager:setTroopZoneActive(name, true)` |
| `ctld.deactivatePickupZone(zoneName)` | `CTLDZoneManager:setTroopZoneActive(name, false)` |
| `ctld.changeRemainingGroupsForPickupZone(zoneName, amount)` | `CTLDZoneManager:changeRemainingGroups()` |
| `ctld.activateWaypointZone(zoneName)` | `CTLDZoneManager:activateWaypointZone()` |
| `ctld.deactivateWaypointZone(zoneName)` | `CTLDZoneManager:deactivateWaypointZone()` |
| `ctld.createExtractZone(zone, flagNumber, smoke)` | `CTLDZoneManager:createExtractZone()` |
| `ctld.removeExtractZone(zone, flagNumber)` | `CTLDZoneManager:removeExtractZone()` |
| `ctld.countDroppedGroupsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager:startGroupCountWatcher()` |
| `ctld.countDroppedUnitsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager:startUnitCountWatcher()` |

**Example — activate a pickup zone at mission start:**

```lua
ctld.activatePickupZone("TRZ_ALPHA")
```

See [Zone setup](zones.md) for how these zones are defined in the Mission Editor.

## Crates

| v1 function | Delegates to |
|---|---|
| `ctld.spawnCrateAtZone(side, weight, zone)` | `CTLDCrateManager:spawnCrateAtZone()` |
| `ctld.spawnCrateAtPoint(side, weight, point, hdg)` | `CTLDCrateManager:spawnCrateAtPoint()` |
| `ctld.cratesInZone(zone, flagNumber)` | `CTLDCrateManager:startCrateCountWatcher()` |

**Example — spawn a crate at a trigger zone:**

```lua
ctld.spawnCrateAtZone(coalition.side.BLUE, 800, "FARP_BRAVO")
```

The `weight` argument selects which crate is spawned. See the
[Crate catalogue](crates-catalogue.md) for the available crate definitions.

## Radio beacon

| v1 function | Delegates to |
|---|---|
| `ctld.createRadioBeaconAtZone(zone, coalition, batteryLife, name)` | `CTLDBeaconManager:createAtZone()` |

## JTAC

| v1 function | Delegates to |
|---|---|
| `ctld.JTACAutoLase(jtacGroupName, laserCode, smoke, lock, colour, radio)` | `CTLDJTACManager:autoLase()` |
| `ctld.JTACStart(jtacGroupName, laserCode, smoke, lock, colour, radio)` | `CTLDJTACManager:startLase()` |
| `ctld.JTACAutoLaseStop(jtacGroupName)` | `CTLDJTACManager:stopAutoLase()` |

**Example — auto-lase an enemy armour group, then stop:**

```lua
ctld.JTACAutoLase("ENEMY_ARMOUR_1", 1688, true)
-- ... when the strike is complete:
ctld.JTACAutoLaseStop("ENEMY_ARMOUR_1")
```

## Callbacks

In v1, external scripts registered a callback with `ctld.addCallback(fn)` to react to CTLD
events. **This function is not provided in v2** — there is no compatibility wrapper. Subscribe
to the v2 event dispatcher instead:

```lua
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(event)
    -- react to the event
end)
```

Available events include `OnCrateSpawned`, `OnCrateLoaded`, `OnCrateUnloaded`,
`OnCrateUnpacked`, `OnVehiclePacked`, `OnTroopsBoarded`, `OnTroopsDeployed`,
`OnTroopsExtracted`, `OnJTACSpawned`, `OnLaseStart`, `OnLaseStop`, `OnBeaconDropped` and
`OnFOBDeployed`. The [Migration v1 → v2](../developer/migration-v1-v2.md) guide lists the
full event catalogue and the callback-to-event mapping.
