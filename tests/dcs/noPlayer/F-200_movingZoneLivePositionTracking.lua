---@diagnostic disable
-- @tier: auto-check
-- =============================================================================
-- F-200_movingZoneLivePositionTracking.lua
-- FEAT-MOVING-ZONE — verify that LGZ_ and TRZ_ attached to a Moving Zone
-- follow their anchor unit (live position via trigger.misc.getZone).
--
-- Prerequisites:
--   missions/Test_CTLDNEXT_01.miz must contain:
--     - CTLD_TEST_ANCHOR_1    : vehicle with a route (moves autonomously)
--     - LGZ_polygonAnchored_B : polygon Moving Zone (linkUnit -> CTLD_TEST_ANCHOR_1)
--     - TRZ_CircularAnchored_B_999_nil_0 : circular Moving Zone (same anchor)
--
-- @scenario  SCN-200
-- @version   1.0 — 2026-07-20
-- @coverage  FEAT-MOVING-ZONE
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCN-200] ABORT: CTLD not initialized.", 15)
    _SCN_200_RESULT = "[SCN-200] ABORT: CTLD not initialized"
    return _SCN_200_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_200_RUNNING then
    trigger.action.outText("[SCN-200] already running — wait for completion.", 10)
    return _SCN_200_RESULT or "[SCN-200] RUNNING"
end
_SCN_200_RUNNING = true
_SCN_200_RESULT  = "[SCN-200] STARTED"

do  -- isolation scope
-- ── 3. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 4. Constants ─────────────────────────────────────────────────────────────
local TAG        = "[SCN-200]"
local LGZ_NAME   = "polygonAnchored"     -- CTLDLogisticZone.name (parsed from LGZ_ prefix)
local TRZ_NAME   = "CircularAnchored"    -- CTLDTroopZone.zoneName (parsed from TRZ_ prefix)
local ANCHOR_UNIT = "CTLD_TEST_ANCHOR_1"
local MOVE_WAIT   = 12   -- seconds to wait for the vehicle to move
local MIN_MOVE_M  = 20   -- minimum displacement expected (metres)

-- ── 5. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    timerHandle = nil,
    timerGen    = 0,
}

local lgz0, trz0   -- positions at t0

-- ── 6. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end
local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function dist2d(a, b)
    local dx = a.x - b.x ; local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx*dx + dz*dz)
end

-- ── 7. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then pcall(timer.removeFunction, S.timerHandle) ; S.timerHandle = nil end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_200_RUNNING = false
    log("cleanup done")
end

-- ── 8. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then pcall(timer.removeFunction, S.timerHandle) ; S.timerHandle = nil end
end

local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil ; callback()
    end, nil, timer.getTime() + delayS)
end

-- ── 9. Finalization ──────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    local total   = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." PASS "..S.passed.."/"..total
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..table.concat(S.failReasons, "; ")
    end
    _SCN_200_RESULT = summary
    log(summary)
    trigger.action.outText(summary, 60, true)
    pcall(cleanup)
end

-- ── 10. Step runner ──────────────────────────────────────────────────────────
local steps = {}
local advanceStep
advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then finalizeScenario() ; return end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        advanceStep()
    end
end

-- ── 11. Steps ────────────────────────────────────────────────────────────────

-- S1 — Precondition: zones and anchor unit exist, isDynamic() = true
steps[1] = function()
    local zm  = CTLDZoneManager.getInstance()
    local lgz = zm._logisticZones[LGZ_NAME]
    local trz = zm._troopZones[TRZ_NAME]
    local u   = Unit.getByName(ANCHOR_UNIT)

    if not lgz then
        fail("F200.1a", "LGZ '"..LGZ_NAME.."' not found in CTLDZoneManager")
        return finalizeScenario()
    end
    if not trz then
        fail("F200.1b", "TRZ '"..TRZ_NAME.."' not found in CTLDZoneManager")
        return finalizeScenario()
    end
    if not (u and u:isExist()) then
        fail("F200.1c", "anchor unit '"..ANCHOR_UNIT.."' not found")
        return finalizeScenario()
    end

    if lgz:isDynamic() then pass("F200.1d", "LGZ isDynamic=true") else fail("F200.1d", "LGZ isDynamic=false") end
    if trz:isDynamic() then pass("F200.1e", "TRZ isDynamic=true") else fail("F200.1e", "TRZ isDynamic=false") end
    if lgz:isAlive()   then pass("F200.1f", "LGZ isAlive=true")   else fail("F200.1f", "LGZ isAlive=false (anchor alive)") end
    if trz:isAlive()   then pass("F200.1g", "TRZ isAlive=true")   else fail("F200.1g", "TRZ isAlive=false (anchor alive)") end

    -- Record t0 positions
    lgz0 = lgz:getCenter()
    trz0 = trz:getCenter()
    log("t0 LGZ center: x="..string.format("%.1f", lgz0.x).." z="..string.format("%.1f", lgz0.z))
    log("t0 TRZ center: x="..string.format("%.1f", trz0.x).." z="..string.format("%.1f", trz0.z))

    if S.failed > 0 then finalizeScenario() ; return end
    advanceStep()
end

-- S2 — Wait for vehicle to move
steps[2] = function()
    log("waiting "..MOVE_WAIT.."s for anchor to move…")
    waitThen(MOVE_WAIT, advanceStep)
end

-- S3 — Check that zone centers have moved
steps[3] = function()
    local zm  = CTLDZoneManager.getInstance()
    local lgz = zm._logisticZones[LGZ_NAME]
    local trz = zm._troopZones[TRZ_NAME]

    local lgz1 = lgz:getCenter()
    local trz1 = trz:getCenter()
    local lgzDist = dist2d(lgz0, lgz1)
    local trzDist = dist2d(trz0, trz1)

    log("LGZ moved "..string.format("%.1f", lgzDist).."m")
    log("TRZ moved "..string.format("%.1f", trzDist).."m")

    if lgzDist >= MIN_MOVE_M then
        pass("F200.3a", "LGZ followed anchor ("..string.format("%.1f", lgzDist).."m)")
    else
        fail("F200.3a", "LGZ did not move enough ("..string.format("%.1f", lgzDist).."m < "..MIN_MOVE_M.."m)")
    end
    if trzDist >= MIN_MOVE_M then
        pass("F200.3b", "TRZ followed anchor ("..string.format("%.1f", trzDist).."m)")
    else
        fail("F200.3b", "TRZ did not move enough ("..string.format("%.1f", trzDist).."m < "..MIN_MOVE_M.."m)")
    end

    advanceStep()
end

-- S4 — Destroy anchor, check isAlive() goes false
steps[4] = function()
    local u = Unit.getByName(ANCHOR_UNIT)
    if u and u:isExist() then
        u:destroy()
        log("anchor '"..ANCHOR_UNIT.."' destroyed")
    end
    waitThen(1, advanceStep)
end

steps[5] = function()
    local zm  = CTLDZoneManager.getInstance()
    local lgz = zm._logisticZones[LGZ_NAME]
    local trz = zm._troopZones[TRZ_NAME]

    if not lgz:isAlive() then pass("F200.5a", "LGZ isAlive=false after anchor destroyed")
    else fail("F200.5a", "LGZ isAlive still true after anchor destroyed") end

    if not trz:isAlive() then pass("F200.5b", "TRZ isAlive=false after anchor destroyed")
    else fail("F200.5b", "TRZ isAlive still true after anchor destroyed") end

    advanceStep()
end

-- ── 12. Start ─────────────────────────────────────────────────────────────────
advanceStep()

end  -- do isolation scope
return _SCN_200_RESULT
