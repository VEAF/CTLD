---@diagnostic disable
-- tests/ci/unit/static_watcher_spec.lua
-- busted specs for CTLDStaticWatcher: watch/unwatch/_tick, and the collision-overwrite WARN
-- added while reviewing FEAT-FARP-TROOP-PICKUP (PR #137) — watch() previously replaced an
-- existing entry for the same id with no log line at all.
-- ============================================================

describe("CTLDStaticWatcher", function()

    local sw

    before_each(function()
        CTLDStaticWatcher._instance = nil
        sw = CTLDStaticWatcher.getInstance()
    end)

    it("fires onDeadFn exactly once when checkFn turns false, then stops watching it", function()
        local fired = 0
        sw:watch("id1", function() return false end, function() fired = fired + 1 end)
        sw:_tick(0)
        sw:_tick(0)
        assert.equals(1, fired)
        assert.is_nil(sw._watched["id1"])
    end)

    it("keeps watching while checkFn returns true", function()
        local fired = 0
        sw:watch("id1", function() return true end, function() fired = fired + 1 end)
        sw:_tick(0)
        assert.equals(0, fired)
        assert.is_not_nil(sw._watched["id1"])
    end)

    it("unwatch removes an entry before it ever fires", function()
        local fired = 0
        sw:watch("id1", function() return false end, function() fired = fired + 1 end)
        sw:unwatch("id1")
        sw:_tick(0)
        assert.equals(0, fired)
    end)

    it("logs a WARN when watch() overwrites a still-live entry for the same id", function()
        local origLog = ctld.utils.log
        local warned = {}
        ctld.utils.log = function(level, ...)
            if level == "WARN" then warned[#warned + 1] = string.format(...) end
            return origLog(level, ...)
        end

        sw:watch("dup", function() return true end, function() end)
        sw:watch("dup", function() return true end, function() end)

        ctld.utils.log = origLog
        assert.equals(1, #warned)
        assert.matches("dup", warned[1])
    end)

    it("does not warn when watch() is called for a fresh id", function()
        local origLog = ctld.utils.log
        local warned = {}
        ctld.utils.log = function(level, ...)
            if level == "WARN" then warned[#warned + 1] = string.format(...) end
            return origLog(level, ...)
        end

        sw:watch("fresh", function() return true end, function() end)

        ctld.utils.log = origLog
        assert.equals(0, #warned)
    end)

end)
