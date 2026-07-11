---@diagnostic disable
-- tests/ci/unit/legacy_api_spec.lua
-- busted specs for the CTLD v1→v2 legacy API wrappers (src/legacy/legacy_api.lua).
-- Each wrapper must (a) route to the correct v2 manager method with args preserved,
-- and (b) log a DEPRECATED warning. Re-integrates the dead FullGas relics
-- F-094 (Troops), F-095 (Zones), F-096 (Crates), F-097 (Beacon), F-098 (JTAC).
-- ============================================================

describe("legacy API wrappers", function()

    local origWarn, warns

    before_each(function()
        origWarn = ctld.logWarning
        warns    = {}
        ctld.logWarning = function(m) warns[#warns + 1] = tostring(m) end
    end)

    after_each(function()
        ctld.logWarning = origWarn
    end)

    local function warnedDeprecated()
        for _, m in ipairs(warns) do
            if m:find("DEPRECATED", 1, true) then return true end
        end
        return false
    end

    -- Assert that calling wrapperFn() routes exactly once to instance[method] with `expected`
    -- args (positional), the routing target actually exists, and a DEPRECATED warning fired.
    local function assertRoute(instanceFn, method, wrapperFn, expected)
        local inst = instanceFn()
        assert.is_function(inst[method])          -- routing target must exist on the manager
        local orig  = inst[method]
        local calls = {}
        inst[method] = function(self, ...) calls[#calls + 1] = { ... }; return true end
        wrapperFn()
        inst[method] = orig
        assert.equals(1, #calls)
        for i, v in ipairs(expected) do
            assert.equals(v, calls[1][i])
        end
        assert.is_true(warnedDeprecated())
    end

    local function troop() return CTLDTroopManager.getInstance() end
    local function zone()  return CTLDZoneManager.getInstance()  end
    local function crate() return CTLDCrateManager.getInstance() end
    local function beacon()return CTLDBeaconManager.getInstance()end
    local function jtac()  return CTLDJTACManager.getInstance()  end

    -- ── F-094 : Troops / Transport ────────────────────────────────────────────
    describe("Troops / Transport (F-094)", function()

        it("spawnGroupAtTrigger → CTLDTroopManager:spawnGroupAtTrigger", function()
            assertRoute(troop, "spawnGroupAtTrigger",
                function() ctld.spawnGroupAtTrigger(2, 3, "trig", 100) end, { 2, 3, "trig", 100 })
        end)

        it("spawnGroupAtPoint → CTLDTroopManager:spawnGroupAtPoint", function()
            local pt = { x = 1, y = 0, z = 2 }
            assertRoute(troop, "spawnGroupAtPoint",
                function() ctld.spawnGroupAtPoint(2, 3, pt, 100) end, { 2, 3, pt, 100 })
        end)

        it("preLoadTransport → CTLDTroopManager:preLoadTransport", function()
            assertRoute(troop, "preLoadTransport",
                function() ctld.preLoadTransport("u1", 5, "troops") end, { "u1", 5, "troops" })
        end)

        it("unloadTransport → CTLDTroopManager:unloadTransport", function()
            assertRoute(troop, "unloadTransport",
                function() ctld.unloadTransport("u1") end, { "u1" })
        end)

        it("loadTransport → CTLDTroopManager:loadTransport", function()
            assertRoute(troop, "loadTransport",
                function() ctld.loadTransport("u1") end, { "u1" })
        end)

        it("unloadInProximityToEnemy → CTLDTroopManager:unloadInProximityToEnemy", function()
            assertRoute(troop, "unloadInProximityToEnemy",
                function() ctld.unloadInProximityToEnemy("u1", 500) end, { "u1", 500 })
        end)

    end)

    -- ── F-095 : Zones (+ dropped-count watchers, routed to the troop manager) ──
    describe("Zones (F-095)", function()

        it("activatePickupZone → setTroopZoneActive(name, true)", function()
            assertRoute(zone, "setTroopZoneActive",
                function() ctld.activatePickupZone("Z1") end, { "Z1", true })
        end)

        it("deactivatePickupZone → setTroopZoneActive(name, false)", function()
            assertRoute(zone, "setTroopZoneActive",
                function() ctld.deactivatePickupZone("Z1") end, { "Z1", false })
        end)

        it("changeRemainingGroupsForPickupZone → changeRemainingGroups", function()
            assertRoute(zone, "changeRemainingGroups",
                function() ctld.changeRemainingGroupsForPickupZone("Z1", -2) end, { "Z1", -2 })
        end)

        it("activateWaypointZone → activateWaypointZone", function()
            assertRoute(zone, "activateWaypointZone",
                function() ctld.activateWaypointZone("W1") end, { "W1" })
        end)

        it("deactivateWaypointZone → deactivateWaypointZone", function()
            assertRoute(zone, "deactivateWaypointZone",
                function() ctld.deactivateWaypointZone("W1") end, { "W1" })
        end)

        it("createExtractZone → createExtractZone", function()
            assertRoute(zone, "createExtractZone",
                function() ctld.createExtractZone("E1", 7, "green") end, { "E1", 7, "green" })
        end)

        it("removeExtractZone → removeExtractZone", function()
            assertRoute(zone, "removeExtractZone",
                function() ctld.removeExtractZone("E1", 7) end, { "E1", 7 })
        end)

        it("countDroppedGroupsInZone → CTLDTroopManager:startGroupCountWatcher", function()
            assertRoute(troop, "startGroupCountWatcher",
                function() ctld.countDroppedGroupsInZone("Z1", 10, 11) end, { "Z1", 10, 11 })
        end)

        it("countDroppedUnitsInZone → CTLDTroopManager:startUnitCountWatcher", function()
            assertRoute(troop, "startUnitCountWatcher",
                function() ctld.countDroppedUnitsInZone("Z1", 10, 11) end, { "Z1", 10, 11 })
        end)

    end)

    -- ── F-096 : Crates ────────────────────────────────────────────────────────
    describe("Crates (F-096)", function()

        it("spawnCrateAtZone → CTLDCrateManager:spawnCrateAtZone", function()
            assertRoute(crate, "spawnCrateAtZone",
                function() ctld.spawnCrateAtZone(2, 500, "Z1") end, { 2, 500, "Z1" })
        end)

        it("spawnCrateAtPoint → CTLDCrateManager:spawnCrateAtPoint", function()
            local pt = { x = 1, y = 0, z = 2 }
            assertRoute(crate, "spawnCrateAtPoint",
                function() ctld.spawnCrateAtPoint(2, 500, pt, 180) end, { 2, 500, pt, 180 })
        end)

        it("cratesInZone → CTLDCrateManager:startCrateCountWatcher", function()
            assertRoute(crate, "startCrateCountWatcher",
                function() ctld.cratesInZone("Z1", 12) end, { "Z1", 12 })
        end)

    end)

    -- ── F-097 : Beacon ────────────────────────────────────────────────────────
    describe("Beacon (F-097)", function()

        it("createRadioBeaconAtZone → CTLDBeaconManager:createAtZone", function()
            assertRoute(beacon, "createAtZone",
                function() ctld.createRadioBeaconAtZone("Z1", 2, 3600, "B1") end,
                { "Z1", 2, 3600, "B1" })
        end)

    end)

    -- ── F-098 : JTAC ──────────────────────────────────────────────────────────
    describe("JTAC (F-098)", function()

        it("JTACAutoLase → CTLDJTACManager:autoLase", function()
            assertRoute(jtac, "autoLase",
                function() ctld.JTACAutoLase("J1", 1688, true, false, "red", 30) end,
                { "J1", 1688, true, false, "red", 30 })
        end)

        it("JTACStart → CTLDJTACManager:startLase", function()
            assertRoute(jtac, "startLase",
                function() ctld.JTACStart("J1", 1688, true, false, "red", 30) end,
                { "J1", 1688, true, false, "red", 30 })
        end)

        it("JTACAutoLaseStop → CTLDJTACManager:stopAutoLase", function()
            assertRoute(jtac, "stopAutoLase",
                function() ctld.JTACAutoLaseStop("J1") end, { "J1" })
        end)

    end)

end)
