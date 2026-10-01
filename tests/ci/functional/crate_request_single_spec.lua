---@diagnostic disable
-- tests/ci/functional/crate_request_single_spec.lua
-- FEAT-NATIVE-CRATE-SPAWN-NEAR ticket 03 -- the single crate picked in Request Equipment appears at the same
-- declared sector and distance as a set of one; an aircraft that declares no plan keeps its current position
-- rule. The menu is built by the real builder over a real zone manager and the callback is the real one read
-- back from the menu node; the static spawn is a double.
-- ============================================================

describe("Request Equipment single crate -- clearance beside a native-cargo aircraft", function()

    local tr = ctld.tr
    local ROOT = tr("CTLD")
    local PLAYER_UNIT = "UH2_nc3"
    local CX, CZ = 100, 200   -- the zone centre, where the aircraft stands

    local savedMission, savedGetZone, origGetByName, origInAir, origOutText, origGs, origRandom
    local spawnedAt

    local UH1H_BOX = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } }

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

    local function firstSingleCrateCommand(node)
        if node.type == "command" then
            if node.anyArgument and node.anyArgument.unit and not node.anyArgument.spawnAsVehicle
               and not node.anyArgument.multiple then
                return node
            end
            return nil
        end
        for _, child in ipairs(node.children or {}) do
            local found = firstSingleCrateCommand(child)
            if found then return found end
        end
        return nil
    end

    -- Build the menu for the aircraft and click the first single crate.
    local function requestOneCrate()
        local playerObj = {
            unitName = PLAYER_UNIT, groupId = 9903, groupName = "Grp_nc3", coalition = coalition.side.BLUE,
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        local menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
        local cmd = firstSingleCrateCommand(menu:_getNode({ ROOT, tr("Request Equipment") }))
        assert.is_not_nil(cmd, "Request Equipment lists no single crate")
        local mgr = CTLDCrateManager.getInstance()
        spawnedAt = nil
        mgr.spawnCrate = function(_, _, pos) spawnedAt = pos; return true end
        cmd.functionToCall(cmd.anyArgument)
        return spawnedAt
    end

    before_each(function()
        ctld.startupReport._entries = {}
        resetSingletons()
        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        origGs       = ctld.gs
        origRandom   = ctld.utils.RandomReal
        trigger.misc.getZone = function(_) return { point = { x = CX, y = 0, z = CZ }, radius = 300 } end
        env.mission = { triggers = { zones = { { name = "LGZ_log1_B" } } } }
        ctld.utils.RandomReal = function() return 0.1 end   -- the right side

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
                    getPoint      = function() return { x = CX, y = 0, z = CZ } end,
                    getPosition   = function()
                        return { p = { x = CX, y = 0, z = CZ }, x = { x = 1, y = 0, z = 0 },
                                 y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
                    end,
                    getDesc       = function() return { box = UH1H_BOX } end,
                    getPlayerName = function() return "tester" end,
                    isExist       = function() return true end,
                    inAir         = function() return false end,
                    getGroup      = function() return { getID = function() return 9903 end } end,
                }
            end
            return origGetByName and origGetByName(n) or nil
        end
        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return false end
        origOutText = trigger.action.outTextForGroup
        trigger.action.outTextForGroup = function() end
    end)

    after_each(function()
        Unit.getByName                 = origGetByName
        ctld.utils.inAir               = origInAir
        ctld.utils.RandomReal          = origRandom
        ctld.gs                        = origGs
        trigger.action.outTextForGroup = origOutText
        env.mission                    = savedMission
        trigger.misc.getZone           = savedGetZone
        resetSingletons()
        ctld.startupReport._entries = {}
    end)

    it("a UH-1H (side 3.0 m) gets its single crate 3.0 m abeam of the helicopter", function()
        local p = requestOneCrate()
        assert.is_not_nil(p, "no crate was spawned")
        assert.is_near(3.0, math.abs(p.z - CZ), 0.01)
        assert.is_near(0, p.x - CX, 0.01)
    end)

    it("an aircraft that declares no plan keeps the secure distance + 5 m", function()
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                local caps = {}
                for name, c in pairs(origGs("capabilitiesByType")) do
                    local copy = {}
                    for key, v in pairs(c) do copy[key] = v end
                    copy.crateSpawnSector, copy.crateSpawnDistance = nil, nil
                    caps[name] = copy
                end
                return caps
            end
            return origGs(k)
        end
        local p = requestOneCrate()
        assert.is_not_nil(p, "no crate was spawned")
        local secure = math.sqrt(8.86 * 8.86 + 1.59 * 1.59) + 5
        assert.is_near(secure, math.sqrt((p.x - CX) ^ 2 + (p.z - CZ) ^ 2), 0.01)
    end)

end)
