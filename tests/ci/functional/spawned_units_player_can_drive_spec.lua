---@diagnostic disable
-- tests/ci/functional/spawned_units_player_can_drive_spec.lua
-- FEAT-VMCT-V1-PARITY ticket 01 (issue #327). CTLD v1 created the units of a player gesture with
-- playerCanDrive = true (ctld.createUnit), so a Combined Arms player or a game master could drive what the
-- helicopters delivered. spawnedUnitsPlayerCanDrive (default true) brings that back, and false turns it off.
-- Each case observes what DCS receives: the unit table handed to coalition.addGroup, or to ctld.utils.dynAdd
-- (which would itself turn a missing field into true, so the field must be set before it).
-- ============================================================

local origAddGroup, origDynAdd, origGetByName, borrowed
local added      -- unit tables handed to coalition.addGroup, in order
local dynAdded   -- unit tables handed to ctld.utils.dynAdd, in order

local function capture(setting)
    borrowed = ctldTestSettings.borrow({ spawnedUnitsPlayerCanDrive = setting })
    origAddGroup, origDynAdd, origGetByName = coalition.addGroup, ctld.utils.dynAdd, Group.getByName
    added, dynAdded = {}, {}
    coalition.addGroup = function(_, _, groupData)
        for _, u in ipairs(groupData.units or {}) do added[#added + 1] = u end
        return { getName = function() return groupData.name end }
    end
    ctld.utils.dynAdd = function(_, groupData)
        for _, u in ipairs(groupData.units or {}) do dynAdded[#dynAdded + 1] = u end
        return { name = groupData.name }
    end
    Group.getByName = function(name)
        return {
            getName = function() return name end,
            isExist = function() return true end,
            getUnit = function()
                return {
                    getName      = function() return name end,
                    isExist      = function() return true end,
                    getCoalition = function() return coalition.side.BLUE end,
                    getCountry   = function() return country.id.USA end,
                    getTypeName  = function() return "M1045 HMMWV TOW" end,
                    getPoint     = function() return { x = 0, y = 0, z = 0 } end,
                }
            end,
            getUnits = function() return {} end,
            getSize = function() return 1 end,
        }
    end
end

local function release()
    coalition.addGroup, ctld.utils.dynAdd, Group.getByName = origAddGroup, origDynAdd, origGetByName
    borrowed:restore()
end

local function transport()
    return {
        getName      = function() return "PCD-Transport" end,
        getTypeName  = function() return "UH-1H" end,
        getCoalition = function() return coalition.side.BLUE end,
        getCountry   = function() return country.id.USA end,
        getPoint     = function() return { x = 0, y = 10, z = 0 } end,
        getPosition  = function() return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 10, z = 0 } } end,
        getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
        getGroup     = function() return { getID = function() return 9901 end } end,
        isExist      = function() return true end,
    }
end

-- Every unit DCS was handed carries `expected`.
local function allDrivable(units, expected)
    assert.is_true(#units > 0)
    for _, u in ipairs(units) do assert.equals(expected, u.playerCanDrive) end
end

local GROUND_KEY = "PCD_TEST_TROOPS"
CTLDObjectRegistry.registerIfAbsent(GROUND_KEY, {
    groupType = "GROUND", namePrefix = "PCD_Grp", category = Unit.Category.GROUND_UNIT,
    units = { { namePrefix = "PCD_Soldier", unitType = "Soldier M4" },
              { namePrefix = "PCD_Soldier", unitType = "Soldier M4", dx = 2 } },
})
local LOCKED_KEY = "PCD_TEST_LOCKED"
CTLDObjectRegistry.registerIfAbsent(LOCKED_KEY, {
    groupType = "GROUND", namePrefix = "PCD_Locked", category = Unit.Category.GROUND_UNIT,
    units = { { namePrefix = "PCD_Locked_Unit", unitType = "M978 HEMTT Tanker", playerCanDrive = false } },
})

-- The gestures, each one creating its units the way CTLD does in game.
local GESTURES = {
    { "troops dropped from a template (spawnObject)", function()
        CTLDObjectRegistry.spawnObject(GROUND_KEY, coalition.side.BLUE, country.id.USA, 0, 0, 0)
        return added
    end },
    { "an AA system assembled from crates", function()
        CTLDCrateAssemblyManager.getInstance():_spawnGroup(
            { { x = 0, y = 0, z = 0 }, { x = 20, y = 0, z = 0 } }, { "Hawk ln", "Hawk sr" }, { 0, 0 }, country.id.USA)
        return dynAdded
    end },
    { "a vehicle spawned for a transport", function()
        CTLDVehicleSpawner.getInstance():spawnVehicleForTransport("M1045 HMMWV TOW", transport(), nil)
        return dynAdded
    end },
    { "a vehicle unloaded from a transport", function()
        local vs  = CTLDVehicleSpawner.getInstance()
        local veh = CTLDVehicle:new({
            id = "pcd_unload", vehicleType = "M1045 HMMWV TOW", unit = nil,
            spawnData = { groupName = "pcd_unload", unitName = "pcd_unload_unit",
                          vehicleType = "M1045 HMMWV TOW", countryId = country.id.USA, coalitionId = 2 },
        })
        veh:setState(CTLDVehicle.STATE.LOADED)
        veh.loadTransportName = "PCD-Transport"
        veh.loadMethod        = "menu_ctld"
        vs._vehicles["pcd_unload"] = veh
        vs:unloadVehicle(veh, transport(), "PCD-Transport", "menu_ctld")
        vs._vehicles["pcd_unload"] = nil
        return dynAdded
    end },
    { "a vehicle landed by parachute or delivered by an AI transport (spawnVehicleAt)", function()
        CTLDVehicleSpawner.getInstance():spawnVehicleAt(
            { vehicleType = "M1045 HMMWV TOW", country = country.id.USA, coalitionId = 2 }, { x = 0, y = 0, z = 0 })
        return added
    end },
    { "a vehicle crate unpacked", function()
        CTLDCrateManager.getInstance():_spawnUnpacked({ unit = "M1043 HMMWV Armament", spawnAs = "GROUND" },
            { x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA, nil)
        return added
    end },
}

for _, setting in ipairs({ true, false }) do
    describe("spawnedUnitsPlayerCanDrive = " .. tostring(setting), function()
        before_each(function() capture(setting) end)
        after_each(release)

        for _, g in ipairs(GESTURES) do
            it(g[1] .. " is created with playerCanDrive = " .. tostring(setting), function()
                allDrivable(g[2](), setting)
            end)
        end
    end)
end

describe("a registry template that sets playerCanDrive = false", function()
    before_each(function() capture(true) end)
    after_each(release)

    it("keeps its false over spawnedUnitsPlayerCanDrive = true", function()
        CTLDObjectRegistry.spawnObject(LOCKED_KEY, coalition.side.BLUE, country.id.USA, 0, 0, 0)
        allDrivable(added, false)
    end)
end)

describe("troops dropped by parachute", function()
    local origGs, origGetHeight, origSchedule

    local function dropWith(setting)
        capture(setting)
        origGs, origGetHeight, origSchedule = ctld.gs, land.getHeight, timer.scheduleFunction
        ctld.gs = function(k)
            if k == "parachuteMinAltitudeTroops" then return 50 end
            if k == "maximumSearchDistance" or k == "maximumMoveDistance" then return 0 end
            return origGs(k)
        end
        land.getHeight = function() return 10 end
        CTLDZoneManager.getInstance()
        timer.scheduleFunction = function(fn, arg, t) fn(arg, t); return 0 end
        local tm = CTLDTroopManager.getInstance()
        tm._inTransit["PCD-Transport"] = { CTLDTroopGroup:new({
            templateName = "Standard Infantry", unitTotal = 2, weight = 200, coalitionId = 2 }) }
        local t = transport()
        t.getPoint = function() return { x = 0, y = 200, z = 0 } end
        tm:parachuteTroops(t, { unitName = "PCD-Transport", groupId = 9901, groupName = "G", coalition = 2 })
        return added
    end

    after_each(function()
        ctld.gs, land.getHeight, timer.scheduleFunction = origGs, origGetHeight, origSchedule
        CTLDTroopManager.getInstance()._inTransit["PCD-Transport"] = nil
        release()
    end)

    it("land with playerCanDrive = true", function() allDrivable(dropWith(true), true) end)
    it("land with playerCanDrive = false when the setting is false", function() allDrivable(dropWith(false), false) end)
end)
