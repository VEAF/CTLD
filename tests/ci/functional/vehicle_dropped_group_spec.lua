---@diagnostic disable
-- FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS (issue #309, ADR 0029): a whole vehicle unloaded from a transport is a dropped group
-- too: it goes for the nearest enemy within maximumSearchDistance, and with none in range walks within maximumMoveDistance,
-- as in CTLD v1 — a JTAC vehicle included (no exception). A vehicle that comes out of a crate being unpacked is not
-- concerned (v1 did not move it either).
-- ============================================================

local function makeTransport(name)
    return {
        _name = name or "UH-1H-T",
        getName = function(self) return self._name end, getTypeName = function() return "UH-1H" end,
        getCoalition = function() return coalition.side.BLUE end, getCountry = function() return 2 end,
        getPoint = function() return { x = 1000, y = 10, z = 2000 } end,
        getPosition = function() return { x = { x = 1, y = 0, z = 0 }, p = { x = 1000, y = 10, z = 2000 } } end,
        getVelocity = function() return { x = 0, y = 0, z = 0 } end,
        getGroup = function() return { getID = function() return 9901 end } end,
        isExist = function() return true end,
    }
end

local function enemyGroup(x, z)
    local leader = { getLife = function() return 10 end, getPoint = function() return { x = x, y = 0, z = z } end }
    return { getUnits = function() return { leader } end }
end

describe("A whole vehicle unloaded from a transport acts on its own (issue #309)", function()

    local vs, transport, origGs, origDynAdd, origGetByName, origGetGroups, origSchedule, origRandom, origAI
    local searchDist, moveDist, enemies, scheduled, orders, resumed, zmSaved

    local function loadedVehicle(id)
        local veh = CTLDVehicle:new({
            id = id, vehicleType = "M1045 HMMWV TOW", unit = nil,
            spawnData = { groupName = id, unitName = id .. "_unit", vehicleType = "M1045 HMMWV TOW", countryId = 2, coalitionId = 2 },
        })
        veh:setState(CTLDVehicle.STATE.LOADED)
        veh.loadTransportName, veh.loadMethod = transport:getName(), "menu_ctld"
        vs._vehicles[id] = veh
        return veh
    end

    local function unload(veh)
        vs:unloadVehicle(veh, transport, transport:getName(), "menu_ctld")
        for _, s in ipairs(scheduled) do s.fn(s.arg) end
        return orders
    end

    before_each(function()
        CTLDVehicleSpawner._instance = nil
        CTLDPlayerManager._instance  = nil
        CTLDJTACManager._instance    = nil
        CTLDCrateManager._instance   = nil
        CTLDZoneManager._instance    = nil
        EventDispatcher._instance    = nil
        ctld.MenuManager._instance   = nil
        _cmInstance                  = nil

        searchDist, moveDist, enemies, scheduled, orders, resumed = 4000, 2000, {}, {}, {}, false
        origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { canTransportWholeVehicle = true, maxWholeVehiclesOnboard = 1,
                                       loadableVehiclesBLUE = { "M1045 HMMWV TOW" }, loadableVehiclesRED = {}, troopsEnabled = false } }
            end
            if k == "maximumDistancePackableUnitsSearch" then return 200 end
            if k == "nbLimitSpawnedTroops" then return { 0, 0 } end
            if k == "JTAC_dropEnabled" then return true end
            if k == "maximumSearchDistance" then return searchDist end
            if k == "maximumMoveDistance" then return moveDist end
            return origGs(k)
        end
        vs = CTLDVehicleSpawner.getInstance()
        transport = makeTransport("UH-1H-T")

        origDynAdd = ctld.utils.dynAdd
        ctld.utils.dynAdd = function(_, data) return { name = data and data.name or "veh" } end
        origGetByName = Group.getByName
        Group.getByName = function(n)
            return { getUnit = function() return { getName = function() return n .. "_unit" end, isExist = function() return true end } end,
                     isExist = function() return true end,
                     getController = function()
                         return { setOption = function() end, setTask = function(_, t) orders[#orders + 1] = t end }
                     end }
        end
        origGetGroups = coalition.getGroups
        coalition.getGroups = function(side, cat)
            if side == coalition.side.RED and cat == Group.Category.GROUND then return enemies end
            return {}
        end
        origSchedule = ctld.scheduler.schedule
        ctld.scheduler.schedule = function(fn, arg)
            if type(arg) == "table" and arg.grpName then scheduled[#scheduled + 1] = { fn = fn, arg = arg } end
        end
        origRandom = math.random
        origAI = rawget(_G, "AI")
        _G.AI = { Option = { Ground = { id = { ALARM_STATE = 9, ROE = 0 },
                                        val = { ALARM_STATE = { AUTO = 1 }, ROE = { OPEN_FIRE = 2 } } } } }
        local zm = CTLDZoneManager.getInstance()
        zmSaved = { getWaypointZoneAt = zm.getWaypointZoneAt }
        zm.getWaypointZoneAt = function() return nil end
        CTLDJTACManager.getInstance().resumeJTAC = function() resumed = true end
    end)

    after_each(function()
        ctld.gs = origGs
        ctld.utils.dynAdd = origDynAdd
        Group.getByName = origGetByName
        coalition.getGroups = origGetGroups
        ctld.scheduler.schedule = origSchedule
        math.random = origRandom
        _G.AI = origAI
        CTLDZoneManager.getInstance().getWaypointZoneAt = zmSaved.getWaypointZoneAt
        CTLDJTACManager.getInstance().resumeJTAC = nil
    end)

    it("is ordered toward the nearest enemy in range", function()
        enemies = { enemyGroup(1000 + 900, 2000 + 100) }
        local o = unload(loadedVehicle("dg_v1"))
        assert.equals(1, #o)
        local pts = o[1].params.route.points
        assert.equals(1900, pts[#pts].x)
        assert.equals(2100, pts[#pts].y)
    end)

    it("walks at random within maximumMoveDistance when no enemy is in range", function()
        math.random = function(...)
            if select("#", ...) == 2 then return 0 end
            return origRandom(...)
        end
        local o = unload(loadedVehicle("dg_v2"))
        assert.equals(1, #o)
    end)

    it("gets the same order when it is a JTAC vehicle (no exception)", function()
        enemies = { enemyGroup(1500, 2000) }
        local veh = loadedVehicle("dg_jtac")
        veh.spawnData.isJTAC = true
        local o = unload(veh)
        assert.is_true(resumed)                         -- the JTAC manager was told, the order is given all the same
        assert.equals(1, #o)
    end)

    it("stays where it was unloaded with both distances at 0", function()
        searchDist, moveDist = 0, 0
        enemies = { enemyGroup(1500, 2000) }
        assert.equals(0, #unload(loadedVehicle("dg_v3")))
    end)

    it("marches to a waypoint zone's centre, which keeps priority over the default", function()
        CTLDZoneManager.getInstance().getWaypointZoneAt = function()
            return { zoneName = "WPZ_v", getCenter = function() return { x = 7000, y = 0, z = 8000 } end }
        end
        enemies = { enemyGroup(1500, 2000) }
        local o = unload(loadedVehicle("dg_v4"))
        assert.equals(1, #o)
        local pts = o[1].params.route.points
        assert.equals(7000, pts[#pts].x)
    end)

    it("is ordered when a vehicle released in flight by DCS lands", function()
        enemies = { enemyGroup(1700, 2500) }
        local veh = loadedVehicle("dg_fall")
        veh:setState(CTLDVehicle.STATE.FALLING)
        veh.unit = { isExist = function() return true end, getPoint = function() return { x = 1500, y = 0, z = 2500 } end,
                     getCoalition = function() return coalition.side.BLUE end, getName = function() return "dg_fall_unit" end }
        local polls = {}
        local capture = ctld.scheduler.schedule
        ctld.scheduler.schedule = function(fn, arg, t)
            if arg == nil then polls[#polls + 1] = fn else capture(fn, arg, t) end
        end
        local origLanded = ctld.utils.hasLanded
        ctld.utils.hasLanded = function() return true end
        vs:_scheduleNativeLandingPoll(veh)
        polls[1](nil, 0)
        ctld.utils.hasLanded, ctld.scheduler.schedule = origLanded, capture
        for _, s in ipairs(scheduled) do s.fn(s.arg) end
        assert.equals(1, #orders)
        local pts = orders[1].params.route.points
        assert.equals(1700, pts[#pts].x)
    end)

    it("is ordered when a vehicle parachuted by CTLD lands", function()
        enemies = { enemyGroup(1700, 2500) }
        local veh = loadedVehicle("dg_para")
        local origLand, origCalc, origSpawnAt = land.getHeight, ctld.utils.calcDropPosition, vs.spawnVehicleAt
        local origSched = ctld.scheduler.schedule
        land.getHeight = function() return 10 end
        ctld.utils.calcDropPosition = function() return { x = 1500, y = 10, z = 2500 }, 5 end
        vs.spawnVehicleAt = function() end
        local landings = {}
        ctld.scheduler.schedule = function(fn, arg, t)
            if type(arg) == "table" and arg.grpName then origSched(fn, arg, t) else landings[#landings + 1] = fn end
        end
        local air = makeTransport("UH-1H-T")
        air.getPoint = function() return { x = 1000, y = 300, z = 2000 } end
        local origGs2 = ctld.gs
        ctld.gs = function(k) if k == "parachuteMinAltitudeVehicles" then return 30 end
                              if k == "parachuteDescentRateVehicles" then return 5 end return origGs2(k) end
        vs:parachuteVehicle(air, veh.id, { unitName = "UH-1H-T", groupId = 9901, coalition = 2 })
        ctld.gs = origGs2
        assert.is_true(#landings >= 1)
        landings[#landings](nil, 0)                      -- the descent ends
        land.getHeight, ctld.utils.calcDropPosition, vs.spawnVehicleAt, ctld.scheduler.schedule =
            origLand, origCalc, origSpawnAt, origSched
        for _, s in ipairs(scheduled) do s.fn(s.arg) end
        assert.equals(1, #orders)
        local pts = orders[1].params.route.points
        assert.equals(1700, pts[#pts].x)
    end)

    it("is not ordered when it comes out of a crate being unpacked", function()
        enemies = { enemyGroup(1500, 2000) }
        local cm = CTLDCrateManager.getInstance()
        local origSpawn, origPost = ctld.utils.spawnFromDescriptor, CTLDCrateManager._dispatchPostSpawn
        ctld.utils.spawnFromDescriptor = function() return true end
        CTLDCrateManager._dispatchPostSpawn = function() end
        local ok = cm:_spawnUnpacked({ desc = "Jeep", unit = "Hummer", weight = 100, cratesRequired = 1 },
                                     { x = 1100, y = 0, z = 2100 }, coalition.side.BLUE, 2, nil)
        ctld.utils.spawnFromDescriptor, CTLDCrateManager._dispatchPostSpawn = origSpawn, origPost
        assert.is_true(ok)
        assert.equals(0, #scheduled)
    end)

end)
