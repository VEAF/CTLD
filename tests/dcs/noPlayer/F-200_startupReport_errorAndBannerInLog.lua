---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- F-200_startupReport_errorAndBannerInLog.lua
-- STARTUP-REPORT-UNIFIED ticket 04 — DCS integration scenario
--
-- Verifies end-to-end behavior of ctld.startupReport.flush():
--   1. CTLD_STARTUP_REPORT banner is present in the env.info output.
--   2. An alarm outText is produced when an ERROR entry exists.
--   3. A clean flush (no entries) produces [OK] in log and no outText.
--
-- @scenario  F-200
-- @version   1.0 — 2026-07-22
-- @coverage  STARTUP-REPORT-UNIFIED
-- @result    expected: [OK]
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.startupReport then
    trigger.action.outText("[F-200] ABORT: CTLD not initialized or startupReport missing.", 15)
    _F200_RESULT = "[F-200] ABORT: CTLD not initialized"
    return _F200_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _F200_RUNNING then
    return _F200_RESULT or "[F-200] RUNNING"
end
_F200_RUNNING = true
_F200_RESULT  = "[F-200] STARTED"

do
local TAG = "[F-200]"
local _t0 = os.clock()
local passed, failed, failReasons = 0, 0, {}

local function pass(id, msg)
    passed = passed + 1
    ctld.utils.log("INFO", "%s [PASS] %s: %s", TAG, id, msg or "")
end
local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    error(id)
end
local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- ── Capture env.info calls ───────────────────────────────────────────────────
local envInfoLog = {}
local origEnvInfo = env.info
env.info = function(msg)
    envInfoLog[#envInfoLog + 1] = msg
    return origEnvInfo(msg)
end

-- ── Capture outText calls ────────────────────────────────────────────────────
local outTextLog = {}
local origOutText = trigger.action.outText
trigger.action.outText = function(msg, dur, clr)
    outTextLog[#outTextLog + 1] = msg
    return origOutText(msg, dur, clr)
end

local function cleanup()
    env.info               = origEnvInfo
    trigger.action.outText = origOutText
    ctld.startupReport._entries = {}
end

local function findInLog(pattern)
    for _, msg in ipairs(envInfoLog) do
        if msg:find(pattern, 1, true) then return true end
    end
    return false
end

-- ── Test logic ───────────────────────────────────────────────────────────────
local _ok, _err = pcall(function()

    -- ── Case 1: ERROR entry → banner in log + alarm outText ──────────────────
    ctld.startupReport._entries = {}
    envInfoLog  = {}
    outTextLog  = {}

    ctld.startupReport.add("ERROR", "F200Test", "Test error entry")
    ctld.startupReport.flush()

    check("F-200.1", "CTLD_STARTUP_REPORT banner in DCS.log",
        findInLog("CTLD_STARTUP_REPORT"))

    check("F-200.2", "alarm outText emitted (exactly 1 call)",
        #outTextLog == 1,
        "outText calls: " .. tostring(#outTextLog))

    check("F-200.3", "outText directs MM to search CTLD_STARTUP_REPORT",
        outTextLog[1] and outTextLog[1]:find("CTLD_STARTUP_REPORT", 1, true) ~= nil)

    -- ── Case 2: clean flush → [OK] in log, no outText ────────────────────────
    ctld.startupReport._entries = {}
    envInfoLog  = {}
    outTextLog  = {}

    ctld.startupReport.flush()

    check("F-200.4", "[OK] written to DCS.log on clean flush",
        findInLog("[OK]"))

    check("F-200.5", "no outText on clean flush",
        #outTextLog == 0,
        "outText calls: " .. tostring(#outTextLog))

    -- ── Case 3: NOTICE only → outText with notice text, no alarm banner ──────
    ctld.startupReport._entries = {}
    envInfoLog  = {}
    outTextLog  = {}

    ctld.startupReport.add("NOTICE", "F200Test", "Install mod X for this mission")
    ctld.startupReport.flush()

    check("F-200.6", "NOTICE outText contains notice text",
        outTextLog[1] and outTextLog[1]:find("Install mod X", 1, true) ~= nil)

    check("F-200.7", "NOTICE outText does not contain alarm banner",
        outTextLog[1] and outTextLog[1]:find("CTLD_STARTUP_REPORT", 1, true) == nil)

end)

-- ── Result ───────────────────────────────────────────────────────────────────
local _ms = math.floor((os.clock() - _t0) * 1000)
pcall(cleanup)
_F200_RUNNING = false

if not _ok then
    _F200_RESULT = TAG .. " FAIL: " .. tostring(_err)
        .. (failed > 0 and (" | " .. table.concat(failReasons, "; ")) or "")
    trigger.action.outText(_F200_RESULT, 60, true)
    return _F200_RESULT
end

local total = passed + failed
_F200_RESULT = TAG .. " PASS " .. passed .. "/" .. total .. " (" .. _ms .. "ms)"
trigger.action.outText(_F200_RESULT, 30, true)
return _F200_RESULT

end
return _F200_RESULT
