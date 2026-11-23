---@diagnostic disable
-- FIX-VMCT-REVIEW-FINDINGS ticket 05 (issue #326): the coalition messages "%1 started building a FOB" and
-- the three AA "deployed / rearmed / repaired" messages name the player, else the unit's type name, as
-- v1's ctld.getPlayerNameOrType did. They showed the unit name. Event payloads are unchanged.
-- ============================================================

local function makeHeli(playerName)
    return {
        getPoint      = function() return { x = 1000, y = 0, z = 2000 } end,
        getPosition   = function()
            return { x = { x = 1, y = 0, z = 0 }, p = { x = 1000, y = 0, z = 2000 } }
        end,
        getCoalition  = function() return coalition.side.BLUE end,
        getCountry    = function() return country.id.USA end,
        getName       = function() return "UH-1H-Slot-7" end,
        getTypeName   = function() return "UH-1H" end,
        getPlayerName = function() return playerName end,
        getGroup      = function() return { getID = function() return 1 end } end,
        isExist       = function() return true end,
        inAir         = function() return false end,
    }
end

describe("ctld.utils.getPlayerNameOrType (#326)", function()

    it("returns the player's name when a player sits in the unit", function()
        assert.equals("Zip", ctld.utils.getPlayerNameOrType(makeHeli("Zip")))
    end)

    it("returns the unit's type name for an AI unit", function()
        assert.equals("UH-1H", ctld.utils.getPlayerNameOrType(makeHeli(nil)))
    end)

    it("returns the type name when DCS gives an empty player name", function()
        assert.equals("UH-1H", ctld.utils.getPlayerNameOrType(makeHeli("")))
    end)

end)

describe("coalition messages name the player (#326)", function()

    local origOutCoalition, origPublish
    local texts, events

    local function saidContaining(fragment)
        for _, t in ipairs(texts) do
            if t:find(fragment, 1, true) then return true end
        end
        return false
    end

    before_each(function()
        texts, events = {}, {}
        origOutCoalition = trigger.action.outTextForCoalition
        trigger.action.outTextForCoalition = function(_, text) texts[#texts + 1] = text end
        EventDispatcher._instance = nil
        local ed = EventDispatcher.getInstance()
        origPublish = ed.publish
        ed.publish = function(self, name, payload)
            events[name] = payload
            return origPublish(self, name, payload)
        end
    end)

    after_each(function()
        trigger.action.outTextForCoalition = origOutCoalition
        EventDispatcher._instance = nil
    end)

    -- ── FOB ───────────────────────────────────────────────────
    describe("FOB construction", function()

        local origGs, played
        local fm, cm, sm, zm
        local saved = {}

        before_each(function()
            CTLDFOBManager._instance     = nil
            CTLDCrateManager._instance   = nil
            CTLDSceneManager._instance   = nil
            CTLDZoneManager._instance    = nil
            played = nil
            origGs = ctld.gs
            ctld.gs = function(k)
                if k == "enabledFOBBuilding" then return true end
                return origGs(k)
            end
            fm = CTLDFOBManager.getInstance()
            cm = CTLDCrateManager.getInstance()
            sm = CTLDSceneManager.getInstance()
            zm = CTLDZoneManager.getInstance()
            local crates = {}
            for i = 1, 3 do
                crates[i] = { crateName = "fob_c" .. i, coalition = coalition.side.BLUE,
                              descriptor = { unit = "FOB", cratesRequired = 3 } }
            end
            saved.getCratesInRange = cm.getCratesInRange
            saved.destroyCrate     = cm.destroyCrate
            saved.getModel         = sm.getModel
            saved.playScene        = sm.playScene
            saved.lgzAt            = zm.getLogisticZoneAtPoint
            saved.lgzFor           = zm.getLogisticZonesForCoalition
            cm.getCratesInRange = function() return crates end
            cm.destroyCrate     = function() end
            sm.getModel         = function() return { crate = { cratesRequired = 3, fobCompatible = true } } end
            sm.playScene        = function(_, _, _, params) played = params end
            zm.getLogisticZoneAtPoint       = function() return nil end
            zm.getLogisticZonesForCoalition = function() return {} end
        end)

        after_each(function()
            ctld.gs = origGs
            cm.getCratesInRange, cm.destroyCrate = saved.getCratesInRange, saved.destroyCrate
            sm.getModel, sm.playScene            = saved.getModel, saved.playScene
            zm.getLogisticZoneAtPoint, zm.getLogisticZonesForCoalition = saved.lgzAt, saved.lgzFor
            CTLDFOBManager._instance   = nil
            CTLDCrateManager._instance = nil
            CTLDSceneManager._instance = nil
            CTLDZoneManager._instance  = nil
        end)

        it("names the player who started building", function()
            fm:unpackFOBCrates(makeHeli("Zip"), "UH-1H-Slot-7", "FOB")
            assert.is_true(saidContaining("Zip started building a FOB"))
        end)

        it("names the type of an AI transport", function()
            fm:unpackFOBCrates(makeHeli(nil), "UH-1H-Slot-7", "FOB")
            assert.is_true(saidContaining("UH-1H started building a FOB"))
        end)

        it("keeps the unit name as the scene's player parameter", function()
            fm:unpackFOBCrates(makeHeli("Zip"), "UH-1H-Slot-7", "FOB")
            assert.equals("UH-1H-Slot-7", played.player)
        end)

    end)

    -- ── AA systems ────────────────────────────────────────────
    describe("AA systems", function()

        local m, cm, origGetHeading
        local hawk

        local function findTemplate(name)
            for _, t in ipairs(CTLDCrateAssemblyManager.TEMPLATES) do
                if t.name == name then return t end
            end
            error("template not found: " .. name)
        end

        local function liveUnit(typeName)
            return {
                getLife     = function() return 1 end,
                getTypeName = function() return typeName end,
                getPoint    = function() return { x = 1000, y = 0, z = 2000 } end,
            }
        end

        before_each(function()
            CTLDCrateAssemblyManager._instance = nil
            CTLDCrateManager._instance         = nil
            m  = CTLDCrateAssemblyManager.getInstance()
            cm = CTLDCrateManager.getInstance()
            hawk = findTemplate("HAWK AA System")
            m._spawnGroup = function()
                return { getName = function() return "new_aa_group" end, getUnits = function() return {} end }
            end
            m._getDetails = function() return {} end
            cm.destroyCrate = function() end
            origGetHeading = ctld.utils.getHeadingInRadians
            ctld.utils.getHeadingInRadians = function() return 0 end
        end)

        after_each(function()
            ctld.utils.getHeadingInRadians     = origGetHeading
            CTLDCrateManager._instance         = nil
            CTLDCrateAssemblyManager._instance = nil
        end)

        local function assembleHawk(heli)
            local allCrates, clicked, idx = {}, nil, 0
            for _, part in ipairs(hawk.parts) do
                if not part.NoCrate then
                    idx = idx + 1
                    local c = {
                        crateName  = "hawk_c" .. idx,
                        position   = { x = 1000 + idx, y = 0, z = 2000 + idx },
                        coalition  = coalition.side.BLUE,
                        descriptor = { unit = part.DCSTypename, cratesRequired = 1 },
                        isOnGround = function() return true end,
                        destroy    = function() end,
                    }
                    cm.crates[c.crateName] = c
                    allCrates[c.crateName] = c
                    if not part.launcher and not clicked then clicked = c end
                end
            end
            m:_assemble(heli, clicked, allCrates, hawk, 500)
        end

        local function nearHawkGroup()
            local units = {}
            for _, part in ipairs(hawk.parts) do units[#units + 1] = liveUnit(part.DCSTypename) end
            local grp = {
                getName  = function() return "old_aa_group" end,
                getUnits = function() return units end,
                destroy  = function() end,
            }
            m._completeSystems["old_aa_group"] = { details = {}, template = hawk }
            m._findNearest = function() return { dist = 0, group = grp } end
        end

        it("a deployed system names the player, an AI deployment the type", function()
            assembleHawk(makeHeli("Zip"))
            assert.is_true(saidContaining("Zip successfully deployed a full HAWK AA System"))
            texts = {}
            assembleHawk(makeHeli(nil))
            assert.is_true(saidContaining("UH-1H successfully deployed a full HAWK AA System"))
        end)

        it("a rearmed system names the player, or the type", function()
            nearHawkGroup()
            m:_rearm(makeHeli("Zip"), { crateName = "launcher" }, {}, hawk)
            assert.is_true(saidContaining("Zip successfully rearmed a full HAWK AA System"))
            texts = {}
            nearHawkGroup()
            m:_rearm(makeHeli(nil), { crateName = "launcher" }, {}, hawk)
            assert.is_true(saidContaining("UH-1H successfully rearmed a full HAWK AA System"))
        end)

        it("a repaired system names the player, or the type", function()
            nearHawkGroup()
            m:_repair(makeHeli("Zip"), { crateName = "repair" }, hawk)
            assert.is_true(saidContaining("Zip successfully repaired a full HAWK AA System"))
            texts = {}
            nearHawkGroup()
            m:_repair(makeHeli(nil), { crateName = "repair" }, hawk)
            assert.is_true(saidContaining("UH-1H successfully repaired a full HAWK AA System"))
        end)

        it("leaves the event payloads unchanged: heli is still the unit", function()
            local heli = makeHeli("Zip")
            nearHawkGroup()
            m:_repair(heli, { crateName = "repair" }, hawk)
            assert.equals(heli, events["OnAASystemRepaired"].heli)
        end)

    end)

end)
