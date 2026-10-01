---@diagnostic disable
-- tests/ci/functional/crate_native_list_spec.lua
-- FIX-NATIVE-CARRY-DETECTION ticket 06 -- native crate load and release are read from the DCS
-- on-board cargo list (ADR 0022), not from the aircraft's bounding box, a speed guard or a drift
-- reference. The aircraft double deliberately has no getDesc / getPosition / getVelocity: the old
-- geometric detection would raise on it.
-- ============================================================

describe("CTLDCrateManager native cargo detection (on-board cargo list)", function()

    local cm, pm
    local aircraft, cargoList, listFails, listGets, airborne
    local unloadCalls, scheduled, loaded, unloaded, loadCrateCalls, logs
    local origGs, origGetByName, origInAir, origSchedule, origLog, origSetupPm

    local function cargoObj(name) return { getName = function() return name end } end

    local function makeStatic(name)
        return {
            getName  = function() return name end,
            isExist  = function() return true end,
            getPoint = function() return { x = 5000, y = 0, z = 5000 } end,   -- nowhere near the aircraft
        }
    end

    local function makeCrate(name)
        local crate = CTLDCrate:new({
            crateName   = name,
            descriptor  = { unit = "ammo_cargo", desc = "Ammo", cratesRequired = 1 },
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = { x = 5000, y = 0, z = 5000 },
            coalition   = coalition.side.BLUE,
            dcsStatic   = makeStatic(name),
        })
        cm.crates[name] = crate
        return crate
    end

    local function setType(typeName)
        aircraft.getTypeName = function() return typeName end
    end

    before_each(function()
        listFails, listGets, airborne = false, 0, false
        unloadCalls, scheduled, loaded, unloaded, loadCrateCalls, logs = {}, {}, {}, {}, {}, {}
        cargoList = {}

        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
        EventDispatcher._instance = nil
        pm = CTLDPlayerManager.getInstance()
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}
        cm.refreshUnpackSectionForUnit       = function() end
        cm.refreshCrateFlightSectionForUnit  = function() end
        cm.refreshLoadCrateSection           = function() end
        cm.refreshRequestEquipmentSection    = function() end
        cm.loadCrate = function(_, name) loadCrateCalls[#loadCrateCalls + 1] = name end
        pm.refreshForUnit = function() end

        aircraft = {
            getName         = function() return "nc6_player" end,
            getTypeName     = function() return "Mi-8MT" end,
            isExist         = function() return true end,
            getPoint        = function() return { x = 0, y = 0, z = 0 } end,
            getCargosOnBoard = function()
                listGets = listGets + 1
                if listFails then error("no such function") end
                return cargoList
            end,
            UnloadCargo     = function(_, st) unloadCalls[#unloadCalls + 1] = st:getName() end,
        }
        pm._players["nc6_player"] = { unitName = "nc6_player", groupId = 9901, coalition = coalition.side.BLUE }

        origGetByName = Unit.getByName
        Unit.getByName = function(n) if n == "nc6_player" then return aircraft end end
        origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return {
                    ["Mi-8MT"] = { useNativeDcsCargoSystem = true, convertNativeLoadToCTLD = false },
                    ["UH-1H"]  = { useNativeDcsCargoSystem = true, convertNativeLoadToCTLD = true },
                }
            end
            return origGs(k)
        end
        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return airborne end
        origSchedule = timer.scheduleFunction
        timer.scheduleFunction = function(fn, _, t) scheduled[#scheduled + 1] = { fn = fn, t = t }; return 0 end
        origLog = ctld.utils.log
        ctld.utils.log = function(level, fmt, ...)
            logs[#logs + 1] = { level = level, text = select("#", ...) > 0 and string.format(fmt, ...) or fmt }
        end

        local ed = EventDispatcher.getInstance()
        ed:subscribe("OnCrateLoaded",   function(p) loaded[#loaded + 1] = p end)
        ed:subscribe("OnCrateUnloaded", function(p) unloaded[#unloaded + 1] = p end)
    end)

    after_each(function()
        Unit.getByName          = origGetByName
        ctld.gs                 = origGs
        ctld.utils.inAir        = origInAir
        timer.scheduleFunction  = origSchedule
        ctld.utils.log          = origLog
        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
        EventDispatcher._instance = nil
    end)

    local function count(level, pattern)
        local n = 0
        for _, l in ipairs(logs) do
            if l.level == level and (not pattern or string.find(l.text, pattern, 1, true)) then n = n + 1 end
        end
        return n
    end

    describe("entry", function()

        it("a tracked crate appearing on the list becomes native carry, wherever it is", function()
            local crate = makeCrate("nc6_crate_a")
            cargoList = { cargoObj("nc6_crate_a") }
            cm:_checkNativeDCSCargo()
            assert.is_true(crate:isLoaded())
            assert.is_true(crate.loadedByDCSNative)
            assert.equals(aircraft, crate.loadedBy)
            assert.equals(1, #loaded)
            assert.equals("dcs_native", loaded[1].method)
            assert.equals("nc6_crate_a", loaded[1].crateName)
            assert.equals("nc6_player", loaded[1].carrierUnitName)
        end)

        it("does not load a tracked crate that is not on the list", function()
            local crate = makeCrate("nc6_crate_b")
            cargoList = { cargoObj("something_else") }
            cm:_checkNativeDCSCargo()
            assert.is_false(crate:isLoaded())
            assert.equals(0, #loaded)
        end)

        it("ignores an untracked entry, with one debug trace, and changes no state", function()
            local crate = makeCrate("nc6_crate_c")
            cargoList = { cargoObj("tablet_crate_9") }
            cm:_checkNativeDCSCargo()
            cm:_checkNativeDCSCargo()
            assert.is_false(crate:isLoaded())
            assert.equals(0, #loaded)
            assert.equals(1, count("DEBUG", "tablet_crate_9"))
        end)

        it("leaves a vehicle's CRG: companion entry to the vehicle scan, without a trace", function()
            makeCrate("nc6_crate_d")
            cargoList = { cargoObj("CRG:some_vehicle_unit") }
            cm:_checkNativeDCSCargo()
            assert.equals(0, count("DEBUG"))
            assert.equals(0, #loaded)
        end)

        it("skips an invalid list entry whose name cannot be read, and still loads the valid crate", function()
            local crate = makeCrate("nc6_crate_x")
            cargoList = {
                { getName = function() error("invalid object") end },
                cargoObj("nc6_crate_x"),
            }
            assert.has_no.errors(function() cm:_checkNativeDCSCargo() end)
            assert.is_true(crate:isLoaded())
        end)

        it("returns before reading any list when no crate is tracked", function()
            cm:_checkNativeDCSCargo()
            assert.equals(0, listGets)
        end)

        it("never scans an aircraft that is not a registered player unit", function()
            makeCrate("nc6_crate_e")
            pm._players["nc6_player"] = nil
            cargoList = { cargoObj("nc6_crate_e") }
            cm:_checkNativeDCSCargo()
            assert.equals(0, listGets)
        end)

        it("an unreadable list logs one warning for the type and the type is no longer watched", function()
            local crate = makeCrate("nc6_crate_f")
            listFails = true
            cm:_checkNativeDCSCargo()
            cm:_checkNativeDCSCargo()
            assert.equals(1, count("WARN"))
            assert.equals(1, listGets)
            assert.is_false(crate:isLoaded())
        end)

    end)

    describe("release", function()

        local function loadNative(name)
            local crate = makeCrate(name)
            cargoList = { cargoObj(name) }
            cm:_checkNativeDCSCargo()
            assert.is_true(crate:isLoaded())
            return crate
        end

        it("leaving the list with the transport on the ground: LANDED, OnCrateUnloaded dcs_native", function()
            local crate = loadNative("nc6_crate_g")
            cargoList = {}
            cm:_checkNativeDCSCargo()
            assert.equals(CTLDCrate.STATE.LANDED, crate.state)
            assert.is_nil(crate.loadedBy)
            assert.equals(1, #unloaded)
            assert.equals("dcs_native", unloaded[1].method)
            assert.equals(0, #scheduled)
        end)

        it("leaving the list with the transport airborne: FALLING until it touches the ground", function()
            local crate = loadNative("nc6_crate_h")
            airborne = true
            cargoList = {}
            cm:_checkNativeDCSCargo()
            assert.equals(CTLDCrate.STATE.FALLING, crate.state)
            assert.is_true(crate.fromParachute)
            assert.equals("dcs_native", unloaded[1].method)
            assert.equals(1, #scheduled, "the existing landing poll is scheduled")
        end)

        it("does not release while the crate stays on the list", function()
            local crate = loadNative("nc6_crate_i")
            cm:_checkNativeDCSCargo()
            cm:_checkNativeDCSCargo()
            assert.is_true(crate:isLoaded())
            assert.equals(0, #unloaded)
        end)

        it("releases nothing when the list cannot be read", function()
            local crate = loadNative("nc6_crate_j")
            listFails = true
            cm:_checkNativeDCSCargo()
            assert.is_true(crate:isLoaded())
        end)

        it("transport no longer existing: the crate is reset to the ground", function()
            local crate = loadNative("nc6_crate_k")
            aircraft.isExist = function() return false end
            cm:_checkNativeDCSCargo()
            assert.equals(CTLDCrate.STATE.LANDED, crate.state)
            assert.is_nil(crate.loadedBy)
        end)

    end)

    describe("conversion kept for convertNativeLoadToCTLD types", function()

        it("converts once even though the crate stays listed during the delay", function()
            setType("UH-1H")
            local crate = makeCrate("nc6_crate_l")
            cargoList = { cargoObj("nc6_crate_l") }
            cm:_checkNativeDCSCargo()
            cm:_checkNativeDCSCargo()
            cm:_checkNativeDCSCargo()
            assert.same({ "nc6_crate_l" }, unloadCalls, "the DCS load is released once")
            assert.equals(1, #scheduled, "one delayed CTLD load")
            assert.is_false(crate.loadedByDCSNative)
            assert.equals(0, #loaded, "no native load event: CTLD loads it after the delay")

            scheduled[1].fn()
            assert.same({ "nc6_crate_l" }, loadCrateCalls)
        end)

        it("can be converted again after the delay if it re-enters the list", function()
            setType("UH-1H")
            makeCrate("nc6_crate_m")
            cargoList = { cargoObj("nc6_crate_m") }
            cm:_checkNativeDCSCargo()
            scheduled[1].fn()
            cm:_checkNativeDCSCargo()
            assert.equals(2, #unloadCalls)
        end)

    end)

end)
