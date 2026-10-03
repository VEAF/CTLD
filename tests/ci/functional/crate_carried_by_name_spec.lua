---@diagnostic disable
-- FIX-DCS-OBJECT-NAME-COMPARISON ticket 01 (issue #236):
-- "is this crate on board this transport?" is answered by unit NAME, never by userdata identity,
-- and maxCratesOnboard caps the TOTAL of crates on board whatever the loading mode.
-- Every case builds the transport that loaded the crate and the one re-resolved at check time
-- as DISTINCT objects sharing a name — the situation the defect is about (the previous specs read
-- the transport back from the same stub, so identity was true by construction).
-- ============================================================

local function resetAll()
    CTLDPlayerManager._instance  = nil
    ctld.MenuManager._instance   = nil
    EventDispatcher._instance    = nil
    CTLDDCSEventBridge._instance = nil
    CTLDZoneManager._instance    = nil
    CTLDTroopManager._instance   = nil
    CTLDVehicleSpawner._instance = nil
    CTLDCrateManager._instance   = nil
    _cmInstance                  = nil
    CTLDBeaconManager._instance  = nil
    CTLDReconManager._instance   = nil
    CTLDJTACManager._instance    = nil
end

local function makeUnit(name, y, speed)
    return {
        isExist     = function() return true end,
        getName     = function() return name end,
        getTypeName = function() return "UH-1H" end,
        getPoint    = function() return { x = 0, y = y or 109.5, z = 0 } end,
        getVelocity = function() return { x = speed or 0, y = 0, z = 0 } end,
    }
end

local function makeCrate(name, position)
    return CTLDCrate:new({
        crateName   = name,
        descriptor  = { desc = "Ammo", unit = "Ammo_Crate", weight = 500, cratesRequired = 1 },
        spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
        position    = position or { x = 0, y = 100, z = 0 },
        coalition   = 2,
        heading     = 0,
        dcsStatic   = nil,
    })
end

describe("FIX-DCS-OBJECT-NAME-COMPARISON — crates on board by name", function()

    local cm
    local _origGs, _origInAir, _origGetDist, _origGetByName, _origSched, _origGetHeight
    local capacity

    before_each(function()
        resetAll()
        _origGs        = ctld.gs
        _origInAir     = ctld.utils.inAir
        _origGetDist   = ctld.utils.getDistance
        _origGetByName = Unit.getByName
        _origSched     = timer.scheduleFunction
        _origGetHeight = land.getHeight
        capacity       = 1

        ctld.gs = function(k)
            if k == "enableHoverSlingload"       then return true  end
            if k == "enableCrates"               then return true  end
            if k == "minimumHoverHeight"         then return 7.5   end
            if k == "maximumHoverHeight"         then return 12.0  end
            if k == "maxDistanceFromCrate"       then return 5.5   end
            if k == "hoverTime"                  then return 1     end
            if k == "maxSlingloadSpeed"          then return 50    end
            if k == "parachuteMinAltitudeCrates" then return 30    end
            if k == "parachuteDescentRateCrates" then return 100   end
            if k == "parachuteInertiaFactor"     then return 0.0   end
            if k == "parachuteLateralDriftMin"   then return 5     end
            if k == "parachuteLateralDriftMax"   then return 10    end
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { cratesEnabled = true, canSlingload = true, maxCratesOnboard = capacity } }
            end
            return _origGs(k)
        end
        ctld.utils.inAir       = function(_) return true end
        ctld.utils.getDistance = function(_, p1, p2)
            local dx = (p1.x or 0) - (p2.x or 0)
            local dz = (p1.z or 0) - (p2.z or 0)
            return math.sqrt(dx * dx + dz * dz)
        end
        timer.scheduleFunction = function() end   -- no self-rescheduling
        land.getHeight         = function(_) return 10 end

        cm = CTLDCrateManager.getInstance()
    end)

    after_each(function()
        ctld.gs                = _origGs
        ctld.utils.inAir       = _origInAir
        ctld.utils.getDistance = _origGetDist
        Unit.getByName         = _origGetByName
        timer.scheduleFunction = _origSched
        land.getHeight         = _origGetHeight
    end)

    local function registerPlayer(unitName)
        CTLDPlayerManager.getInstance()._players[unitName] = {
            unitName = unitName, groupId = 9901, groupName = "G", coalition = 2, typeName = "UH-1H",
            isTransport = true, canCarryVehicles = false,
            loadedCrates = {}, loadedTroops = {}, loadedVehicles = {},
            addLoadedCrate = function() end, removeLoadedCrate = function() end,
        }
    end

    describe("cratesOnboard", function()

        it("lists a crate loaded on a distinct object that has the same name", function()
            local crate = makeCrate("c1")
            crate:load(makeUnit("UH-1H-1"))
            cm.crates["c1"] = crate

            local onboard = cm:cratesOnboard("UH-1H-1")
            assert.equals(1, #onboard)
            assert.equals(crate, onboard[1])
        end)

        it("does not list it for another unit name", function()
            local crate = makeCrate("c1")
            crate:load(makeUnit("UH-1H-1"))
            cm.crates["c1"] = crate

            assert.equals(0, #cm:cratesOnboard("UH-1H-2"))
        end)

        it("counts a slung crate and a menu-loaded crate together", function()
            local menuCrate, slungCrate = makeCrate("c1"), makeCrate("c2")
            menuCrate:load(makeUnit("UH-1H-1"))
            slungCrate.inTransitOnSlingload = true
            slungCrate:load(makeUnit("UH-1H-1"))
            cm.crates["c1"], cm.crates["c2"] = menuCrate, slungCrate

            assert.equals(2, #cm:cratesOnboard("UH-1H-1"))
        end)

        it("ignores a crate whose carrier name cannot be read", function()
            local crate = makeCrate("c1")
            local carrier = makeUnit("UH-1H-1")
            crate:load(carrier)
            carrier.getName = function() error("released object") end
            cm.crates["c1"] = crate

            assert.equals(0, #cm:cratesOnboard("UH-1H-1"))
        end)

    end)

    describe("slung crate lookup", function()

        it("finds a slung crate through a distinct same-name transport object", function()
            local crate = makeCrate("c1")
            crate.inTransitOnSlingload = true
            crate:load(makeUnit("UH-1H-1"))
            cm.crates["c1"] = crate

            assert.equals(crate, cm:_getSlingloadedCrate(makeUnit("UH-1H-1")))
        end)

        it("loses the slung crate when the aircraft goes over maxSlingloadSpeed", function()
            local crate = makeCrate("c1")
            crate.inTransitOnSlingload = true
            crate:load(makeUnit("UH-1H-1"))
            cm.crates["c1"] = crate
            registerPlayer("UH-1H-1")
            local fast = makeUnit("UH-1H-1", 109.5, 100)
            Unit.getByName = function(n) if n == "UH-1H-1" then return fast end end

            local lost
            EventDispatcher.getInstance():subscribe("OnCrateLost", function(p) lost = p end)
            cm:checkHoverStatus()

            assert.is_not_nil(lost)
            assert.equals("slingload_overspeed", lost.trigger)
        end)

    end)

    describe("parachuteCrates", function()

        it("drops a crate loaded on a distinct same-name transport object", function()
            local crate = makeCrate("c1")
            crate:load(makeUnit("UH-1H-1", 110))
            cm.crates["c1"] = crate

            local fired = false
            EventDispatcher.getInstance():subscribe("OnCrateParachuting", function() fired = true end)
            cm:parachuteCrates(makeUnit("UH-1H-1", 110),
                { unitName = "UH-1H-1", groupId = 9901, groupName = "G", coalition = 2 })

            assert.is_true(fired)
        end)

    end)

    describe("maxCratesOnboard is a total", function()

        local function hoverAboveGroundCrate(menuLoaded)
            local transport = makeUnit("UH-1H-1", 109.5)
            Unit.getByName = function(n) if n == "UH-1H-1" then return transport end end
            registerPlayer("UH-1H-1")
            local loaded = makeCrate("c1")
            loaded:load(makeUnit("UH-1H-1"))        -- loaded earlier, by the F10 menu: not slung
            cm.crates["c1"] = loaded
            local ground = makeCrate("c2", { x = 0, y = 100, z = 0 })
            cm.crates["c2"] = ground
            cm:checkHoverStatus()
            return ground
        end

        it("refuses a hover hook-up when a menu-loaded crate already fills the capacity", function()
            capacity = 1
            local ground = hoverAboveGroundCrate()
            assert.is_false(ground.inTransitOnSlingload == true)
        end)

        it("still hooks a crate when the aircraft has room left", function()
            capacity = 2
            local ground = hoverAboveGroundCrate()
            assert.is_true(ground.inTransitOnSlingload == true)
        end)

    end)

end)
