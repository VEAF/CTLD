---@diagnostic disable
-- tests/functional/vehicle_spec.lua
-- busted specs for CTLDVehicleSpawner
-- Reference: live_tests/functional/F-120, F-121, F-122, F-123
-- ============================================================

local function makeTransport(name)
    name = name or "UH-1H-T"
    return {
        _name    = name,
        getName      = function(self) return self._name end,
        getTypeName  = function(self) return "UH-1H" end,
        getCoalition = function(self) return coalition.side.BLUE end,
        getPoint     = function(self) return { x=0, y=10, z=0 } end,
        getPosition  = function(self) return { x={x=1,y=0,z=0}, p={x=0,y=10,z=0} } end,
        getGroup     = function(self) return { getID = function() return 9901 end } end,
        isExist      = function(self) return true end,
    }
end

local function makeVehicleUnit(name, x, z)
    return {
        _name      = name,
        _destroyed = false,
        getName      = function(self) return self._name end,
        isExist      = function(self) return true end,
        getPoint     = function(self) return { x = x or 10, y = 0, z = z or 10 } end,
        getCoalition = function(self) return coalition.side.BLUE end,
        getCountry   = function(self) return 2 end,
        destroy      = function(self) self._destroyed = true end,
    }
end

describe("CTLDVehicleSpawner", function()

    local vs
    local _origGs
    local mockTransport

    before_each(function()
        -- Reset singletons
        CTLDVehicleSpawner._instance  = nil
        CTLDPlayerManager._instance   = nil
        CTLDJTACManager._instance     = nil
        CTLDCrateManager._instance    = nil
        EventDispatcher._instance     = nil
        ctld.MenuManager._instance    = nil
        _cmInstance                   = nil

        _origGs = ctld.gs
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return {
                    ["UH-1H"] = {
                        canTransportWholeVehicle = true,
                        maxWholeVehiclesOnboard  = 1,
                        loadableVehiclesBLUE     = { "M1045 HMMWV TOW" },
                        loadableVehiclesRED      = {},
                        troopsEnabled            = false,
                    }
                }
            end
            if k == "maximumDistancePackableUnitsSearch" then return 200 end
            if k == "nbLimitSpawnedTroops"               then return { 0, 0 } end
            if k == "JTAC_dropEnabled"                   then return true end
            return _origGs(k)
        end

        vs            = CTLDVehicleSpawner.getInstance()
        mockTransport = makeTransport("UH-1H-T")
    end)

    after_each(function()
        ctld.gs = _origGs
    end)

    -- ── F-120 : findLoadableVehicles + loadVehicle ───────────────────────────────
    describe("F-120 — findLoadableVehicles + loadVehicle menu_ctld", function()

        it("U-01: empty when no WAITING vehicles", function()
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(0, #r)
        end)

        it("U-02: finds WAITING vehicle in range", function()
            local u = makeVehicleUnit("f120_u", 10, 10)
            local veh = CTLDVehicle:new({
                id = "f120_v", vehicleType = "M1045 HMMWV TOW", unit = u,
                spawnData = { groupName="f120_v", unitName="f120_u",
                              vehicleType="M1045 HMMWV TOW", countryId=2, coalitionId=2 },
            })
            vs._vehicles["f120_v"]         = veh
            vs._unitToVehicle["f120_u"]    = "f120_v"
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(1, #r)
            assert.equals("M1045 HMMWV TOW", r[1].vehicleType)
            vs._vehicles["f120_v"]      = nil
            vs._unitToVehicle["f120_u"] = nil
        end)

        it("U-03: out-of-range vehicle excluded", function()
            local uNear = makeVehicleUnit("f120_near", 10, 10)
            local uFar  = makeVehicleUnit("f120_far", 9999, 0)
            local vNear = CTLDVehicle:new({
                id="f120_n", vehicleType="M1045 HMMWV TOW", unit=uNear,
                spawnData={groupName="f120_n",unitName="f120_near",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            local vFar = CTLDVehicle:new({
                id="f120_f", vehicleType="M1045 HMMWV TOW", unit=uFar,
                spawnData={groupName="f120_f",unitName="f120_far",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_n"] = vNear
            vs._vehicles["f120_f"] = vFar
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(1, #r)
            vs._vehicles["f120_n"] = nil
            vs._vehicles["f120_f"] = nil
        end)

        it("F-01: loadVehicle → state LOADED", function()
            local u = makeVehicleUnit("f120_lu", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_lv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_lv",unitName="f120_lu",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_lv"]         = veh
            vs._unitToVehicle["f120_lu"]    = "f120_lv"
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
            vs._vehicles["f120_lv"] = nil
        end)

        it("F-01: loadVehicle → unit destroyed", function()
            local u = makeVehicleUnit("f120_du", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_dv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_dv",unitName="f120_du",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_dv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.is_true(u._destroyed)
            vs._vehicles["f120_dv"] = nil
        end)

        it("F-01: loadVehicle → loadTransportName set", function()
            local u = makeVehicleUnit("f120_tn", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_tv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_tv",unitName="f120_tn",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_tv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals(mockTransport:getName(), veh.loadTransportName)
            vs._vehicles["f120_tv"] = nil
        end)

        it("F-01: loadVehicle → loadMethod == 'menu_ctld'", function()
            local u = makeVehicleUnit("f120_mu", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_mv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_mv",unitName="f120_mu",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_mv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals("menu_ctld", veh.loadMethod)
            vs._vehicles["f120_mv"] = nil
        end)

        it("U-04: LOADED vehicle no longer in findLoadableVehicles", function()
            local u = makeVehicleUnit("f120_xu", 10, 10)
            local veh = CTLDVehicle:new({
                id="f120_xv", vehicleType="M1045 HMMWV TOW", unit=u,
                spawnData={groupName="f120_xv",unitName="f120_xu",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            vs._vehicles["f120_xv"] = veh
            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            local r = vs:findLoadableVehicles(mockTransport)
            assert.equals(0, #r)
            vs._vehicles["f120_xv"] = nil
        end)

    end)

    -- ── F-121 : findLoadedVehicles + unloadVehicle ───────────────────────────────
    describe("F-121 — findLoadedVehicles + unloadVehicle menu_ctld", function()

        local _origDynAdd

        before_each(function()
            _origDynAdd = ctld.utils.dynAdd
            ctld.utils.dynAdd = function(_, data)
                return { name = data and data.name or "f121_grp" }
            end
        end)

        after_each(function()
            ctld.utils.dynAdd = _origDynAdd
        end)

        it("U-05: findLoadedVehicles returns vehicle on this transport", function()
            local veh = CTLDVehicle:new({
                id="f121_v1", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_v1",unitName="f121_v1",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            vs._vehicles["f121_v1"] = veh
            local r = vs:findLoadedVehicles(mockTransport)
            assert.equals(1, #r)
            assert.equals("M1045 HMMWV TOW", r[1].vehicleType)
            vs._vehicles["f121_v1"] = nil
        end)

        it("U-06: vehicle on other transport not returned", function()
            local veh = CTLDVehicle:new({
                id="f121_v2", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_v2",unitName="f121_v2",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = "some_other_aircraft"
            vs._vehicles["f121_v2"] = veh
            local r = vs:findLoadedVehicles(mockTransport)
            assert.equals(0, #r)
            vs._vehicles["f121_v2"] = nil
        end)

        it("F-02: unloadVehicle → state WAITING", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "f121_u" then
                    return { getUnit = function(_)
                        return { getName=function() return "f121_u_unit" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local veh = CTLDVehicle:new({
                id="f121_u", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_u",unitName="f121_u_unit",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f121_u"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())

            Group.getByName = _origGetByName
            vs._vehicles["f121_u"] = nil
        end)

        it("F-02: unloadVehicle → dynAdd called", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "f121_d" then
                    return { getUnit = function(_)
                        return { getName=function() return "f121_d_unit" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local called = false
            ctld.utils.dynAdd = function(_, data)
                called = true
                return { name = data and data.name or "f121_d" }
            end

            local veh = CTLDVehicle:new({
                id="f121_d", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_d",unitName="f121_d_unit",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f121_d"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            assert.is_true(called)

            Group.getByName = _origGetByName
            vs._vehicles["f121_d"] = nil
        end)

        it("U-07: findLoadedVehicles empty after unload", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "f121_e" then
                    return { getUnit = function(_)
                        return { getName=function() return "f121_e_unit" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local veh = CTLDVehicle:new({
                id="f121_e", vehicleType="M1045 HMMWV TOW", unit=nil,
                spawnData={groupName="f121_e",unitName="f121_e_unit",
                           vehicleType="M1045 HMMWV TOW",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f121_e"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")
            local r = vs:findLoadedVehicles(mockTransport)
            assert.equals(0, #r)

            Group.getByName = _origGetByName
            vs._vehicles["f121_e"] = nil
        end)

    end)

    -- ── F-122 : JTAC lifecycle on load/unload ────────────────────────────────────
    describe("F-122 — JTAC lifecycle on loadVehicle / unloadVehicle", function()

        local _origDynAdd

        before_each(function()
            _origDynAdd = ctld.utils.dynAdd
            ctld.utils.dynAdd = function(_, data)
                return { name = data and data.name or "f122_grp" }
            end
        end)

        after_each(function()
            ctld.utils.dynAdd = _origDynAdd
        end)

        it("F-03: loadVehicle → setJTACInTransit called with correct group name", function()
            local jm = CTLDJTACManager.get()
            local transitCalls = {}
            local _origSet = jm.setJTACInTransit
            jm.setJTACInTransit = function(_, gName, _) table.insert(transitCalls, gName) end

            local u = makeVehicleUnit("f122_u", 5, 5)
            local veh = CTLDVehicle:new({
                id="f122_v", vehicleType="Soldier M249", unit=u,
                spawnData={groupName="F122_JTAC_GRP",unitName="f122_u",
                           vehicleType="Soldier M249",countryId=2,coalitionId=2},
            })
            vs._vehicles["f122_v"]        = veh
            vs._unitToVehicle["f122_u"]   = "f122_v"

            vs:loadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")

            assert.equals(1, #transitCalls)
            assert.equals("F122_JTAC_GRP", transitCalls[1])

            jm.setJTACInTransit = _origSet
            vs._vehicles["f122_v"] = nil
        end)

        it("F-04: unloadVehicle → resumeJTAC called with correct group name", function()
            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "F122_JTAC_GRP2" then
                    return { getUnit = function(_)
                        return { getName=function() return "f122_u2" end,
                                 isExist=function() return true end } end }
                end
                return _origGetByName(name)
            end

            local jm = CTLDJTACManager.get()
            local resumeCalls = {}
            local _origResume = jm.resumeJTAC
            jm.resumeJTAC = function(_, gName) table.insert(resumeCalls, gName) end

            local veh = CTLDVehicle:new({
                id="f122_v2", vehicleType="Soldier M249", unit=nil,
                spawnData={groupName="F122_JTAC_GRP2",unitName="f122_u2",
                           vehicleType="Soldier M249",countryId=2,coalitionId=2},
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = "menu_ctld"
            vs._vehicles["f122_v2"] = veh

            vs:unloadVehicle(veh, mockTransport, mockTransport:getName(), "menu_ctld")

            assert.equals(1, #resumeCalls)
            assert.equals("F122_JTAC_GRP2", resumeCalls[1])

            jm.resumeJTAC   = _origResume
            Group.getByName = _origGetByName
            vs._vehicles["f122_v2"] = nil
        end)

    end)

    -- ── F-123 : _dispatchPostSpawn registers non-JTAC GROUND vehicle ─────────────
    describe("F-123 — _spawnUnpacked registers non-JTAC GROUND vehicle", function()

        it("F-05: vehicle count increases after _spawnUnpacked (GROUND, non-JTAC)", function()
            local mgr  = CTLDCrateManager.getInstance()
            local tPos = mockTransport:getPoint()

            local countBefore = 0
            for _ in pairs(vs._vehicles) do countBefore = countBefore + 1 end

            local _origSpawn = ctld.utils.spawnFromDescriptor
            ctld.utils.spawnFromDescriptor = function() return true, nil end

            local _origUniqId = ctld.utils.getNextUniqId
            local _callCount  = 0
            ctld.utils.getNextUniqId = function()
                _callCount = _callCount + 1
                if _callCount == 1 then return 9900 end  -- gid
                if _callCount == 2 then return 9901 end  -- uid → CTLD_UNP_9901
                return _origUniqId()
            end

            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "CTLD_UNP_9901" then
                    return { getUnit = function(_)
                        return {
                            getName      = function() return "CTLD_UNP_9901_u" end,
                            isExist      = function() return true end,
                            getCoalition = function() return coalition.side.BLUE end,
                            getCountry   = function() return 2 end,
                            getPoint     = function() return tPos end,
                        } end }
                end
                return _origGetByName(name)
            end

            local fakeDesc = {
                unit = "M1045 HMMWV TOW", desc = "HMMWV TOW",
                spawnAs = "GROUND", isJTAC = false, cratesRequired = 1,
            }
            mgr:_spawnUnpacked(fakeDesc, tPos, coalition.side.BLUE, 2)

            local countAfter = 0
            for _ in pairs(vs._vehicles) do countAfter = countAfter + 1 end
            assert.equals(countBefore + 1, countAfter)

            -- Cleanup
            ctld.utils.spawnFromDescriptor = _origSpawn
            ctld.utils.getNextUniqId       = _origUniqId
            Group.getByName                = _origGetByName
            for id, v in pairs(vs._vehicles) do
                if v.vehicleType == "M1045 HMMWV TOW" then vs._vehicles[id] = nil end
            end
        end)

        it("U-08: findLoadableVehicles finds the unpack'd vehicle", function()
            local mgr  = CTLDCrateManager.getInstance()
            local tPos = { x = 5, y = 0, z = 5 }

            local _origSpawn = ctld.utils.spawnFromDescriptor
            ctld.utils.spawnFromDescriptor = function() return true, nil end

            local _origUniqId = ctld.utils.getNextUniqId
            local _callCount  = 0
            ctld.utils.getNextUniqId = function()
                _callCount = _callCount + 1
                if _callCount == 1 then return 9800 end
                if _callCount == 2 then return 9801 end  -- → CTLD_UNP_9801
                return _origUniqId()
            end

            local _origGetByName = Group.getByName
            Group.getByName = function(name)
                if name == "CTLD_UNP_9801" then
                    return { getUnit = function(_)
                        return {
                            getName      = function() return "CTLD_UNP_9801_u" end,
                            isExist      = function() return true end,
                            getCoalition = function() return coalition.side.BLUE end,
                            getCountry   = function() return 2 end,
                            getPoint     = function() return tPos end,
                        } end }
                end
                return _origGetByName(name)
            end

            local fakeDesc = {
                unit = "M1045 HMMWV TOW", desc = "HMMWV TOW",
                spawnAs = "GROUND", isJTAC = false, cratesRequired = 1,
            }
            mgr:_spawnUnpacked(fakeDesc, tPos, coalition.side.BLUE, 2)

            -- Unit at tPos = {x=5,y=0,z=5}, transport at {x=0,y=10,z=0} → dist≈7m ≤200
            local near  = vs:findLoadableVehicles(makeTransport("UH-1H-T2"))
            local found = false
            for _, v in ipairs(near) do
                if v.vehicleType == "M1045 HMMWV TOW" then found = true end
            end
            assert.is_true(found)

            -- Cleanup
            ctld.utils.spawnFromDescriptor = _origSpawn
            ctld.utils.getNextUniqId       = _origUniqId
            Group.getByName                = _origGetByName
            for id, v in pairs(vs._vehicles) do
                if v.vehicleType == "M1045 HMMWV TOW" then vs._vehicles[id] = nil end
            end
        end)

    end)

    -- ── FIX-NATIVE-CARRY-DETECTION ticket 01 : F10 unload / parachute lists ──────
    describe("findVirtualCarryVehicles — F10 unload and parachute lists", function()

        local function loadedVehicle(id, method)
            local veh = CTLDVehicle:new({
                id = id, vehicleType = "M1045 HMMWV TOW", unit = nil,
                spawnData = { groupName = id, unitName = id,
                              vehicleType = "M1045 HMMWV TOW", countryId = 2, coalitionId = 2 },
            })
            veh:setState(CTLDVehicle.STATE.LOADED)
            veh.loadTransportName = mockTransport:getName()
            veh.loadMethod        = method
            vs._vehicles[id]      = veh
            return veh
        end

        it("lists nothing when only a native-carry vehicle is aboard", function()
            loadedVehicle("nc1_native", "dcs_native")
            assert.equals(0, #vs:findVirtualCarryVehicles(mockTransport))
        end)

        it("lists a virtual-carry vehicle", function()
            local virt = loadedVehicle("nc1_virtual", "menu_ctld")
            local r = vs:findVirtualCarryVehicles(mockTransport)
            assert.equals(1, #r)
            assert.equals(virt, r[1])
        end)

        it("lists only the virtual-carry vehicle when both kinds are aboard", function()
            loadedVehicle("nc1_native", "dcs_native")
            local virt = loadedVehicle("nc1_virtual", "menu_ctld")
            local r = vs:findVirtualCarryVehicles(mockTransport)
            assert.equals(1, #r)
            assert.equals(virt, r[1])
        end)

        it("findLoadedVehicles still returns both kinds (weight accounting, AI dropoff)", function()
            loadedVehicle("nc1_native", "dcs_native")
            loadedVehicle("nc1_virtual", "menu_ctld")
            assert.equals(2, #vs:findLoadedVehicles(mockTransport))
        end)

    end)

    -- ── FIX-NATIVE-CARRY-DETECTION ticket 03 : entry read from the on-board cargo list ──
    describe("_checkNativeLoading — entry read from the DCS on-board cargo list", function()

        local origGetByName, origGs2
        local aircraft, cargoList, listFails, listGets

        local function cargoObj(name)
            return { getName = function() return name end }
        end

        local function waitingVehicle(id, unitName)
            local veh = CTLDVehicle:new({
                id = id, vehicleType = "M1045 HMMWV TOW",
                unit = makeVehicleUnit(unitName, 500, 500),   -- far from the aircraft: position is irrelevant
                spawnData = { groupName = id, unitName = unitName,
                              vehicleType = "M1045 HMMWV TOW", countryId = 2, coalitionId = 2 },
            })
            vs._vehicles[id]         = veh
            vs._unitToVehicle[unitName] = id
            return veh
        end

        before_each(function()
            cargoList, listFails, listGets = {}, false, 0
            aircraft = makeTransport("nc3_player")
            aircraft.getTypeName      = function() return "Mi-8MT" end
            aircraft.getCargosOnBoard = function()
                listGets = listGets + 1
                if listFails then error("no such function") end
                return cargoList
            end
            CTLDPlayerManager.getInstance()._players["nc3_player"] = { groupId = 9901 }
            origGetByName = Unit.getByName
            Unit.getByName = function(n) if n == "nc3_player" then return aircraft end end
            origGs2 = ctld.gs
            ctld.gs = function(k)
                if k == "capabilitiesByType" then
                    return { ["Mi-8MT"] = { canTransportWholeVehicle = true,
                                            useNativeDcsCargoSystem  = true } }
                end
                return origGs2(k)
            end
        end)

        after_each(function()
            Unit.getByName = origGetByName
            ctld.gs = origGs2
            CTLDPlayerManager.getInstance()._players["nc3_player"] = nil
        end)

        it("loads a WAITING vehicle whose CRG: entry is on the list, wherever the vehicle is", function()
            local veh = waitingVehicle("nc3_a", "nc3_unit_a")
            cargoList = { cargoObj("CRG:nc3_unit_a") }
            vs:_checkNativeLoading()
            assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
            assert.equals("dcs_native", veh.loadMethod)
            assert.equals("nc3_player", veh.loadTransportName)
        end)

        it("does not load a WAITING vehicle that is not on the list", function()
            local veh = waitingVehicle("nc3_b", "nc3_unit_b")
            cargoList = { cargoObj("CRG:some_other_unit") }
            vs:_checkNativeLoading()
            assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())
        end)

        it("ignores an untracked entry without changing any state", function()
            local veh = waitingVehicle("nc3_c", "nc3_unit_c")
            cargoList = { cargoObj("cr1-1"), cargoObj("tablet-crate") }
            vs:_checkNativeLoading()
            assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())
        end)

        it("scans a player aircraft of any category (helicopter here)", function()
            waitingVehicle("nc3_d", "nc3_unit_d")
            vs:_checkNativeLoading()
            assert.equals(1, listGets)
        end)

        it("never scans an AI-flown aircraft (not a registered player unit)", function()
            CTLDPlayerManager.getInstance()._players["nc3_player"] = nil
            waitingVehicle("nc3_e", "nc3_unit_e")
            vs:_checkNativeLoading()
            assert.equals(0, listGets)
        end)

        it("logs exactly one warning per type for an unreadable list and stops watching the type", function()
            waitingVehicle("nc3_f", "nc3_unit_f")
            listFails = true
            local warns = 0
            local origLog = ctld.utils.log
            ctld.utils.log = function(level)
                if level == "WARN" or level == "WARNING" then warns = warns + 1 end
            end
            vs:_checkNativeLoading()
            vs:_checkNativeLoading()
            ctld.utils.log = origLog
            assert.equals(1, warns)
            assert.equals(1, listGets)
        end)

        it("returns before any scan when no vehicle is waiting or in native carry", function()
            vs:_checkNativeLoading()
            assert.equals(0, listGets)
        end)

        -- ── ticket 04 : release read from the on-board cargo list ────────────────────
        describe("release when the vehicle leaves the list", function()

            local airborne, altitude, resumed, deregistered, unloaded, dead, polls
            local origInAir, origSchedule, origGroupGet, origDynAdd, jtacMgr, origResume, origDereg
            local dynAddCalls

            local function loadThroughList(id, unitName)
                local veh = waitingVehicle(id, unitName)
                veh.unit.getPoint = function() return { x = 500, y = altitude, z = 500 } end
                cargoList = { cargoObj("CRG:" .. unitName) }
                vs:_checkNativeLoading()
                assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
                return veh
            end

            before_each(function()
                airborne, altitude, dynAddCalls = false, 0, 0
                resumed, deregistered, unloaded, dead, polls = {}, {}, {}, {}, {}
                origInAir = ctld.utils.inAir
                ctld.utils.inAir = function() return airborne end
                origDynAdd = ctld.utils.dynAdd
                ctld.utils.dynAdd = function() dynAddCalls = dynAddCalls + 1; return nil end
                origGroupGet = Group.getByName
                jtacMgr = CTLDJTACManager.getInstance()
                origResume, origDereg = jtacMgr.resumeJTAC, jtacMgr.deregisterJTAC
                jtacMgr.resumeJTAC     = function(_, g) resumed[#resumed + 1] = g end
                jtacMgr.deregisterJTAC = function(_, g) deregistered[#deregistered + 1] = g end
                jtacMgr.jtacs = jtacMgr.jtacs or {}
                origSchedule = timer.scheduleFunction
                timer.scheduleFunction = function(fn) polls[#polls + 1] = fn; return 0 end
                local ed = EventDispatcher.getInstance()
                ed:subscribe("OnVehicleUnloaded", function(p) unloaded[#unloaded + 1] = p end)
                ed:subscribe("OnVehicleDead",     function(p) dead[#dead + 1] = p end)
            end)

            after_each(function()
                ctld.utils.inAir       = origInAir
                ctld.utils.dynAdd      = origDynAdd
                Group.getByName        = origGroupGet
                jtacMgr.resumeJTAC     = origResume
                jtacMgr.deregisterJTAC = origDereg
                jtacMgr.jtacs          = {}
                timer.scheduleFunction = origSchedule
            end)

            it("on the ground: back to WAITING, unit recovered not respawned, JTAC resumes, method dcs_native", function()
                local veh = loadThroughList("nc4_a", "nc4_unit_a")
                local unit = veh.unit
                Group.getByName = function() return { getUnit = function() return unit end } end
                cargoList = {}
                vs:_checkNativeLoading()
                assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())
                assert.equals(unit, veh.unit)
                assert.equals(0, dynAddCalls)
                assert.equals("nc4_a", vs._unitToVehicle["nc4_unit_a"])
                assert.same({ "nc4_a" }, resumed)
                assert.equals(1, #unloaded)
                assert.equals("dcs_native", unloaded[1].method)
            end)

            it("in flight: published as parachute, FALLING, WAITING only after landing, JTAC resumes then", function()
                local veh = loadThroughList("nc4_b", "nc4_unit_b")
                local unit = veh.unit
                Group.getByName = function() return { getUnit = function() return unit end } end
                airborne, altitude = true, 600
                cargoList = {}
                vs:_checkNativeLoading()
                assert.equals(CTLDVehicle.STATE.FALLING, veh:getState())
                assert.equals("parachute", unloaded[1].method)
                assert.equals(unit, veh.unit)
                assert.equals(0, dynAddCalls)
                assert.same({}, resumed)
                assert.equals(1, #polls, "a landing poll must be scheduled")

                altitude = 80
                assert.is_not_nil(polls[1](nil, 0))
                assert.equals(CTLDVehicle.STATE.FALLING, veh:getState())
                assert.same({}, resumed)

                altitude = 1
                assert.is_nil(polls[1](nil, 1))
                assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())
                assert.same({ "nc4_b" }, resumed)
            end)

            it("a falling vehicle is not a waiting vehicle, so it is never loaded again by the scan", function()
                local veh = loadThroughList("nc4_c", "nc4_unit_c")
                local unit = veh.unit
                Group.getByName = function() return { getUnit = function() return unit end } end
                airborne, altitude = true, 600
                cargoList = {}
                vs:_checkNativeLoading()
                cargoList = { cargoObj("CRG:nc4_unit_c") }
                vs:_checkNativeLoading()
                assert.equals(CTLDVehicle.STATE.FALLING, veh:getState())
            end)

            it("does not release while the entry stays on the list", function()
                local veh = loadThroughList("nc4_d", "nc4_unit_d")
                vs:_checkNativeLoading()
                vs:_checkNativeLoading()
                assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
                assert.equals(0, #unloaded)
            end)

            it("does not release anything when the list cannot be read", function()
                local veh = loadThroughList("nc4_e", "nc4_unit_e")
                listFails = true
                vs:_checkNativeLoading()
                assert.equals(CTLDVehicle.STATE.LOADED, veh:getState())
            end)

            it("destroyed while falling: removed from tracking, JTAC deregistered, OnVehicleDead", function()
                local veh = loadThroughList("nc4_f", "nc4_unit_f")
                local unit = veh.unit
                jtacMgr.jtacs["nc4_f"] = {}
                Group.getByName = function() return { getUnit = function() return unit end } end
                airborne, altitude = true, 600
                cargoList = {}
                vs:_checkNativeLoading()
                unit.isExist = function() return false end
                assert.is_nil(polls[1](nil, 0))
                assert.is_nil(vs._vehicles["nc4_f"])
                assert.is_nil(vs._unitToVehicle["nc4_unit_f"])
                assert.same({ "nc4_f" }, deregistered)
                assert.equals(1, #dead)
                assert.equals("nc4_f", dead[1].vehicleId)
            end)

            it("S_EVENT_DEAD on a falling vehicle: removed from tracking, JTAC deregistered, OnVehicleDead", function()
                local veh = loadThroughList("nc4_h", "nc4_unit_h")
                local unit = veh.unit
                jtacMgr.jtacs["nc4_h"] = {}
                Group.getByName = function() return { getUnit = function() return unit end } end
                airborne, altitude = true, 600
                cargoList = {}
                vs:_checkNativeLoading()
                vs:onDead({ initiator = unit })
                assert.is_nil(vs._vehicles["nc4_h"])
                assert.same({ "nc4_h" }, deregistered)
                assert.equals(1, #dead)
                assert.is_nil(polls[1](nil, 0), "the landing poll stops once the vehicle is gone")
            end)

            it("the transport disappearing while the vehicle falls does not stop the landing", function()
                local veh = loadThroughList("nc4_g", "nc4_unit_g")
                local unit = veh.unit
                Group.getByName = function() return { getUnit = function() return unit end } end
                airborne, altitude = true, 600
                cargoList = {}
                vs:_checkNativeLoading()
                CTLDPlayerManager.getInstance()._players["nc3_player"] = nil
                Unit.getByName = function() return nil end
                altitude = 1
                assert.is_nil(polls[1](nil, 0))
                assert.equals(CTLDVehicle.STATE.WAITING, veh:getState())
            end)

            it("a virtual-carry unload still respawns the vehicle, whatever method is published", function()
                local veh = CTLDVehicle:new({
                    id = "nc4_v", vehicleType = "M1045 HMMWV TOW", unit = nil,
                    spawnData = { groupName = "nc4_v", unitName = "nc4_unit_v",
                                  vehicleType = "M1045 HMMWV TOW", countryId = 2, coalitionId = 2 },
                })
                veh:setState(CTLDVehicle.STATE.LOADED)
                veh.loadMethod, veh.loadTransportName = "menu_ctld", "nc3_player"
                vs._vehicles["nc4_v"] = veh
                vs:unloadVehicle(veh, aircraft, nil, "menu_ctld")
                assert.equals(1, dynAddCalls)
            end)

        end)

    end)

end)
