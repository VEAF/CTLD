-- ============================================================
-- src/legacy/legacy_api.lua
-- Legacy API compatibility wrappers — CTLD v1 → v2
--
-- Provides the original ctld.* function signatures used in
-- mission DO SCRIPT triggers, forwarding each call to the
-- corresponding v2 manager with a deprecation warning.
--
-- Deprecation warnings are logged at WARNING level so they
-- appear in both DCS.log and ctld.log (if enabled).
--
-- NOTE: ctld.spawnCrateAtZone / ctld.spawnCrateAtPoint delegate
-- to CTLDCrateManager:spawnCrate() (implemented, uses ctld.utils.dynAddStatic).
--
-- NOTE: ctld.addCallback() is not wrapped — use
-- EventDispatcher:subscribe(eventName, handler) instead.
-- See documentation/migration-v2.md for the full migration guide.
--
-- Load order: after all managers (last in listToMerge.txt,
-- before CTLD_userConfig.lua).
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- Troops / Transport
-- ============================================================

--- @deprecated Use CTLDTroopManager:spawnGroupAtTrigger()
function ctld.spawnGroupAtTrigger(groupSide, number, triggerName, searchRadius)
    ctld.logWarning("DEPRECATED: ctld.spawnGroupAtTrigger — use CTLDTroopManager:spawnGroupAtTrigger()")
    CTLDTroopManager.getInstance():spawnGroupAtTrigger(groupSide, number, triggerName, searchRadius)
end

--- @deprecated Use CTLDTroopManager:spawnGroupAtPoint()
function ctld.spawnGroupAtPoint(groupSide, number, point, searchRadius)
    ctld.logWarning("DEPRECATED: ctld.spawnGroupAtPoint — use CTLDTroopManager:spawnGroupAtPoint()")
    CTLDTroopManager.getInstance():spawnGroupAtPoint(groupSide, number, point, searchRadius)
end

--- @deprecated Use CTLDTroopManager:preLoadTransport()
function ctld.preLoadTransport(unitName, number, troops)
    ctld.logWarning("DEPRECATED: ctld.preLoadTransport — use CTLDTroopManager:preLoadTransport()")
    CTLDTroopManager.getInstance():preLoadTransport(unitName, number, troops)
end

--- @deprecated Use CTLDTroopManager:unloadTransport()
function ctld.unloadTransport(unitName)
    ctld.logWarning("DEPRECATED: ctld.unloadTransport — use CTLDTroopManager:unloadTransport()")
    CTLDTroopManager.getInstance():unloadTransport(unitName)
end

--- @deprecated Use CTLDTroopManager:loadTransport()
function ctld.loadTransport(unitName)
    ctld.logWarning("DEPRECATED: ctld.loadTransport — use CTLDTroopManager:loadTransport()")
    CTLDTroopManager.getInstance():loadTransport(unitName)
end

--- @deprecated Use CTLDTroopManager:unloadInProximityToEnemy()
function ctld.unloadInProximityToEnemy(unitName, distance)
    ctld.logWarning("DEPRECATED: ctld.unloadInProximityToEnemy — use CTLDTroopManager:unloadInProximityToEnemy()")
    return CTLDTroopManager.getInstance():unloadInProximityToEnemy(unitName, distance)
end

-- ============================================================
-- Zones
-- ============================================================

--- @deprecated Use CTLDZoneManager:setTroopZoneActive()
function ctld.activatePickupZone(zoneName)
    ctld.logWarning("DEPRECATED: ctld.activatePickupZone — use CTLDZoneManager:setTroopZoneActive(name, true)")
    CTLDZoneManager.getInstance():setTroopZoneActive(zoneName, true)
end

--- @deprecated Use CTLDZoneManager:setTroopZoneActive()
function ctld.deactivatePickupZone(zoneName)
    ctld.logWarning("DEPRECATED: ctld.deactivatePickupZone — use CTLDZoneManager:setTroopZoneActive(name, false)")
    CTLDZoneManager.getInstance():setTroopZoneActive(zoneName, false)
end

--- @deprecated Use CTLDZoneManager:changeRemainingGroups()
function ctld.changeRemainingGroupsForPickupZone(zoneName, amount)
    ctld.logWarning("DEPRECATED: ctld.changeRemainingGroupsForPickupZone — use CTLDZoneManager:changeRemainingGroups()")
    CTLDZoneManager.getInstance():changeRemainingGroups(zoneName, amount)
end

--- @deprecated Use CTLDZoneManager:activateWaypointZone()
function ctld.activateWaypointZone(zoneName)
    ctld.logWarning("DEPRECATED: ctld.activateWaypointZone — use CTLDZoneManager:activateWaypointZone()")
    CTLDZoneManager.getInstance():activateWaypointZone(zoneName)
end

--- @deprecated Use CTLDZoneManager:deactivateWaypointZone()
function ctld.deactivateWaypointZone(zoneName)
    ctld.logWarning("DEPRECATED: ctld.deactivateWaypointZone — use CTLDZoneManager:deactivateWaypointZone()")
    CTLDZoneManager.getInstance():deactivateWaypointZone(zoneName)
end

--- @deprecated Use CTLDZoneManager:createExtractZone()
function ctld.createExtractZone(zone, flagNumber, smoke)
    ctld.logWarning("DEPRECATED: ctld.createExtractZone — use CTLDZoneManager:createExtractZone()")
    CTLDZoneManager.getInstance():createExtractZone(zone, flagNumber, smoke)
end

--- @deprecated Use CTLDZoneManager:removeExtractZone()
function ctld.removeExtractZone(zone, flagNumber)
    ctld.logWarning("DEPRECATED: ctld.removeExtractZone — use CTLDZoneManager:removeExtractZone()")
    CTLDZoneManager.getInstance():removeExtractZone(zone, flagNumber)
end

--- @deprecated Use CTLDTroopManager:startGroupCountWatcher()
function ctld.countDroppedGroupsInZone(zone, blueFlag, redFlag)
    ctld.logWarning("DEPRECATED: ctld.countDroppedGroupsInZone — use CTLDTroopManager:startGroupCountWatcher()")
    CTLDTroopManager.getInstance():startGroupCountWatcher(zone, blueFlag, redFlag)
end

--- @deprecated Use CTLDTroopManager:startUnitCountWatcher()
function ctld.countDroppedUnitsInZone(zone, blueFlag, redFlag)
    ctld.logWarning("DEPRECATED: ctld.countDroppedUnitsInZone — use CTLDTroopManager:startUnitCountWatcher()")
    CTLDTroopManager.getInstance():startUnitCountWatcher(zone, blueFlag, redFlag)
end

-- ============================================================
-- Crates
-- ============================================================

--- @deprecated Use CTLDCrateManager:spawnCrateAtZone()
-- NOTE: non-functional until CTLDCrateManager:spawnCrate() is implemented.
function ctld.spawnCrateAtZone(side, weight, zone)
    ctld.logWarning("DEPRECATED: ctld.spawnCrateAtZone — use CTLDCrateManager:spawnCrateAtZone()")
    return CTLDCrateManager.getInstance():spawnCrateAtZone(side, weight, zone)
end

--- @deprecated Use CTLDCrateManager:spawnCrateAtPoint()
-- NOTE: non-functional until CTLDCrateManager:spawnCrate() is implemented.
function ctld.spawnCrateAtPoint(side, weight, point, hdg)
    ctld.logWarning("DEPRECATED: ctld.spawnCrateAtPoint — use CTLDCrateManager:spawnCrateAtPoint()")
    return CTLDCrateManager.getInstance():spawnCrateAtPoint(side, weight, point, hdg)
end

--- @deprecated Use CTLDCrateManager:startCrateCountWatcher()
function ctld.cratesInZone(zone, flagNumber)
    ctld.logWarning("DEPRECATED: ctld.cratesInZone — use CTLDCrateManager:startCrateCountWatcher()")
    CTLDCrateManager.getInstance():startCrateCountWatcher(zone, flagNumber)
end

-- ============================================================
-- Beacons
-- ============================================================

--- @deprecated Use CTLDBeaconManager:createAtZone()
function ctld.createRadioBeaconAtZone(zone, coalitionId, batteryLife, name)
    ctld.logWarning("DEPRECATED: ctld.createRadioBeaconAtZone — use CTLDBeaconManager:createAtZone()")
    CTLDBeaconManager.getInstance():createAtZone(zone, coalitionId, batteryLife, name)
end

-- ============================================================
-- JTAC
-- ============================================================

--- @deprecated Use CTLDJTACManager:autoLase()
function ctld.JTACAutoLase(jtacGroupName, laserCode, smoke, lock, colour, radio)
    ctld.logWarning("DEPRECATED: ctld.JTACAutoLase — use CTLDJTACManager:autoLase()")
    CTLDJTACManager.getInstance():autoLase(jtacGroupName, laserCode, smoke, lock, colour, radio)
end

--- @deprecated Use CTLDJTACManager:startLase()
function ctld.JTACStart(jtacGroupName, laserCode, smoke, lock, colour, radio)
    ctld.logWarning("DEPRECATED: ctld.JTACStart — use CTLDJTACManager:startLase()")
    CTLDJTACManager.getInstance():startLase(jtacGroupName, laserCode, smoke, lock, colour, radio)
end

--- @deprecated Use CTLDJTACManager:stopAutoLase()
function ctld.JTACAutoLaseStop(jtacGroupName)
    ctld.logWarning("DEPRECATED: ctld.JTACAutoLaseStop — use CTLDJTACManager:stopAutoLase()")
    CTLDJTACManager.getInstance():stopAutoLase(jtacGroupName)
end
