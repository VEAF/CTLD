---@diagnostic disable
-- FIX-SCHEDULER-SINGLE-ENTRY ticket 01 (issue #234):
-- ctld.scheduler.schedule is the single entry point for timers; cancelAll() cancels every timer
-- still pending, named or not. The DCS `timer` is stubbed: it records what is scheduled and
-- removed, and lets a spec fire a callback the way DCS does (a numeric return reschedules the
-- SAME function id, anything else ends the chain).
-- ============================================================

describe("ctld.scheduler.schedule / cancelAll", function()

    local _origSchedule, _origRemove, _origIds, _origPending
    local nextId, scheduled, removed

    local function fire(id, now)
        local entry = scheduled[id]
        return entry.fn(entry.arg, now or 0)
    end

    before_each(function()
        _origSchedule = timer.scheduleFunction
        _origRemove   = timer.removeFunction
        _origIds      = ctld.scheduler._ids
        _origPending  = ctld.scheduler._pending
        ctld.scheduler._ids     = {}
        ctld.scheduler._pending = {}

        nextId, scheduled, removed = 100, {}, {}
        timer.scheduleFunction = function(fn, arg, t)
            nextId = nextId + 1
            scheduled[nextId] = { fn = fn, arg = arg, t = t }
            return nextId
        end
        timer.removeFunction = function(id) removed[#removed + 1] = id end
    end)

    after_each(function()
        timer.scheduleFunction  = _origSchedule
        timer.removeFunction    = _origRemove
        ctld.scheduler._ids     = _origIds
        ctld.scheduler._pending = _origPending
    end)

    local function removedSet()
        local set, n = {}, 0
        for _, id in ipairs(removed) do
            if not set[id] then set[id] = true; n = n + 1 end
        end
        return set, n
    end

    describe("schedule", function()

        it("returns the DCS function id and passes the first-fire time through", function()
            local id = ctld.scheduler.schedule(function() end, nil, 42)
            assert.equals(101, id)
            assert.equals(42, scheduled[id].t)
        end)

        it("forwards the callback's arguments and returns exactly what the callback returns", function()
            local seenArg, seenNow
            local id = ctld.scheduler.schedule(function(a, now)
                seenArg, seenNow = a, now
                return now + 5
            end, "payload", 0)

            local ret = fire(id, 10)

            assert.equals("payload", seenArg)
            assert.equals(10, seenNow)
            assert.equals(15, ret)
        end)

        it("keeps a self-rescheduling callback pending under the same id", function()
            local id = ctld.scheduler.schedule(function(_, now) return now + 1 end, nil, 0)
            fire(id, 0)
            fire(id, 1)
            ctld.scheduler.cancelAll()
            assert.is_true(removedSet()[id])
        end)

        it("forgets a callback that ends its chain (returns nil)", function()
            local id = ctld.scheduler.schedule(function() return nil end, nil, 0)
            fire(id, 0)
            ctld.scheduler.cancelAll()
            assert.is_nil(removedSet()[id])
        end)

        it("tracks the latest id of a chain that reschedules itself by calling schedule again", function()
            local firstId, secondId
            local function tick()
                secondId = ctld.scheduler.schedule(tick, nil, 1)   -- manual reschedule, new id
            end
            firstId = ctld.scheduler.schedule(tick, nil, 0)
            fire(firstId)

            ctld.scheduler.cancelAll()

            local set = removedSet()
            assert.is_nil(set[firstId])      -- the first one-shot already fired
            assert.is_true(set[secondId])    -- the pending one is cancelled
        end)

    end)

    describe("cancelAll", function()

        it("cancels every pending timer, once, and reports the real count", function()
            local logged
            local _origLog = ctld.utils.log
            ctld.utils.log = function(_, fmt, ...) logged = string.format(fmt, ...) end

            local a = ctld.scheduler.schedule(function(_, now) return now + 1 end, nil, 0)
            local b = ctld.scheduler.schedule(function() end, nil, 0)
            ctld.scheduler.register("named_loop", ctld.scheduler.schedule(function(_, now) return now + 1 end, nil, 0))
            local namedId = ctld.scheduler._ids["named_loop"]

            ctld.scheduler.cancelAll()
            ctld.utils.log = _origLog

            local set, n = removedSet()
            assert.is_true(set[a]); assert.is_true(set[b]); assert.is_true(set[namedId])
            assert.equals(3, n)
            assert.equals(3, #removed)   -- the named id is in both sets but cancelled once
            assert.truthy(logged:find("3 timer", 1, true))
        end)

        it("leaves both registries empty so scheduling works again afterwards", function()
            ctld.scheduler.schedule(function() end, nil, 0)
            ctld.scheduler.register("named_loop", 999)
            ctld.scheduler.cancelAll()

            assert.is_nil(next(ctld.scheduler._ids))
            assert.is_nil(next(ctld.scheduler._pending))
            local id = ctld.scheduler.schedule(function() end, nil, 0)
            assert.is_not_nil(id)
        end)

    end)

    describe("register / cancel", function()

        it("register replaces and cancels a previous id of the same name", function()
            ctld.scheduler.register("loop", 1)
            ctld.scheduler.register("loop", 2)
            assert.equals(2, ctld.scheduler._ids["loop"])
            assert.is_true(removedSet()[1])
        end)

        it("cancel drops the named id from both registries", function()
            local id = ctld.scheduler.schedule(function(_, now) return now + 1 end, nil, 0)
            ctld.scheduler.register("loop", id)
            ctld.scheduler.cancel("loop")

            assert.is_nil(ctld.scheduler._ids["loop"])
            assert.is_true(removedSet()[id])
            removed = {}
            ctld.scheduler.cancelAll()
            assert.equals(0, #removed)   -- nothing left pending
        end)

    end)

end)
