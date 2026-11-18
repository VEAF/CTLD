---@diagnostic disable
-- FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS ticket 04 (issue #309, ADR 0029): forbidUnpackInLogisticZone.
-- When on, an ordinary crate (vehicle, equipment) is not unpacked inside a friendly logistic zone: the Unpack Crate menu
-- refuses with the v1 message and consumes nothing, and a parachuted crate does not unpack by itself there. Off by default:
-- nothing changes. The menu is built by the real builder and the callback is the real one read back from the menu node;
-- the logistic zone is a double (a disc around the pilot) so the position decides, as in the game.
-- ============================================================

describe("forbidUnpackInLogisticZone", function()

    local tr = ctld.tr
    local ROOT = tr("CTLD")
    local PLAYER_UNIT = "UH2_lgz1"
    local CX, CZ = 100, 200
    local REFUSAL = "You can't unpack that here! Take it to where it's needed!"
    local SUCCESS = "Test Jeep unpacked successfully!"

    local origGetByName, origInAir, origOutText, origGs, origSpawn, origPostSpawn
    local messages, forbid, zoneCoalition

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

    -- A friendly (or other) logistic zone: the disc of 100 m around (CX, CZ), for the coalition asked.
    local function stubZone()
        local zm = CTLDZoneManager.getInstance()
        zm.getLogisticZoneAtPoint = function(_, point, coa)
            if zoneCoalition ~= 0 and coa ~= 0 and zoneCoalition ~= coa then return nil end
            if math.abs(point.x - CX) < 100 and math.abs(point.z - CZ) < 100 then return { name = "LGZ" } end
            return nil
        end
    end

    local function addCrate(name, x, parachute)
        local desc = { desc = "Test Jeep", unit = "Hummer", weight = 100, cratesRequired = 1 }
        local crate = CTLDCrate:new({
            crateName = name, descriptor = desc, spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position = { x = x, y = 0, z = CZ }, coalition = coalition.side.BLUE,
        })
        crate.fromParachute = parachute or false
        crate.dcsStatic = { isExist = function() return true end, getPoint = function() return crate.position end,
                            destroy = function() end }
        CTLDCrateManager.getInstance().crates[name] = crate
        return crate
    end

    -- Click the Unpack Crate entry of a crate next to the pilot.
    local function clickUnpack()
        addCrate("lgz1", CX + 5)
        local playerObj = {
            unitName = PLAYER_UNIT, groupId = 9905, groupName = "Grp_lgz1", coalition = coalition.side.BLUE,
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

    local function crateStillThere(name)
        local c = CTLDCrateManager.getInstance().crates[name]
        return c ~= nil and c:isOnGround()
    end

    before_each(function()
        ctld.startupReport._entries = {}
        resetSingletons()
        messages, forbid, zoneCoalition = {}, true, coalition.side.BLUE
        origGs = ctld.gs
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
        stubZone()

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
                    getGroup      = function() return { getID = function() return 9905 end } end,
                }
            end
            return origGetByName and origGetByName(n) or nil
        end
        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return false end
        origOutText = trigger.action.outTextForGroup
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end
        ctld.gs = function(k)
            if k == "forbidUnpackInLogisticZone" then return forbid end
            return origGs(k)
        end
        origSpawn = ctld.utils.spawnFromDescriptor
        ctld.utils.spawnFromDescriptor = function() return true end
        origPostSpawn = CTLDCrateManager._dispatchPostSpawn
        CTLDCrateManager._dispatchPostSpawn = function() end
    end)

    after_each(function()
        Unit.getByName                 = origGetByName
        ctld.utils.inAir               = origInAir
        ctld.gs                        = origGs
        ctld.utils.spawnFromDescriptor = origSpawn
        CTLDCrateManager._dispatchPostSpawn = origPostSpawn
        trigger.action.outTextForGroup = origOutText
        resetSingletons()
        ctld.startupReport._entries = {}
    end)

    describe("the Unpack Crate menu", function()

        it("refuses inside a friendly logistic zone, with the v1 message, and keeps the crate", function()
            clickUnpack()
            assert.is_true(said(REFUSAL))
            assert.is_false(said(SUCCESS))
            assert.is_true(crateStillThere("lgz1"))
        end)

        it("unpacks as before when the option is off", function()
            forbid = false
            clickUnpack()
            assert.is_true(said(SUCCESS))
            assert.is_false(said(REFUSAL))
            assert.is_nil(CTLDCrateManager.getInstance().crates["lgz1"])
        end)

        it("unpacks outside any logistic zone even when the option is on", function()
            CTLDZoneManager.getInstance().getLogisticZoneAtPoint = function() return nil end
            clickUnpack()
            assert.is_true(said(SUCCESS))
            assert.is_false(said(REFUSAL))
        end)

        it("is not stopped by a logistic zone of the other coalition", function()
            zoneCoalition = coalition.side.RED
            clickUnpack()
            assert.is_true(said(SUCCESS))
            assert.is_false(said(REFUSAL))
        end)

    end)

    describe("a parachuted crate that lands by itself", function()

        it("is not unpacked inside a friendly logistic zone", function()
            local c = addCrate("lgzp1", CX + 10, true)
            CTLDCrateManager.getInstance():_checkAutoUnpack(c)
            assert.is_true(crateStillThere("lgzp1"))
        end)

        it("is unpacked there when the option is off", function()
            forbid = false
            local c = addCrate("lgzp1", CX + 10, true)
            CTLDCrateManager.getInstance():_checkAutoUnpack(c)
            assert.is_nil(CTLDCrateManager.getInstance().crates["lgzp1"])
        end)

        it("is unpacked outside the zone even when the option is on", function()
            local c = addCrate("lgzp1", CX + 500, true)
            CTLDCrateManager.getInstance():_checkAutoUnpack(c)
            assert.is_nil(CTLDCrateManager.getInstance().crates["lgzp1"])
        end)

    end)

end)
