---@diagnostic disable
-- FIX-LGZ-POLL-FIRST-OBSERVATION: the 10 s logistics poller must not rebuild a Request Equipment section that was just built for the
-- zones the aircraft is in. A rebuild by the poller is ambient (the menu disappears for 4 s, ADR 0015), so a false "change" on its first
-- pass makes the pilot lose the menu for no reason; a real zone entry or exit must still rebuild it.
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

describe("logistics zone poller after the Request Equipment section is built", function()

    local cm, playerObj, lgzPoll, zonesHere, rebuilds
    local origGs, origGetByName, origInAir, origSchedule, origRefresh

    local function build()
        lgzPoll = nil
        origSchedule = timer.scheduleFunction
        timer.scheduleFunction = function(fn, _, t)
            if t == 10 then lgzPoll = fn end
            return 0
        end
        cm = CTLDCrateManager.getInstance()
        timer.scheduleFunction = origSchedule
        ctld.gs = function(k)
            if k == "capabilitiesByType" then return { ["UH-1H"] = { cratesEnabled = true } } end
            if k == "loadCrateFromMenu" or k == "enableSmokeDrop" or k == "enabledFOBBuilding"
               or k == "enablePackingVehicles" or k == "enabledRadioBeaconDrop" or k == "reconF10Menu"
               or k == "JTAC_jtacStatusF10" or k == "JTAC_dropEnabled" or k == "enableParachuteDrop" then return false end
            if k == "ctldCrateDescriptors" then return {} end
            return origGs(k)
        end
        local transport = {
            isExist = function() return true end, getName = function() return "UH-1H-1" end,
            getTypeName = function() return "UH-1H" end, getCoalition = function() return 2 end,
            getCountry = function() return country.id.USA end,
            getPoint = function() return { x = 0, y = 0, z = 0 } end,
            getVelocity = function() return { x = 0, y = 0, z = 0 } end,
            getPlayerName = function() return "tester" end,
            getGroup = function() return { getID = function() return 9901 end } end,
        }
        Unit.getByName = function(n) if n == "UH-1H-1" then return transport end end
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function() return zonesHere end
        playerObj = { unitName = "UH-1H-1", groupId = 9901, groupName = "Grp_test", coalition = 2, typeName = "UH-1H",
                      isTransport = true, canCarryVehicles = false }
        CTLDPlayerManager.getInstance()._players["UH-1H-1"] = playerObj
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        origRefresh = CTLDCrateManager.refreshRequestEquipmentSection
        CTLDCrateManager.refreshRequestEquipmentSection = function(self, p)
            rebuilds = rebuilds + 1
            return origRefresh(self, p)
        end
    end

    before_each(function()
        resetAll()
        zonesHere, rebuilds = {}, 0
        origGs, origGetByName, origInAir = ctld.gs, Unit.getByName, ctld.utils.inAir
        ctld.utils.inAir = function() return false end
    end)

    after_each(function()
        if origRefresh then CTLDCrateManager.refreshRequestEquipmentSection = origRefresh end
        origRefresh = nil
        ctld.gs, Unit.getByName, ctld.utils.inAir = origGs, origGetByName, origInAir
        resetAll()
    end)

    it("the first poll after the build outside any zone does not rebuild the section", function()
        build()
        assert.is_function(lgzPoll)
        lgzPoll(nil, 0)
        assert.equals(0, rebuilds)
    end)

    it("the first poll after the build inside a zone does not rebuild the section", function()
        zonesHere = {{ name = "log1", registryKey = function() return "LGZ_log1_B" end }}
        build()
        lgzPoll(nil, 0)
        assert.equals(0, rebuilds)
    end)

    it("entering a logistics zone after the build still rebuilds the section", function()
        build()
        lgzPoll(nil, 0)
        zonesHere = {{ name = "log1", registryKey = function() return "LGZ_log1_B" end }}
        lgzPoll(nil, 10)
        assert.equals(1, rebuilds)
    end)

    it("leaving a logistics zone after the build still rebuilds the section", function()
        zonesHere = {{ name = "log1", registryKey = function() return "LGZ_log1_B" end }}
        build()
        lgzPoll(nil, 0)
        zonesHere = {}
        lgzPoll(nil, 10)
        assert.equals(1, rebuilds)
    end)
end)
