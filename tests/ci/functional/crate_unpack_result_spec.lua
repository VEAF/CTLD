---@diagnostic disable
-- FIX-UNPACK-FALSE-SUCCESS: the Unpack Crate click announces "<equipment> unpacked successfully!" only when the group was created.
-- _spawnUnpacked answers true (created), false (DCS refused: the pilot is told) or nil (nothing attempted: JTAC limit reached,
-- missing data); nil used to be announced as a success. The menu is built by the real builder and the callback is the real one read
-- back from the menu node; the object creation is a double that can be made to succeed or to fail.
-- ============================================================

describe("Unpack Crate announces only what was created", function()

    local tr = ctld.tr
    local ROOT = tr("CTLD")
    local PLAYER_UNIT = "UH2_up1"
    local CX, CZ = 100, 200
    local SUCCESS = "Test Jeep unpacked successfully!"
    local FAILURE = "Unpack failed: the equipment could not be created."
    local LIMIT   = "JTAC limit reached for your coalition."

    local origGetByName, origInAir, origOutText, origGs, origLog, origSpawn, origPositions, origPostSpawn
    local messages, logs, spawnResult, jtacLimit, noPosition

    local function resetSingletons()
        ctld.MenuManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        CTLDTroopManager._instance   = nil
        CTLDCrateManager._instance   = nil
        CTLDVehicleSpawner._instance = nil
        CTLDFOBManager._instance     = nil
        CTLDBeaconManager._instance  = nil
        CTLDReconManager._instance   = nil
        CTLDJTACManager._instance    = nil
        CTLDZoneManager._instance    = nil
        EventDispatcher._instance    = nil
        CTLDDCSEventBridge._instance = nil
    end

    local function said(text)
        for _, m in ipairs(messages) do if m == text then return true end end
        return false
    end

    local function logged(level, pattern)
        for _, l in ipairs(logs) do
            if l.level == level and l.text:find(pattern, 1, true) then return true end
        end
        return false
    end

    -- Put one unpackable crate next to the pilot, build the menu, and click the Unpack Crate entry.
    local function unpack(isJTAC)
        local desc = { desc = "Test Jeep", unit = "Hummer", weight = 100, cratesRequired = 1, isJTAC = isJTAC }
        local cm = CTLDCrateManager.getInstance()
        local crate = CTLDCrate:new({
            crateName = "unp1", descriptor = desc, spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position = { x = CX + 5, y = 0, z = CZ }, coalition = coalition.side.BLUE,
        })
        crate.dcsStatic = { isExist = function() return true end, getPoint = function() return { x = CX + 5, y = 0, z = CZ } end,
                            destroy = function() end }
        cm.crates["unp1"] = crate

        local playerObj = {
            unitName = PLAYER_UNIT, groupId = 9904, groupName = "Grp_up1", coalition = coalition.side.BLUE,
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
        CTLDPlayerManager.getInstance()._players[PLAYER_UNIT] = playerObj
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        local menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
        local node = menu:_getNode({ ROOT, tr("Crate Commands"), tr("Unpack Crate") })
        local cmd
        for _, child in ipairs(node.children or {}) do
            if child.type == "command" and child.anyArgument and child.anyArgument.unitType == "Hummer" then cmd = child end
        end
        assert.is_not_nil(cmd, "Unpack Crate lists no entry for the crate next to the pilot")
        cmd.functionToCall(cmd.anyArgument)
    end

    before_each(function()
        ctld.startupReport._entries = {}
        resetSingletons()
        messages, logs, spawnResult, jtacLimit, noPosition = {}, {}, true, nil, false
        origGs, origLog = ctld.gs, ctld.utils.log
        EventDispatcher.getInstance()
        CTLDDCSEventBridge.getInstance()
        CTLDZoneManager.getInstance()
        CTLDPlayerManager.getInstance()
        CTLDTroopManager.getInstance()
        CTLDVehicleSpawner.getInstance()
        CTLDCrateManager.getInstance()
        CTLDFOBManager.getInstance()
        CTLDBeaconManager.getInstance()
        CTLDReconManager.getInstance()
        CTLDJTACManager.getInstance()

        origGetByName = Unit.getByName
        Unit.getByName = function(n)
            if n == PLAYER_UNIT then
                return {
                    getName       = function() return PLAYER_UNIT end,
                    getTypeName   = function() return "UH-1H" end,
                    getCoalition  = function() return coalition.side.BLUE end,
                    getCountry    = function() return country.id.USA end,
                    getPoint      = function() return { x = CX, y = 0, z = CZ } end,
                    getPosition   = function()
                        return { p = { x = CX, y = 0, z = CZ }, x = { x = 1, y = 0, z = 0 },
                                 y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
                    end,
                    getDesc       = function() return { box = { min = { x = -8, y = -1.6, z = -1.6 }, max = { x = 4, y = 1.6, z = 1.6 } } } end,
                    getPlayerName = function() return "tester" end,
                    isExist       = function() return true end,
                    inAir         = function() return false end,
                    getGroup      = function() return { getID = function() return 9904 end } end,
                }
            end
            return origGetByName and origGetByName(n) or nil
        end
        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return false end
        origOutText = trigger.action.outTextForGroup
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end
        ctld.utils.log = function(level, fmt, ...)
            logs[#logs + 1] = { level = level, text = select("#", ...) > 0 and string.format(fmt, ...) or fmt }
        end
        ctld.gs = function(k)
            if k == "JTAC_LIMIT_BLUE" and jtacLimit ~= nil then return jtacLimit end
            return origGs(k)
        end
        origSpawn = ctld.utils.spawnFromDescriptor
        ctld.utils.spawnFromDescriptor = function() return spawnResult, spawnResult and nil or "refused" end
        origPositions = ctld.utils.getSpawnObjectPositions
        ctld.utils.getSpawnObjectPositions = function(...)
            if noPosition then return { positions = {} } end
            return origPositions(...)
        end
        origPostSpawn = CTLDCrateManager._dispatchPostSpawn
        CTLDCrateManager._dispatchPostSpawn = function() end
    end)

    after_each(function()
        Unit.getByName                 = origGetByName
        ctld.utils.inAir               = origInAir
        ctld.utils.log                 = origLog
        ctld.gs                        = origGs
        ctld.utils.spawnFromDescriptor = origSpawn
        ctld.utils.getSpawnObjectPositions = origPositions
        CTLDCrateManager._dispatchPostSpawn = origPostSpawn
        trigger.action.outTextForGroup = origOutText
        resetSingletons()
        ctld.startupReport._entries = {}
    end)

    it("announces the success when the equipment was created (control)", function()
        unpack(false)
        assert.is_true(said(SUCCESS))
        assert.is_false(said(FAILURE))
    end)

    it("announces only the refusal when the JTAC limit of the coalition is reached", function()
        jtacLimit = 0
        unpack(true)
        assert.is_true(said(LIMIT))
        assert.is_false(said(SUCCESS))
    end)

    it("announces only the failure when DCS refuses the group", function()
        spawnResult = false
        unpack(false)
        assert.is_true(said(FAILURE))
        assert.is_false(said(SUCCESS))
    end)

    it("announces no success and logs the click when no spawn position was found", function()
        noPosition = true
        unpack(false)
        assert.is_false(said(SUCCESS))
        assert.is_true(logged("WARNING", "Unpack Crate — nothing attempted"))
    end)
end)
