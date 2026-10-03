---@diagnostic disable
-- @tier: disabled -- destructive: cancelAll() stops every CTLD loop of the live mission, so the
--                   mission must be reloaded (Shift+R) afterwards; never part of a sweep.
--                   Run alone: run_scenarios.py --tier disabled --scenario scheduler_shutdown
-- =============================================================================
-- CTLD — ctld.scheduler.cancelAll() against the REAL DCS timer (FIX-SCHEDULER-SINGLE-ENTRY, #234)
--
-- The busted specs stub `timer`; only a live mission can show that timer.removeFunction really stops
-- a self-rescheduling chain, of both kinds, and that the real CTLD loops are gone after cancelAll().
--
-- Counting loops (both scheduled through ctld.scheduler.schedule):
--   A  returns t + 1                      (DCS reschedules the SAME function id)
--   B  calls schedule() again each tick   (a NEW id each tick, like CTLDCrateManager:checkHoverStatus)
-- Real loops observed by wrapping the manager method each one calls:
--   H  CTLDCrateManager:checkHoverStatus   (1 s, manual reschedule)
--   V  CTLDVehicleSpawner:_checkNativeLoading (1 s, returns t + 1)
--
-- Sequence: S1 start the counters -> wait 4 s -> check all four advanced
--           S2 cancelAll() -> wait 4 s -> check all four froze
-- AFTER THIS SCENARIO CTLD HAS NO RUNNING LOOP: reload the mission (Shift+R).
--
-- @scenario  SCHED-SD
-- @version   1.0 — 2026-10-03
-- =============================================================================

if not ctld or not ctld.scheduler or not ctld.scheduler.schedule then
    _SCN_SCHEDSD_RESULT = "[SCHED-SD] ABORT: ctld.scheduler.schedule not available (CTLD not initialized?)"
    return _SCN_SCHEDSD_RESULT
end
if _SCN_SCHEDSD_RUNNING then
    return _SCN_SCHEDSD_RESULT or "[SCHED-SD] RUNNING"
end
_SCN_SCHEDSD_RUNNING = true

do
local TAG = "[SCHED-SD]"
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local count = { A = 0, B = 0, H = 0, V = 0 }
local failReasons, passed = {}, 0
local restore = {}

local function check(id, cond, detail)
    if cond then passed = passed + 1
    else failReasons[#failReasons + 1] = id .. (detail and (" | " .. detail) or "") end
    log((cond and "[PASS] " or "[FAIL] ") .. id .. (detail and (" | " .. detail) or ""))
end

-- Wrap a manager method on its instance (the loops call it through getInstance()/_instance).
local function wrap(obj, name, key)
    local orig = obj[name]
    restore[#restore + 1] = function() obj[name] = nil end   -- drop the instance shadow
    obj[name] = function(self, ...)
        count[key] = count[key] + 1
        return orig(self, ...)
    end
end

-- The scenario's own waits use the raw DCS timer: they must survive cancelAll().
local function waitThen(s, fn) timer.scheduleFunction(function() fn() end, nil, timer.getTime() + s) end

local function snapshot() return { A = count.A, B = count.B, H = count.H, V = count.V } end

local function finish()
    for _, r in ipairs(restore) do pcall(r) end
    local total = passed + #failReasons
    _SCN_SCHEDSD_RESULT = (#failReasons == 0)
        and (TAG .. " PASS " .. passed .. "/" .. total)
        or  (TAG .. " FAIL " .. #failReasons .. "/" .. total .. ": " .. table.concat(failReasons, "; "))
    _SCN_SCHEDSD_RUNNING = false
    log(_SCN_SCHEDSD_RESULT .. " — RELOAD THE MISSION (Shift+R): CTLD has no running loop now")
    trigger.action.outText(_SCN_SCHEDSD_RESULT .. "\nReload the mission (Shift+R).", 120, true)
end

local function step2()
    local before = snapshot()
    check("S1.alive", before.A >= 2 and before.B >= 2 and before.H >= 2 and before.V >= 2,
        string.format("A=%d B=%d H=%d V=%d after 4 s", before.A, before.B, before.H, before.V))

    ctld.scheduler.cancelAll()
    local atCancel = snapshot()

    waitThen(4, function()
        local after = snapshot()
        check("S2.A", after.A == atCancel.A, "A " .. atCancel.A .. " -> " .. after.A .. " (same-id chain)")
        check("S2.B", after.B == atCancel.B, "B " .. atCancel.B .. " -> " .. after.B .. " (re-scheduled chain)")
        check("S2.H", after.H == atCancel.H, "H " .. atCancel.H .. " -> " .. after.H .. " (real hover poll)")
        check("S2.V", after.V == atCancel.V, "V " .. atCancel.V .. " -> " .. after.V .. " (real vehicle poll)")
        finish()
    end)
end

local ok, err = pcall(function()
    wrap(CTLDCrateManager.getInstance(), "checkHoverStatus", "H")
    wrap(CTLDVehicleSpawner._instance, "_checkNativeLoading", "V")

    ctld.scheduler.schedule(function(_, t) count.A = count.A + 1; return t + 1 end, nil, timer.getTime() + 1)
    local function tickB() count.B = count.B + 1; ctld.scheduler.schedule(tickB, nil, timer.getTime() + 1) end
    ctld.scheduler.schedule(tickB, nil, timer.getTime() + 1)

    _SCN_SCHEDSD_RESULT = TAG .. " STARTED"
    log("counters started; checking in 4 s")
    waitThen(4, step2)
end)
if not ok then
    for _, r in ipairs(restore) do pcall(r) end
    _SCN_SCHEDSD_RUNNING = false
    _SCN_SCHEDSD_RESULT = TAG .. " ABORT: " .. tostring(err)
end

end  -- do
return _SCN_SCHEDSD_RESULT
