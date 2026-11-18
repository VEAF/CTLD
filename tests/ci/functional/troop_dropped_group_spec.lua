---@diagnostic disable
-- FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS (issue #309, ADR 0029): a dropped group acts on its own by default, as in CTLD v1.
-- It goes for the nearest enemy ground group within maximumSearchDistance (no line of sight needed); with none in range
-- it walks to a random point within maximumMoveDistance of the drop point. A template task, then a waypoint zone, keep
-- priority; both distances at 0 leave the group where it was dropped.
-- Driven through CTLDTroopManager:disembark (a pilot's ground drop, a fast-rope drop, an AI transport's drop) with doubles
-- of the aircraft, the enemy groups, the object registry and the random source.
-- ============================================================

local function makeUnit(name, coa)
    coa = coa or coalition.side.BLUE
    return {
        _name        = name,
        getName      = function(self) return self._name end,
        getCoalition = function() return coa end,
        getCountry   = function() return 2 end,
        getTypeName  = function() return "UH-1H" end,
        getPoint     = function() return { x = 1000, y = 5, z = 2000 } end,
        getPosition  = function() return { x = { x = 1, y = 0, z = 0 }, p = { x = 1000, y = 5, z = 2000 } } end,
        getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
        getGroup     = function() return { getID = function() return 9901 end } end,
        isExist      = function() return true end,
    }
end

local function makeZone()
    return { coalition = 0, active = true, pickMaxStock = 0, pickCurrentStock = 10, zoneName = "TRZ_test",
             isInZone = function() return true end, hasPickup = function() return true end,
             consumeStock = function() end, restoreStock = function() end }
end

local function makeTemplate(overrides)
    local t = { name = "Alpha Squad", total = 4, _dbKey = "Alpha_Squad", inf = 3, mg = 1, at = 0, aa = 0,
                mortar = 0, jtac = 0, civ = 0, specificParams = {} }
    for k, v in pairs(overrides or {}) do t[k] = v end
    return t
end

--- An enemy ground group whose leader stands at (x, z).
local function enemyGroup(x, z, alive)
    local leader = { getLife = function() return alive == false and 0 or 10 end,
                     getPoint = function() return { x = x, y = 0, z = z } end }
    return { getUnits = function() return { leader } end }
end

describe("A dropped group acts on its own (issue #309)", function()

    local tm, unit, origGs, origSpawn, origGetByName, origGetGroups, origRandom, origSchedule, zmSaved, origAI
    local searchDist, moveDist, enemies, scheduled, orders, randoms

    local DROP = { x = 1000, z = 2000 }   -- where the aircraft stands

    --- Runs what the drop scheduled (the order is given 2 s after the spawn) and returns the routes it set.
    local function drop(templateOverrides)
        tm:embarkFromTroopZone(unit, makeZone(), makeTemplate(templateOverrides))
        assert.is_true(tm:disembark(unit))
        for _, s in ipairs(scheduled) do s.fn(s.arg) end
        return orders
    end

    local function destination(order)
        local pts = order.params.route.points
        return pts[#pts]
    end

    before_each(function()
        CTLDTroopManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        ctld.MenuManager._instance   = nil
        EventDispatcher._instance    = nil
        CTLDZoneManager._instance    = nil
        CTLDJTACManager._instance    = nil
        CTLDVehicleSpawner._instance = nil
        _cmInstance                  = nil

        searchDist, moveDist, enemies, scheduled, orders = 4000, 2000, {}, {}, {}
        origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then return { ["UH-1H"] = { troopsEnabled = true, maxTroopsOnboard = 10 } } end
            if k == "numberOfTroops"          then return 10 end
            if k == "nbLimitSpawnedTroops"    then return { 0, 0 } end
            if k == "maxTransportWeight"      then return 0 end
            if k == "spawnDistanceInCircle"   then return 10 end
            if k == "enableFastRopeInsertion" then return true end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "maximumSearchDistance"   then return searchDist end
            if k == "maximumMoveDistance"     then return moveDist end
            return origGs(k)
        end

        tm   = CTLDTroopManager.getInstance()
        unit = makeUnit("UH-1H-1")

        origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function()
            return { getName = function() return "MockDropped" end, getUnits = function() return {} end,
                     isExist = function() return true end }
        end
        origGetByName = Group.getByName
        Group.getByName = function(n)
            if n == "MockDropped" then
                return { isExist = function() return true end,
                         getController = function()
                             return { setOption = function() end, setTask = function(_, t) orders[#orders + 1] = t end }
                         end }
            end
            return origGetByName(n)
        end
        origGetGroups = coalition.getGroups
        coalition.getGroups = function(side, cat)
            if side == coalition.side.RED and cat == Group.Category.GROUND then return enemies end
            return {}
        end
        origSchedule = ctld.scheduler.schedule
        -- Keep only what orders a group (their argument names it); anything else CTLD schedules is not run here.
        ctld.scheduler.schedule = function(fn, arg)
            if type(arg) == "table" and arg.grpName then scheduled[#scheduled + 1] = { fn = fn, arg = arg } end
        end

        origAI = rawget(_G, "AI")
        _G.AI = { Option = { Ground = { id = { ALARM_STATE = 9, ROE = 0 },
                                     val = { ALARM_STATE = { AUTO = 1 }, ROE = { OPEN_FIRE = 2 } } } } }

        origRandom, randoms = math.random, {}
        -- Only the two-argument calls (the walk's offsets) are fixed; the drop's own spawn angle keeps the real source.
        math.random = function(...)
            if select("#", ...) == 2 and #randoms > 0 then return table.remove(randoms, 1) end
            return origRandom(...)
        end

        local zm = CTLDZoneManager.getInstance()
        zmSaved = { isUnitInZone = zm.isUnitInZone, getWaypointZoneAt = zm.getWaypointZoneAt }
        zm.isUnitInZone      = function() return nil end
        zm.getWaypointZoneAt = function() return nil end
        tm._isInAir = function() return false end
    end)

    after_each(function()
        ctld.gs = origGs
        CTLDObjectRegistry.spawnObject = origSpawn
        Group.getByName = origGetByName
        coalition.getGroups = origGetGroups
        ctld.scheduler.schedule = origSchedule
        math.random = origRandom
        _G.AI = origAI
        local zm = CTLDZoneManager.getInstance()
        zm.isUnitInZone, zm.getWaypointZoneAt = zmSaved.isUnitInZone, zmSaved.getWaypointZoneAt
    end)

    describe("with an enemy in range", function()

        it("is ordered toward the nearest enemy, without any line of sight", function()
            enemies = { enemyGroup(1000 + 3000, 2000), enemyGroup(1000 + 800, 2000 + 600) }
            local o = drop()
            assert.equals(1, #o)
            assert.equals(1800, destination(o[1]).x)
            assert.equals(2600, destination(o[1]).y)    -- the waypoint's y is the world z
        end)

        it("ignores an enemy beyond maximumSearchDistance", function()
            enemies = { enemyGroup(1000 + 4500, 2000) }
            randoms = { 100, 0, 0, 0 }                   -- x: +100, z: 0
            local o = drop()
            assert.equals(1100, destination(o[1]).x)
        end)

        it("looks at the first alive unit of an enemy group, and skips a group with none", function()
            enemies = { enemyGroup(1500, 2000, false) }
            randoms = { 50, 0, 0, 0 }
            local o = drop()
            assert.equals(1050, destination(o[1]).x)
        end)

    end)

    describe("with no enemy in range", function()

        it("walks to a random point within maximumMoveDistance of the drop point", function()
            randoms = { 900, 200, 100, 600 }             -- dx = 900-200 = 700, dz = 100-600 = -500
            local o = drop()
            assert.equals(1, #o)
            assert.equals(DROP.x + 700, destination(o[1]).x)
            assert.equals(DROP.z - 500, destination(o[1]).y)
        end)

        it("draws each offset in 0..maximumMoveDistance", function()
            moveDist = 300
            local seen = {}
            math.random = function(...)
                local a, b = ...
                if a == 0 and b == 300 then seen[#seen + 1] = { a, b }; return 0 end
                return origRandom(...)                   -- everything else keeps the real source
            end
            drop()
            assert.equals(4, #seen)                      -- two offsets per axis, as v1 drew them
        end)

    end)

    describe("the distances at 0", function()

        it("gives no order when both are 0", function()
            searchDist, moveDist = 0, 0
            enemies = { enemyGroup(1010, 2000) }
            assert.equals(0, #drop())
        end)

        it("still walks at random when only the search distance is 0 (v1: no enemy search)", function()
            searchDist = 0
            enemies = { enemyGroup(1010, 2000) }
            randoms = { 400, 0, 0, 0 }
            local o = drop()
            assert.equals(1, #o)
            assert.equals(1400, destination(o[1]).x)
        end)

        it("gives no order when there is no enemy and maximumMoveDistance is 0", function()
            moveDist = 0
            assert.equals(0, #drop())
        end)

        it("still goes for an enemy in range when only maximumMoveDistance is 0", function()
            moveDist = 0
            enemies = { enemyGroup(1500, 2500) }
            local o = drop()
            assert.equals(1, #o)
            assert.equals(1500, destination(o[1]).x)
        end)

    end)

    describe("priority", function()

        it("lets a waypoint zone march the group to its centre, with no second order", function()
            local zm = CTLDZoneManager.getInstance()
            zm.getWaypointZoneAt = function()
                return { zoneName = "WPZ_a", getCenter = function() return { x = 5000, y = 0, z = 6000 } end }
            end
            enemies = { enemyGroup(1500, 2000) }
            local o = drop()
            assert.equals(1, #o)
            assert.equals(5000, destination(o[1]).x)
        end)

        it("lets a template task keep the routing, with no default order on top", function()
            -- the task itself looks for its target after a delay; it must be the only thing scheduled
            enemies = {}
            local before = #scheduled
            tm:embarkFromTroopZone(unit, makeZone(), makeTemplate({ specificParams = { task = "gotoNearestWPZ" } }))
            assert.is_true(tm:disembark(unit))
            assert.equals(before + 1, #scheduled)
        end)

        it("gives no order when the troops go into an extraction zone (no group is spawned)", function()
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function() return { zoneName = "EXZ_a", objectiveFlag = "flag" } end
            local origGet, origSet = trigger.misc.getUserFlag, trigger.action.setUserFlag
            trigger.misc.getUserFlag, trigger.action.setUserFlag = function() return 0 end, function() end
            local o = drop()
            trigger.misc.getUserFlag, trigger.action.setUserFlag = origGet, origSet
            assert.equals(0, #o)
        end)

    end)

    describe("however the troops come down", function()

        it("is ordered after a fast-rope drop", function()
            tm._isInAir        = function() return true end
            tm._safeToFastRope = function() return true end
            enemies = { enemyGroup(1700, 2000) }
            local o = drop()
            assert.equals(1, #o)
            assert.equals(1700, destination(o[1]).x)
        end)

        it("is ordered after the drop of an AI transport (Unload All)", function()
            enemies = { enemyGroup(1700, 2000) }
            tm:embarkFromTroopZone(unit, makeZone(), makeTemplate())
            assert.is_true(tm:disembarkAll(unit))
            for _, s in ipairs(scheduled) do s.fn(s.arg) end
            assert.equals(1, #orders)
        end)

    end)

end)
