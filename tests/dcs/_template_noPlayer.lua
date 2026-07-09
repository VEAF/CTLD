---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/_template_auto.lua
-- CTLD Auto Scenario Template — v1.0 [2026-06-30]
--
-- Usage (via VEAF-dcs-bridge exec_lua — see the integration-testing skill):
--   1. exec_lua CTLD.lua first, wait 3-5 s for init.
--   2. exec_lua this scenario.
--   3. Result appears on DCS screen + the exec return value.
--   4. Re-inject to restart.
--
-- Pattern:
--   Single pcall — all assertions run synchronously.
--   No human interaction, no timers, no F10 menu.
--
-- Return contract: the exec return / _SCN_XXX_RESULT global is one of
--   "[SCN-XXX] PASS <p>/<t>"
--   "[SCN-XXX] FAIL: <reason>"
--   "[SCN-XXX] ABORT: <msg>"      (preconditions unmet)
--
-- @scenario  SCN-XXX
-- @version   1.0 — YYYY-MM-DD
-- @coverage  F-XXX, F-YYY
-- @result    expected: [OK]
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCN-XXX] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_XXX_RESULT = "[SCN-XXX] ABORT: CTLD not initialized"
    return _SCN_XXX_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_XXX_RUNNING then
    trigger.action.outText("[SCN-XXX] already running — wait or restart DCS.", 10)
    return _SCN_XXX_RESULT or "[SCN-XXX] RUNNING"
end
_SCN_XXX_RUNNING = true
_SCN_XXX_RESULT  = "[SCN-XXX] STARTED"

do  -- isolation scope
-- ── 3. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

-- ── 4. Constants ─────────────────────────────────────────────────────────────
local TAG = "[SCN-XXX]"
local _t0 = os.clock()

-- ── 5. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local passed, failed, failReasons = 0, 0, {}

local function pass(id, msg)
    passed = passed + 1
    log("[PASS] " .. id .. ": " .. (msg or ""))
end

local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    log("[FAIL] " .. id .. ": " .. (msg or ""))
    error(id)  -- stops pcall, jumps to result block
end

local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- ── 6. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    -- add scenario-specific state resets here
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
end

-- ── 7. Test logic (pcall) ────────────────────────────────────────────────────
local _ok, _err = pcall(function()

    -- check("F-XXX.1", "description", condition, "detail_on_fail")
    -- check("F-XXX.2", "description", condition)

end)

-- ── 8. Result ────────────────────────────────────────────────────────────────
local _ms = math.floor((os.clock() - _t0) * 1000)
pcall(cleanup)
_SCN_XXX_RUNNING = false

if not _ok then
    _SCN_XXX_RESULT = TAG .. " FAIL: " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    return _SCN_XXX_RESULT
end

local total   = passed + failed
_SCN_XXX_RESULT = TAG .. " PASS " .. passed .. "/" .. total .. " (" .. _ms .. "ms)"
trigger.action.outText(_SCN_XXX_RESULT, 30, true)
return _SCN_XXX_RESULT

end  -- do isolation scope
return _SCN_XXX_RESULT
