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
        -- Only the walk's offsets, math.random(0, maximumMoveDistance), are fixed; the drop's own spawn angle and
        -- the parachute drift keep the real source.
        math.random = function(...)
            local a, b = ...
            if select("#", ...) == 2 and a == 0 and b == moveDist and #randoms > 0 then return table.remove(randoms, 1) end
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

    describe("parachuted troops (ticket 02)", function()

        local origAddGroup, origTimerSchedule, origGetHeight, jumpers
        local transport = {
            getPoint = function() return { x = 1000, y = 200, z = 2000 } end,
            getVelocity = function() return { x = 0, y = 0, z = 0 } end,
            getName = function() return "UH-1H-1" end,
        }

        before_each(function()
            origAddGroup, origTimerSchedule, origGetHeight = coalition.addGroup, timer.scheduleFunction, land.getHeight
            -- The landing runs when the descent ends: run it at once (the first callback scheduled with an empty
            -- argument), while keeping the group orders for the test to run.
            local landed = false
            local capture = ctld.scheduler.schedule
            ctld.scheduler.schedule = function(fn, arg, t)
                if type(arg) == "table" and arg.grpName then return capture(fn, arg, t) end
                if not landed and type(arg) == "table" and next(arg) == nil then
                    landed = true
                    fn(arg, t)
                end
            end
            timer.scheduleFunction = function() return 0 end
            land.getHeight = function() return 10 end
            local spawned = {}
            coalition.addGroup = function(_, _, data)
                spawned[data.name] = true
                return { getName = function() return data.name end }
            end
            -- the real Group.getByName of this spec only knows MockDropped; the parachuted group has its own name
            local prev = Group.getByName
            Group.getByName = function(n)
                if spawned[n] then
                    return { isExist = function() return true end, getName = function() return n end,
                             getUnits = function() return {} end,
                             getController = function()
                                 return { setOption = function() end, setTask = function(_, t) orders[#orders + 1] = t end }
                             end }
                end
                return prev(n)
            end
            local ctldGs = ctld.gs
            ctld.gs = function(k)
                if k == "parachuteMinAltitudeTroops" then return 50 end
                if k == "parachuteDescentRateTroops" then return 100 end
                if k == "parachuteInertiaFactor"     then return 0.0 end
                if k == "parachuteLateralDriftMin"   then return 5 end
                if k == "parachuteLateralDriftMax"   then return 10 end
                return ctldGs(k)
            end
            jumpers = CTLDTroopGroup:new({ templateName = "Paras", unitTotal = 2, weight = 200, coalitionId = 2 })
            tm._inTransit["UH-1H-1"] = { jumpers }
        end)

        after_each(function()
            coalition.addGroup, timer.scheduleFunction, land.getHeight = origAddGroup, origTimerSchedule, origGetHeight
        end)

        local function jump()
            tm:parachuteTroops(transport, { unitName = "UH-1H-1", groupId = 9901, groupName = "G", coalition = 2 })
            for _, s in ipairs(scheduled) do s.fn(s.arg) end
            return orders
        end

        it("get the order of a dropped group once they land: toward the nearest enemy in range", function()
            enemies = { enemyGroup(1000 + 700, 2000 + 700) }
            local o = jump()
            assert.equals(1, #o)
            local d = destination(o[1])
            assert.equals(1700, d.x)
            assert.equals(2700, d.y)
        end)

        it("walk at random when no enemy is in range", function()
            randoms = { 600, 100, 300, 0 }               -- dx = 500, dz = 300
            local o = jump()
            assert.equals(1, #o)
            local d = destination(o[1])
            -- the landing point is the drop point drifted by a few metres: the walk is around it
            assert.is_true(math.abs(d.x - 1500) < 40 and math.abs(d.y - 2300) < 40)
        end)

        it("stay where they land with both distances at 0", function()
            searchDist, moveDist = 0, 0
            enemies = { enemyGroup(1700, 2000) }
            assert.equals(0, #jump())
        end)

        it("keep following their template task, with no default order on top", function()
            jumpers.specificParams = { task = "gotoNearestWPZ" }
            enemies = { enemyGroup(1700, 2000) }
            local before = #scheduled
            tm:parachuteTroops(transport, { unitName = "UH-1H-1", groupId = 9901, groupName = "G", coalition = 2 })
            assert.equals(before + 1, #scheduled)         -- the task's own timer, nothing else
        end)

    end)

    describe("scripted spawns (ticket 03)", function()

        local POINT = { x = 1000, y = 5, z = 2000 }
        local spawnOpts

        before_each(function()
            -- the real registry stub of this spec returns a group; keep the options the spawn was given
            local base = CTLDObjectRegistry.spawnObject
            CTLDObjectRegistry.spawnObject = function(key, coa, country, x, z, hdg, opts)
                spawnOpts = opts
                return base(key, coa, country, x, z, hdg, opts)
            end
        end)

        local function spawn(...)
            assert.is_true(tm:spawnGroupAtPoint("blue", 4, POINT, ...))
            for _, s in ipairs(scheduled) do s.fn(s.arg) end
            return orders
        end

        it("orders the spawned group toward the nearest enemy within maximumSearchDistance", function()
            enemies = { enemyGroup(1000 + 900, 2000) }
            local o = spawn(0)
            assert.equals(1, #o)
            assert.equals(1900, destination(o[1]).x)
        end)

        it("takes its own search distance, which can leave an enemy out of range", function()
            enemies = { enemyGroup(1000 + 900, 2000) }
            randoms = { 100, 0, 0, 0 }
            local o = spawn(0, 500)                      -- radius 0 (placement), search distance 500
            assert.equals(1100, destination(o[1]).x)     -- the enemy at 900 m is out of range: a random walk
        end)

        it("takes its own search distance, which can bring an enemy into range", function()
            searchDist = 100                             -- the setting alone would not reach it
            enemies = { enemyGroup(1000 + 900, 2000) }
            local o = spawn(0, 5000)
            assert.equals(1900, destination(o[1]).x)
        end)

        it("with a search distance of 0 looks for no enemy and walks at random (as the v1 code does)", function()
            enemies = { enemyGroup(1000 + 900, 2000) }
            randoms = { 300, 0, 0, 0 }
            local o = spawn(0, 0)
            assert.equals(1300, destination(o[1]).x)
        end)

        it("keeps `radius` as the placement circle", function()
            spawn(120)
            assert.equals(120, spawnOpts.circleRadius)
        end)

        it("lets a waypoint zone march the spawned group to its centre", function()
            CTLDZoneManager.getInstance().getWaypointZoneAt = function()
                return { zoneName = "WPZ_s", getCenter = function() return { x = 9000, y = 0, z = 9500 } end }
            end
            enemies = { enemyGroup(1500, 2000) }
            local o = spawn(0)
            assert.equals(9000, destination(o[1]).x)
        end)

        it("leaves a group where it was spawned with both distances at 0", function()
            searchDist, moveDist = 0, 0
            enemies = { enemyGroup(1500, 2000) }
            assert.equals(0, #spawn(0))
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
