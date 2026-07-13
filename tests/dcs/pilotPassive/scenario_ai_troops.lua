---@diagnostic disable
-- @tier: auto-slow  (no human, but needs minutes of real AI-heli flight to resolve -- excluded from the fast --headless sweep; run with --tier auto-slow. Core logic already covered fast by noPlayer aiTransport_featureT/U F-176..182. See ticket 06/07)
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_ai_troops.lua
-- CTLD — AI auto-pickup / auto-dropoff: troops alone
--
-- Interactive test mini-app: single injection, advances
-- automatically (waitFor ground/takeoff) or waits for the DCS condition.
--
-- Prerequisites:
--   - BLUE helo named "heliai_troops" (UH-1H), no human pilot
--   - Route: WP1 = on AIZ_base_B_P_5 (landed) → WP2 = flight → WP3 = on AIZ_front_B_D (landed)
--   - DCS trigger zone "AIZ_base_B_P_5"  (radius ~200 m, centered on WP1)
--   - DCS trigger zone "AIZ_front_B_D"   (radius ~200 m, centered on WP3)
--   - BLUE slot occupied (human player in a slot for MenuManager)
--   - CTLD.lua injected before this script (wait 3-5 s)
--
-- Sequence (4 steps, single injection):
--   S1 [auto]  Init + AI helo activation
--   S2 [auto]  Wait for pickup (hasTroops=true) detected via waitFor
--   S3 [auto]  Wait for dropoff (hasTroops=false) detected via waitFor
--   S4 [auto]  Finalization
--
-- @scenario  MT-07
-- @version   3.0 — 2026-06-30
-- @coverage  AI auto-pickup troops, AI auto-dropoff troops
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-07] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MT07_RESULT = "[MT-07] ABORT: CTLD not initialized"
    return _SCN_MT07_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT07_RUNNING then
    trigger.action.outText("[MT-07] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_MT07_RESULT or "[MT-07] RUNNING"
end
_SCN_MT07_RUNNING = true
_SCN_MT07_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT07_INSTR = ""
_SCN_MT07_SHOW  = function()
    trigger.action.outText(_SCN_MT07_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[MT-07]"
local NAME            = "AI auto-pickup/dropoff troops"
local MENU_NAME       = "CTLD Test"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }

local AI_UNIT = "heliai_troops"
local AIZ_P   = "AIZ_base_B_P_5"
local AIZ_D   = "AIZ_front_B_D"

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,
    timerHandle = nil,
    timerGen    = 0,
    transport   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_MT07_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT07_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | "..details) or "")) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    if S.groupId then
        local mm = ctld.MenuManager:getInstance()
        local menu = mm and mm:getMenuByGroupId(S.groupId)
        if menu then
            pcall(function()
                menu:clearBranch(MENU_PATH)
                menu:setBranchEnabled(MENU_PATH, false)
                menu:refresh()
            end)
        end
    end
    -- AI cleanup
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT then table.remove(names, i) end
    end
    local unit = Unit.getByName(AI_UNIT)
    if unit and unit:isExist() then
        local ok, tm = pcall(CTLDTroopManager.getInstance)
        if ok and tm and tm:hasTroops(AI_UNIT) then tm:disembarkAll(unit) end
    end
    _SCN_MT07_INSTR = nil ; _SCN_MT07_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT07_RUNNING = false
    _SCN_MT07_CLEANUP = nil
    log("cleanup done")
end

-- ── 9. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitFor(checkFn, intervalS, timeoutS, onSuccess, onFail)
    cancelTimer()
    local myGen = S.timerGen
    local elapsed = 0
    local function poll()
        if S.timerGen ~= myGen then return nil end
        elapsed = elapsed + intervalS
        if checkFn() then
            S.timerHandle = nil ; onSuccess()
        elseif elapsed >= timeoutS then
            S.timerHandle = nil ; log("[TIMEOUT] "..timeoutS.."s") ; onFail()
        else
            return timer.getTime() + intervalS
        end
    end
    S.timerHandle = timer.scheduleFunction(poll, nil, timer.getTime() + intervalS)
end

local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        callback()
    end, nil, timer.getTime() + delayS)
end

-- ── 10. Finalization ─────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    if S.groupId then
        local mm = ctld.MenuManager:getInstance()
        local menu = mm and mm:getMenuByGroupId(S.groupId)
        if menu then
            pcall(function()
                menu:clearBranch(MENU_PATH)
                menu:setBranchEnabled(MENU_PATH, false)
                menu:refresh()
            end)
        end
    end
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." PASS "..S.passed.."/"..total ; _SCN_MT07_RESULT = summary
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ") ; _SCN_MT07_RESULT = summary
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT07_RUNNING = false end
end

-- ── 11. Step runner ──────────────────────────────────────────────────────────
local steps = {}
local advanceStep

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        finalizeScenario()
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERROR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 12. Steps ────────────────────────────────────────────────────────────────

-- S1 — Init + AI helo activation [auto]
steps[1] = function()
    instruct(
        "Step 1/4 — INIT AI TRANSPORT (MT-07)\n"..
        "Initializing AI transports…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-07.1.1", "AIZ_P zone found: "..AIZ_P, zP ~= nil)
        check("MT-07.1.2", "AIZ_D zone found: "..AIZ_D, zD ~= nil)
        if zP then check("MT-07.1.3", "AIZ_P.isAIPickup=true",  zP.isAIPickup  == true) end
        if zD then check("MT-07.1.4", "AIZ_D.isAIDropoff=true", zD.isAIDropoff == true) end

        local grp = Group.getByName(AI_UNIT)
        if grp then grp:activate() end

        local unit = Unit.getByName(AI_UNIT)
        check("MT-07.1.5", "AI unit '"..AI_UNIT.."' present", unit ~= nil)
        if unit then
            check("MT-07.1.6", "AI unit without human pilot", unit:getPlayerName() == nil)
        end

        local tm = CTLDTroopManager.getInstance()
        check("MT-07.1.7", "No troops aboard yet (initial state)", not tm:hasTroops(AI_UNIT))

        log("STEP 1 OK — helo activated, waiting for pickup on "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Wait for auto pickup (hasTroops=true) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — WAIT FOR PICKUP (MT-07)\n"..
        "Helo "..AI_UNIT.." must land on "..AIZ_P..".\n"..
        "Automatic pickup detection (hasTroops=true).\n"..
        "Timeout: 300 s."
    )
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            return tm:hasTroops(AI_UNIT)
        end,
        3, 300,
        function()
            local tm = CTLDTroopManager.getInstance()
            local hasTr = tm:hasTroops(AI_UNIT)
            check("MT-07.2.1", "hasTroops=true after auto-pickup on "..AIZ_P, hasTr,
                "hasTroops="..tostring(hasTr))

            local list  = tm:getInTransit(AI_UNIT) or {}
            local total = 0
            for _, grp in ipairs(list) do total = total + (grp.unitTotal or 0) end
            log("Cargo: "..total.." soldier(s)")

            local zm = CTLDZoneManager.getInstance()
            local zP = zm._troopZones[AIZ_P]
            if zP and zP.pickMaxStock ~= 0 then
                check("MT-07.2.2", "AIZ_P stock decremented",
                    zP.pickCurrentStock < zP.pickMaxStock,
                    "current="..tostring(zP.pickCurrentStock).." max="..tostring(zP.pickMaxStock))
            end
            advanceStep()
        end,
        function()
            fail("MT-07.2.1", "timeout 300s — no pickup on "..AIZ_P)
            advanceStep()
        end
    )
end

-- S3 — Wait for auto dropoff (hasTroops=false) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — WAIT FOR DROPOFF (MT-07)\n"..
        "Helo "..AI_UNIT.." must land on "..AIZ_D..".\n"..
        "Automatic dropoff detection (hasTroops=false).\n"..
        "Timeout: 600 s."
    )
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            return not tm:hasTroops(AI_UNIT)
        end,
        3, 600,
        function()
            local tm = CTLDTroopManager.getInstance()
            check("MT-07.3.1", "hasTroops=false after auto-dropoff on "..AIZ_D,
                not tm:hasTroops(AI_UNIT),
                "hasTroops="..tostring(tm:hasTroops(AI_UNIT)))
            log("Disembark confirmed — groups appeared near "..AIZ_D)
            advanceStep()
        end,
        function()
            fail("MT-07.3.1", "timeout 600s — no dropoff on "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalization [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALIZATION")
    waitThen(1, function()
        log("MT-07 full cycle (pickup "..AIZ_P.." → disembark "..AIZ_D..")")
        advanceStep()
    end)
end

-- ── 13. Start ────────────────────────────────────────────────────────────────
S.transport = (function()
    local ok, pm = pcall(CTLDPlayerManager.getInstance)
    if ok and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    for _, grp in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        for _, unit in ipairs(grp:getUnits() or {}) do
            if unit and unit:isExist() and unit:getPlayerName() then return unit end
        end
    end
    return nil
end)()

if not S.transport then
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot before injection.", 20)
    cleanup()
    _SCN_MT07_RESULT = "[MT-07] ABORT"
    return _SCN_MT07_RESULT
end

local pm_start = CTLDPlayerManager.getInstance()
local playerObjStart
if pm_start and pm_start._players then
    for _, p in pairs(pm_start._players) do
        if p.unitName == S.transport:getName() then
            playerObjStart = p ; break
        end
    end
    if not playerObjStart then
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    trigger.action.outText(TAG.." ABORT: no CTLD playerObj for transport.", 20)
    _SCN_MT07_RESULT = "[MT-07] ABORT"
    cleanup() ; return _SCN_MT07_RESULT
end

S.groupId = playerObjStart.groupId

local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT: no CTLD MenuManager menu for player group.", 20)
    _SCN_MT07_RESULT = "[MT-07] ABORT"
    cleanup() ; return _SCN_MT07_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_MT07_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." start — "..#steps.." steps | "..S.transport:getName(), 8)
_SCN_MT07_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_MT07_RESULT until PASS/FAIL
advanceStep()

end  -- do isolation scope
return _SCN_MT07_RESULT
