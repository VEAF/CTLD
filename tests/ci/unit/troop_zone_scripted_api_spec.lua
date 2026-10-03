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
        CTLDStaticWatcher._instance = nil

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
            local zone = zm._troopZones["TRZ_camp1_B_999_nil_0"]
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
            local zone = zm._troopZones["TRZ_camp1_B_999_nil_0"]
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
            local zone = zm._troopZones["TRZ_dock_R_999_nil_0"]
            assert.is_not_nil(zone)
            assert.equals(200, zone.radius)
            assert.equals(10, zone:getCenter().x)
        end)

        it("tracks the unit across two evaluations", function()
            local u = fakeUnit({ x = 10, y = 0, z = 20 })
            Unit.getByName = function(_) return u end

            zm:createTroopZoneAtObject("Ship-1", "TRZ_dock_R_999_nil_0")
            local zone = zm._troopZones["TRZ_dock_R_999_nil_0"]
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
            local zone = zm._troopZones["TRZ_depot_A_10_nil_0"]
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
            local zone = zm._troopZones["TRZ_convoy_B_999_nil_0"]
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
            local zone = zm._troopZones["TRZ_farp1_B_999_nil_0"]
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
            assert.is_nil(zm._troopZones["NOT_A_TRZ_NAME"])
        end)

        it("returns false and registers nothing when the named object can't be resolved", function()
            local ok = zm:createTroopZoneAtObject("Nothing", "TRZ_ghost_B_999_nil_0")

            assert.is_false(ok)
            assert.is_nil(zm._troopZones["TRZ_ghost_B_999_nil_0"])
        end)

        -- FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY: registration keys on the full trzName string now,
        -- not the parsed short zoneName -- two different full names sharing the same parsed
        -- zoneName ("dup") no longer collide (each gets its own key). Duplicate detection is
        -- exercised here with the exact same trzName called twice instead.
        it("refuses and leaves the existing zone untouched on a duplicate full trzName", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_dup_B_999_nil_0")
            local firstZone = zm._troopZones["TRZ_dup_B_999_nil_0"]

            local ok = zm:createTroopZoneAtObject("myZone", "TRZ_dup_B_999_nil_0")

            assert.is_false(ok)
            assert.equals(firstZone, zm._troopZones["TRZ_dup_B_999_nil_0"])
        end)

        it("two different full names sharing the same parsed zoneName both register", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            local ok1 = zm:createTroopZoneAtObject("myZone", "TRZ_dup_B_999_nil_0")
            local ok2 = zm:createTroopZoneAtObject("myZone", "TRZ_dup_R_10_nil_0")

            assert.is_true(ok1)
            assert.is_true(ok2)
            assert.is_not_nil(zm._troopZones["TRZ_dup_B_999_nil_0"])
            assert.is_not_nil(zm._troopZones["TRZ_dup_R_10_nil_0"])
            assert.are_not.equals(zm._troopZones["TRZ_dup_B_999_nil_0"], zm._troopZones["TRZ_dup_R_10_nil_0"])
        end)
    end)

    describe("removal and lookup reuse existing methods", function()
        it("removeExtractZone tears down a zone created this way", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_temp_B_999_nil_0")
            assert.is_not_nil(zm._troopZones["TRZ_temp_B_999_nil_0"])

            zm:removeExtractZone("TRZ_temp_B_999_nil_0")

            assert.is_nil(zm._troopZones["TRZ_temp_B_999_nil_0"])
        end)

        it("getTroopZone finds a zone created this way", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_findme_B_999_nil_0")

            assert.equals(zm._troopZones["TRZ_findme_B_999_nil_0"], zm:getTroopZone("TRZ_findme_B_999_nil_0"))
        end)
    end)

    describe("createTroopZoneAtObject / removeExtractZone publish OnTroopZoneUpdated", function()

        local function capture(eventName, fn)
            local ed    = EventDispatcher.getInstance()
            local fired = {}
            local cb    = function(p) fired[#fired + 1] = p end
            ed:subscribe(eventName, cb)
            local ok, err = pcall(fn)
            ed:unsubscribe(eventName, cb)
            assert(ok, err)
            return fired
        end

        it("createTroopZoneAtObject publishes on success", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            local fired = capture("OnTroopZoneUpdated", function()
                zm:createTroopZoneAtObject("myZone", "TRZ_evt_B_999_nil_0")
            end)
            assert.equals(1, #fired)
        end)

        it("createTroopZoneAtObject does not publish on failure (unresolvable object)", function()
            local fired = capture("OnTroopZoneUpdated", function()
                zm:createTroopZoneAtObject("nope", "TRZ_evt2_B_999_nil_0")
            end)
            assert.equals(0, #fired)
        end)

        it("removeExtractZone publishes on success", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_evt3_B_999_nil_0")

            local fired = capture("OnTroopZoneUpdated", function()
                zm:removeExtractZone("TRZ_evt3_B_999_nil_0")
            end)
            assert.equals(1, #fired)
        end)

        it("removeExtractZone does not publish when the zone is not found", function()
            local fired = capture("OnTroopZoneUpdated", function()
                zm:removeExtractZone("TRZ_nonexistent_B_999_nil_0")
            end)
            assert.equals(0, #fired)
        end)
    end)

    -- FEAT-TRZ-DYNAMIC-OBJECT-AUTODISCOVERY ticket 02 — anchor-death real removal (ADR 0021).
    describe("anchor-death real removal", function()

        local function capture(eventName, fn)
            local ed    = EventDispatcher.getInstance()
            local fired = {}
            local cb    = function(p) fired[#fired + 1] = p end
            ed:subscribe(eventName, cb)
            local ok, err = pcall(fn)
            ed:unsubscribe(eventName, cb)
            assert(ok, err)
            return fired
        end

        -- ctld.utils.safeObjectName (used by onDead) needs a getName() — fakeUnit doesn't have
        -- one (nothing else in this file's existing tests needs it).
        local function fakeNamedUnit(name, point)
            local u = fakeUnit(point)
            function u:getName() return name end
            return u
        end

        it("removes a unit-anchored zone on a simulated S_EVENT_DEAD for its anchor", function()
            local u = fakeNamedUnit("Ship-1", { x = 10, y = 0, z = 20 })
            Unit.getByName = function(name) if name == "Ship-1" then return u end end
            zm:createTroopZoneAtObject("Ship-1", "TRZ_dock_R_999_nil_0")
            assert.is_not_nil(zm:getTroopZone("TRZ_dock_R_999_nil_0"))

            -- The event engine hands back a DCS object that is not guaranteed to be the one stored
            -- at zone creation: use a distinct object carrying the same name.
            local fired = capture("OnTroopZoneUpdated", function()
                zm:onDead({ initiator = fakeNamedUnit("Ship-1", { x = 10, y = 0, z = 20 }) })
            end)

            assert.is_nil(zm:getTroopZone("TRZ_dock_R_999_nil_0"))
            assert.equals(1, #fired)
        end)

        it("removes a group-anchored zone on a simulated S_EVENT_DEAD for its first unit", function()
            local firstUnit = fakeNamedUnit("Convoy-1-lead", { x = 5, y = 0, z = 5 })
            local g = fakeGroup(firstUnit)
            Group.getByName = function(name) if name == "Convoy-1" then return g end end
            zm:createTroopZoneAtObject("Convoy-1", "TRZ_convoy_B_999_nil_0")
            assert.is_not_nil(zm:getTroopZone("TRZ_convoy_B_999_nil_0"))

            zm:onDead({ initiator = fakeNamedUnit("Convoy-1-lead", { x = 5, y = 0, z = 5 }) })

            assert.is_nil(zm:getTroopZone("TRZ_convoy_B_999_nil_0"))
        end)

        it("onDead ignores a zone anchored to a different, still-alive unit", function()
            local u1 = fakeNamedUnit("Truck-1", { x = 1, y = 0, z = 1 })
            local u2 = fakeNamedUnit("SomeOtherUnit", { x = 2, y = 0, z = 2 })
            Unit.getByName = function(name) if name == "Truck-1" then return u1 end end
            zm:createTroopZoneAtObject("Truck-1", "TRZ_truck_B_999_nil_0")

            zm:onDead({ initiator = u2 })

            assert.is_not_nil(zm:getTroopZone("TRZ_truck_B_999_nil_0"))
        end)

        it("does not touch a fixed-position zone (trigger zone) on any S_EVENT_DEAD", function()
            trigger.misc.getZone = function(_) return fakeZone({ x = 1, y = 0, z = 1 }, 100) end
            zm:createTroopZoneAtObject("myZone", "TRZ_fixed_B_999_nil_0")
            local unrelated = fakeNamedUnit("SomeUnit", { x = 0, y = 0, z = 0 })

            assert.has_no_error(function() zm:onDead({ initiator = unrelated }) end)
            assert.is_not_nil(zm:getTroopZone("TRZ_fixed_B_999_nil_0"))
        end)

        it("removes a static-anchored zone once CTLDStaticWatcher detects it gone", function()
            local s = fakeUnit({ x = 30, y = 0, z = 40 })
            StaticObject.getByName = function(name) if name == "Bunker-1" then return s end end
            zm:createTroopZoneAtObject("Bunker-1", "TRZ_bunker_B_999_nil_0")
            assert.is_not_nil(zm:getTroopZone("TRZ_bunker_B_999_nil_0"))

            s._exists = false
            function s:isExist() return self._exists end

            local fired = capture("OnTroopZoneUpdated", function()
                CTLDStaticWatcher.getInstance():_tick(0)
            end)

            assert.is_nil(zm:getTroopZone("TRZ_bunker_B_999_nil_0"))
            assert.equals(1, #fired)
        end)

        it("does not watch a unit anchor via CTLDStaticWatcher (S_EVENT_DEAD handles it)", function()
            local u = fakeUnit({ x = 1, y = 0, z = 1 })
            Unit.getByName = function(name) if name == "Truck-2" then return u end end
            zm:createTroopZoneAtObject("Truck-2", "TRZ_truck2_B_999_nil_0")

            local sw = CTLDStaticWatcher.getInstance()
            local watching = false
            for id in pairs(sw._watched) do
                if id == "trz_static_TRZ_truck2_B_999_nil_0" then watching = true end
            end
            assert.is_false(watching)
        end)
    end)
end)
