---@diagnostic disable
-- FIX-REQUEST-EQUIPMENT-SILENT-FAILURE: a Request Equipment click that produces nothing tells the pilot and logs an ERROR
-- (it used to do nothing at all, and a failed vehicle still announced "Vehicle ready for loading").
-- The menu is built by the real builder over a real zone manager and the callback is the real one read back from the menu
-- node; the object creation is a double that can be made to fail.
-- ============================================================

describe("Request Equipment reports a request that produced nothing", function()

    local tr = ctld.tr
    local ROOT = tr("CTLD")
    local PLAYER_UNIT = "UH2_rf1"
    local CX, CZ = 100, 200
    local FAILURE = "Request failed: the equipment could not be brought out."

    local savedMission, savedGetZone, origGetByName, origInAir, origOutText, origGs, origLog
    local playerType, playerCountry, testLang, messages, logs

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

    local function findCommand(node, accept)
        if node.type == "command" then
            if node.anyArgument and accept(node.anyArgument) then return node end
            return nil
        end
        for _, child in ipairs(node.children or {}) do
            local found = findCommand(child, accept)
            if found then return found end
        end
        return nil
    end

    local function isSingle(a)  return a.unit and not a.spawnAsVehicle and not a.multiple end
    local function isSet(a)     return a.multiple ~= nil end
    local function isVehicle(a) return a.spawnAsVehicle == true end

    local function menuNode(accept)
        local playerObj = {
            unitName = PLAYER_UNIT, groupId = 9903, groupName = "Grp_rf1", coalition = coalition.side.BLUE,
            typeName = playerType, isTransport = true, canCarryVehicles = false,
        }
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        local menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
        local cmd = findCommand(menu:_getNode({ ROOT, tr("Request Equipment") }), accept)
        assert.is_not_nil(cmd, "Request Equipment lists no such item")
        return cmd
    end

    local function click(accept)
        local cmd = menuNode(accept)
        cmd.functionToCall(cmd.anyArgument)
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

    before_each(function()
        ctld.startupReport._entries = {}
        resetSingletons()
        playerType, playerCountry, testLang, messages, logs = "UH-1H", country.id.USA, nil, {}, {}
        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        origGs, origLog = ctld.gs, ctld.utils.log
        trigger.misc.getZone = function(_) return { point = { x = CX, y = 0, z = CZ }, radius = 300 } end
        env.mission = { triggers = { zones = { { name = "LGZ_log1_B" } } } }

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
                    getTypeName   = function() return playerType end,
                    getCoalition  = function() return coalition.side.BLUE end,
                    getCountry    = function() return playerCountry end,
                    getPoint      = function() return { x = CX, y = 0, z = CZ } end,
                    getPosition   = function()
                        return { p = { x = CX, y = 0, z = CZ }, x = { x = 1, y = 0, z = 0 },
                                 y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
                    end,
                    getDesc       = function() return { box = { min = { x = -8, y = -1.6, z = -1.6 }, max = { x = 4, y = 1.6, z = 1.6 } } } end,
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
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end
        ctld.utils.log = function(level, fmt, ...)
            logs[#logs + 1] = { level = level, text = select("#", ...) > 0 and string.format(fmt, ...) or fmt }
        end
        ctld.gs = function(k)
            if k == "i18n_lang" and testLang then return testLang end
            return origGs(k)
        end
    end)

    after_each(function()
        Unit.getByName                 = origGetByName
        ctld.utils.inAir               = origInAir
        ctld.utils.log                 = origLog
        ctld.gs                        = origGs
        trigger.action.outTextForGroup = origOutText
        env.mission                    = savedMission
        trigger.misc.getZone           = savedGetZone
        resetSingletons()
        ctld.startupReport._entries = {}
    end)

    describe("a single crate", function()

        it("whose creation returns nothing tells the pilot and logs an ERROR", function()
            CTLDCrateManager.getInstance().spawnCratesAligned = function() return 0, { clock = "3", positions = {} } end
            click(isSingle)
            assert.is_true(said(tr(FAILURE)))
            assert.is_true(logged("ERROR", "Request Equipment"))
        end)

        it("on a type with no spawn plan (radial path) whose creation returns nothing does the same", function()
            playerType = "Plain"
            local origCaps = origGs("capabilitiesByType")
            ctld.gs = function(k)
                if k == "capabilitiesByType" then
                    local caps = {}
                    for name, c in pairs(origCaps) do caps[name] = c end
                    caps["Plain"] = { cratesEnabled = true, troopsEnabled = true }
                    return caps
                end
                return origGs(k)
            end
            CTLDCrateManager.getInstance().spawnCrate = function() return nil end
            click(isSingle)
            assert.is_true(said(tr(FAILURE)))
            assert.is_true(logged("ERROR", "Request Equipment"))
        end)

        it("whose descriptor cannot be found tells the pilot and logs an ERROR", function()
            CTLDCrateManager.getInstance().findDescriptorByTypeName = function() return nil end
            click(isSingle)
            assert.is_true(said(tr(FAILURE)))
            assert.is_true(logged("ERROR", "descriptor"))
        end)

        it("is announced in French when the language is French", function()
            testLang = "fr"
            CTLDCrateManager.getInstance().spawnCratesAligned = function() return 0, { clock = "3", positions = {} } end
            click(isSingle)
            assert.is_true(said("Échec de la demande : l'équipement n'a pas pu être sorti."))
        end)

        it("that is created gives no failure message (control)", function()
            CTLDCrateManager.getInstance().spawnCratesAligned = function() return 1, { clock = "3", positions = {} } end
            click(isSingle)
            assert.is_false(said(tr(FAILURE)))
            assert.is_false(logged("ERROR", "Request Equipment"))
        end)

        -- FIX-REVIEW-HYGIENE-B ticket 03 (issue #255): the sling model declares no size, so the row is refused
        -- and the single crate takes the path of a type with no spawn plan.
        it("in a slingLoad mission takes the path of a type with no spawn plan, even on a type that declares one", function()
            ctld.gs = function(k)
                if k == "slingLoad" then return true end
                return origGs(k)
            end
            local cm = CTLDCrateManager.getInstance()
            local aligned, modelKey = false, nil
            cm.spawnCratesAligned = function() aligned = true; return 1, { clock = "3", positions = {} } end
            cm.spawnCrate = function(_, _, _, _, _, _, _, key) modelKey = key; return true end
            click(isSingle)
            assert.is_false(aligned)
            assert.equals("sling", modelKey)
            assert.is_false(said(tr(FAILURE)))
        end)

    end)

    describe("a set of crates", function()

        it("of which none is created tells the pilot and logs an ERROR", function()
            CTLDCrateManager.getInstance().spawnCratesAligned = function() return 0, { clock = "3", positions = {} } end
            click(isSet)
            assert.is_true(said(tr(FAILURE)))
            assert.is_true(logged("ERROR", "Request Equipment"))
        end)

        it("of which only some are created keeps its count message and logs a WARNING", function()
            CTLDCrateManager.getInstance().spawnCratesAligned = function(_, descriptors)
                return #descriptors - 1, { clock = "3", positions = {} }
            end
            click(isSet)
            assert.is_false(said(tr(FAILURE)))
            assert.is_true(logged("WARNING", "Request Equipment"))
        end)

        it("that is fully created gives no failure message (control)", function()
            CTLDCrateManager.getInstance().spawnCratesAligned = function(_, descriptors)
                return #descriptors, { clock = "3", positions = {} }
            end
            click(isSet)
            assert.is_false(said(tr(FAILURE)))
        end)

    end)

    describe("a whole vehicle", function()

        before_each(function() playerType = "C-130J-30" end)

        it("whose creation returns nothing tells the pilot instead of announcing it ready", function()
            CTLDVehicleSpawner.getInstance().spawnVehicleForTransport = function() return nil end
            local cmd = menuNode(isVehicle)
            cmd.functionToCall(cmd.anyArgument)
            assert.is_true(said(tr(FAILURE)))
            assert.is_false(said(tr("Vehicle ready for loading", cmd.anyArgument.desc)))
            assert.is_true(logged("ERROR", "Request Equipment"))
        end)

        it("that is created is announced ready, without a failure message (control)", function()
            CTLDVehicleSpawner.getInstance().spawnVehicleForTransport = function() return { id = "veh_1" } end
            local cmd = menuNode(isVehicle)
            cmd.functionToCall(cmd.anyArgument)
            assert.is_true(said(tr("Vehicle ready for loading", cmd.anyArgument.desc)))
            assert.is_false(said(tr(FAILURE)))
        end)

    end)

    -- FIX-SPAWN-COUNTRY-FALLBACK: a VEAF campaign mission, whose blue holds only CJTF Blue. USA is in no coalition and
    -- DCS refuses a static created under it; the crate used to default to USA and never appeared.
    describe("in a mission whose blue coalition holds only CJTF Blue", function()

        local CJTF_BLUE = 80
        local origCountryCoalition, origAddStatic, origStaticByName, created

        before_each(function()
            playerCountry = CJTF_BLUE
            country.name[CJTF_BLUE], country.id.CJTF_BLUE = "CJTF_BLUE", CJTF_BLUE
            created = {}
            origCountryCoalition, origAddStatic = coalition.getCountryCoalition, coalition.addStaticObject
            origStaticByName = StaticObject.getByName
            coalition.getCountryCoalition = function(cId)
                return cId == CJTF_BLUE and coalition.side.BLUE or coalition.side.NEUTRAL
            end
            coalition.addStaticObject = function(cId, data)
                if coalition.getCountryCoalition(cId) == coalition.side.NEUTRAL then
                    error("country " .. cId .. " not in a coalition")
                end
                created[data.name] = cId
                return { getName = function() return data.name end }
            end
            StaticObject.getByName = function(name) return created[name] and { _name = name } or nil end
        end)

        after_each(function()
            coalition.getCountryCoalition = origCountryCoalition
            coalition.addStaticObject     = origAddStatic
            StaticObject.getByName        = origStaticByName
            country.name[CJTF_BLUE], country.id.CJTF_BLUE = nil, nil
        end)

        local function createdUnder()
            local list = {}
            for _, cId in pairs(created) do list[#list + 1] = cId end
            return list
        end

        it("brings the single crate out under the pilot's country", function()
            click(isSingle)
            local under = createdUnder()
            assert.equals(1, #under)
            assert.equals(CJTF_BLUE, under[1])
            assert.is_false(said(tr(FAILURE)))
        end)

        it("brings every crate of a set out under the pilot's country", function()
            click(isSet)
            local under = createdUnder()
            assert.is_true(#under > 1)
            for _, cId in ipairs(under) do assert.equals(CJTF_BLUE, cId) end
            assert.is_false(said(tr(FAILURE)))
        end)

        it("tells the pilot and logs the DCS error at WARNING when DCS refuses the crate", function()
            coalition.addStaticObject = function(cId) error("country " .. cId .. " refused") end
            click(isSingle)
            assert.is_true(said(tr(FAILURE)))
            assert.is_true(logged("WARNING", "refused"))
        end)

    end)

end)
