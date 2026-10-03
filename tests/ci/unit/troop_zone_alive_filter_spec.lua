---@diagnostic disable
-- FIX-TROOP-ZONE-ISALIVE-FILTER: every troop-zone query that looks a zone up by position, coalition
-- or unit ignores a zone whose anchor no longer exists, like the logistic-zone queries already do.
-- The anchor "disappears" with no death event (a script removed it), so the death handler never
-- removed the zone and it is still registered at its last known position.
-- ============================================================

describe("CTLDZoneManager troop-zone queries and a vanished anchor", function()

    local zm
    local origUnitGetByName
    local anchorAlive
    local PT = { x = 100, y = 0, z = 200 }

    -- The anchor of every zone below: toggled by the test, no event is ever fired.
    local anchor = {
        isExist  = function() return anchorAlive end,
        getPoint = function() return PT end,
    }

    local function newZone(extra)
        local data = {
            dcsName = "Z", zoneName = "Z", coalition = coalition.side.BLUE,
            center = PT, radius = 500,
            linkedUnit = anchor,
        }
        for k, v in pairs(extra or {}) do data[k] = v end
        return CTLDTroopZone:new(data)
    end

    local function register(zone) zm._troopZones[zone:registryKey()] = zone; return zone end

    before_each(function()
        zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)
        anchorAlive = true
        origUnitGetByName = Unit.getByName
        Unit.getByName = function(name)
            if name == "U1" then
                return { isExist = function() return true end, getPoint = function() return PT end,
                         getCoalition = function() return coalition.side.BLUE end }
            end
        end
    end)

    after_each(function() Unit.getByName = origUnitGetByName end)

    local BLUE = coalition.side.BLUE

    local queries = {
        { "getTroopZonesForCoalition", { isWaypoint = false },
          function() return zm:getTroopZonesForCoalition(BLUE)[1] end },
        { "getTroopZoneAtPoint", { },
          function() return zm:getTroopZoneAtPoint(PT, BLUE) end },
        { "getTroopZoneForUnit", { },
          function() return zm:getTroopZoneForUnit("U1") end },
        { "getWaypointZoneAt", { isWaypoint = true },
          function() return zm:getWaypointZoneAt(PT, BLUE) end },
        { "getNearestWaypointZone", { isWaypoint = true },
          function() return zm:getNearestWaypointZone(PT, BLUE) end },
        { "getDropoffZoneAt", { isDropoff = true },
          function() return zm:getDropoffZoneAt(PT, BLUE) end },
        { "getAIPickupZoneAt", { isAIPickup = true },
          function() return zm:getAIPickupZoneAt(PT, BLUE) end },
        { "getAIDropoffZoneAt", { isAIDropoff = true },
          function() return zm:getAIDropoffZoneAt(PT, BLUE) end },
        { "isUnitInZone", { },
          function() return zm:isUnitInZone("U1") end },
    }

    for _, q in ipairs(queries) do
        local name, flags, run = q[1], q[2], q[3]

        describe(name, function()

            it("returns the zone while its anchor exists", function()
                local zone = register(newZone(flags))
                assert.equals(zone, run())
            end)

            it("does not return it once its anchor has disappeared without a death event", function()
                register(newZone(flags))
                anchorAlive = false
                assert.is_nil(run())
            end)

        end)
    end

    describe("controls", function()

        it("an un-anchored zone is returned whatever happens to other anchors", function()
            local fixed = register(newZone({ dcsName = "Fixed", zoneName = "Fixed", linkedUnit = false }))
            anchorAlive = false
            assert.equals(fixed, zm:getTroopZoneAtPoint(PT, BLUE))
        end)

        it("the lookup by registry key still returns a zone whose anchor is gone", function()
            local zone = register(newZone())
            anchorAlive = false
            assert.equals(zone, zm:getTroopZone(zone:registryKey()))
        end)

    end)

end)
