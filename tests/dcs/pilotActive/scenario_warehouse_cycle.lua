---@diagnostic disable
-- @tier: human (fly)  -- crate load, takeoff, FARP deploy, reposition >400m, land: genuine piloting
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_warehouse_cycle.lua
-- CTLD — Full FARP warehouse snapshot cycle
--
-- Validates the full pack + warehouse snapshot chain:
--   - Metal FARP crate spawned via F10 menu
--   - Player loads/flies/lands/unpacks FARP via F10
--   - Script sets known fuel levels in the warehouse
--   - Player packs FARP via F10 "Pack FARP"
--   - Script verifies metadata.warehouseSnapshot == the set values
--   - Player flies to a new position and unpacks the FARP
--   - Script verifies the warehouse is restored to the same values
--
-- Flow (7 steps, single injection):
--   S1 [auto]   Setup + instructions: request crate + load + take off + land
--   S2 [human]  Confirm: crate loaded onboard + on the ground?
--   S3 [human]  Confirm: FARP deployed (~15s wait)?
--   S4 [auto]   Verify active scene + SET fuel 5k/10k/15k/20k + pack instructions
--   S5 [human]  Confirm: FARP packed + crate reloaded?
--   S6 [auto]   Verify snapshot + instructions: fly + land at new position
--   S7 [human]  Confirm: FARP redeployed at new position (~15s wait)?
--   S8 [auto]   Verify warehouse restored == the set values
--
-- Prerequisites:
--   - UH-1H BLUE slot occupied, helo on the ground
--   - Farp_FG_Petit_Helipad mod installed (required for the warehouse checks)
--   - enableFARPRepack=true (enabled automatically by S1)
--   - Inject CTLD.lua first, wait 3–5 s for init.
--
-- @scenario  WRHSE
-- @version   3.0 — 2026-06-30
-- @coverage  W.1–W.7
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[WRHSE] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_WRHSE_RESULT = "[WRHSE] ABORT: CTLD not initialized"
    return _SCN_WRHSE_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_WRHSE_RUNNING then
    trigger.action.outText("[WRHSE] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_WRHSE_RESULT or "[WRHSE] RUNNING"
end
_SCN_WRHSE_RUNNING = true
_SCN_WRHSE_CLEANUP = nil

-- ── 3. Global show callback (Lua closure compatible with MenuManager) ────────
_SCN_WRHSE_INSTR = ""
_SCN_WRHSE_SHOW  = function()
    trigger.action.outText(_SCN_WRHSE_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
-- enableFARPRepack is intentionally NOT restored — it must persist during the test.
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[WRHSE]"
local NAME            = "FARP Warehouse Cycle"
local HUMAN_TIMEOUT_S = 600
local MENU_NAME       = "CTLD Test"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }

-- Fuel values to set and verify
local FUEL_SET  = { [0] = 5000, [1] = 10000, [2] = 15000, [3] = 20000 }
local FUEL_NAME = { [0] = "JetFuel(0)", [1] = "AvGas(1)", [2] = "MW50(2)", [3] = "Diesel(3)" }

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step          = 0,
    passed        = 0,
    failed        = 0,
    failReasons   = {},
    groupId       = nil,
    timerHandle   = nil,
    timerGen      = 0,
    transport     = nil,
    packPos       = nil,   -- position recorded at pack time (relocation check)
    savedRequired = nil,   -- original cratesRequired (restored after unpack)
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_WRHSE_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_WRHSE_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end
local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- Find the first active FARP scene supporting onRepack, or nil.
local function findFarpScene()
    local sm = CTLDSceneManager.getInstance()
    for _, sc in pairs(sm._active) do
        local model = sm:getModel(sc._modelName)
        if model and model.onRepack then return sc end
    end
    return nil
end

-- Find the first FARP crate carrying a warehouseSnapshot, or nil.
local function findPackedCrate()
    local cm = CTLDCrateManager.getInstance()
    for _, crate in pairs(cm.crates) do
        if crate.metadata and crate.metadata.warehouseSnapshot then
            return crate
        end
    end
    return nil
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
    _SCN_WRHSE_INSTR = nil ; _SCN_WRHSE_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_WRHSE_RUNNING = false
    _SCN_WRHSE_CLEANUP = nil
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
        _SCN_WRHSE_RESULT = TAG.." PASS "..S.passed.."/"..total
    else
        summary = TAG.." ❌ [KO] "..NAME.." — "..S.failed.." FAIL: "..
            table.concat(S.failReasons, " | ")
        _SCN_WRHSE_RESULT = TAG.." FAIL "..S.failed.."/"..total..": "..table.concat(S.failReasons, " | ")
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_WRHSE_RUNNING = false end
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
        fail(stepId, "no CTLD menu")
        finalizeScenario()
        return
    end

    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_WRHSE_SHOW)

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
    menu:refresh()

    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        log("[TIMEOUT] step "..S.step.." ("..stepId..") — ABORT")
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        fail(stepId, "timeout "..HUMAN_TIMEOUT_S.."s with no response")
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
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERROR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Setup + instructions (auto)
steps[1] = function()
    -- (removed dead FullGas ctld_test.cleanup() -- nil at runtime, same cause as the 194 relics;
    -- the scenario does its own Metal FARP scene cleanup just below.)
    cfg.settings["enableFARPRepack"] = true

    -- Destroy any existing Metal FARP scene
    local sm = CTLDSceneManager.getInstance()
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Metal FARP" then sm:packScene(sc) end
    end

    -- Verify Metal FARP descriptor
    local mgr_c = CTLDCrateManager.getInstance()
    local desc  = mgr_c:findDescriptorByUnitType("Metal FARP")
    check("W.1.1", "Metal FARP descriptor available", desc ~= nil)

    -- Force cratesRequired=1 for this test (restored after unpack at step 4)
    if desc then
        S.savedRequired     = desc.cratesRequired
        desc.cratesRequired = 1
        log("W.1.x [INFO] cratesRequired: "..tostring(S.savedRequired).." -> 1")
    end

    -- Record the player's current position
    if S.transport then
        local p = S.transport:getPoint()
        S.packPos = { x = p.x, z = p.z }
    end

    instruct(
        "Step 1/"..#steps.." — SETUP ACTIVE (enableFARPRepack=true)\n"..
        "FUEL TARGET : Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000\n"..
        "\nActions to perform:\n"..
        "  1. F10 → Request Equipment → [zone] → Metal FARP (request 1 crate)\n"..
        "  2. F10 → Crate Commands → Load Crate → Metal FARP\n"..
        "  3. Take off\n"..
        "  4. Land\n"..
        "\nConfirm YES when done."
    )
    setHumanStep("W.S1", "Crate loaded, took off and landed?", {
        { label = "YES — crate loaded, took off, landed", fn = function() pass("W.S1", "S1 actions confirmed") ; advanceStep() end },
        { label = "SKIP — skip this step",               fn = function() log("[SKIP] S1") ; advanceStep() end },
    })
end

-- S2 — Verify crate loaded + unload+unpack instructions [human]
steps[2] = function()
    local mgr_c    = CTLDCrateManager.getInstance()
    local found    = false
    local stateStr = "?"
    for _, crate in pairs(mgr_c.crates) do
        if crate.descriptor then
            found    = true
            stateStr = tostring(crate.state).." unit="..tostring(crate.descriptor.unit)
            break
        end
    end
    check("W.2.1", "FARP crate present in the manager", found, "Did you load the crate before confirming?")
    log("W.2.1 [INFO] crate.state = "..stateStr)

    instruct(
        "Step 2/"..#steps.." — UNLOAD + UNPACK FARP\n"..
        "\nActions to perform:\n"..
        "  1. F10 → Crate Commands → Unload Crate\n"..
        "  2. F10 → Crate Commands → Unpack Crate → Metal FARP\n"..
        "  3. Wait ~15s for the FARP scene to deploy\n"..
        "\nConfirm YES when the FARP is deployed."
    )
    setHumanStep("W.S2", "FARP deployed (~15s)?", {
        { label = "YES — FARP deployed",  fn = function() pass("W.S2", "FARP deployment confirmed") ; advanceStep() end },
        { label = "SKIP — skip",          fn = function() log("[SKIP] S2") ; advanceStep() end },
    })
end

-- S3 — Verify active scene + SET fuel + pack instructions [auto then human]
steps[3] = function()
    instruct(
        "Step 3/"..#steps.." — SCENE CHECK + SET FUEL (auto)\n"..
        "Auto-checking the active FARP scene and setting the fuel levels…"
    )
    waitThen(2, function()
        -- Restore cratesRequired now that the FARP is deployed
        local mgr_c_r = CTLDCrateManager.getInstance()
        local sc_r    = findFarpScene()
        local desc_r  = sc_r and mgr_c_r:findDescriptorByUnitType(sc_r._modelName)
        if desc_r and S.savedRequired then
            desc_r.cratesRequired = S.savedRequired
            log("W.3.x [INFO] cratesRequired restored to "..S.savedRequired)
        end

        local farpScene = findFarpScene()
        check("W.3.1", "active FARP scene in CTLDSceneManager", farpScene ~= nil,
            "Did you unpack the FARP and wait ~15s?")
        if not farpScene then fail("W.3.1b", "FARP scene not found") ; advanceStep() ; return end

        local farpName = farpScene._params and farpScene._params.farpName
        check("W.3.2", "farpName set in scene._params", farpName ~= nil)
        if not farpName then fail("W.3.2b", "farpName nil — scene has no airbase") ; advanceStep() ; return end

        local ab = Airbase.getByName(farpName)
        check("W.3.3", "Airbase '"..farpName.."' found", ab ~= nil)
        if not ab then fail("W.3.3b", "Airbase.getByName returned nil") ; advanceStep() ; return end

        local w = ab:getWarehouse()
        check("W.3.4", "warehouse accessible (Farp_FG_Petit_Helipad mod required)", w ~= nil,
            "getWarehouse() returned nil — this scene has no accessible warehouse")
        if not w then fail("W.3.4b", "warehouse nil") ; advanceStep() ; return end

        -- Set the known fuel levels
        for fuelType = 0, 3 do
            w:setLiquidAmount(fuelType, FUEL_SET[fuelType])
        end
        for fuelType = 0, 3 do
            local ok_rb, readback = pcall(function() return w:getLiquidAmount(fuelType) end)
            if ok_rb then
                local match = math.abs(readback - FUEL_SET[fuelType]) < 1
                check("W.3."..(fuelType + 5),
                    FUEL_NAME[fuelType].." set="..FUEL_SET[fuelType].." readback OK",
                    match, "readback="..tostring(readback))
            else
                log("W.3."..(fuelType + 5).." [INFO] getLiquidAmount not available — set only")
            end
        end

        instruct(
            "Step 3/"..#steps.." — FUEL SET ✅\n"..
            "Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000\n"..
            "\nActions to perform:\n"..
            "  1. F10 → Crate Commands → Pack FARP → Pack Metal FARP\n"..
            "  2. F10 → Crate Commands → Load Crate (the crate that just appeared)\n"..
            "\nConfirm YES when the crate is loaded."
        )
        setHumanStep("W.S3", "FARP packed + crate loaded?", {
            { label = "YES — FARP packed, crate loaded", fn = function() pass("W.S3", "pack+load confirmed") ; advanceStep() end },
            { label = "SKIP — skip",                     fn = function() log("[SKIP] S3") ; advanceStep() end },
        })
    end)
end

-- S4 — Verify warehouseSnapshot in the crate + flight instructions [auto then human]
steps[4] = function()
    instruct(
        "Step 4/"..#steps.." — SNAPSHOT CHECK (auto)\n"..
        "Auto-checking the warehouseSnapshot in the crate…"
    )
    waitThen(1, function()
        local packed_crate = findPackedCrate()
        check("W.4.1", "FARP crate with warehouseSnapshot found", packed_crate ~= nil,
            "Did you Pack FARP then Load the crate?")
        if not packed_crate then fail("W.4.1b", "No packed crate with snapshot found") ; advanceStep() ; return end

        local snap = packed_crate.metadata.warehouseSnapshot
        check("W.4.2", "warehouseSnapshot.liquid is a table", type(snap.liquid) == "table",
            "type="..type(snap.liquid))

        if snap.liquid then
            for fuelType = 0, 3 do
                local expected = FUEL_SET[fuelType]
                local actual   = snap.liquid[fuelType]
                check("W.4."..(fuelType + 3),
                    FUEL_NAME[fuelType].." snapshot == "..expected,
                    type(actual) == "number" and math.abs(actual - expected) < 1,
                    "expected="..expected.." actual="..tostring(actual))
            end
        end

        -- Record the current pack position
        if S.transport then
            local p = S.transport:getPoint()
            S.packPos = { x = p.x, z = p.z }
            log("W.4.8 [INFO] Pack position: x="..math.floor(p.x).." z="..math.floor(p.z))
        end

        instruct(
            "Step 4/"..#steps.." — SNAPSHOT VERIFIED ✅\n"..
            "\nActions to perform:\n"..
            "  1. Take off\n"..
            "  2. Fly to a DIFFERENT position (at least 400m)\n"..
            "  3. Land\n"..
            "\nConfirm YES when landed at the new position."
        )
        setHumanStep("W.S4", "Landed at new position (>400m)?", {
            { label = "YES — landed at new position", fn = function() pass("W.S4", "relocation confirmed") ; advanceStep() end },
            { label = "SKIP — skip",                  fn = function() log("[SKIP] S4") ; advanceStep() end },
        })
    end)
end

-- S5 — Verify relocation + unload+unpack instructions [auto then human]
steps[5] = function()
    instruct(
        "Step 5/"..#steps.." — RELOCATION CHECK (auto)\n"..
        "Auto-checking the relocation…"
    )
    waitThen(1, function()
        if not S.transport then fail("W.5.0", "no BLUE player unit") ; advanceStep() ; return end

        check("W.5.1", "transport on the ground", not ctld.utils.inAir(S.transport),
            "inAir="..tostring(ctld.utils.inAir(S.transport)))

        if S.packPos then
            local p    = S.transport:getPoint()
            local dx   = p.x - S.packPos.x
            local dz   = p.z - S.packPos.z
            local dist = math.sqrt(dx * dx + dz * dz)
            log("W.5.2 [INFO] Distance from pack position: "..math.floor(dist).." m")
            if dist < 100 then
                fail("W.5.2", "transport still near the pack position ("..math.floor(dist).." m) — fly > 400m")
            else
                pass("W.5.2", "Relocated: "..math.floor(dist).." m")
            end
        else
            log("W.5.2 [INFO] Pack position not recorded — relocation check skipped")
        end

        instruct(
            "Step 5/"..#steps.." — RELOCATION ✅\n"..
            "\nActions to perform:\n"..
            "  1. F10 → Crate Commands → Unload Crate\n"..
            "  2. F10 → Crate Commands → Unpack Crate → Metal FARP\n"..
            "  3. Wait ~15s for the FARP scene to deploy\n"..
            "\nConfirm YES when the FARP is deployed at the new position."
        )
        setHumanStep("W.S5", "FARP redeployed at new position (~15s)?", {
            { label = "YES — FARP redeployed", fn = function() pass("W.S5", "redeployment confirmed") ; advanceStep() end },
            { label = "SKIP — skip",           fn = function() log("[SKIP] S5") ; advanceStep() end },
        })
    end)
end

-- S6 — Verify new active FARP scene [auto]
steps[6] = function()
    instruct(
        "Step 6/"..#steps.." — NEW FARP SCENE CHECK (auto)\n"..
        "Auto-checking the FARP scene at the new position…"
    )
    waitThen(2, function()
        local farpScene2 = findFarpScene()
        check("W.6.1", "new active FARP scene in CTLDSceneManager", farpScene2 ~= nil,
            "Did you unpack the FARP and wait ~15s?")
        if not farpScene2 then fail("W.6.1b", "No active FARP scene found") ; advanceStep() ; return end

        local farpName2 = farpScene2._params and farpScene2._params.farpName
        check("W.6.2", "farpName set in new scene._params", farpName2 ~= nil,
            "Mod required — without it the warehouse check at S7 will fail")
        log("W.6.2 [INFO] FARP airbase name: "..tostring(farpName2))

        advanceStep()
    end)
end

-- S7 — Verify warehouse fuel restored [auto]
steps[7] = function()
    instruct(
        "Step 7/"..#steps.." — WAREHOUSE RESTORED CHECK (auto)\n"..
        "Final check: fuel restored from the snapshot.\n"..
        "Expected : Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000"
    )
    waitThen(2, function()
        local farpScene2 = findFarpScene()
        check("W.7.1", "FARP scene still active", farpScene2 ~= nil)
        if not farpScene2 then fail("W.7.1b", "scene disappeared between S6 and S7") ; advanceStep() ; return end

        local farpName2 = farpScene2._params and farpScene2._params.farpName
        check("W.7.2", "farpName available from scene._params", farpName2 ~= nil,
            "Farp_FG_Petit_Helipad mod required")
        if not farpName2 then fail("W.7.2b", "farpName nil — mod missing") ; advanceStep() ; return end

        local ab = Airbase.getByName(farpName2)
        check("W.7.3", "Airbase '"..farpName2.."' accessible", ab ~= nil)
        if not ab then fail("W.7.3b", "Airbase.getByName returned nil") ; advanceStep() ; return end

        local w      = ab:getWarehouse()
        local passed = 0
        for fuelType = 0, 3 do
            local expected = FUEL_SET[fuelType]
            local actual   = w:getLiquidAmount(fuelType)
            local ok       = type(actual) == "number" and math.abs(actual - expected) < 1
            check("W.7."..(fuelType + 4),
                FUEL_NAME[fuelType].." restored: expected="..expected.." actual="..tostring(actual),
                ok,
                "delta="..tostring(actual and math.abs(actual - expected) or "nil"))
            if ok then passed = passed + 1 end
        end

        log("Fuel types verified: "..passed.."/4 PASS")
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
    _SCN_WRHSE_RESULT = TAG.." ABORT: no BLUE player"
    cleanup()
    return _SCN_WRHSE_RESULT
end

-- Retrieve the player's groupId via CTLDPlayerManager
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
    _SCN_WRHSE_RESULT = TAG.." ABORT: no CTLD playerObj"
    cleanup() ; return _SCN_WRHSE_RESULT
end

S.groupId = playerObjStart.groupId

-- Create the "CTLD Test" submenu under "CTLD" via MenuManager
local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT: no CTLD MenuManager menu for player group.", 20)
    _SCN_WRHSE_RESULT = TAG.." ABORT: no CTLD MenuManager menu"
    cleanup() ; return _SCN_WRHSE_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_WRHSE_CLEANUP = cleanup
_SCN_WRHSE_RESULT  = TAG.." STARTED"

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." starting — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return _SCN_WRHSE_RESULT
