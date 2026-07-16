---@diagnostic disable
-- @tier: auto-check  (needs a BLUE slot for position; spawns its own Metal FARP scene,
--                     no piloting/F10 -- STARTED; handles the Farp_FG_Petit_Helipad mod being
--                     absent gracefully, so it PASSes with or without the mod)
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_p4_metal_farp.lua
-- CTLD — Metal FARP via F10 menu: warehouse stocking (sub-case P4)
--
-- Validates:
--   - playScene "Metal FARP" runs correctly
--   - Step 9 (func) calls addLiquid on the warehouse if the mod is present
--   - If mod absent: step 1 skips spawn (farpName = nil), step 9 no-op, no crash
--
-- Sequence (2 steps, single injection):
--   S1 [auto] playScene Metal FARP on the player transport
--   S2 [auto T+35] Verify warehouse stocked (if mod present) or clean skip (if absent)
--
-- Prerequisites:
--   - UH-1H BLUE on the ground
--   - Inject CTLD.lua first, wait 3–5 s for init.
--
-- @scenario  P4-METAL
-- @version   3.0 — 2026-06-30
-- @coverage  P4.1–P4.5
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[P4-METAL] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_P4METAL_RESULT = "[P4-METAL] ABORT: CTLD not initialized"
    return _SCN_P4METAL_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_P4METAL_RUNNING then
    trigger.action.outText("[P4-METAL] already running — wait for completion or restart DCS.", 10)
    return _SCN_P4METAL_RESULT or "[P4-METAL] RUNNING"
end
_SCN_P4METAL_RUNNING = true
_SCN_P4METAL_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[P4-METAL]"
local NAME = "Metal FARP warehouse stocking"

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
    log("[INSTR] " .. msg)
    -- Expose the current instruction globally so run_manual_scenario.py mirrors it to the terminal
    -- (return-contract convention; without this the CLI shows nothing, only the DCS screen does).
    _SCN_P4METAL_INSTR = TAG .. "\n" .. msg
    trigger.action.outText(_SCN_P4METAL_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end
local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_P4METAL_RUNNING = false
    _SCN_P4METAL_CLEANUP = nil
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
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." PASS "..S.passed.."/"..total ; _SCN_P4METAL_RESULT = summary
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ") ; _SCN_P4METAL_RESULT = summary
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_P4METAL_RUNNING = false end
end

-- ── 12. Step runner ──────────────────────────────────────────────────────────
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

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Start the Metal FARP scene
steps[1] = function()
    instruct(
        "Step 1/2 — START METAL FARP SCENE (auto)\n"..
        "Starting playScene Metal FARP (~25s).\n"..
        "Warehouse check in 35s…"
    )

    local sm    = CTLDSceneManager.getInstance()
    local model = sm:getModel("Metal FARP")
    check("P4.1", "scene model 'Metal FARP' registered", model ~= nil)
    if not model then fail("P4.1b", "scene Metal FARP not found") ; return end

    -- Cleanup: destroy any existing Metal FARP scene
    -- (removed dead FullGas ctld_test.cleanup() -- nil, same cause as the 194 relics)
    for _, sc in pairs(sm._active or {}) do
        if sc._modelName == "Metal FARP" then pcall(function() sm:packScene(sc) end) end
    end

    local scene = sm:playScene(S.transport, "Metal FARP", {})
    check("P4.2", "playScene Metal FARP started", scene ~= nil)
    if not scene then fail("P4.2b", "playScene returned nil") ; return end

    log("Metal FARP scene started (~25s). Warehouse check in 35s.")
    waitThen(35, advanceStep)
end

-- S2 — Verify warehouse stocking (~T+35)
steps[2] = function()
    instruct(
        "Step 2/2 — WAREHOUSE CHECK (auto T+35)\n"..
        "Auto check of Metal FARP warehouse stocking."
    )

    -- Look for an Airbase named Farp_FG_Petit_Helipad*
    -- If the mod is absent, no airbase of this type exists
    local farpAb  = nil
    local farpName = nil

    for _, ab in pairs(world.getAirbases()) do
        local n = ab:getName()
        if n and n:find("Farp_FG_Petit_Helipad") then
            farpAb   = ab
            farpName = n
            break
        end
    end

    if not farpAb then
        -- Mod absent: expected behavior = no airbase, no crash
        pass("P4.3", "mod absent: no Farp_FG_Petit_Helipad airbase (expected behavior)")
        pass("P4.4", "no crash even without the mod (clean SKIP)")
    else
        log("Farp airbase detected: "..farpName)
        local w = farpAb:getWarehouse()
        check("P4.3", "warehouse accessible", w ~= nil)
        if w then
            local jet   = w:getLiquid(0)
            local avgas = w:getLiquid(1)
            local mw50  = w:getLiquid(2)
            local diese = w:getLiquid(3)
            log(string.format("Warehouse — jet=%d avgas=%d mw50=%d diesel=%d",
                jet or 0, avgas or 0, mw50 or 0, diese or 0))
            check("P4.4", "jet fuel > 0 after stocking",  (jet  or 0) > 0)
            check("P4.5", "avgas > 0 after stocking",     (avgas or 0) > 0)
        end
    end

    advanceStep()
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
    _SCN_P4METAL_RESULT = "[P4-METAL] ABORT"
    return _SCN_P4METAL_RESULT
end

_SCN_P4METAL_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | "..#steps.." steps ===")
trigger.action.outText(TAG.." starting — "..#steps.." steps | "..S.transport:getName(), 8)
_SCN_P4METAL_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_P4METAL_RESULT until PASS/FAIL
advanceStep()

end  -- do isolation scope
return _SCN_P4METAL_RESULT
