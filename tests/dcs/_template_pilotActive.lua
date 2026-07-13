---@diagnostic disable
-- @tier: human
-- =============================================================================
-- live_tests/scenarios/_template_interactive.lua
-- CTLD Interactive Scenario Template
--
-- Interactive test mini-application: single injection, advances
-- automatically (waitFor / waitThen) or via the F10 "CTLD Test" menu
-- (human visual checks).
--
-- Pre-requisites:
--   - Inject CTLD.lua first, wait 3–5 s for init.
--   - BLUE slot occupied (helicopter or plane depending on the scenario).
--   - CTLD config appropriate to the scenario (enable the tested features).
--
-- Sequence (3 example steps):
--   S1 [F10]   Initial manual check            → YES / NO / SKIP
--   S2 [auto]  DCS condition detected (waitFor) → auto
--   S3 [auto]  Deferred check (waitThen)        → auto
--
-- @scenario  SCN-XXX
-- @version   3.0 — 2026-06-30
-- @coverage  F-XXX, F-YYY
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCN-XXX] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_XXX_RESULT = "[SCN-XXX] ABORT: CTLD not initialized"
    return _SCN_XXX_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_XXX_RUNNING then
    trigger.action.outText("[SCN-XXX] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_XXX_RESULT or "[SCN-XXX] RUNNING"
end
_SCN_XXX_RUNNING = true
_SCN_XXX_CLEANUP = nil   -- exposed for external reset (reset script)

-- ── 3. Global show callback (Lua closure compatible with MenuManager) ────────
_SCN_XXX_INSTR = ""
_SCN_XXX_SHOW  = function()
    trigger.action.outText(_SCN_XXX_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false   -- internal traces via log() only, not on screen

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[SCN-XXX]"
local NAME            = "Scenario description"
local HUMAN_TIMEOUT_S = 3600  -- generous: a real pilot session, not a race against the clock
local MENU_NAME       = "CTLD Test"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }   -- nested under CTLD (order=0 → first)

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,   -- player groupId for MenuManager lookups
    timerHandle = nil,
    timerGen    = 0,     -- generation counter: invalidates timers from a previous waitFor
    transport   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_XXX_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_XXX_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    -- Hide the scenario menu via MenuManager (clearBranch + setBranchEnabled + refresh)
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
    _SCN_XXX_INSTR = nil ; _SCN_XXX_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_XXX_RUNNING = false
    _SCN_XXX_CLEANUP = nil
    log("cleanup done")
end

-- ── 9. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1   -- invalidate any existing poll even if removeFunction fails
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
        if S.timerGen ~= myGen then return nil end  -- invalidated: silent stop
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

-- Execute callback once after delayS seconds (one-shot timer, honours timerGen).
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
    -- Hide the scenario menu via MenuManager
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
        summary = TAG.." PASS "..S.passed.."/"..total
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ")
    end
    _SCN_XXX_RESULT = summary   -- polled by the runner for this async scenario
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_XXX_RUNNING = false end
end

-- ── 11. Human step (MenuManager) ─────────────────────────────────────────────
-- The "CTLD Test" submenu is created ONLY ONCE in Start (order=0).
-- Only the child commands are cleared/recreated between steps (clearBranch).
local advanceStep

local function setHumanStep(stepId, title, options)
    cancelTimer()
    local myGen = S.timerGen  -- capture after cancelTimer (current gen)

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm and mm:getMenuByGroupId(S.groupId)
    if not menu then
        log("[ERR] setHumanStep: no CTLD menu for groupId="..tostring(S.groupId))
        fail(stepId, "no CTLD menu")
        finalizeScenario()
        return
    end

    -- Clear the previous step's commands and rebuild (ensure node visibility)
    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_XXX_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end  -- duplicate or post-timeout: ignore
        cancelTimer()
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        opt_fn()
    end

    for _, opt in ipairs(options) do
        local fn = opt.fn
        menu:addCommand(MENU_PATH, opt.label, function() onResponse(fn) end)
    end
    menu:refresh()

    -- Timeout timer (managed manually to control timerGen precisely)
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        log("[TIMEOUT] step "..S.step.." ("..stepId..") — ABORT")
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        fail(stepId, "timeout "..HUMAN_TIMEOUT_S.."s without response")
        finalizeScenario()
    end, nil, timer.getTime() + HUMAN_TIMEOUT_S)
end

-- ── 12. Step runner ──────────────────────────────────────────────────────────
local steps = {}

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        finalizeScenario()
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        local msg = "S"..S.step.." ERROR: "..tostring(err)
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ "..msg, 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Initial manual check [F10 human]
steps[1] = function()
    instruct(
        "Step 1/3 — INITIAL CHECK (F-XXX)\n"..
        "Describe here what the tester must observe or do.\n"..
        "\nExample:\n"..
        "  F10 → CTLD → [submenu] → [action]\n"..
        "  ✅ expected: [item VISIBLE]\n"..
        "  ❌ expected: [item HIDDEN]\n"..
        "\nAnswer YES/NO/SKIP via F10 → CTLD → CTLD Test."
    )
    setHumanStep("F-XXX", "Correct result?", {
        { label = "YES — expected result",    fn = function() pass("F-XXX", "initial check OK") ; advanceStep() end },
        { label = "NO — incorrect result",    fn = function() fail("F-XXX", "initial check KO") ; advanceStep() end },
        { label = "SKIP — cannot verify",     fn = function() log("[SKIP] S1")                  ; advanceStep() end },
    })
end

-- S2 — DCS condition auto-detected [POLLED via waitFor]
steps[2] = function()
    instruct(
        "Step 2/3 — AUTO-DETECTED ACTION (S2)\n"..
        "Perform the DCS action (e.g. take off, approach zone...).\n"..
        "The scenario will advance automatically upon detection."
    )
    waitFor(
        function()
            -- Replace with the real DCS condition (e.g. S.transport:inAir())
            return S.transport and S.transport:isExist() and S.transport:inAir()
        end,
        3, 300,
        function() pass("S2", "condition detected") ; advanceStep() end,
        function() fail("S2", "timeout condition")  ; advanceStep() end
    )
end

-- S3 — Deferred auto check [waitThen]
steps[3] = function()
    instruct(
        "Step 3/3 — DEFERRED AUTO CHECK (F-YYY)\n"..
        "Automatic check in progress (2s)…"
    )
    waitThen(2, function()
        -- Replace with the real automatic assertions.
        local ok = true   -- example: check result
        if ok then
            pass("F-YYY", "auto check OK")
            log("[AUTO-CHECK] F-YYY PASS")
        else
            fail("F-YYY", "auto check KO")
            log("[AUTO-CHECK] F-YYY FAIL")
        end
        advanceStep()
    end)
end

-- ── 14. Start ────────────────────────────────────────────────────────────────
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
    _SCN_XXX_RESULT = TAG.." ABORT: no BLUE player"
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot before injection.", 20)
    cleanup()
    return _SCN_XXX_RESULT
end

-- Get the player's groupId via CTLDPlayerManager
local pm_start = CTLDPlayerManager.getInstance()
local playerObjStart
if pm_start and pm_start._players then
    for _, p in pairs(pm_start._players) do
        if p.unitName == S.transport:getName() then
            playerObjStart = p ; break
        end
    end
    if not playerObjStart then
        -- Fallback: first available player
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    _SCN_XXX_RESULT = TAG.." ABORT: no CTLD playerObj for transport"
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    cleanup() ; return _SCN_XXX_RESULT
end

S.groupId = playerObjStart.groupId

-- Create the "CTLD Test" submenu under "CTLD" via MenuManager (order=0)
-- Nesting guarantees the submenu stays in the CTLD tree on every refresh.
local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    _SCN_XXX_RESULT = TAG.." ABORT: no CTLD MenuManager menu for player group"
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    cleanup() ; return _SCN_XXX_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
-- addSubMenu is idempotent: if the node already existed (previous cleanup), it does not update
-- order nor enabled. Force both via _getNode.
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_XXX_CLEANUP = cleanup   -- exposed for external reset

_SCN_XXX_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_XXX_RESULT until PASS/FAIL
log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." starting — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return _SCN_XXX_RESULT
