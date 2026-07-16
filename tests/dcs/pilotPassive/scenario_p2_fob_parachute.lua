---@diagnostic disable
-- @tier: auto-check  (needs a BLUE slot for position; spawns its own FOB crates + auto-unpacks,
--                     no piloting/F10 -- STARTED, resolves via internal timers)
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_p2_fob_parachute.lua
-- CTLD — FOB auto-unpack from a parachute drop (sub-case P2)
--
-- Validates:
--   (a) checkSpatialGuards blocks if too close to an existing LGZ
--   (b) when the guards pass: scene plays + FOB registered in CTLDFOBManager
--
-- Flow (3 steps, single injection):
--   S1 [auto] Spawn 3 FOB crates LANDED+fromParachute + fake LGZ → guard blocks
--   S2 [auto] Remove fake LGZ → auto-unpack triggers FOB scene
--   S3 [auto T+130] Verify FOB registered
--
-- Prerequisites:
--   - UH-1H BLUE on the ground, > 500 m from any existing logistic zone
--   - Inject CTLD.lua first, wait 3–5 s for init.
--
-- @scenario  P2-FOB-PARA
-- @version   3.0 — 2026-06-30
-- @coverage  P2.1–P2.6
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[P2-FOB-PARA] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_P2FOBPARA_RESULT = "[P2-FOB-PARA] ABORT: CTLD not initialized"
    return _SCN_P2FOBPARA_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_P2FOBPARA_RUNNING then
    trigger.action.outText("[P2-FOB-PARA] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_P2FOBPARA_RESULT or "[P2-FOB-PARA] RUNNING"
end
_SCN_P2FOBPARA_RUNNING = true
_SCN_P2FOBPARA_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG      = "[P2-FOB-PARA]"
local NAME     = "FOB auto-unpack from a parachute drop"
local FAKE_LGZ = "_p2_fake_lgz_"

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
    _SCN_P2FOBPARA_INSTR = TAG .. "\n" .. msg
    trigger.action.outText(_SCN_P2FOBPARA_INSTR, 360, true)
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
    _SCN_P2FOBPARA_RUNNING = false
    _SCN_P2FOBPARA_CLEANUP = nil
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
        summary = TAG.." PASS "..S.passed.."/"..total ; _SCN_P2FOBPARA_RESULT = summary
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ") ; _SCN_P2FOBPARA_RESULT = summary
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_P2FOBPARA_RUNNING = false end
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

-- S1 — Spawn 3 FOB crates LANDED+fromParachute + fake LGZ → guard must block
steps[1] = function()
    instruct(
        "Step 1/3 — GUARD TEST (P2.1–P2.3)\n"..
        "Spawn 3 FOB crates LANDED+fromParachute + fake LGZ at the centroid.\n"..
        "Auto-check that the guard blocks the auto-unpack."
    )

    -- (removed dead FullGas ctld_test.cleanup() -- nil, same cause as the 194 relics; the
    -- scenario does its own FOB cleanup just below, and the runner resets via _SCN_*_CLEANUP.)

    if not S.transport then fail("P2.0", "no BLUE player") ; return end

    local cId   = S.transport:getCoalition()
    local pPos  = S.transport:getPoint()
    local hdg   = ctld.utils.getHeadingInRadians("p2", S.transport, true)

    -- Cleanup existing FOBs
    local fobMgr = CTLDFOBManager.getInstance()
    for _, fob in ipairs(fobMgr:getFOBsForCoalition(cId)) do
        pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(fob.name) end)
        fobMgr._fobs[fob.fobId] = nil
    end
    fobMgr._objectToFOB = {}

    -- FOB descriptor
    local cm      = CTLDCrateManager.getInstance()
    local fobDesc = cm:findDescriptorByUnitType("FOB")
    check("P2.1", "FOB descriptor present", fobDesc ~= nil)
    if not fobDesc then fail("P2.1b", "FOB descriptor missing") ; return end

    -- Centroid: 80 m in front of the helo
    local cx = pPos.x + math.cos(hdg) * 80
    local cz = pPos.z + math.sin(hdg) * 80
    local cy = land.getHeight({ x = cx, y = cz })

    -- Spawn 3 FOB crates LANDED + fromParachute around the centroid (< 20 m)
    local spawned = 0
    for i = 1, 3 do
        local angle = (i - 1) * (2 * math.pi / 3)
        local nx = cx + math.cos(angle) * 8
        local nz = cz + math.sin(angle) * 8
        local ny = land.getHeight({ x = nx, y = nz })
        local c = cm:spawnCrate(fobDesc, { x = nx, y = ny, z = nz }, cId,
            "p2_script", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
        if c then
            c.state         = CTLDCrate.STATE.LANDED
            c.fromParachute = true
            c.position      = { x = nx, y = ny, z = nz }
            spawned = spawned + 1
        end
    end
    check("P2.2", "3 FOB crates spawned LANDED+fromParachute", spawned == 3, "spawned="..spawned)

    -- Register fake LGZ AT the centroid (guard: too close = blocked)
    local fakeRadius = ctld.gs("fobLogisticZoneRadius") or 150
    CTLDZoneManager.getInstance():registerFOBAsLogistic(FAKE_LGZ, { x = cx, y = cy, z = cz }, fakeRadius, cId)
    log("fake LGZ '"..FAKE_LGZ.."' registered at the centroid")

    local fobsBefore = #fobMgr:getFOBsForCoalition(cId)

    -- _checkAutoUnpack: must be blocked by the guard
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor and c.descriptor.unit == "FOB" then
            cm:_checkAutoUnpack(c)
            break
        end
    end

    local fobsAfter = #fobMgr:getFOBsForCoalition(cId)
    check("P2.3", "guard blocks FOB auto-unpack when LGZ too close",
        fobsAfter == fobsBefore,
        "fobsBefore="..fobsBefore.." fobsAfter="..fobsAfter)

    log("Step 1 OK — removing LGZ in 1s for step 2")
    waitThen(1, advanceStep)
end

-- S2 — Remove the fake LGZ → auto-unpack triggers FOB scene
steps[2] = function()
    instruct(
        "Step 2/3 — HAPPY PATH (auto)\n"..
        "Remove fake LGZ → auto-unpack triggers FOB scene.\n"..
        "FOB check in 160s…"
    )

    local cId = S.transport and S.transport:getCoalition() or coalition.side.BLUE

    -- Remove the fake LGZ
    pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(FAKE_LGZ) end)
    log("fake LGZ '"..FAKE_LGZ.."' removed")

    local cm = CTLDCrateManager.getInstance()

    -- _checkAutoUnpack: guards pass now → FOB scene starts
    -- Temporarily clear ALL logistic zones so mission real LGZs (e.g. Batumi)
    -- don't block the guard (test is about the fake-LGZ guard, not real mission layout)
    local zm = CTLDZoneManager.getInstance()
    local _savedLGZs = zm._logisticZones
    zm._logisticZones = {}
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor and c.descriptor.unit == "FOB" then
            cm:_checkAutoUnpack(c)
            break
        end
    end
    zm._logisticZones = _savedLGZs

    log("FOB scene started (async). Check in 160s.")
    waitThen(160, advanceStep)
end

-- S3 — Verify FOB registered (~T+130)
steps[3] = function()
    instruct(
        "Step 3/3 — FOB CHECK (auto)\n"..
        "Auto-check that the FOB is registered in CTLDFOBManager."
    )

    local cId = S.transport and S.transport:getCoalition() or coalition.side.BLUE
    local fobMgr = CTLDFOBManager.getInstance()
    local fobs   = fobMgr:getFOBsForCoalition(cId)

    check("P2.4", "at least 1 FOB registered after parachute auto-unpack",
        #fobs >= 1, "count="..#fobs)

    if #fobs >= 1 then
        local fob = fobs[1]
        check("P2.5", "FOB isAlive()", fob:isAlive())
        local intPct = math.floor(fob:getIntegrityPercent() * 100 + 0.5)
        check("P2.6", "integrity = 100%", intPct == 100, "integrity="..intPct.."%")
        log(string.format("FOB '%s' @ (%.0f, %.0f) — %d%% integrity",
            fob.name, fob.position.x, fob.position.z, intPct))
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
    _SCN_P2FOBPARA_RESULT = "[P2-FOB-PARA] ABORT"
    return _SCN_P2FOBPARA_RESULT
end

_SCN_P2FOBPARA_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | "..#steps.." steps ===")
trigger.action.outText(TAG.." starting — "..#steps.." steps | "..S.transport:getName(), 8)
_SCN_P2FOBPARA_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_P2FOBPARA_RESULT until PASS/FAIL
advanceStep()

end  -- do isolation scope
return _SCN_P2FOBPARA_RESULT
