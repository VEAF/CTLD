---@diagnostic disable
-- tests/ci/unit/ship_troop_zone_anchor_spec.lua
-- FIX-SHIP-ZONE-ANCHOR-PARITY ticket 01 — a troopZones entry backed by a ship rides that ship.
-- v1 (ctld.inPickupZone) re-resolves the ship's position on every check, with a hardcoded
-- 200 m radius; CTLD 2 snapshotted it at init, so a carrier steamed away from its own pickup
-- point. This spec pins both halves of the parity: the anchor and the radius.
-- ============================================================

describe("a troop zone backed by a ship", function()

    local zm, origGs, origGetZone, origUnitGetByName, settings, ship

    local function fakeShip(name, point)
        local u = { _point = point, _exists = true }
        function u:getName()      return name end
        function u:getTypeName()  return "Stennis" end
        function u:getPoint()     return self._point end
        function u:getCoalition() return coalition.side.BLUE end
        function u:isExist()      return self._exists end
        return u
    end

    before_each(function()
        zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)
        ship = fakeShip("CVN-74", { x = 1000, y = 0, z = 2000 })

        origGs             = ctld.gs
        origGetZone        = trigger.misc.getZone
        origUnitGetByName  = Unit.getByName

        settings = { troopZones = { { "CVN-74", "blue", 999, "yes", 2 } }, wpZones = {}, logisticUnits = {} }
        ctld.gs = function(key)
            if settings[key] ~= nil then return settings[key] end
            return origGs and origGs(key)
        end
        trigger.misc.getZone = function(name) return nil end   -- no trigger zone by that name
        Unit.getByName       = function(name) return (name == "CVN-74") and ship or nil end
    end)

    after_each(function()
        ctld.gs              = origGs
        trigger.misc.getZone = origGetZone
        Unit.getByName       = origUnitGetByName
    end)

    it("is registered from the unit name when no trigger zone matches", function()
        zm:_loadLegacyZones()
        assert.is_not_nil(zm._troopZones["CVN-74"])
        assert.is_true(zm._troopZones["CVN-74"]:hasPickup())
    end)

    it("tracks the ship between two evaluations, with no re-init", function()
        zm:_loadLegacyZones()
        local zone = zm._troopZones["CVN-74"]
        assert.equals(1000, zone:getCenter().x)
        assert.equals(2000, zone:getCenter().z)

        ship._point = { x = 9000, y = 0, z = 2000 }   -- the carrier steams east
        assert.equals(9000, zone:getCenter().x)
    end)

    it("carries its pickup point with it — a point 9 km east is inside once the ship is there", function()
        zm:_loadLegacyZones()
        local zone = zm._troopZones["CVN-74"]
        local far  = { x = 9050, y = 0, z = 2000 }

        assert.is_false(zone:isInZone(far))
        ship._point = { x = 9000, y = 0, z = 2000 }
        assert.is_true(zone:isInZone(far))
    end)

    it("uses v1's 200 m radius, not maximumDistancePackableUnitsSearch", function()
        settings.maximumDistancePackableUnitsSearch = 1500
        zm:_loadLegacyZones()
        assert.equals(200, zm._troopZones["CVN-74"].radius)
    end)

    it("stays at its last known position when the ship sinks, without erroring", function()
        zm:_loadLegacyZones()
        local zone = zm._troopZones["CVN-74"]
        ship._point  = { x = 5000, y = 0, z = 2000 }
        assert.equals(5000, zone:getCenter().x)

        ship._exists = false
        assert.is_not_nil(zone:getCenter())
        assert.equals(1000, zone:getCenter().x)   -- the point captured at init
        assert.is_false(zone:isAlive())
    end)

    it("reports itself as dynamic, like the logistic zone that already did", function()
        zm:_loadLegacyZones()
        assert.is_true(zm._troopZones["CVN-74"]:isDynamic())
    end)

    it("leaves a trigger-zone-backed troop zone resolving through trigger.misc.getZone", function()
        settings.troopZones  = { { "pickzone1", "blue", 999, "yes", 2 } }
        trigger.misc.getZone = function(name)
            if name ~= "pickzone1" then return nil end
            return { point = { x = 10, y = 0, z = 20 }, radius = 300 }
        end

        zm:_loadLegacyZones()
        local zone = zm._troopZones["pickzone1"]

        assert.is_not_nil(zone)
        assert.equals(300, zone.radius)
        assert.equals(10, zone:getCenter().x)
        assert.is_false(zone:isDynamic())

        -- and it follows its trigger zone if that zone moves (Moving Zone)
        trigger.misc.getZone = function(name)
            return { point = { x = 700, y = 0, z = 20 }, radius = 300 }
        end
        assert.equals(700, zone:getCenter().x)
    end)

end)
