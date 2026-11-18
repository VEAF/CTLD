---@diagnostic disable
-- FEAT-TROOP-GESTURE-EVENTS (issue #308): the four troop gestures that published nothing now announce themselves
-- on the event bus, like the vehicle and crate gestures do.
--   OnTroopsUnloaded   a group dropped (on the ground, by fast-rope, or into an extraction zone)
--   OnTroopsLoaded     troops loaded in a pickup zone
--   OnTroopsReturned   troops given back to the pickup zone
--   OnTroopsExtracted  a dropped group picked up in the field
-- Published at the end of a gesture that really happened, never on a refusal; `player` is the slot unit name of a
-- player transport and empty for an AI one.
-- ============================================================

local function makeUnit(name, coa)
    coa = coa or coalition.side.BLUE
    return {
        _name        = name,
        getName      = function(self) return self._name end,
        getCoalition = function(self) return coa end,
        getCountry   = function(self) return 2 end,
        getTypeName  = function(self) return "UH-1H" end,
        getPoint     = function(self) return { x = 0, y = 5, z = 0 } end,
        getPosition  = function(self) return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } } end,
        getVelocity  = function(self) return { x = 0, y = 0, z = 0 } end,
        getGroup     = function(self) return { getID = function() return 9901 end } end,
        isExist      = function(self) return true end,
    }
end

local function makeZone(overrides)
    local z = {
        coalition = 0, active = true, pickMaxStock = 0, pickCurrentStock = 10, zoneName = "TRZ_test",
        isInZone     = function() return true end,
        hasPickup    = function() return true end,
        consumeStock = function() end,
        restoreStock = function() end,
    }
    for k, v in pairs(overrides or {}) do z[k] = v end
    return z
end

local function makeTemplate(overrides)
    local t = { name = "Alpha Squad", total = 4, _dbKey = "Alpha_Squad", inf = 3, mg = 1, at = 0, aa = 0,
                mortar = 0, jtac = 0, civ = 0, specificParams = {} }
    for k, v in pairs(overrides or {}) do t[k] = v end
    return t
end

describe("Troop gesture events (issue #308)", function()

    local tm, mockUnit, origGs, origSpawn, zmSaved
    local fired

    local function listen(name)
        fired[name] = {}
        EventDispatcher.getInstance():subscribe(name, function(p) fired[name][#fired[name] + 1] = p end)
    end

    --- Registers the unit as a player's transport (its slot unit name becomes the event's `player`).
    local function asPlayer(unit)
        CTLDPlayerManager.getInstance()._players[unit:getName()] = {
            unitName = unit:getName(), groupId = 9901, groupName = "G", coalition = unit:getCoalition(),
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
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

        origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then return { ["UH-1H"] = { troopsEnabled = true, maxTroopsOnboard = 10 } } end
            if k == "numberOfTroops"          then return 10 end
            if k == "nbLimitSpawnedTroops"    then return { 0, 0 } end
            if k == "maxTransportWeight"      then return 0 end
            if k == "spawnDistanceInCircle"   then return 10 end
            if k == "enableFastRopeInsertion" then return true end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "maxExtractDistance"      then return 125 end
            return origGs(k)
        end

        tm       = CTLDTroopManager.getInstance()
        mockUnit = makeUnit("UH-1H-1")
        fired    = {}
        for _, n in ipairs({ "OnTroopsUnloaded", "OnTroopsLoaded", "OnTroopsReturned", "OnTroopsExtracted" }) do listen(n) end

        -- Dropping spawns a DCS group through the object registry, with no exercise zone and no waypoint zone.
        origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function()
            return { getName = function() return "MockDeploy" end, getUnits = function() return {} end,
                     isExist = function() return true end }
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
        local zm = CTLDZoneManager.getInstance()
        zm.isUnitInZone, zm.getWaypointZoneAt = zmSaved.isUnitInZone, zmSaved.getWaypointZoneAt
    end)

    -- ── OnTroopsLoaded (ticket 02) ────────────────────────────────────────────
    describe("OnTroopsLoaded", function()

        it("is published once, with the group, the carrier, the player and the pickup zone", function()
            asPlayer(mockUnit)
            assert.is_true(tm:embarkFromTroopZone(mockUnit, makeZone({ zoneName = "TRZ_alpha" }), makeTemplate()))
            local ev = fired.OnTroopsLoaded
            assert.equals(1, #ev)
            assert.equals("Alpha Squad", ev[1].troops.templateName)
            assert.equals("UH-1H-1", ev[1].carrierUnitName)
            assert.equals("UH-1H-1", ev[1].player)
            assert.equals("TRZ_alpha", ev[1].zone)
            assert.is_number(ev[1].timestamp)
        end)

        it("has an empty player for an AI transport", function()
            assert.is_true(tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate()))
            assert.equals(1, #fired.OnTroopsLoaded)
            assert.is_nil(fired.OnTroopsLoaded[1].player)
        end)

        it("is published by the scripted loadTransport as well", function()
            local zm = CTLDZoneManager.getInstance()
            local origGetZone, origGetByName = zm.getTroopZoneForUnit, Unit.getByName
            zm.getTroopZoneForUnit = function() return makeZone({ zoneName = "TRZ_script" }) end
            Unit.getByName = function(n) if n == "UH-1H-1" then return mockUnit end return origGetByName(n) end
            tm._templates = { makeTemplate() }
            local ok = tm:loadTransport("UH-1H-1")
            zm.getTroopZoneForUnit, Unit.getByName = origGetZone, origGetByName
            assert.is_true(ok)
            assert.equals(1, #fired.OnTroopsLoaded)
            assert.equals("TRZ_script", fired.OnTroopsLoaded[1].zone)
        end)

        it("is not published when the zone is not available", function()
            assert.is_false(tm:embarkFromTroopZone(mockUnit, makeZone({ active = false }), makeTemplate()))
            assert.is_false(tm:embarkFromTroopZone(mockUnit, makeZone({ coalition = 1 }), makeTemplate()))
            assert.equals(0, #fired.OnTroopsLoaded)
        end)

        it("is not published when the group is too big for the aircraft", function()
            assert.is_false(tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate({ total = 20, inf = 20 })))
            assert.equals(0, #fired.OnTroopsLoaded)
        end)

    end)

    -- ── OnTroopsReturned (ticket 02) ──────────────────────────────────────────
    describe("OnTroopsReturned", function()

        it("is published once per group handed back, with the zone", function()
            asPlayer(mockUnit)
            local zone = makeZone({ zoneName = "TRZ_alpha" })
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate())
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate({ name = "Bravo Squad" }))
            assert.is_true(tm:returnToTroopZone(mockUnit, zone))
            local ev = fired.OnTroopsReturned
            assert.equals(2, #ev)
            assert.equals("UH-1H-1", ev[1].carrierUnitName)
            assert.equals("UH-1H-1", ev[1].player)
            assert.equals("TRZ_alpha", ev[1].zone)
            local names = { ev[1].troops.templateName, ev[2].troops.templateName }
            table.sort(names)
            assert.same({ "Alpha Squad", "Bravo Squad" }, names)
            assert.is_number(ev[1].timestamp)
        end)

        it("has an empty player for an AI transport", function()
            local zone = makeZone()
            tm:embarkFromTroopZone(mockUnit, zone, makeTemplate())
            assert.is_true(tm:returnToTroopZone(mockUnit, zone))
            assert.is_nil(fired.OnTroopsReturned[1].player)
        end)

        it("is not published when there are no troops to return", function()
            assert.is_false(tm:returnToTroopZone(mockUnit, makeZone()))
            assert.equals(0, #fired.OnTroopsReturned)
        end)

    end)

    -- ── OnTroopsUnloaded (ticket 01) ──────────────────────────────────────────
    describe("OnTroopsUnloaded", function()

        before_each(function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate())
        end)

        it("is published once, with the group, the carrier, a method and a destination, for a ground drop", function()
            asPlayer(mockUnit)
            assert.is_true(tm:disembark(mockUnit))
            local ev = fired.OnTroopsUnloaded
            assert.equals(1, #ev)
            assert.equals("Alpha Squad", ev[1].troops.templateName)
            assert.equals("UH-1H-1", ev[1].carrierUnitName)
            assert.equals("UH-1H-1", ev[1].player)
            assert.equals("ground", ev[1].method)
            assert.same({ type = "combat", troopZone = nil }, ev[1].destination)
            assert.is_number(ev[1].timestamp)
        end)

        it("carries method 'fast_rope' when the troops are lowered by rope", function()
            asPlayer(mockUnit)
            tm._isInAir        = function() return true end
            tm._safeToFastRope = function() return true end
            assert.is_true(tm:disembark(mockUnit))
            assert.equals("fast_rope", fired.OnTroopsUnloaded[1].method)
        end)

        it("names the extraction zone when the troops are dropped into one", function()
            asPlayer(mockUnit)
            local zm = CTLDZoneManager.getInstance()
            zm.isUnitInZone = function() return { zoneName = "EXZ_north", objectiveFlag = "flag_exz" } end
            local origGet, origSet = trigger.misc.getUserFlag, trigger.action.setUserFlag
            trigger.misc.getUserFlag   = function() return 0 end
            trigger.action.setUserFlag = function() end
            assert.is_true(tm:disembark(mockUnit))
            trigger.misc.getUserFlag, trigger.action.setUserFlag = origGet, origSet
            local ev = fired.OnTroopsUnloaded[1]
            assert.equals("extraction_zone", ev.destination.type)
            assert.equals("EXZ_north", ev.destination.troopZone)
        end)

        it("has an empty player for an AI transport", function()
            assert.is_true(tm:disembark(mockUnit))   -- no player registered for this unit
            assert.equals(1, #fired.OnTroopsUnloaded)
            assert.is_nil(fired.OnTroopsUnloaded[1].player)
        end)

        it("is published once per group by 'Unload All'", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate({ name = "Bravo Squad" }))
            assert.is_true(tm:disembarkAll(mockUnit))
            assert.equals(2, #fired.OnTroopsUnloaded)
            local names = { fired.OnTroopsUnloaded[1].troops.templateName, fired.OnTroopsUnloaded[2].troops.templateName }
            table.sort(names)
            assert.same({ "Alpha Squad", "Bravo Squad" }, names)
        end)

        it("is published once for the group chosen by index", function()
            tm:embarkFromTroopZone(mockUnit, makeZone(), makeTemplate({ name = "Bravo Squad" }))
            assert.is_true(tm:disembarkIndex(mockUnit, 2))
            assert.equals(1, #fired.OnTroopsUnloaded)
            assert.equals("Bravo Squad", fired.OnTroopsUnloaded[1].troops.templateName)
        end)

        it("is not published when there are no troops on board", function()
            local other = makeUnit("UH-1H-2")
            assert.is_false(tm:disembark(other))
            assert.equals(0, #fired.OnTroopsUnloaded)
        end)

        it("is not published when the aircraft is too high to fast-rope", function()
            tm._isInAir        = function() return true end
            tm._safeToFastRope = function() return false end
            assert.is_false(tm:disembark(mockUnit))
            assert.equals(0, #fired.OnTroopsUnloaded)
        end)

        it("is not published when the group could not be spawned", function()
            CTLDObjectRegistry.spawnObject = function() return nil end
            assert.is_false(tm:disembark(mockUnit))
            assert.equals(0, #fired.OnTroopsUnloaded)
        end)

    end)

end)
