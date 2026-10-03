---@diagnostic disable
-- tests/ci/unit/core_manager_spec.lua
-- busted specs for CTLDCoreManager:_initExtractableGroups (INIT-E)
-- No prior art: core_spec.lua only covers CTLDDCSEventBridge — nothing in tests/ci/ exercised
-- any CTLDCoreManager INIT-* function before FEAT-EXTR-GROUP-NAMING-CONVENTION, ticket 01.
-- ============================================================

local function resetAll()
    CTLDCoreManager._instance    = nil
    CTLDPlayerManager._instance  = nil
    ctld.MenuManager._instance   = nil
    EventDispatcher._instance    = nil
    CTLDDCSEventBridge._instance = nil
    CTLDZoneManager._instance    = nil
    CTLDTroopManager._instance   = nil
end

-- Minimal fake DCS Group object — only the methods _initExtractableGroups actually calls.
local function fakeGroup(name, coa)
    return {
        getName      = function() return name end,
        isExist      = function() return true end,
        getCoalition = function() return coa end,
    }
end

describe("CTLDCoreManager:_initExtractableGroups (INIT-E)", function()

    local _origGs, _origGetByName, _origGetGroups
    local cm, tm

    before_each(function()
        resetAll()
        _origGs        = ctld.gs
        _origGetByName = Group.getByName
        _origGetGroups = coalition.getGroups

        tm = CTLDTroopManager.getInstance()
        -- Bypass CTLDCoreManager:init()'s full wiring (event bridge, INIT-B/C/D/A) — this method
        -- reads no `self` field, only the CTLDTroopManager singleton and ctld.gs/DCS globals.
        cm = setmetatable({}, CTLDCoreManager)
    end)

    after_each(function()
        ctld.gs              = _origGs
        Group.getByName       = _origGetByName
        coalition.getGroups   = _origGetGroups
    end)

    describe("EXTR_ convention", function()

        it("registers a group named EXTR_<name>, not otherwise listed", function()
            ctld.gs = function(k)
                if k == "extractableGroups" then return {} end
                return _origGs(k)
            end
            coalition.getGroups = function(side)
                if side == coalition.side.BLUE then
                    return { fakeGroup("EXTR_Civilians", coalition.side.BLUE) }
                end
                return {}
            end

            cm:_initExtractableGroups()
            assert.equals("EXTR_Civilians", tm._droppedGroups[coalition.side.BLUE][1])
        end)

        it("registers a NEUTRAL-coalition EXTR_ group (civilians)", function()
            ctld.gs = function(k)
                if k == "extractableGroups" then return {} end
                return _origGs(k)
            end
            coalition.getGroups = function(side)
                if side == coalition.side.NEUTRAL then
                    return { fakeGroup("EXTR_Refugees", coalition.side.NEUTRAL) }
                end
                return {}
            end

            cm:_initExtractableGroups()
            assert.is_not_nil(tm._droppedGroups[coalition.side.NEUTRAL])
            assert.equals("EXTR_Refugees", tm._droppedGroups[coalition.side.NEUTRAL][1])
        end)

        it("does NOT match a name that merely contains EXTR (substring, not anchored prefix)", function()
            ctld.gs = function(k)
                if k == "extractableGroups" then return {} end
                return _origGs(k)
            end
            coalition.getGroups = function(side)
                if side == coalition.side.BLUE then
                    return { fakeGroup("MyEXTR_Group", coalition.side.BLUE) }
                end
                return {}
            end

            cm:_initExtractableGroups()
            assert.equals(0, #tm._droppedGroups[coalition.side.BLUE])
        end)

        it("does NOT match a name that starts with EXTR but lacks the underscore", function()
            ctld.gs = function(k)
                if k == "extractableGroups" then return {} end
                return _origGs(k)
            end
            coalition.getGroups = function(side)
                if side == coalition.side.BLUE then
                    return { fakeGroup("EXTRACTION Alpha", coalition.side.BLUE),
                             fakeGroup("EXTRACTION_Alpha", coalition.side.BLUE) }
                elseif side == coalition.side.NEUTRAL then
                    return { fakeGroup("EXTREME Recon 1", coalition.side.NEUTRAL) }
                end
                return {}
            end

            cm:_initExtractableGroups()
            assert.equals(0, #tm._droppedGroups[coalition.side.BLUE])
            assert.equals(0, #(tm._droppedGroups[coalition.side.NEUTRAL] or {}))
        end)

        it("silently skips an EXTR_ group absent at init (isExist()==false)", function()
            ctld.gs = function(k)
                if k == "extractableGroups" then return {} end
                return _origGs(k)
            end
            local ghost = fakeGroup("EXTR_Ghost", coalition.side.BLUE)
            ghost.isExist = function() return false end
            coalition.getGroups = function(side)
                if side == coalition.side.BLUE then return { ghost } end
                return {}
            end

            cm:_initExtractableGroups()
            assert.equals(0, #tm._droppedGroups[coalition.side.BLUE])
        end)

    end)

    describe("deduplication against the explicit list", function()

        it("a group both listed AND EXTR_-named registers exactly once", function()
            local group = fakeGroup("EXTR_Shared", coalition.side.RED)
            ctld.gs = function(k)
                if k == "extractableGroups" then return { "EXTR_Shared" } end
                return _origGs(k)
            end
            Group.getByName = function(name)
                if name == "EXTR_Shared" then return group end
                return nil
            end
            coalition.getGroups = function(side)
                if side == coalition.side.RED then return { group } end
                return {}
            end

            cm:_initExtractableGroups()
            local occurrences = 0
            for _, n in ipairs(tm._droppedGroups[coalition.side.RED]) do
                if n == "EXTR_Shared" then occurrences = occurrences + 1 end
            end
            assert.equals(1, occurrences)
        end)

    end)

    describe("explicit list (pre-existing behavior, first coverage)", function()

        it("still registers a listed group found in the mission", function()
            local group = fakeGroup("Infantry1", coalition.side.BLUE)
            ctld.gs = function(k)
                if k == "extractableGroups" then return { "Infantry1" } end
                return _origGs(k)
            end
            Group.getByName = function(name)
                if name == "Infantry1" then return group end
                return nil
            end
            coalition.getGroups = function(_) return {} end

            cm:_initExtractableGroups()
            assert.equals("Infantry1", tm._droppedGroups[coalition.side.BLUE][1])
        end)

        it("silently skips a listed group not found in the mission", function()
            ctld.gs = function(k)
                if k == "extractableGroups" then return { "Ghost" } end
                return _origGs(k)
            end
            Group.getByName     = function(_) return nil end
            coalition.getGroups = function(_) return {} end

            assert.has_no.errors(function() cm:_initExtractableGroups() end)
        end)

    end)

end)
