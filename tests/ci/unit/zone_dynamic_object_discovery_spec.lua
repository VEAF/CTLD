---@diagnostic disable
-- tests/ci/unit/zone_dynamic_object_discovery_spec.lua
-- FEAT-TRZ-DYNAMIC-OBJECT-AUTODISCOVERY ticket 03 — TRZ_<...> auto-discovery on a static, unit,
-- or group: continuous (init scan + S_EVENT_BIRTH), reusing createTroopZoneAtObject's own
-- resolution/construction unchanged (see CTLDZoneManager:_discoverTRZDynamicObjects / :onBirth).
-- ============================================================

describe("CTLDZoneManager — TRZ_ dynamic-object discovery", function()

    local zm
    local origGetStatics, origGetGroups
    local origUnitGetByName, origStaticGetByName, origGroupGetByName, origGetZone

    local function fakeObj(name, point)
        local o = { _point = point or { x = 0, y = 0, z = 0 }, _exists = true }
        function o:getName()  return name end
        function o:getPoint() return self._point end
        function o:isExist()  return self._exists end
        return o
    end

    -- A fake group: getUnits() for _forEachMissionUnit's own iteration, getUnit(1) for the
    -- "first unit" anchor/guard logic, no getGroup() on its members needed here (set per-unit
    -- below when a birth-event test needs it).
    local function fakeGroupObj(name, units)
        local g = { _exists = true, _units = units }
        function g:getName()  return name end
        function g:isExist()  return self._exists end
        function g:getUnits() return self._units end
        function g:getUnit(i) return self._units[i] end
        return g
    end

    before_each(function()
        zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)

        origGetStatics       = coalition.getStaticObjects
        origGetGroups        = coalition.getGroups
        origUnitGetByName    = Unit.getByName
        origStaticGetByName  = StaticObject.getByName
        origGroupGetByName   = Group.getByName
        origGetZone          = trigger.misc.getZone

        coalition.getStaticObjects = function(_side) return {} end
        coalition.getGroups        = function(_side) return {} end
        Unit.getByName              = function(_) return nil end
        StaticObject.getByName      = function(_) return nil end
        Group.getByName             = function(_) return nil end
        trigger.misc.getZone        = function(_) return nil end
    end)

    after_each(function()
        coalition.getStaticObjects = origGetStatics
        coalition.getGroups        = origGetGroups
        Unit.getByName              = origUnitGetByName
        StaticObject.getByName      = origStaticGetByName
        Group.getByName             = origGroupGetByName
        trigger.misc.getZone        = origGetZone
    end)

    describe("_discoverTRZDynamicObjects (init scan)", function()

        it("registers a static named TRZ_...", function()
            local s = fakeObj("TRZ_bunker1_B_999_nil_0", { x = 10, y = 0, z = 20 })
            coalition.getStaticObjects = function(_side) return { s } end
            StaticObject.getByName     = function(name) if name == s:getName() then return s end end

            zm:_discoverTRZDynamicObjects()

            local zone = zm:getTroopZone("TRZ_bunker1_B_999_nil_0")
            assert.is_not_nil(zone)
            assert.is_true(zone:hasPickup())
        end)

        it("registers an isolated unit named TRZ_...", function()
            local u = fakeObj("TRZ_dock_R_999_nil_0", { x = 1, y = 0, z = 1 })
            local g = fakeGroupObj("SomeGroupName", { u })
            coalition.getGroups   = function(_side) return { g } end
            Unit.getByName        = function(name) if name == u:getName() then return u end end

            zm:_discoverTRZDynamicObjects()

            assert.is_not_nil(zm:getTroopZone("TRZ_dock_R_999_nil_0"))
        end)

        it("registers a group named TRZ_... exactly once, not once per member unit", function()
            local u1 = fakeObj("Truck-1", { x = 1, y = 0, z = 1 })
            local u2 = fakeObj("Truck-2", { x = 2, y = 0, z = 2 })
            local g  = fakeGroupObj("TRZ_convoy_B_999_nil_0", { u1, u2 })
            coalition.getGroups = function(_side) return { g } end
            Group.getByName     = function(name) if name == g:getName() then return g end end

            zm:_discoverTRZDynamicObjects()

            local count = 0
            for name in pairs(zm._troopZones) do
                if name == "TRZ_convoy_B_999_nil_0" then count = count + 1 end
            end
            assert.equals(1, count)
        end)

        it("skips a malformed TRZ_ name (logged, no crash, nothing registered)", function()
            local s = fakeObj("TRZ_bad", { x = 0, y = 0, z = 0 })   -- missing required fields
            coalition.getStaticObjects = function(_side) return { s } end
            StaticObject.getByName     = function(name) if name == s:getName() then return s end end

            assert.has_no_error(function() zm:_discoverTRZDynamicObjects() end)
            assert.is_nil(zm:getTroopZone("TRZ_bad"))
        end)

        it("refuses a name colliding with an already-registered zone, leaves the original untouched", function()
            trigger.misc.getZone = function(name)
                if name == "TRZ_dup_B_999_nil_0" then return { point = { x = 1, y = 0, z = 1 }, radius = 100 } end
            end
            zm:createTroopZoneAtObject("TRZ_dup_B_999_nil_0", "TRZ_dup_B_999_nil_0")
            local original = zm:getTroopZone("TRZ_dup_B_999_nil_0")
            assert.is_not_nil(original)

            local s = fakeObj("TRZ_dup_B_999_nil_0", { x = 99, y = 0, z = 99 })
            coalition.getStaticObjects = function(_side) return { s } end
            StaticObject.getByName     = function(name) if name == s:getName() then return s end end

            zm:_discoverTRZDynamicObjects()

            assert.equals(original, zm:getTroopZone("TRZ_dup_B_999_nil_0"))
        end)

        it("ignores an object whose name doesn't start with TRZ_", function()
            local s = fakeObj("SomeRandomBunker", { x = 0, y = 0, z = 0 })
            coalition.getStaticObjects = function(_side) return { s } end

            zm:_discoverTRZDynamicObjects()

            local count = 0
            for _ in pairs(zm._troopZones) do count = count + 1 end
            assert.equals(0, count)
        end)

    end)

    describe("onBirth (late activation)", function()

        it("registers a late-born static named TRZ_...", function()
            local s = fakeObj("TRZ_farpalt_B_999_nil_0", { x = 5, y = 0, z = 5 })
            StaticObject.getByName = function(name) if name == s:getName() then return s end end

            zm:onBirth({ initiator = s })

            assert.is_not_nil(zm:getTroopZone("TRZ_farpalt_B_999_nil_0"))
        end)

        it("registers a late-born isolated unit named TRZ_...", function()
            local u = fakeObj("TRZ_ship2_R_999_nil_0", { x = 1, y = 0, z = 1 })
            Unit.getByName = function(name) if name == u:getName() then return u end end

            zm:onBirth({ initiator = u })

            assert.is_not_nil(zm:getTroopZone("TRZ_ship2_R_999_nil_0"))
        end)

        it("registers a late-born group's name exactly once via its first unit's birth", function()
            local u1 = fakeObj("Convoy2-lead", { x = 1, y = 0, z = 1 })
            local u2 = fakeObj("Convoy2-2nd", { x = 2, y = 0, z = 2 })
            local g  = fakeGroupObj("TRZ_convoy2_B_999_nil_0", { u1, u2 })
            function u1:getGroup() return g end
            function u2:getGroup() return g end
            Group.getByName = function(name) if name == g:getName() then return g end end

            zm:onBirth({ initiator = u1 })
            zm:onBirth({ initiator = u2 })   -- not the group's first unit: must not re-attempt

            local count = 0
            for name in pairs(zm._troopZones) do
                if name == "TRZ_convoy2_B_999_nil_0" then count = count + 1 end
            end
            assert.equals(1, count)
        end)

        it("does nothing for a dead (not isExist) initiator", function()
            local s = fakeObj("TRZ_gone_B_999_nil_0", { x = 0, y = 0, z = 0 })
            s._exists = false

            assert.has_no_error(function() zm:onBirth({ initiator = s }) end)
            assert.is_nil(zm:getTroopZone("TRZ_gone_B_999_nil_0"))
        end)

    end)

end)
