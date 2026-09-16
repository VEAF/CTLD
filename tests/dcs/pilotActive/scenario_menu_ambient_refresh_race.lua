---@diagnostic disable
-- @tier: human (menu) -- a real F10 click at a script-controlled instant is required
-- =============================================================================
-- tests/dcs/pilotActive/scenario_menu_ambient_refresh_race.lua
-- CTLD — FIX-MENU-AMBIENT-REFRESH-RACE regression: no misfire during an ambient refresh
--
-- Replays this lot's own live reproduction (see dev/adr/0015-safe-by-default-ambient-menu-refresh.md):
-- a background ("ambient") menu refresh landing while the player is navigated into
-- Troop Commands > Embark/Extract Troops > Load from <TRZ> must never make their next click
-- fire an unrelated command (the observed misfire: a Smoke drop instead of Load Standard Group).
-- With the fix, the click either resolves to nothing (during the wipe-then-delay window) or to
-- the correct command (after the delayed rebuild completes) — self-verified via
-- CTLDTroopManager:hasTroops(), not just the player's own report.
--
-- Prerequisites:
--   - A BLUE transport occupying a slot, parked on the ground inside a TRZ with pickup stock,
--     no troops aboard (mirrors the reported case exactly — an empty transport, so the troop
--     submenu path has no conditional sibling that could shift F-key numbers on its own).
--   - At least one troop template configured (e.g. "Standard Group").
--
-- Sequence (2 steps, single injection):
--   S1 [F10]  Navigate to the embark screen, confirm ready → script forces one ambient refresh
--   S2 [F10]  Click the displayed "Load [template]" entry, report + auto-verify the outcome
--
-- @scenario  MARR
-- @version   1.0 — 2026-09-16
-- @coverage  FIX-MENU-AMBIENT-REFRESH-RACE
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MARR] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MARR_RESULT = "[MARR] ABORT: CTLD not initialized"
    return _SCN_MARR_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MARR_RUNNING then
    trigger.action.outText("[MARR] already running — wait for completion or restart DCS.", 10)
    return _SCN_MARR_RESULT or "[MARR] RUNNING"
end
_SCN_MARR_RUNNING = true
_SCN_MARR_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MARR_INSTR = ""
_SCN_MARR_SHOW  = function()
    trigger.action.outText(_SCN_MARR_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[MARR]"
local NAME            = "Menu ambient refresh race — no misfire"
local HUMAN_TIMEOUT_S = 3600
local MENU_NAME       = "CTLD Test"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,
    unitName    = nil,
    timerHandle = nil,
    timerGen    = 0,
    transport   = nil,
    playerObj   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_MARR_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MARR_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

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
    _SCN_MARR_INSTR = nil ; _SCN_MARR_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MARR_RUNNING = false
    _SCN_MARR_CLEANUP = nil
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
        summary = TAG.." ✅ [OK] "..NAME.." — "..S.passed.."/"..total.." PASS"
        _SCN_MARR_RESULT = TAG.." PASS "..S.passed.."/"..total
    else
        summary = TAG.." ❌ [KO] "..NAME.." — "..S.failed.." FAIL: "..table.concat(S.failReasons, " | ")
        _SCN_MARR_RESULT = TAG.." FAIL "..S.failed.."/"..total..": "..table.concat(S.failReasons, " | ")
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MARR_RUNNING = false end
end

-- ── 11. Human step (MenuManager) ─────────────────────────────────────────────
local advanceStep

local function setHumanStep(stepId, title, options)
    cancelTimer()
    local myGen = S.timerGen

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm and mm:getMenuByGroupId(S.groupId)
    if not menu then
        log("[ERR] setHumanStep: no CTLD menu for groupId="..tostring(S.groupId))
        fail(stepId, "no CTLD menu") ; finalizeScenario() ; return
    end

    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_MARR_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end
        cancelTimer()
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        opt_fn()
    end

    for _, opt in ipairs(options) do
        local fn = opt.fn
        menu:addCommand(MENU_PATH, opt.label, function() onResponse(fn) end)
    end
    -- This CTLD Test menu itself is refreshed urgently (a direct consequence of running the
    -- scenario, not the ambient condition under test) — explicit opt-in since it has no click
    -- context of its own to auto-detect from.
    menu:refresh({ urgent = true })

    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        log("[TIMEOUT] step "..S.step.." ("..stepId..") — ABORT")
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh({ urgent = true }) end)
        fail(stepId, "timeout "..HUMAN_TIMEOUT_S.."s with no response")
        finalizeScenario()
    end, nil, timer.getTime() + HUMAN_TIMEOUT_S)
end

-- ── 12. Step runner ──────────────────────────────────────────────────────────
local steps = {}

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then finalizeScenario() ; return end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERROR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Navigate to the embark screen, then the script forces one ambient refresh [F10 human]
steps[1] = function()
    if S.playerObj.isTransport ~= true then
        instruct("Step 1/2 — ABORT PREREQUISITE\nThis unit is not a CTLD transport.")
        fail("MARR-0", "not a transport — test impossible") ; finalizeScenario() ; return
    end
    local tm = CTLDTroopManager.getInstance()
    if tm:hasTroops(S.unitName) then
        instruct("Step 1/2 — ABORT PREREQUISITE\nTroops already aboard — start from an empty transport (mirrors the reported case).")
        fail("MARR-0", "troops already aboard — test impossible") ; finalizeScenario() ; return
    end

    instruct(
        "Step 1/2 — NAVIGATE (do not click the template yet)\n"..
        "On the ground, inside a TRZ with troop stock:\n"..
        "  F10 → CTLD → Troop Commands → Embark / Extract Troops → Load from <your TRZ>\n"..
        "You should see the template list (e.g. 'Load Standard Group').\n"..
        "STOP there — do not click a template.\n"..
        "\nOnce you are looking at that screen, confirm below."
    )
    setHumanStep("MARR-1", "On the template list, not yet clicked?", {
        { label = "READY — I'm on the template list", fn = function()
            -- Force one ambient refresh for this group — the same effect a background poller
            -- (e.g. _lgzGroundPoll) has today: no opts, no runUrgent context, so it takes the
            -- ambient path (immediate wipe, delayed rebuild) per ADR 0015.
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:getMenuByGroupId(S.groupId)
            log("[TEST] forcing ambient refresh for groupId="..tostring(S.groupId))
            menu:refresh()
            pass("MARR-1", "ambient refresh forced")
            advanceStep()
        end },
        { label = "SKIP — cannot verify", fn = function() log("[SKIP] S1") ; finalizeScenario() end },
    })
end

-- S2 — Click the template as displayed, report + auto-verify the outcome [F10 human]
steps[2] = function()
    instruct(
        "Step 2/2 — CLICK NOW (MARR-2)\n"..
        "Click the template entry you were already looking at (e.g. 'Load Standard Group'),\n"..
        "exactly as shown on your screen — do not reopen or renavigate the menu first.\n"..
        "\nThen report what happened below."
    )
    setHumanStep("MARR-2", "What happened when you clicked?", {
        { label = "Nothing happened (no CTLD message, no visible effect)", fn = function()
            local tm = CTLDTroopManager.getInstance()
            if tm:hasTroops(S.unitName) then
                fail("MARR-2", "reported nothing happened, but troops ARE aboard — inconsistent")
            else
                pass("MARR-2", "click resolved to nothing during the ambient gap — expected, safe")
            end
            advanceStep()
        end },
        { label = "Troops loaded correctly", fn = function()
            local tm = CTLDTroopManager.getInstance()
            if tm:hasTroops(S.unitName) then
                pass("MARR-2", "embarkFromTroopZone ran correctly — auto-verified via hasTroops()")
            else
                fail("MARR-2", "reported troops loaded, but hasTroops() is false — self-report mismatch")
            end
            advanceStep()
        end },
        { label = "Something else happened (wrong command fired — e.g. smoke)", fn = function()
            fail("MARR-2", "misfire reproduced: an unrelated CTLD command fired instead of embark")
            advanceStep()
        end },
    })
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
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot before injection.", 20)
    _SCN_MARR_RESULT = TAG.." ABORT: no BLUE player"
    cleanup() ; return _SCN_MARR_RESULT
end

local pm_start = CTLDPlayerManager.getInstance()
local playerObjStart
if pm_start and pm_start._players then
    for _, p in pairs(pm_start._players) do
        if p.unitName == S.transport:getName() then playerObjStart = p ; break end
    end
    if not playerObjStart then
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    _SCN_MARR_RESULT = TAG.." ABORT: no CTLD playerObj"
    cleanup() ; return _SCN_MARR_RESULT
end

S.groupId   = playerObjStart.groupId
S.unitName  = playerObjStart.unitName
S.playerObj = playerObjStart

local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    _SCN_MARR_RESULT = TAG.." ABORT: no CTLD MenuManager menu"
    cleanup() ; return _SCN_MARR_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0, enabled = true })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh({ urgent = true })

_SCN_MARR_CLEANUP = cleanup
_SCN_MARR_RESULT  = TAG.." STARTED"

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | 2 steps ===")
trigger.action.outText(TAG.." starting — 2 steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return _SCN_MARR_RESULT
