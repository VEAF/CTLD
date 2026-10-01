---@diagnostic disable
-- tests/ci/functional/zone_registry_key_menu_spec.lua
-- FIX-ZONE-REGISTRY-KEY ticket 01 -- the F10 Request Equipment and Load from <zone> menus must
-- hand the zone's registry key (the full DCS name for an auto-discovered zone) to their callbacks.
-- Regression of PR #210 / ADR 0020: both menus passed the short name to a registry keyed by the
-- full name, so every crate request answered "not close enough" and every troop load "Zone not found.".
-- The menus are built by the real builders over a real zone manager; the callbacks are the real
-- ones read back from the menu nodes.
-- ============================================================

local tr = ctld.tr

describe("F10 menus designate an auto-discovered zone by its registry key", function()

    local ROOT = tr("CTLD")
    local PLAYER_UNIT = "BLUE_UH1H_1"
    local ZONE_CENTER = { x = 100, y = 0, z = 200 }

    local savedMission, savedGetZone, origGetByName, origInAir, origOutText

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

    local function makePlayer()
        return {
            unitName         = PLAYER_UNIT,
            groupId          = 9901,
            groupName        = "Grp_regkey",
            coalition        = coalition.side.BLUE,
            typeName         = "UH-1H",
            isTransport      = true,
            canCarryVehicles = false,
        }
    end

    -- Depth-first search for the first command node under a menu node.
    local function firstCommand(node)
        if node.type == "command" then return node end
        for _, child in ipairs(node.children or {}) do
            local found = firstCommand(child)
            if found then return found end
        end
        return nil
    end

    local texts
    local function buildMenuFor(playerObj)
        local menu
        local ok, err = pcall(function()
            CTLDPlayerManager.getInstance():buildMenu(playerObj)
            menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
        end)
        assert(ok, err)
        return menu
    end

    before_each(function()
        ctld.startupReport._entries = {}
        resetSingletons()

        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        trigger.misc.getZone = function(_) return { point = ZONE_CENTER, radius = 300 } end
        env.mission = { triggers = { zones = {
            { name = "LGZ_log1_B" },
            { name = "TRZ_pickup1_B_999_nil_0" },
        } } }

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

        local tm = CTLDTroopManager.getInstance()
        tm._templates = {}
        tm:createLoadableGroup({ name = "Standard Group", composition = { inf = 4 } })
        tm._isInAir              = function() return false end
        tm._findAllNearbyDropped = function() return {} end

        origGetByName = Unit.getByName
        Unit.getByName = function(n)
            if n == PLAYER_UNIT then
                return {
                    getName       = function() return PLAYER_UNIT end,
                    getTypeName   = function() return "UH-1H" end,
                    getCoalition  = function() return coalition.side.BLUE end,
                    getPoint      = function() return ZONE_CENTER end,
                    getPlayerName = function() return "tester" end,
                    isExist       = function() return true end,
                    inAir         = function() return false end,
                    getGroup      = function() return { getID = function() return 9901 end } end,
                }
            end
            return origGetByName and origGetByName(n) or nil
        end
        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return false end

        texts = {}
        origOutText = trigger.action.outTextForGroup
        trigger.action.outTextForGroup = function(_, text) texts[#texts + 1] = text end
    end)

    after_each(function()
        Unit.getByName                 = origGetByName
        ctld.utils.inAir               = origInAir
        trigger.action.outTextForGroup = origOutText
        env.mission                    = savedMission
        trigger.misc.getZone           = savedGetZone
        resetSingletons()
        ctld.startupReport._entries = {}
    end)

    it("Request Equipment: a crate request from an auto-discovered logistic zone is not refused", function()
        local zm = CTLDZoneManager.getInstance()
        assert.is_not_nil(zm:getLogisticZone("LGZ_log1_B"))   -- precondition: registered by full name

        local menu = buildMenuFor(makePlayer())
        local reqNode = menu:_getNode({ ROOT, tr("Request Equipment") })
        assert.is_not_nil(reqNode)
        local cmd = firstCommand(reqNode)
        assert.is_not_nil(cmd, "Request Equipment lists no crate for the player")

        pcall(cmd.functionToCall, cmd.anyArgument)

        for _, t in ipairs(texts) do
            assert.are_not.equals(
                tr("You are not close enough to friendly logistics to get a crate!"), t)
        end
    end)

    it("Request Equipment: the zone submenu is labelled by the registry key, never the short name", function()
        local menu = buildMenuFor(makePlayer())
        assert.is_not_nil(menu:_getNode({ ROOT, tr("Request Equipment"), "LGZ_log1_B" }))
        assert.is_nil(menu:_getNode({ ROOT, tr("Request Equipment"), "log1" }))
    end)

    it("Request Equipment: two zones sharing a short name get two separate submenus", function()
        local zm = CTLDZoneManager.getInstance()
        for _, key in ipairs({ "LGZ_dup_B", "LGZ_dup_B2" }) do
            zm._logisticZones[key] = CTLDLogisticZone:new({
                name = "dup", dcsName = key, coalition = coalition.side.BLUE,
                center = ZONE_CENTER, radius = 300, active = true,
            })
        end
        local menu = buildMenuFor(makePlayer())
        local first  = menu:_getNode({ ROOT, tr("Request Equipment"), "LGZ_dup_B" })
        local second = menu:_getNode({ ROOT, tr("Request Equipment"), "LGZ_dup_B2" })
        assert.is_not_nil(first)
        assert.is_not_nil(second)
        assert.are_not.equals(first, second)
        assert.equals("LGZ_dup_B",  firstCommand(first).anyArgument.zoneName)
        assert.equals("LGZ_dup_B2", firstCommand(second).anyArgument.zoneName)
    end)

    it("Load from <zone>: two troop zones sharing a short name get two separate entries", function()
        env.mission = { triggers = { zones = {
            { name = "TRZ_dup_B_999_nil_0" },
            { name = "TRZ_dup_B_999_nil_1" },
        } } }
        CTLDZoneManager._instance = nil
        resetSingletons()
        EventDispatcher.getInstance()
        CTLDDCSEventBridge.getInstance()
        CTLDZoneManager.getInstance()
        CTLDPlayerManager.getInstance()
        local tm = CTLDTroopManager.getInstance()
        tm._templates = {}
        tm:createLoadableGroup({ name = "Standard Group", composition = { inf = 4 } })
        tm._isInAir              = function() return false end
        tm._findAllNearbyDropped = function() return {} end

        local menu = buildMenuFor(makePlayer())
        local base = { ROOT, tr("Troop Commands"), tr("Embark / Extract Troops") }
        local function path(label) return { base[1], base[2], base[3], tr("Load from %1", label) } end
        local first  = menu:_getNode(path("TRZ_dup_B_999_nil_0"))
        local second = menu:_getNode(path("TRZ_dup_B_999_nil_1"))
        assert.is_not_nil(first)
        assert.is_not_nil(second)
        assert.equals("TRZ_dup_B_999_nil_0", firstCommand(first).anyArgument.zoneName)
        assert.equals("TRZ_dup_B_999_nil_1", firstCommand(second).anyArgument.zoneName)
    end)

    it("Request Equipment: a request is still refused once the zone is inactive", function()
        local menu = buildMenuFor(makePlayer())
        local cmd = firstCommand(menu:_getNode({ ROOT, tr("Request Equipment") }))
        CTLDZoneManager.getInstance():getLogisticZone("LGZ_log1_B"):deactivate()

        pcall(cmd.functionToCall, cmd.anyArgument)

        local refused = false
        for _, t in ipairs(texts) do
            if t == tr("You are not close enough to friendly logistics to get a crate!") then refused = true end
        end
        assert.is_true(refused)
    end)

    it("Load from <zone>: a troop load from an auto-discovered troop zone reaches embarkFromTroopZone", function()
        local zm = CTLDZoneManager.getInstance()
        local zone = zm:getTroopZone("TRZ_pickup1_B_999_nil_0")
        assert.is_not_nil(zone)   -- precondition: registered by full name

        local embarked
        local tm = CTLDTroopManager.getInstance()
        local origEmbark = tm.embarkFromTroopZone
        tm.embarkFromTroopZone = function(_, _, z) embarked = z end

        local menu = buildMenuFor(makePlayer())
        local loadNode = menu:_getNode({ ROOT, tr("Troop Commands"), tr("Embark / Extract Troops"),
                                         tr("Load from %1", "TRZ_pickup1_B_999_nil_0") })
        assert.is_not_nil(loadNode, "no Load from entry for the auto-discovered zone")
        local cmd = firstCommand(loadNode)
        assert.is_not_nil(cmd)

        cmd.functionToCall(cmd.anyArgument)
        tm.embarkFromTroopZone = origEmbark

        for _, t in ipairs(texts) do assert.are_not.equals(tr("Zone not found."), t) end
        assert.equals(zone, embarked)
    end)

end)
