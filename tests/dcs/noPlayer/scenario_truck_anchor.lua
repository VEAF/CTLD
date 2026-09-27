---@diagnostic disable
-- @tier: auto-check  (no player/F10 — a real timer polls the truck's AI-driven route movement,
--                     resolving within seconds; safe for the --headless sweep)
-- =============================================================================
-- tests/dcs/noPlayer/scenario_truck_anchor.lua
-- CTLD — TRZ_ anchored to a moving ground vehicle (truck) via createTroopZoneAtObject
--
-- Verifies the FEAT-TRUCK-MOBILE-PICKUP-ZONE hypothesis: a TRZ_ can anchor to an arbitrary
-- ground Unit the same way FIX-SHIP-ZONE-ANCHOR-PARITY already proved for a ship — position
-- tracking while alive, freeze-at-last-position once destroyed.
--
-- Prerequisites:
--   - A BLUE ground vehicle group named "truckai_anchor_test" placed in the .miz, **late-
--     activated** (never activated by any trigger), with a short road route so it drives
--     somewhere observable once activated. This scenario activates it itself (S1) and destroys
--     it as its final step (S4, proving the freeze-at-destruction behavior) — reload the mission
--     (Shift+R) to restore both the late-activation state and the unit before running again.
--   - CTLD.lua injected before this script (wait 3-5 s for init).
--
-- Sequence (single injection, auto-check):
--   S1 [auto]   Activate the truck group, anchor a TRZ_ to it, record initial center
--   S2 [polled] Wait for the truck to move away from its recorded position
--   S3 [auto]   isDynamic() check
--   S4 [auto]   Destroy the truck unit
--   S5 [polled] Wait for isAlive()==false, getCenter() frozen at last position
--
-- @scenario  SCN-TRUCK-ANCHOR
-- @version   1.1 — 2026-09-28
-- @coverage  FEAT-TRUCK-MOBILE-PICKUP-ZONE
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCN-TRUCK-ANCHOR] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_TRUCK_ANCHOR_RESULT = "[SCN-TRUCK-ANCHOR] ABORT: CTLD not initialized"
    return _SCN_TRUCK_ANCHOR_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_TRUCK_ANCHOR_RUNNING then
    trigger.action.outText("[SCN-TRUCK-ANCHOR] already running — wait for completion or restart DCS.", 10)
    return _SCN_TRUCK_ANCHOR_RESULT or "[SCN-TRUCK-ANCHOR] RUNNING"
end
_SCN_TRUCK_ANCHOR_RUNNING = true

do  -- isolation scope
-- ── 3. Debug ON (save previous state) ───────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 4. Constants ─────────────────────────────────────────────────────────────
local TAG        = "[SCN-TRUCK-ANCHOR]"
local NAME       = "TRZ_ anchored to a moving ground vehicle (truck)"
local TRUCK_NAME = "truckai_anchor_test"   -- live, already-active unit placed in the .miz
local TRZ_NAME   = "TRZ_truckanchor_B_1_nil_0"
local MOVE_THRESHOLD_M       = 20   -- meters the truck must drive before we call it "moved"
local MOVE_POLL_INTERVAL_S   = 3
local MOVE_POLL_TIMEOUT_S    = 60
local DEATH_POLL_INTERVAL_S  = 1
local DEATH_POLL_TIMEOUT_S   = 10

-- ── 5. State ─────────────────────────────────────────────────────────────────
local S = {
    step         = 0,
    passed       = 0,
    failed       = 0,
    failReasons  = {},
    timerHandle  = nil,
    initialPos   = nil,
    lastAlivePos = nil,
}

-- ── 6. Helpers ────────────────────────────────────────────────────────────────
local function log(msg)
    ctld.utils.log("INFO", "%s %s", TAG, msg)
    trigger.action.outText(TAG .. " " .. msg, 12)
end

local function pass(id, msg)
    S.passed = S.passed + 1
    log("[PASS] " .. id .. ": " .. (msg or ""))
end

local function fail(id, msg)
    S.failed = S.failed + 1
    table.insert(S.failReasons, id .. ": " .. (msg or ""))
    log("[FAIL] " .. id .. ": " .. (msg or ""))
end

local function dist2D(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

-- ── 7. Timer helper (poll until condition or timeout) ────────────────────────
local function cancelTimer()
    if S.timerHandle then
        timer.removeFunction(S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitFor(checkFn, intervalS, timeoutS, onSuccess, onFail)
    local elapsed = { v = 0 }
    local function poll()
        elapsed.v = elapsed.v + intervalS
        local ok, result = pcall(checkFn)
        if ok and result then
            S.timerHandle = nil
            onSuccess()
        elseif elapsed.v >= timeoutS then
            S.timerHandle = nil
            onFail()
        else
            return timer.getTime() + intervalS
        end
    end
    cancelTimer()
    S.timerHandle = poll
    timer.scheduleFunction(poll, nil, timer.getTime() + intervalS)
end

-- ── 8. Cleanup ────────────────────────────────────────────────────────────────
local function cleanup()
    cancelTimer()
    local zm = CTLDZoneManager.getInstance()
    if zm and zm._troopZones and zm._troopZones[TRZ_NAME] then
        zm._troopZones[TRZ_NAME] = nil
    end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_TRUCK_ANCHOR_RUNNING = false
    log("Cleanup done. NOTE: the truck unit was destroyed as part of this test — " ..
        "reload the mission (Shift+R) to restore it before running again.")
end

-- ── 9. Step runner ────────────────────────────────────────────────────────────
local steps = {}
local advanceStep  -- forward declaration

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        cancelTimer()
        local total = S.passed + S.failed
        local verdict
        if S.failed == 0 then
            verdict = TAG .. " PASS " .. S.passed .. "/" .. total
        else
            verdict = TAG .. " FAIL " .. S.failed .. "/" .. total .. ": " .. table.concat(S.failReasons, "; ")
        end
        _SCN_TRUCK_ANCHOR_RESULT = verdict
        ctld.utils.log("INFO", "%s — %s", verdict, NAME)
        trigger.action.outText(verdict, 30, true)
        local ok, err = pcall(cleanup)
        if not ok then
            ctld.utils.log("WARN", "%s cleanup error: %s", TAG, tostring(err))
            _SCN_TRUCK_ANCHOR_RUNNING = false
        end
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S" .. S.step, "pcall: " .. tostring(err))
        advanceStep()
    end
end

-- ── 10. Steps ─────────────────────────────────────────────────────────────────

-- S1 [auto]: anchor TRZ_ to the live truck unit, record initial center
steps[1] = function()
    log("Step 1: anchor TRZ_ to '" .. TRUCK_NAME .. "'")
    -- TRUCK_NAME resolves as a group name here (single-unit group) — same resolution order
    -- (Unit -> StaticObject -> Group -> Airbase) createTroopZoneAtObject uses in production.
    local grp = Group.getByName(TRUCK_NAME)
    local u = grp and grp:getUnit(1)
    if not u or not u:isExist() then
        fail("S1", "truck group/unit not found or not alive: " .. TRUCK_NAME)
        advanceStep()
        return
    end
    -- The group is late-activated (never activated by any trigger) — activate it now so its
    -- AI driver actually starts the route; without this it exists but sits at speed 0 forever.
    trigger.action.activateGroup(grp)
    local ok = CTLDZoneManager.getInstance():createTroopZoneAtObject(TRUCK_NAME, TRZ_NAME)
    if not ok then
        fail("S1", "createTroopZoneAtObject returned false for " .. TRUCK_NAME)
        advanceStep()
        return
    end
    local zone = CTLDZoneManager.getInstance():getTroopZone(TRZ_NAME)
    if not zone then
        fail("S1", "getTroopZone('" .. TRZ_NAME .. "') returned nil after creation")
        advanceStep()
        return
    end
    S.initialPos = zone:getCenter()
    if not S.initialPos then
        fail("S1", "getCenter() returned nil right after anchoring")
        advanceStep()
        return
    end
    pass("S1", "TRZ_ anchored to live truck, initial center recorded")
    advanceStep()
end

-- S2 [polled]: wait for the truck to have driven away from its recorded position
steps[2] = function()
    log("Step 2: waiting up to " .. MOVE_POLL_TIMEOUT_S .. "s for the truck to move...")
    waitFor(
        function()
            local zone = CTLDZoneManager.getInstance():getTroopZone(TRZ_NAME)
            if not zone then return false end
            local p = zone:getCenter()
            return p ~= nil and dist2D(p, S.initialPos) >= MOVE_THRESHOLD_M
        end,
        MOVE_POLL_INTERVAL_S, MOVE_POLL_TIMEOUT_S,
        function()
            pass("S2", "getCenter() tracked the truck's movement (>= " .. MOVE_THRESHOLD_M .. "m)")
            advanceStep()
        end,
        function()
            fail("S2", "getCenter() did not move >= " .. MOVE_THRESHOLD_M ..
                "m within " .. MOVE_POLL_TIMEOUT_S .. "s — check the truck's route/speed in the mission")
            advanceStep()
        end
    )
end

-- S3 [auto]: isDynamic() check
steps[3] = function()
    log("Step 3: isDynamic() check")
    local zone = CTLDZoneManager.getInstance():getTroopZone(TRZ_NAME)
    if zone and zone:isDynamic() then
        pass("S3", "isDynamic() == true while the truck is alive")
    else
        fail("S3", "isDynamic() == false while the truck is alive")
    end
    S.lastAlivePos = zone and zone:getCenter() or nil
    advanceStep()
end

-- S4 [auto]: destroy the truck unit
steps[4] = function()
    log("Step 4: destroying the truck unit")
    local grp = Group.getByName(TRUCK_NAME)
    local u = grp and grp:getUnit(1)
    if u and u:isExist() then
        pcall(function() u:destroy() end)
    end
    advanceStep()
end

-- S5 [polled]: wait for isAlive()==false, getCenter() frozen at last position
steps[5] = function()
    log("Step 5: waiting up to " .. DEATH_POLL_TIMEOUT_S .. "s for isAlive() to become false...")
    waitFor(
        function()
            local zone = CTLDZoneManager.getInstance():getTroopZone(TRZ_NAME)
            return zone ~= nil and zone:isAlive() == false
        end,
        DEATH_POLL_INTERVAL_S, DEATH_POLL_TIMEOUT_S,
        function()
            local zone = CTLDZoneManager.getInstance():getTroopZone(TRZ_NAME)
            local p = zone and zone:getCenter()
            if p and S.lastAlivePos and dist2D(p, S.lastAlivePos) < 1 then
                pass("S5", "isAlive()==false, getCenter() frozen at last known position")
            elseif p then
                pass("S5", "isAlive()==false, getCenter() still returns a valid point")
            else
                fail("S5", "isAlive()==false but getCenter() returned nil")
            end
            advanceStep()
        end,
        function()
            fail("S5", "isAlive() never became false within " .. DEATH_POLL_TIMEOUT_S .. "s")
            advanceStep()
        end
    )
end

-- ── 11. Start ─────────────────────────────────────────────────────────────────
_SCN_TRUCK_ANCHOR_RESULT = TAG .. " STARTED"
log("=== START: " .. NAME .. " (" .. #steps .. " steps) ===")
advanceStep()

end  -- do isolation scope
return _SCN_TRUCK_ANCHOR_RESULT
