---@diagnostic disable
-- FIX-NATIVE-CRATE-CTLD-ACTIONS ticket 01: CTLD's unload, parachute and weight apply to
-- VIRTUAL-carry crates only. A crate loaded through the DCS cargo UI (native carry,
-- loadedByDCSNative) is unloaded and parachuted through the DCS cargo UI, and DCS accounts for
-- its weight itself — as it already does for whole vehicles.
-- ============================================================

local function resetAll()
    CTLDPlayerManager._instance  = nil
    ctld.MenuManager._instance   = nil
    EventDispatcher._instance    = nil
    CTLDDCSEventBridge._instance = nil
    CTLDZoneManager._instance    = nil
    CTLDTroopManager._instance   = nil
    CTLDVehicleSpawner._instance = nil
    CTLDCrateManager._instance   = nil
    _cmInstance                  = nil
    CTLDBeaconManager._instance  = nil
    CTLDReconManager._instance   = nil
    CTLDJTACManager._instance    = nil
end

describe("FIX-NATIVE-CRATE-CTLD-ACTIONS — virtual-carry-only actions", function()

    local cm
    local _origGs, _origGetHeight, _origGetByName, _origInAir
    local origOutText, messages
    local transport, destroyed

    local function makeCrate(name, weight, native)
        local crate = CTLDCrate:new({
            crateName   = name,
            descriptor  = { desc = "Ammo", unit = "Ammo_Crate", weight = weight, cratesRequired = 1 },
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = { x = 0, y = 10, z = 0 },
            coalition   = 2,
            heading     = 0,
            dcsStatic   = {
                isExist  = function() return true end,
                destroy  = function() destroyed[#destroyed + 1] = name end,
                getPoint = function() return { x = 0, y = 10, z = 0 } end,
            },
        })
        crate:load(transport)
        if native then crate.loadedByDCSNative = true end
        cm.crates[name] = crate
        return crate
    end

    before_each(function()
        resetAll()
        _origGs        = ctld.gs
        _origGetHeight = land.getHeight
        _origGetByName = Unit.getByName
        _origInAir     = ctld.utils.inAir
        origOutText    = trigger.action.outTextForGroup
        messages, destroyed = {}, {}
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end

        ctld.gs = function(k)
            if k == "parachuteMinAltitudeCrates" then return 30 end
            if k == "parachuteDescentRateCrates" then return 100 end
            if k == "parachuteInertiaFactor"     then return 0.0 end
            if k == "parachuteLateralDriftMin"   then return 5 end
            if k == "parachuteLateralDriftMax"   then return 10 end
            return _origGs(k)
        end
        land.getHeight = function(_) return 10 end

        transport = {
            isExist     = function() return true end,
            getName     = function() return "UH-1H-1" end,
            getTypeName = function() return "UH-1H" end,
            getPoint    = function() return { x = 0, y = 110, z = 0 } end,
            getVelocity = function() return { x = 0, y = 0, z = 0 } end,
        }
        Unit.getByName = function(n) if n == "UH-1H-1" then return transport end end
        cm = CTLDCrateManager.getInstance()
    end)

    after_each(function()
        ctld.gs                        = _origGs
        land.getHeight                 = _origGetHeight
        Unit.getByName                 = _origGetByName
        ctld.utils.inAir               = _origInAir
        trigger.action.outTextForGroup = origOutText
    end)

    describe("isLoadedByCTLD", function()

        it("is true for a crate loaded through the CTLD menu (virtual carry)", function()
            assert.is_true(makeCrate("v1", 500, false):isLoadedByCTLD())
        end)

        it("is false for a crate loaded through the DCS cargo UI (native carry)", function()
            assert.is_false(makeCrate("n1", 500, true):isLoadedByCTLD())
        end)

        it("is false for a crate that is not loaded", function()
            local crate = makeCrate("g1", 500, false)
            crate:unload({ x = 1, y = 0, z = 1 })
            assert.is_false(crate:isLoadedByCTLD())
        end)

        it("isLoaded stays true for both loading modes", function()
            assert.is_true(makeCrate("v2", 500, false):isLoaded())
            assert.is_true(makeCrate("n2", 500, true):isLoaded())
        end)

        it("a crate released natively then loaded through the menu counts as virtual (no stale flag)", function()
            local crate = makeCrate("n3", 500, true)
            crate.state, crate.loadedBy = CTLDCrate.STATE.LANDED, nil   -- native release does not clear the flag
            crate:load(transport)
            assert.is_true(crate:isLoadedByCTLD())
        end)

    end)

    describe("transport weight", function()

        it("counts virtual crates only", function()
            makeCrate("v1", 500, false)
            makeCrate("n1", 300, true)
            assert.equals(500, cm:getLoadedCrateWeight("UH-1H-1"))
        end)

        it("is zero with native crates only", function()
            makeCrate("n1", 300, true)
            assert.equals(0, cm:getLoadedCrateWeight("UH-1H-1"))
        end)

    end)

    describe("parachuteCrates", function()

        local playerObj = { unitName = "UH-1H-1", groupId = 9901, groupName = "G", coalition = 2 }

        it("leaves a natively loaded crate alone: still loaded, DCS object not destroyed", function()
            local native = makeCrate("n1", 300, true)
            local fired = false
            EventDispatcher.getInstance():subscribe("OnCrateParachuting", function() fired = true end)

            cm:parachuteCrates(transport, playerObj)

            assert.is_false(fired)
            assert.equals(CTLDCrate.STATE.LOADED, native.state)
            assert.equals(0, #destroyed)
            assert.equals(ctld.tr("No crates loaded."), messages[#messages])
        end)

        it("parachutes the virtual crates and leaves the native one in the bay", function()
            local virtual = makeCrate("v1", 500, false)
            local native  = makeCrate("n1", 300, true)

            cm:parachuteCrates(transport, playerObj)

            assert.equals(CTLDCrate.STATE.FALLING, virtual.state)
            assert.equals(CTLDCrate.STATE.LOADED, native.state)
            assert.is_nil(next(destroyed))
        end)

    end)

    describe("F10 actions", function()

        local function buildMenu()
            CTLDCrateManager.getInstance()
            ctld.gs = function(k)
                if k == "capabilitiesByType" then
                    return { ["UH-1H"] = { cratesEnabled = true, canParachuteDrop = true, maxCratesOnboard = 4 } }
                end
                if k == "loadCrateFromMenu" or k == "enableSmokeDrop" or k == "enabledFOBBuilding"
                   or k == "enablePackingVehicles" or k == "enabledRadioBeaconDrop" or k == "reconF10Menu"
                   or k == "JTAC_jtacStatusF10" or k == "JTAC_dropEnabled" then return false end
                if k == "ctldCrateDescriptors" then return {} end
                if k == "enableParachuteDrop" then return true end
                return _origGs(k)
            end
            local playerObj = {
                unitName = "UH-1H-1", groupId = 9901, groupName = "Grp_test", coalition = 2,
                typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
            }
            CTLDPlayerManager.getInstance():buildMenu(playerObj)
            local menu = ctld.MenuManager:getInstance():getMenuByGroupId(9901)
            return menu, playerObj
        end

        local function node(menu, name)
            return menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Crate Commands"), ctld.tr(name) })
        end

        it("Parachute Crates stays disabled with only native crates on board", function()
            local menu, playerObj = buildMenu()
            makeCrate("n1", 300, true)
            cm:refreshCrateFlightSection(playerObj, true)
            assert.is_false(node(menu, "Parachute Crates").enabled)
        end)

        it("Parachute Crates is enabled once a virtual crate is on board too", function()
            local menu, playerObj = buildMenu()
            makeCrate("n1", 300, true)
            makeCrate("v1", 500, false)
            cm:refreshCrateFlightSection(playerObj, true)
            assert.is_true(node(menu, "Parachute Crates").enabled)
        end)

        describe("Drop Crate(s)", function()

            local dropped, _origPositions, _origSecure, _origGroupId

            before_each(function()
                dropped = {}
                _origPositions = ctld.utils.getSpawnObjectPositions
                _origSecure    = ctld.utils.getSecureDistanceFromUnit
                _origGroupId   = ctld.utils.getGroupId
                ctld.utils.inAir = function() return false end
                ctld.utils.getGroupId = function() return 9901 end
                ctld.utils.getSecureDistanceFromUnit = function() return 10 end
                ctld.utils.getSpawnObjectPositions = function(_, n)
                    local positions = {}
                    for i = 1, n do positions[i] = { x = i, y = 0, z = i } end
                    return { positions = positions, clock = 12 }
                end
                cm.unloadCrate = function(_, crateName) dropped[#dropped + 1] = crateName end
            end)

            after_each(function()
                ctld.utils.getSpawnObjectPositions   = _origPositions
                ctld.utils.getSecureDistanceFromUnit = _origSecure
                ctld.utils.getGroupId                = _origGroupId
                cm.unloadCrate = nil
            end)

            it("drops virtual crates only, never a natively loaded one", function()
                local menu = buildMenu()
                makeCrate("n1", 300, true)
                makeCrate("v1", 500, false)

                node(menu, "Drop Crate(s)").functionToCall({ unitName = "UH-1H-1" })

                assert.same({ "v1" }, dropped)
            end)

            it("says there is nothing to drop when only native crates are on board", function()
                local menu = buildMenu()
                makeCrate("n1", 300, true)

                node(menu, "Drop Crate(s)").functionToCall({ unitName = "UH-1H-1" })

                assert.same({}, dropped)
                assert.equals(ctld.tr("No crates on board to drop."), messages[#messages])
            end)

        end)

    end)

end)
