---@diagnostic disable
-- tests/ci/unit/troop_zone_scripted_api_spec.lua
-- FEAT-TROOP-ZONE-SCRIPTED-API ticket 02 — createTroopZoneAtObject: a scripted way to add a
-- pickup-capable TRZ_ troop zone on any named DCS object (zone, unit, static, group, airbase).
-- ============================================================

describe("CTLDZoneManager:createTroopZoneAtObject", function()

    local zm
    local origGetZone, origUnitGetByName, origStaticGetByName, origGroupGetByName, origAirbaseGetByName

    local function fakeZone(point, radius)
        return { point = point, radius = radius }
    end

    local function fakeUnit(point)
        local u = { _point = point }
        function u:getPoint() return self._point end
        function u:isExist()  return true end
        return u
    end

    local function fakeGroup(firstUnit)
        local g = {}
        function g:getUnit(i) if i == 1 then return firstUnit end end
        return g
    end

    local function fakeAirbase(point)
        local a = { _point = point }
        function a:getPoint() return self._point end
        return a
    end

    before_each(function()
        zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)

        origGetZone            = trigger.misc.getZone
        origUnitGetByName      = Unit.getByName
        origStaticGetByName    = StaticObject.getByName
        origGroupGetByName     = Group.getByName
        origAirbaseGetByName   = Airbase.getByName

        trigger.misc.getZone   = function(_) return nil end
        Unit.getByName         = function(_) return nil end
        StaticObject.getByName = function(_) return nil end
        Group.getByName        = function(_) return nil end
        Airbase.getByName      = function(_) return nil end
    end)

    after_each(function()
        trigger.misc.getZone   = origGetZone
        Unit.getByName         = origUnitGetByName
        StaticObject.getByName = origStaticGetByName
        Group.getByName        = origGroupGetByName
        Airbase.getByName      = origAirbaseGetByName
    end)

    describe("resolving via a Mission Editor trigger zone", function()
        it("creates a pickup zone with the zone's own radius", function()
            trigger.misc.getZone = function(name)
                if name == "myZone" then return fakeZone({ x = 100, y = 0, z = 200 }, 300) end
            end

            local ok = zm:createTroopZoneAtObject("myZone", "TRZ_camp1_B_999_nil_0")

            assert.is_true(ok)
            local zone = zm._troopZones["camp1"]
            assert.is_not_nil(zone)
            assert.is_true(zone:hasPickup())
            assert.equals(coalition.side.BLUE, zone.coalition)
            assert.equals(300, zone.radius)
            assert.equals(100, zone:getCenter().x)
        end)

        it("tracks the trigger zone across two evaluations (Moving Zone)", function()
            local currentPoint = { x = 100, y = 0, z = 200 }
            trigger.misc.getZone = function(name)
                if name == "myZone" then return fakeZone(currentPoint, 300) end
            end

            zm:createTroopZoneAtObject("myZone", "TRZ_camp1_B_999_nil_0")
            local zone = zm._troopZones["camp1"]
            assert.equals(100, zone:getCenter().x)

            currentPoint = { x = 999, y = 0, z = 200 }
            assert.equals(999, zone:getCenter().x)
        end)
    end)

    describe("resolving via a unit", function()
        it("creates a pickup zone anchored to the unit, with the default radius", function()
            local u = fakeUnit({ x = 10, y = 0, z = 20 })
            Unit.getByName = function(name) if name == "Ship-1" then return u end end

            local ok = zm:createTroopZoneAtObject("Ship-1", "TRZ_dock_R_999_nil_0")

            assert.is_true(ok)
            local zone = zm._troopZones["dock"]
            assert.is_not_nil(zone)
            assert.equals(200, zone.radius)
            assert.equals(10, zone:getCenter().x)
        end)

        it("tracks the unit across two evaluations", function()
            local u = fakeUnit({ x = 10, y = 0, z = 20 })
            Unit.getByName = function(_) return u end

            zm:createTroopZoneAtObject("Ship-1", "TRZ_dock_R_999_nil_0")
            local zone = zm._troopZones["dock"]
            assert.equals(10, zone:getCenter().x)

            u._point = { x = 500, y = 0, z = 20 }
            assert.equals(500, zone:getCenter().x)
        end)
    end)

    describe("resolving via a static", function()
        it("creates a pickup zone anchored to the static", function()
            local s = fakeUnit({ x = 1, y = 0, z = 2 })
            StaticObject.getByName = function(name) if name == "Container-1" then return s end end

            local ok = zm:createTroopZoneAtObject("Container-1", "TRZ_depot_A_10_nil_0")

            assert.is_true(ok)
            local zone = zm._troopZones["depot"]
            assert.is_not_nil(zone)
            assert.equals(200, zone.radius)
            assert.equals(10, zone.pickMaxStock)
        end)
    end)

    describe("resolving via a group", function()
        it("creates a pickup zone anchored to the group's first unit", function()
            local u = fakeUnit({ x = 5, y = 0, z = 6 })
            local g = fakeGroup(u)
            Group.getByName = function(name) if name == "Convoy-1" then return g end end

            local ok = zm:createTroopZoneAtObject("Convoy-1", "TRZ_convoy_B_999_nil_0")

            assert.is_true(ok)
            local zone = zm._troopZones["convoy"]
            assert.is_not_nil(zone)
            assert.equals(5, zone:getCenter().x)
        end)
    end)

    describe("resolving via an airbase/FARP", function()
        it("creates a fixed pickup zone at the airbase position (no live tracking)", function()
            local ab = fakeAirbase({ x = 50, y = 0, z = 60 })
            Airbase.getByName = function(name) if name == "FARP Alpha" then return ab end end

            local ok = zm:createTroopZoneAtObject("FARP Alpha", "TRZ_farp1_B_999_nil_0")

            assert.is_true(ok)
            local zone = zm._troopZones["farp1"]
            assert.is_not_nil(zone)
            assert.equals(200, zone.radius)
            assert.equals(50, zone:getCenter().x)

            ab._point = { x = 999, y = 0, z = 60 } -- moving the fake airbase must NOT move the zone
            assert.equals(50, zone:getCenter().x)
        end)
    end)

    describe("failure handling", function()
        it("returns false and registers nothing for a malformed TRZ_ name", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 0, y = 0, z = 0 }, 100) end

            local ok = zm:createTroopZoneAtObject("myZone", "NOT_A_TRZ_NAME")

            assert.is_false(ok)
            assert.is_nil(zm._troopZones["myZone"])
        end)

        it("returns false and registers nothing when the named object can't be resolved", function()
            local ok = zm:createTroopZoneAtObject("Nothing", "TRZ_ghost_B_999_nil_0")

            assert.is_false(ok)
            assert.is_nil(zm._troopZones["ghost"])
        end)

        it("refuses and leaves the existing zone untouched on a duplicate zoneName", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_dup_B_999_nil_0")
            local firstZone = zm._troopZones["dup"]

            local ok = zm:createTroopZoneAtObject("myZone", "TRZ_dup_R_10_nil_0")

            assert.is_false(ok)
            assert.equals(firstZone, zm._troopZones["dup"])
        end)
    end)

    describe("removal and lookup reuse existing methods", function()
        it("removeExtractZone tears down a zone created this way", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_temp_B_999_nil_0")
            assert.is_not_nil(zm._troopZones["temp"])

            zm:removeExtractZone("temp")

            assert.is_nil(zm._troopZones["temp"])
        end)

        it("getTroopZone finds a zone created this way", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_findme_B_999_nil_0")

            assert.equals(zm._troopZones["findme"], zm:getTroopZone("findme"))
        end)
    end)
end)
