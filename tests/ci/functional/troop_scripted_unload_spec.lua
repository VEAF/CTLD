---@diagnostic disable
-- FIX-TROOP-UNLOAD-TRANSPORT: the scripted troop drops (CTLDTroopManager:unloadTransport and
-- :unloadInProximityToEnemy, behind the deprecated ctld.unloadTransport / ctld.unloadInProximityToEnemy) called a
-- method named `deploy` that no longer exists and raised an error. They drop the troops again, with the v1 rules:
-- unloadTransport gives the troops back to the pickup zone it stands in and drops them anywhere else (an extraction
-- zone takes priority, as for the menu); unloadInProximityToEnemy (AI only) drops them when an enemy is in sight.
-- ============================================================

local function makeUnit(name, playerName)
    return {
        _name = name,
        getName      = function(self) return self._name end,
        getCoalition = function() return coalition.side.BLUE end,
        getCountry   = function() return 2 end,
        getTypeName  = function() return "UH-1H" end,
        getPoint     = function() return { x = 0, y = 5, z = 0 } end,
        getPosition  = function() return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } } end,
        getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
        getGroup     = function() return { getID = function() return 9901 end } end,
        getPlayerName = function() return playerName end,
        isExist      = function() return true end,
    }
end

local function makeZone(overrides)
    local z = {
        coalition = 0, active = true, pickMaxStock = 10, pickCurrentStock = 10, zoneName = "TRZ_test",
        isInZone  = function() return true end,
        hasPickup = function() return true end,
        consumeStock = function(self, n) self.pickCurrentStock = self.pickCurrentStock - n end,
        restoreStock = function(self, n) self.pickCurrentStock = self.pickCurrentStock + n end,
    }
    for k, v in pairs(overrides or {}) do z[k] = v end
    return z
end

local function makeTemplate(name)
    return { name = name or "Alpha Squad", total = 4, _dbKey = "Alpha_Squad", inf = 3, mg = 1, at = 0, aa = 0,
             mortar = 0, jtac = 0, civ = 0, specificParams = {} }
end

describe("Scripted troop drops (unloadTransport, unloadInProximityToEnemy)", function()

    local tm, unit, origGs, origSpawn, origGetByName, zmSaved, spawned, unloaded, returned, zones

    before_each(function()
        CTLDTroopManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        ctld.MenuManager._instance   = nil
        EventDispatcher._instance    = nil
        CTLDZoneManager._instance    = nil
        CTLDJTACManager._instance    = nil
        CTLDVehicleSpawner._instance = nil
        _cmInstance                  = nil

        origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then return { ["UH-1H"] = { troopsEnabled = true, maxTroopsOnboard = 10 } } end
            if k == "numberOfTroops"          then return 10 end
            if k == "nbLimitSpawnedTroops"    then return { 0, 0 } end
            if k == "maxTransportWeight"      then return 0 end
            if k == "spawnDistanceInCircle"   then return 10 end
            if k == "enableFastRopeInsertion" then return false end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            return origGs(k)
        end

        tm   = CTLDTroopManager.getInstance()
        unit = makeUnit("AI-Heli-1", nil)
        origGetByName = Unit.getByName
        Unit.getByName = function(n) if n == unit._name then return unit end return origGetByName(n) end

        spawned, unloaded, returned = 0, 0, 0
        origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function()
            spawned = spawned + 1
            return { getName = function() return "Dropped_" .. spawned end, getUnits = function() return {} end,
                     isExist = function() return true end }
        end
        EventDispatcher.getInstance():subscribe("OnTroopsUnloaded", function() unloaded = unloaded + 1 end)
        EventDispatcher.getInstance():subscribe("OnTroopsReturned", function() returned = returned + 1 end)

        -- No zone by default: the unit stands in the open. A test sets `zones` to place it in a zone.
        zones = { extract = nil, pickup = nil }
        local zm = CTLDZoneManager.getInstance()
        zmSaved = { isUnitInZone = zm.isUnitInZone, getWaypointZoneAt = zm.getWaypointZoneAt }
        zm.isUnitInZone      = function(_, _, kind) return zones[kind] end
        zm.getWaypointZoneAt = function() return nil end
        tm._isInAir = function() return false end
    end)

    after_each(function()
        ctld.gs = origGs
        Unit.getByName = origGetByName
        CTLDObjectRegistry.spawnObject = origSpawn
        local zm = CTLDZoneManager.getInstance()
        zm.isUnitInZone, zm.getWaypointZoneAt = zmSaved.isUnitInZone, zmSaved.getWaypointZoneAt
    end)

    local function load(...)
        for _, name in ipairs({ ... }) do
            assert.is_true(tm:embarkFromTroopZone(unit, makeZone(), makeTemplate(name)))
        end
    end

    describe("unloadTransport", function()

        it("drops the troops on board and says so", function()
            load("Alpha Squad")
            local ok
            assert.has_no.errors(function() ok = tm:unloadTransport("AI-Heli-1") end)
            assert.is_true(ok)
            assert.is_false(tm:hasTroops("AI-Heli-1"))
            assert.equals(1, spawned)
            assert.equals(1, unloaded)
        end)

        it("drops every group on board", function()
            load("Alpha Squad", "Bravo Squad")
            assert.is_true(tm:unloadTransport("AI-Heli-1"))
            assert.is_false(tm:hasTroops("AI-Heli-1"))
            assert.equals(2, spawned)
            assert.equals(2, unloaded)
        end)

        it("gives the troops back to the pickup zone it stands in, and drops nothing", function()
            load("Alpha Squad")
            local zone = makeZone({ pickCurrentStock = 6 })
            zones.pickup = zone
            assert.is_true(tm:unloadTransport("AI-Heli-1"))
            assert.is_false(tm:hasTroops("AI-Heli-1"))
            assert.equals(10, zone.pickCurrentStock)     -- 6 + the 4 troops handed back
            assert.equals(0, spawned)
            assert.equals(1, returned)
        end)

        it("drops the troops into an extraction zone, which takes priority over a pickup zone", function()
            load("Alpha Squad")
            local origGet, origSet = trigger.misc.getUserFlag, trigger.action.setUserFlag
            trigger.misc.getUserFlag, trigger.action.setUserFlag = function() return 0 end, function() end
            zones.extract = { zoneName = "EXZ_north", objectiveFlag = "flag" }
            zones.pickup  = makeZone()
            local ok = tm:unloadTransport("AI-Heli-1")
            trigger.misc.getUserFlag, trigger.action.setUserFlag = origGet, origSet
            assert.is_true(ok)
            assert.equals(1, unloaded)
            assert.equals(0, returned)
        end)

        it("returns false with no troops on board, and for an unknown unit", function()
            assert.is_false(tm:unloadTransport("AI-Heli-1"))
            assert.is_false(tm:unloadTransport("nobody"))
            assert.equals(0, unloaded)
        end)

        it("works through the deprecated ctld.unloadTransport wrapper", function()
            load("Alpha Squad")
            assert.has_no.errors(function() ctld.unloadTransport("AI-Heli-1") end)
            assert.is_false(tm:hasTroops("AI-Heli-1"))
        end)

    end)

    describe("unloadInProximityToEnemy", function()

        local origDetect, enemy

        before_each(function()
            origDetect = CTLDJTACDetector.findNearestVisibleEnemy
            enemy = { isExist = function() return true end }
            CTLDJTACDetector.findNearestVisibleEnemy = function() return enemy end
        end)

        after_each(function()
            CTLDJTACDetector.findNearestVisibleEnemy = origDetect
        end)

        it("drops the troops of an AI transport when an enemy is in sight", function()
            load("Alpha Squad", "Bravo Squad")
            local ok
            assert.has_no.errors(function() ok = tm:unloadInProximityToEnemy("AI-Heli-1", 1000) end)
            assert.is_true(ok)
            assert.is_false(tm:hasTroops("AI-Heli-1"))
            assert.equals(2, unloaded)
        end)

        it("drops nothing when no enemy is in sight", function()
            load("Alpha Squad")
            enemy = nil
            assert.is_false(tm:unloadInProximityToEnemy("AI-Heli-1", 1000))
            assert.is_true(tm:hasTroops("AI-Heli-1"))
        end)

        it("leaves a player-controlled transport alone", function()
            unit = makeUnit("Player-Heli-1", "SomePilot")
            load("Alpha Squad")
            assert.is_false(tm:unloadInProximityToEnemy("Player-Heli-1", 1000))
            assert.is_true(tm:hasTroops("Player-Heli-1"))
        end)

        it("works through the deprecated ctld.unloadInProximityToEnemy wrapper", function()
            load("Alpha Squad")
            local ok
            assert.has_no.errors(function() ok = ctld.unloadInProximityToEnemy("AI-Heli-1", 1000) end)
            assert.is_true(ok)
        end)

    end)

end)
