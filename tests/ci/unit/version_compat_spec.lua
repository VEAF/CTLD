---@diagnostic disable
-- tests/ci/unit/version_compat_spec.lua
-- ctld.utils.compareVersions + registerSceneModel requiresCtld check (ADR 0006).
-- A plugin scene may declare model.requiresCtld; if CTLD is older, a WARN is emitted but the
-- scene still registers (best-effort, not a hard fail).
-- Ticket: .backlog/SCENE-PLUGINS/tickets/04-requiresctld-version-check.md
-- ============================================================

describe("ctld.utils.compareVersions", function()

    local cmp = function(a, b) return ctld.utils.compareVersions(a, b) end

    it("equal versions → 0", function()
        assert.equals(0, cmp("2.0.0", "2.0.0"))
    end)

    it("higher patch → 1 / -1", function()
        assert.equals(1,  cmp("2.0.1", "2.0.0"))
        assert.equals(-1, cmp("2.0.0", "2.0.1"))
    end)

    it("minor dominates patch", function()
        assert.equals(1,  cmp("2.1.0", "2.0.9"))
    end)

    it("major dominates minor", function()
        assert.equals(1,  cmp("3.0.0", "2.9.9"))
    end)

    it("a release outranks the same version's pre-release", function()
        assert.equals(1,  cmp("2.0.0", "2.0.0-rc1"))
        assert.equals(-1, cmp("2.0.0-rc1", "2.0.0"))
    end)

    it("pre-release numbers compare numerically", function()
        assert.equals(-1, cmp("2.0.0-rc1", "2.0.0-rc2"))
        assert.equals(1,  cmp("2.0.0-rc10", "2.0.0-rc2"))
        assert.equals(0,  cmp("2.0.0-rc1", "2.0.0-rc1"))
    end)

end)

describe("CTLDSceneManager:registerSceneModel requiresCtld", function()

    local sm, outTextCalls, origOT

    before_each(function()
        sm = CTLDSceneManager.getInstance()
        outTextCalls = {}
        origOT = trigger.action.outText
        trigger.action.outText = function(msg, dur)
            outTextCalls[#outTextCalls + 1] = msg
            return origOT(msg, dur)
        end
    end)

    after_each(function()
        trigger.action.outText = origOT
    end)

    local function warned(sceneName)
        for _, msg in ipairs(outTextCalls) do
            if msg:find(sceneName, 1, true) and msg:find("requires CTLD", 1, true) then
                return true
            end
        end
        return false
    end

    it("requiresCtld above running version → WARN, but scene still registers", function()
        sm:registerSceneModel({ name = "TooNewScene",
            requiresCtld = "9.9.9",
            steps = {{ delayAfterPreviousStep = 0, func = function() end }} })
        assert.is_true(warned("TooNewScene"))
        assert.is_true(sm:isSceneEnabled("TooNewScene"))
    end)

    it("requiresCtld at/below running version → no WARN", function()
        sm:registerSceneModel({ name = "OldEnoughScene",
            requiresCtld = "1.0.0",
            steps = {{ delayAfterPreviousStep = 0, func = function() end }} })
        assert.is_false(warned("OldEnoughScene"))
        assert.is_true(sm:isSceneEnabled("OldEnoughScene"))
    end)

    it("no requiresCtld → no WARN", function()
        sm:registerSceneModel({ name = "NoReqScene",
            steps = {{ delayAfterPreviousStep = 0, func = function() end }} })
        assert.is_false(warned("NoReqScene"))
    end)

end)
