---@diagnostic disable
-- tests/ci/unit/zone_type_discovery_spec.lua
-- FEAT-VMCT-INTEGRATION ticket 01 — logistic zones discovered by DCS type name.
-- A catalogue of types replaces a per-mission list of unit names: every matching object
-- becomes a zone anchored to it, and a type nothing matches is silent, not a warning.
-- ============================================================

local function fakeObject(name, typeName, point, coal)
    local o = { _point = point or { x = 0, y = 0, z = 0 } }
    function o:getName()      return name end
    function o:getTypeName()  return typeName end
    function o:getPoint()     return self._point end
    function o:getCoalition() return coal or coalition.side.BLUE end
    function o:isExist()      return true end
    return o
end

--- Put units / statics in the mission for the duration of one spec.
local function missionHolds(units, statics)
    coalition.getGroups = function(side)
        if side ~= coalition.side.BLUE then return {} end
        return { { getUnits = function() return units or {} end } }
    end
    coalition.getStaticObjects = function(side)
        if side ~= coalition.side.BLUE then return {} end
        return statics or {}
    end
end

describe("CTLDZoneManager:_discoverLogisticUnitTypes", function()

    local zm, origGs, origGetGroups, origGetStatics, settings

    before_each(function()
        zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)
        origGs         = ctld.gs
        origGetGroups  = coalition.getGroups
        origGetStatics = coalition.getStaticObjects
        settings = { logisticUnitTypes = {}, maximumDistanceLogistic = 200 }
        ctld.gs = function(key)
            if settings[key] ~= nil then return settings[key] end
            return origGs and origGs(key)
        end
    end)

    after_each(function()
        ctld.gs                    = origGs
        coalition.getGroups        = origGetGroups
        coalition.getStaticObjects = origGetStatics
    end)

    it("registers every unit of a listed type and ignores the others", function()
        settings.logisticUnitTypes = { "Stennis" }
        missionHolds({
            fakeObject("CVN-74", "Stennis", { x = 10, y = 0, z = 20 }),
            fakeObject("CVN-75", "Stennis", { x = 30, y = 0, z = 40 }),
            fakeObject("Escort", "PERRY",   { x = 50, y = 0, z = 60 }),
        })

        zm:_discoverLogisticUnitTypes()

        assert.is_not_nil(zm._logisticZones["CVN-74"])
        assert.is_not_nil(zm._logisticZones["CVN-75"])
        assert.is_nil(zm._logisticZones["Escort"])
    end)

    it("registers statics too — a FARP ammo dump is not a unit", function()
        settings.logisticUnitTypes = { "FARP Ammo Dump Coating" }
        missionHolds({}, { fakeObject("ammo1", "FARP Ammo Dump Coating") })

        zm:_discoverLogisticUnitTypes()

        assert.is_not_nil(zm._logisticZones["ammo1"])
    end)

    it("anchors the zone to the object, so it follows a ship under way", function()
        settings.logisticUnitTypes = { "Stennis" }
        local carrier = fakeObject("CVN-74", "Stennis", { x = 10, y = 0, z = 20 })
        missionHolds({ carrier })

        zm:_discoverLogisticUnitTypes()
        local zone = zm._logisticZones["CVN-74"]
        assert.equals(10, zone:getCenter().x)

        carrier._point = { x = 8000, y = 0, z = 20 }
        assert.equals(8000, zone:getCenter().x)
    end)

    it("uses maximumDistanceLogistic as the radius and the object's own coalition", function()
        settings.logisticUnitTypes      = { "Stennis" }
        settings.maximumDistanceLogistic = 350
        missionHolds({ fakeObject("CVN-74", "Stennis", nil, coalition.side.RED) })

        zm:_discoverLogisticUnitTypes()
        local zone = zm._logisticZones["CVN-74"]
        assert.equals(350, zone.radius)
        assert.equals(coalition.side.RED, zone.coalition)
    end)

    it("never overwrites a zone already registered under the same name", function()
        settings.logisticUnitTypes = { "Stennis" }
        missionHolds({ fakeObject("CVN-74", "Stennis") })
        local existing = CTLDLogisticZone:new({
            name = "CVN-74", coalition = coalition.side.BLUE,
            center = { x = 1, y = 0, z = 1 }, radius = 999,
        })
        zm._logisticZones["CVN-74"] = existing

        zm:_discoverLogisticUnitTypes()

        assert.equals(existing, zm._logisticZones["CVN-74"])
        assert.equals(999, zm._logisticZones["CVN-74"].radius)
    end)

    it("registers nothing when the setting is empty or absent", function()
        missionHolds({ fakeObject("CVN-74", "Stennis") })

        settings.logisticUnitTypes = {}
        zm:_discoverLogisticUnitTypes()
        assert.is_nil(zm._logisticZones["CVN-74"])

        settings.logisticUnitTypes = nil
        zm:_discoverLogisticUnitTypes()
        assert.is_nil(zm._logisticZones["CVN-74"])
    end)

    it("is silent about a listed type absent from the mission — a catalogue, not a manifest", function()
        settings.logisticUnitTypes = { "KUZNECOW" }
        missionHolds({ fakeObject("Escort", "PERRY") })

        local warned = false
        local origLog = ctld.utils.log
        ctld.utils.log = function(level, ...)
            if level == "WARN" or level == "ERROR" then warned = true end
            return origLog(level, ...)
        end

        zm:_discoverLogisticUnitTypes()

        ctld.utils.log = origLog
        assert.is_false(warned)
        assert.equals(0, zm:_count(zm._logisticZones))
    end)

end)
