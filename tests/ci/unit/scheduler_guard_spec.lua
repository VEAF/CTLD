---@diagnostic disable
-- FIX-SCHEDULER-SINGLE-ENTRY ticket 02 (issue #234): every timer goes through
-- ctld.scheduler.schedule, so ctld.scheduler.cancelAll() can cancel it. A direct call to
-- timer.scheduleFunction anywhere else in src/ is invisible to the registry — the exact
-- situation that left 13 of ~15 loops running across a re-injection.
-- ============================================================

describe("timer.scheduleFunction is only called by the scheduler", function()

    -- Repo root, resolved the way the other guard specs do it.
    local ROOT = debug.getinfo(1, "S").source
                    :match("^@(.+)tests[\\/]ci[\\/]unit[\\/]") or ""

    it("no src/ file calls it directly, except the one call inside ctld.scheduler.schedule", function()
        local list = assert(io.open(ROOT .. "tools/build/listToMerge.txt", "r"))
        local offenders, schedulerCalls = {}, 0
        for entry in list:lines() do
            local rel = entry:match("^%s*([%w_/%.%-]+%.lua)%s*$")
            local f = rel and io.open(ROOT .. "src/" .. rel, "r")
            if f then
                local n = 0
                for line in f:lines() do
                    n = n + 1
                    if line:find("timer.scheduleFunction(", 1, true) and not line:match("^%s*%-%-") then
                        if rel == "CTLD_utils.lua" then
                            schedulerCalls = schedulerCalls + 1
                        else
                            offenders[#offenders + 1] = string.format("src/%s:%d  %s", rel, n, line:match("^%s*(.-)%s*$"))
                        end
                    end
                end
                f:close()
            end
        end
        list:close()

        assert.same({}, offenders)
        -- The scheduler itself is the single place allowed to reach DCS: exactly one call.
        assert.equals(1, schedulerCalls)
    end)

end)
