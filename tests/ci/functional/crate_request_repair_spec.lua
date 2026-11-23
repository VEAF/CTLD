---@diagnostic disable
-- FIX-VMCT-REVIEW-FINDINGS ticket 03 (issue #324): every single crate of Request Equipment is brought out,
-- the six "… Repair" crates included. They carry a weight and no unit; the single-crate path looked the
-- crate up by unit and answered "Request failed". The menu is built by the real builder over a real zone
-- manager and the callback is the real one read back from the menu node; the crate creation is a double.
-- ============================================================

describe("Request Equipment brings out every single crate of the catalogue (#324)", function()

    local tr = ctld.tr
    local ROOT = tr("CTLD")
    local PLAYER_UNIT = "UH2_rp1"
    local CX, CZ = 100, 200
    local FAILURE = "Request failed: the equipment could not be brought out."

    local savedMission, savedGetZone, origGetByName, origInAir, origOutText, origGs
    local messages, created

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

    local function collectSingleCommands(node, out)
        if node.type == "command" then
            local a = node.anyArgument
            if type(a) == "table" and a.desc and not a.multiple and not a.spawnAsVehicle then
                out[#out + 1] = node
            end
            return out
        end
        for _, child in ipairs(node.children or {}) do collectSingleCommands(child, out) end
        return out
    end

    local function singleCommands()
        local playerObj = {
            unitName = PLAYER_UNIT, groupId = 9907, groupName = "Grp_rp1", coalition = coalition.side.BLUE,
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        local menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
        return collectSingleCommands(menu:_getNode({ ROOT, tr("Request Equipment") }), {})
    end

    -- display label -> set of catalogue weights shown under that label
    local function weightsByLabel()
        local byLabel = {}
        for _, data in pairs(CTLDCrateManager.getInstance()._processedCrates or {}) do
            for _, entry in ipairs(data.singleCrates) do
                local sc = entry.singleCrate
                byLabel[sc.desc] = byLabel[sc.desc] or {}
                byLabel[sc.desc][sc.weight] = true
            end
        end
        return byLabel
    end

    local function said(text)
        for _, m in ipairs(messages) do if m == text then return true end end
        return false
    end

    before_each(function()
        ctld.startupReport._entries = {}
        resetSingletons()
        messages, created = {}, {}
        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        origGs = ctld.gs
        trigger.misc.getZone = function(_) return { point = { x = CX, y = 0, z = CZ }, radius = 300 } end
        env.mission = { triggers = { zones = { { name = "LGZ_rp1_B" } } } }
        ctld.gs = function(k)
            if k == "JTAC_dropEnabled" then return true end
            return origGs(k)
        end

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
                    getDesc       = function()
                        return { box = { min = { x = -8, y = -1.6, z = -1.6 }, max = { x = 4, y = 1.6, z = 1.6 } } }
                    end,
                    getPlayerName = function() return "tester" end,
                    isExist       = function() return true end,
                    inAir         = function() return false end,
                    getGroup      = function() return { getID = function() return 9907 end } end,
                }
            end
            return origGetByName and origGetByName(n) or nil
        end
        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return false end
        origOutText = trigger.action.outTextForGroup
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end

        local mgr = CTLDCrateManager.getInstance()
        mgr.spawnCratesAligned = function(_, descriptors)
            created[#created + 1] = descriptors[1]
            return 1, { clock = "3", positions = {} }
        end
        mgr.spawnCrate = function(_, descriptor)
            created[#created + 1] = descriptor
            return {}
        end
    end)

    after_each(function()
        Unit.getByName                 = origGetByName
        ctld.utils.inAir               = origInAir
        ctld.gs                        = origGs
        trigger.action.outTextForGroup = origOutText
        env.mission                    = savedMission
        trigger.misc.getZone           = savedGetZone
        resetSingletons()
        ctld.startupReport._entries = {}
    end)

    for _, label in ipairs({ "HAWK Repair", "NASAMS Repair", "Patriot Repair" }) do
        it("brings out a '" .. label .. "' crate", function()
            local cmd
            for _, c in ipairs(singleCommands()) do
                if c.anyArgument.desc:find(label, 1, true) == 1 then cmd = c end
            end
            assert.is_not_nil(cmd, "Request Equipment lists no '" .. label .. "'")
            cmd.functionToCall(cmd.anyArgument)
            assert.is_false(said(tr(FAILURE)))
            assert.equals(1, #created)
            assert.equals(label, created[1].desc)
        end)
    end

    it("brings out, for every single crate the blue menu lists, the crate of that very entry", function()
        local byLabel = weightsByLabel()
        local cmds = singleCommands()
        assert.is_true(#cmds > 20)
        for _, cmd in ipairs(cmds) do
            created = {}
            cmd.functionToCall(cmd.anyArgument)
            local label = cmd.anyArgument.desc
            assert.equals(1, #created, "nothing brought out for '" .. label .. "'")
            assert.is_true(byLabel[label][created[1].weight] == true,
                "'" .. label .. "' brought out the crate of '" .. tostring(created[1].desc) .. "'")
        end
        assert.is_false(said(tr(FAILURE)))
    end)

    it("resolves every single crate of the catalogue, red ones included, by its own weight", function()
        local mgr = CTLDCrateManager.getInstance()
        for _, data in pairs(mgr._processedCrates) do
            for _, entry in ipairs(data.singleCrates) do
                local sc = entry.singleCrate
                local d = mgr:findDescriptorByWeight(sc.weight)
                assert.is_not_nil(d, "no descriptor for weight " .. tostring(sc.weight))
                assert.equals(sc.unit, d.unit)
                assert.equals(sc.cratesRequired, d.cratesRequired)
            end
        end
    end)

end)
