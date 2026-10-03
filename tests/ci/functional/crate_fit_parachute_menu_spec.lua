---@diagnostic disable
-- FIX-NATIVE-CONVERSION-DOORS: the F10 "Fit parachute" action of a type whose DCS cargo-UI loads are handed over to CTLD
-- (convertNativeLoadToCTLD). It is offered only while a crate of the pilot's aircraft is held by DCS awaiting that hand-over
-- and the aircraft is on the ground; a type that does not hand over has no such entry.
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

describe("F10 Fit parachute", function()

    local cm, transport, playerObj, menu
    local origGs, origGetByName, origInAir
    local tr = ctld.tr

    local function node()
        return menu:_getNode({ tr("CTLD"), tr("Crate Commands"), tr("Fit parachute") })
    end

    local function build(typeName)
        CTLDCrateManager.getInstance()
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return {
                    ["UH-1H"]  = { cratesEnabled = true, convertNativeLoadToCTLD = true,  useNativeDcsCargoSystem = true },
                    ["Mi-8MT"] = { cratesEnabled = true, convertNativeLoadToCTLD = false, useNativeDcsCargoSystem = true },
                }
            end
            if k == "loadCrateFromMenu" or k == "enableSmokeDrop" or k == "enabledFOBBuilding"
               or k == "enablePackingVehicles" or k == "enabledRadioBeaconDrop" or k == "reconF10Menu"
               or k == "JTAC_jtacStatusF10" or k == "JTAC_dropEnabled" or k == "enableParachuteDrop" then return false end
            if k == "ctldCrateDescriptors" then return {} end
            return origGs(k)
        end
        transport = {
            isExist     = function() return true end,
            getName     = function() return "UH-1H-1" end,
            getTypeName = function() return typeName end,
            getCoalition = function() return 2 end,
            getCountry  = function() return country.id.USA end,
            getPoint    = function() return { x = 0, y = 0, z = 0 } end,
            getVelocity = function() return { x = 0, y = 0, z = 0 } end,
            getPlayerName = function() return "tester" end,
            getGroup    = function() return { getID = function() return 9901 end } end,
        }
        Unit.getByName = function(n) if n == "UH-1H-1" then return transport end end
        playerObj = { unitName = "UH-1H-1", groupId = 9901, groupName = "Grp_test", coalition = 2, typeName = typeName,
                      isTransport = true, canCarryVehicles = false }
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        menu = ctld.MenuManager:getInstance():getMenuByGroupId(9901)
        cm = CTLDCrateManager.getInstance()
    end

    local function awaitingCrate(awaiting)
        local crate = CTLDCrate:new({
            crateName = "fp1", descriptor = { desc = "Ammo", unit = "Ammo_Crate", weight = 500, cratesRequired = 1 },
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, position = { x = 0, y = 0, z = 0 }, coalition = 2,
        })
        crate:load(transport)
        crate.loadedByDCSNative = true
        crate._awaitingHandOver = awaiting
        crate.dcsStatic = { isExist = function() return true end, getPoint = function() return { x = 0, y = 0, z = 0 } end }
        cm.crates["fp1"] = crate
        return crate
    end

    before_each(function()
        resetAll()
        origGs, origGetByName, origInAir = ctld.gs, Unit.getByName, ctld.utils.inAir
        ctld.utils.inAir = function() return false end
    end)

    after_each(function()
        ctld.gs, Unit.getByName, ctld.utils.inAir = origGs, origGetByName, origInAir
        resetAll()
    end)

    it("a type that hands DCS cargo-UI loads over to CTLD has the entry, disabled while no crate is waiting", function()
        build("UH-1H")
        assert.is_not_nil(node())
        cm:refreshCrateFlightSection(playerObj, false)
        assert.is_false(node().enabled)
    end)

    it("is enabled while a crate of the aircraft awaits its hand-over and the aircraft is on the ground", function()
        build("UH-1H")
        awaitingCrate(true)
        cm:refreshCrateFlightSection(playerObj, false)
        assert.is_true(node().enabled)
    end)

    it("is disabled in flight", function()
        build("UH-1H")
        awaitingCrate(true)
        cm:refreshCrateFlightSection(playerObj, true)
        assert.is_false(node().enabled)
    end)

    it("is disabled for a crate that does not await a hand-over", function()
        build("UH-1H")
        awaitingCrate(nil)
        cm:refreshCrateFlightSection(playerObj, false)
        assert.is_false(node().enabled)
    end)

    it("a type that does not hand over has no such entry", function()
        build("Mi-8MT")
        assert.is_nil(node())
    end)

    it("clicking it asks the crate manager to fit the parachute for this player", function()
        build("UH-1H")
        local asked
        cm.fitParachute = function(_, arg) asked = arg end
        node().functionToCall({ unitName = "UH-1H-1" })
        assert.equals("UH-1H-1", asked.unitName)
    end)

end)
