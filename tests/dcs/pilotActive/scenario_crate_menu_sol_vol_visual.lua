---@diagnostic disable
-- @tier: human (fly)  -- takeoff/landing required (sol/vol/sol menu check)
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_crate_menu_sol_vol_visual.lua
-- CTLD — Crate Commands menu: ground / flight / ground check (visual)
--
-- Interactive test mini-app: single injection, advances
-- automatically (waitFor takeoff/landing) or via the F10 menu
-- "CTLD Test" (visual checks).
--
-- Prerequisites:
--   - UH-1H BLUE slot occupied, helo on the ground near a logistics zone
--   - enableCrates=true, enablePackingVehicles=true in the config
--   - canParachuteDrop=true, canSlingload=true for the UH-1H type
--
-- Sequence (5 steps, single injection):
--   S1 [F10]  Check ground menu           → YES / NO / SKIP
--   S2 [auto] Load crate + take off       → detected via inAir()
--   S3 [auto] Check flight menu           → auto-checked
--   S4 [auto] Land                        → detected via not inAir()
--   S5 [auto] Check ground menu restored  → auto-checked
--
-- @scenario  CMFV
-- @version   2.1 — 2026-06-30
-- @coverage  F-168 (sol), F-169 (vol), F-170 (restauration sol)
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CMFV-VIS] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_CMFV_RESULT = "[CMFV-VIS] ABORT: CTLD not initialized"
    return _SCN_CMFV_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_CMFV_RUNNING then
    trigger.action.outText("[CMFV-VIS] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_CMFV_RESULT or "[CMFV-VIS] RUNNING"
end
_SCN_CMFV_RUNNING = true
_SCN_CMFV_CLEANUP = nil   -- exposed for external reset (reset script)

-- ── 3. Global show callback (Lua closure compatible with MenuManager) ────────
_SCN_CMFV_INSTR = ""
_SCN_CMFV_SHOW  = function()
    trigger.action.outText(_SCN_CMFV_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false   -- internal traces via log() only, not on screen

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[CMFV-VIS]"
local NAME            = "Crate Commands menu — sol/vol/sol"
local HUMAN_TIMEOUT_S = 3600  -- generous: a real pilot session, not a race against the clock
local MENU_NAME       = "CTLD Test"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }   -- inside CTLD (order=999 → last)
local RESP_FLAG       = "CMFV_RESP"

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
    _SCN_CMFV_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_CMFV_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

-- Capture the real Crate Commands menu state into CTLD.log.
local function logMenuSnapshot()
    local ok, err = pcall(function()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then
            for _, p in pairs(pm._players) do playerObj = p ; break end
        end
        if not playerObj then log("[SNAPSHOT] no playerObj") ; return end

        local mm   = ctld.MenuManager:getInstance()
        local menu = mm:getMenuByGroupId(playerObj.groupId)
        if not menu or not menu._lookup then log("[SNAPSHOT] no menu._lookup") ; return end

        local root      = ctld.tr("CTLD")
        local cratesSub = ctld.tr("Crate Commands")
        local prefix    = root .. "." .. cratesSub .. "."

        local seen = {}
        local items = {}
        for path, node in pairs(menu._lookup) do
            if path:find(prefix, 1, true) == 1 then
                local name = path:sub(#prefix + 1)
                if name ~= "" and not name:find(".", 1, true) then
                    if not seen[name] then
                        seen[name] = true
                        local enabled = node.enabled ~= false and "VISIBLE" or "HIDDEN "
                        table.insert(items, "  "..enabled.." : "..name)
                    end
                else
                    local parent = name:match("^([^%.]+)")
                    if parent and not seen[parent] then
                        seen[parent] = true
                        local parentNode = menu._lookup[prefix .. parent]
                        local enabled = (parentNode and parentNode.enabled ~= false) and "VISIBLE" or "HIDDEN "
                        table.insert(items, "  "..enabled.." : "..parent)
                    end
                end
            end
        end
        table.sort(items)
        if #items == 0 then
            log("[SNAPSHOT] Crate Commands: no item found in _lookup (prefix="..prefix..")")
        else
            log("[SNAPSHOT] Crate Commands at response time:\n"..table.concat(items, "\n"))
        end
    end)
    if not ok then log("[SNAPSHOT] ERROR: "..tostring(err)) end
end

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
    trigger.action.setUserFlag(RESP_FLAG, 0)
    _SCN_CMFV_INSTR = nil ; _SCN_CMFV_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_CMFV_RUNNING = false
    _SCN_CMFV_CLEANUP = nil
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

-- Auto-verify Crate Commands menu state.
-- expected = list of {name=string, state="VISIBLE"|"HIDDEN"|"ABSENT"}
-- Returns: ok (bool), issues (list of strings)
local function checkMenuExpected(expected)
    local pm = CTLDPlayerManager.getInstance()
    local playerObj
    if pm and pm._players then
        for _, p in pairs(pm._players) do playerObj = p ; break end
    end
    if not playerObj then return false, {"no playerObj"} end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu or not menu._lookup then return false, {"no menu._lookup"} end

    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")
    local prefix    = root .. "." .. cratesSub .. "."

    -- Build actual state map: itemName → "VISIBLE" | "HIDDEN"
    local actual = {}
    local seen   = {}
    for path, node in pairs(menu._lookup) do
        if path:find(prefix, 1, true) == 1 then
            local rel  = path:sub(#prefix + 1)
            local name = rel:find(".", 1, true) and rel:match("^([^%.]+)") or rel
            if name and name ~= "" and not seen[name] then
                seen[name] = true
                local parentNode = menu._lookup[prefix .. name]
                actual[name] = (parentNode and parentNode.enabled ~= false) and "VISIBLE" or "HIDDEN"
            end
        end
    end
    -- anything not in actual → "ABSENT"

    local issues = {}
    for _, exp in ipairs(expected) do
        local got = actual[exp.name] or "ABSENT"
        if got ~= exp.state then
            table.insert(issues, string.format("  %-22s : got %-7s expected %s", exp.name, got, exp.state))
        end
    end
    return #issues == 0, issues
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
        summary = TAG.." PASS "..S.passed.."/"..total ; _SCN_CMFV_RESULT = summary
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ") ; _SCN_CMFV_RESULT = summary
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_CMFV_RUNNING = false end
end

-- ── 11. Human step (MenuManager) ─────────────────────────────────────────────
-- The "CTLD Test" submenu is created ONLY ONCE in Start (order=999).
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

    -- Clear the previous step's commands and rebuild (ensure the node is visible)
    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_CMFV_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end  -- duplicate or post-timeout: ignore
        cancelTimer()
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        logMenuSnapshot()
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
        fail(stepId, "timeout "..HUMAN_TIMEOUT_S.."s no response")
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

-- S1 — Ground menu check + crate load [F10]
steps[1] = function()
    if cfg.settings["enablePackingVehicles"] ~= true then
        instruct(
            "Step 1/5 — ABORT PREREQUISITE\n"..
            "enablePackingVehicles=false in the config.\n"..
            "This test requires enablePackingVehicles=true.\n"..
            "Change the config and restart."
        )
        fail("F-168", "enablePackingVehicles=false — test not possible")
        finalizeScenario()
        return
    end
    instruct(
        "Step 1/5 — GROUND MENU + LOAD A CRATE (F-168)\n"..
        "Prerequisite: helo on the ground within range of a logistics zone\n"..
        "\nA) Request equipment:\n"..
        "  F10 → CTLD → Request Equipment → [zone] → [category] → [item]\n"..
        "  → a vehicle/equipment appears on the ground\n"..
        "\nB) Pack the vehicle into a crate:\n"..
        "  F10 → CTLD → Crate Commands → Pack Equipt → [vehicle name]\n"..
        "  → the vehicle is replaced by a crate on the ground\n"..
        "\nC) Check F10 → CTLD → Crate Commands (after B the Hummer is already packed — "..
        "Pack Equipt normally disappears, nothing left to pack):\n"..
        "  ✅ VISIBLE  : Load Crate\n"..
        "  ✅ VISIBLE  : Drop Crate(s)\n"..
        "  ✅ VISIBLE  : Unpack Crate\n"..
        "  ✅ VISIBLE  : List Nearby Crates\n"..
        "  ❌ HIDDEN   : Parachute Crates\n"..
        "  ❌ HIDDEN   : Release Slingload\n"..
        "  ❌ HIDDEN   : Cut Slingload\n"..
        "\nD) Load the crate: F10 → CTLD → Crate Commands → Load Crate\n"..
        "\nAnswer YES/NO after A+B+C+D."
    )
    setHumanStep("F-168", "Ground menu correct + crate loaded?", {
        { label = "YES — menu OK and crate loaded",  fn = function() pass("F-168", "ground menu OK") ; advanceStep() end },
        { label = "NO — menu incorrect",             fn = function() fail("F-168", "ground menu KO") ; advanceStep() end },
        { label = "SKIP — cannot verify",            fn = function() log("[SKIP] S1")               ; advanceStep() end },
    })
end

-- S2 — Take off [auto]
steps[2] = function()
    instruct(
        "Step 2/5 — TAKE OFF (auto)\n"..
        "Take off — the scenario will advance automatically\n"..
        "as soon as takeoff is detected."
    )
    waitFor(
        function() return S.transport:isExist() and S.transport:inAir() end,
        3, 300,
        function() pass("S2", "takeoff detected") ; advanceStep() end,
        function() fail("S2", "takeoff timeout") ; advanceStep() end
    )
end

-- S3 — Flight menu check [AUTO]
-- F-169: onTakeoff already calls refreshCrateFlightSection(playerObj, true) via _isFlying flag.
-- waitThen(2) ensures DCS event processing is complete before the check.
steps[3] = function()
    instruct(
        "Step 3/5 — AUTO CHECK FLIGHT MENU (F-169)\n"..
        "Automatic menu check in progress (2s)…"
    )
    local EXPECTED_VOL = {
        { name = "Parachute Crates",  state = "VISIBLE" },
        { name = "Load Crate",        state = "HIDDEN"  },
        { name = "Drop Crate(s)",     state = "HIDDEN"  },
        { name = "Unpack Crate",      state = "HIDDEN"  },
        { name = "List Nearby Crates",state = "HIDDEN"  },
        { name = "Pack Equipt",       state = "ABSENT"  },
        { name = "Release Slingload", state = "HIDDEN"  },
        { name = "Cut Slingload",     state = "HIDDEN"  },
    }
    waitThen(2, function()
        local cm = CTLDCrateManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then for _, p in pairs(pm._players) do playerObj = p ; break end end
        local inAirNow = S.transport and S.transport:isExist() and S.transport:inAir() or false
        log("[AUTO-CHECK] S3 inAir="..tostring(inAirNow))
        if playerObj then cm:refreshCrateFlightSection(playerObj, inAirNow) end

        local ok, issues = checkMenuExpected(EXPECTED_VOL)
        logMenuSnapshot()
        if ok then
            pass("F-169", "flight menu auto-checked OK")
            local msg = TAG.." ✅ F-169 flight menu OK (auto-checked)\nParachute Crates VISIBLE, Pack Equipt ABSENT."
            log("[AUTO-CHECK] F-169 PASS")
            trigger.action.outText(msg, 15, true)
        else
            fail("F-169", "flight menu KO: "..table.concat(issues, " | "))
            local msg = TAG.." ❌ F-169 flight menu KO (auto-checked)\n"..table.concat(issues, "\n")
            log("[AUTO-CHECK] F-169 FAIL: "..table.concat(issues, " | "))
            trigger.action.outText(msg, 20, true)
        end
        advanceStep()
    end)
end

-- S4 — Land without parachuting [auto]
steps[4] = function()
    instruct(
        "Step 4/5 — LAND (auto)\n"..
        "Land WITHOUT using Parachute Crates.\n"..
        "The scenario will advance automatically when landing is detected."
    )
    waitFor(
        function() return S.transport:isExist() and not S.transport:inAir() end,
        3, 300,
        function() pass("S4", "landing detected") ; advanceStep() end,
        function() fail("S4", "landing timeout") ; advanceStep() end
    )
end

-- S5 — Ground menu restored check [AUTO]
-- Key checks: Parachute Crates → HIDDEN (was VISIBLE in flight).
--             Drop Crate(s)    → VISIBLE (crate still aboard).
steps[5] = function()
    instruct(
        "Step 5/5 — AUTO CHECK GROUND RESTORED (F-170)\n"..
        "Automatic menu check in progress (2s)…"
    )
    local EXPECTED_SOL_KEY = {
        { name = "Parachute Crates", state = "HIDDEN"  },
        { name = "Drop Crate(s)",    state = "VISIBLE" },
    }
    waitThen(2, function()
        local cm = CTLDCrateManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then for _, p in pairs(pm._players) do playerObj = p ; break end end
        local inAirNow = S.transport and S.transport:isExist() and S.transport:inAir() or false
        log("[AUTO-CHECK] S5 inAir="..tostring(inAirNow))
        if playerObj then cm:refreshCrateFlightSection(playerObj, inAirNow) end

        local ok, issues = checkMenuExpected(EXPECTED_SOL_KEY)
        logMenuSnapshot()
        if ok then
            pass("F-170", "ground restored auto-checked OK")
            local msg = TAG.." ✅ F-170 ground restored OK (auto-checked)\nParachute Crates HIDDEN, Drop Crate(s) VISIBLE."
            log("[AUTO-CHECK] F-170 PASS")
            trigger.action.outText(msg, 15, true)
        else
            fail("F-170", "ground restored KO: "..table.concat(issues, " | "))
            local msg = TAG.." ❌ F-170 ground restored KO (auto-checked)\n"..table.concat(issues, "\n")
            log("[AUTO-CHECK] F-170 FAIL: "..table.concat(issues, " | "))
            trigger.action.outText(msg, 20, true)
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
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot before injection.", 20)
    cleanup()
    _SCN_CMFV_RESULT = "[CMFV-VIS] ABORT"
    return _SCN_CMFV_RESULT
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
    trigger.action.outText(TAG.." ABORT: no CTLD playerObj for transport.", 20)
    _SCN_CMFV_RESULT = "[CMFV-VIS] ABORT"
    cleanup() ; return _SCN_CMFV_RESULT
end

S.groupId = playerObjStart.groupId

-- Create the "CTLD Test" submenu under "CTLD" via MenuManager (order=999 → last)
-- Nesting guarantees "CTLD Test" is rebuilt with the CTLD tree on every
-- refresh → stays after "CTLD" in the F10 list, never before it.
local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT: no CTLD MenuManager menu for player group.", 20)
    _SCN_CMFV_RESULT = "[CMFV-VIS] ABORT"
    cleanup() ; return _SCN_CMFV_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
-- addSubMenu is idempotent: if the node already existed (previous cleanup), it does not update
-- order nor enabled. Force both via _getNode.
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_CMFV_CLEANUP = cleanup   -- exposed for external reset

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | 5 steps ===")
trigger.action.outText(TAG.." start — 5 steps | "..S.transport:getName(), 8)
_SCN_CMFV_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_CMFV_RESULT until PASS/FAIL
advanceStep()

end  -- do isolation scope
return _SCN_CMFV_RESULT
