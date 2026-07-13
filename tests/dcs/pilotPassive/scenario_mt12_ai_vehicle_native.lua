---@diagnostic disable
-- @tier: auto-slow  (no human, but needs minutes of real AI-heli flight to resolve -- excluded from the fast --headless sweep; run with --tier auto-slow. Core logic already covered fast by noPlayer aiTransport_featureT/U F-176..182. See ticket 06/07)
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_mt12_ai_vehicle_native.lua
-- CTLD — AI auto-pickup of a native DCS vehicle via vehicleStock (Feature T)
--
-- Interactive test mini-application: single injection, advances
-- automatically (waitFor) to detect the virtual pickup and dropoff.
--
-- Prerequisites:
--   - BLUE heli named "heliai_mt12" (UH-60L or canTransportWholeVehicle=true)
--   - Route: WP1 = landed on AIZ_mt12_B_P_V → WP3 = landed on AIZ_mt12_B_D
--   - DCS trigger zone "AIZ_mt12_B_P_V" (radius ~200 m)
--   - DCS trigger zone "AIZ_mt12_B_D"   (radius ~200 m)
--   - NO DCS vehicle group inside AIZ_mt12_B_P_V (otherwise C1 takes precedence over C2)
--   - vehicleStock = { ["Hummer"] = 2 } in the zone config
--   - BLUE slot occupied (human player for MenuManager)
--   - CTLD.lua injected before this script (wait 3-5 s)
--
-- Sequence (4 steps, single injection):
--   S1 [auto]  Init + zone verification + initial vehicleStock
--   S2 [auto]  Wait for virtual pickup (_aiTransportVehicle populated) via waitFor
--   S3 [auto]  Wait for dropoff (_aiTransportVehicle cleared = DCS spawn) via waitFor
--   S4 [auto]  Finalization
--
-- @scenario  MT-12
-- @version   4.0 — 2026-07-01
-- @coverage  AI vehicle native pickup, AI vehicle dropoff spawn DCS (clone spawn, repeatable)
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-12] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MT12_RESULT = "[MT-12] ABORT: CTLD not initialized"
    return _SCN_MT12_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT12_RUNNING then
    trigger.action.outText("[MT-12] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_MT12_RESULT or "[MT-12] RUNNING"
end
_SCN_MT12_RUNNING = true
_SCN_MT12_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT12_INSTR = ""
_SCN_MT12_SHOW  = function()
    trigger.action.outText(_SCN_MT12_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-12]"
local NAME      = "AI native vehicle pickup/dropoff via vehicleStock"
local MENU_NAME = "CTLD Test"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

local AI_SRC   = "heliai_mt12"      -- late-activation source in the .miz (never activated)
local AI_UNIT  = "heliai_mt12_run"  -- temporary clone (spawned + destroyed at cleanup)
local AIZ_P    = "AIZ_mt12_B_P_V"
local AIZ_D    = "AIZ_mt12_B_D"
local VEH_TYPE = "Hummer"

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

-- Clone helpers (ctld.utils.deepCopy returns nil — a local deepCopy is required)
local function deepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do copy[deepCopy(k)] = deepCopy(v) end
        setmetatable(copy, getmetatable(orig))
    else copy = orig end
    return copy
end

local function findGrpInMission(name)
    for _, cData in pairs(env.mission.coalition or {}) do
        for _, country in ipairs(cData.country or {}) do
            for _, cat in ipairs({"helicopter","plane","vehicle","ship"}) do
                for _, grp in ipairs((country[cat] or {}).group or {}) do
                    if grp.name == name then return grp, country.id end
                end
            end
        end
    end
    return nil, nil
end

local function spawnClone(srcName, cloneName)
    local tmpl, ctryId = findGrpInMission(srcName)
    if not tmpl then return nil, "not found in env.mission: " .. srcName end
    local clone = deepCopy(tmpl)
    clone.name            = cloneName
    clone.units[1].name   = cloneName
    clone.groupId         = nil
    clone.units[1].unitId = nil
    clone.lateActivation  = false
    local ok, _ = pcall(coalition.addGroup, ctryId, Group.Category.HELICOPTER, clone)
    if not ok then return nil, "coalition.addGroup failed for " .. cloneName end
    local g = Group.getByName(cloneName)
    if not g then return nil, "group not found after spawn: " .. cloneName end
    return g, nil
end

local function destroyClone(cloneName)
    local g = Group.getByName(cloneName)
    if g and g:isExist() then pcall(function() g:destroy() end) ; log("clone destroyed: "..cloneName) end
end

local function instruct(msg)
    _SCN_MT12_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT12_INSTR, 360, true)
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
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT then table.remove(names, i) end
    end
    local cm = CTLDCoreManager.getInstance()
    if cm._aiTransportVehicle then cm._aiTransportVehicle[AI_UNIT] = nil end
    destroyClone(AI_UNIT)
    _SCN_MT12_INSTR = nil ; _SCN_MT12_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT12_RUNNING = false
    _SCN_MT12_CLEANUP = nil
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
        summary = TAG.." PASS "..S.passed.."/"..total ; _SCN_MT12_RESULT = summary
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ") ; _SCN_MT12_RESULT = summary
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT12_RUNNING = false end
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

-- S1 — Init + zone verification + initial vehicleStock [auto]
steps[1] = function()
    instruct(
        "Step 1/4 — INIT AI VEHICLE NATIVE (MT-12)\n"..
        "Verifying Hummer vehicleStock (isScene=false)…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-12.1.1", "AIZ_P found: "..AIZ_P, zP ~= nil)
        check("MT-12.1.2", "AIZ_D found: "..AIZ_D, zD ~= nil)
        if zP then
            check("MT-12.1.3", "AIZ_P.isAIPickup=true",        zP.isAIPickup == true)
            check("MT-12.1.4", "AIZ_P.aiCargoType='V'",         zP.aiCargoType == "V",
                  tostring(zP.aiCargoType))
            check("MT-12.1.5", "AIZ_P._aiVehicleStock non-nil", zP._aiVehicleStock ~= nil)
            check("MT-12.1.6", "AIZ_P._aiTroopStock=nil",       zP._aiTroopStock == nil)
            if zP._aiVehicleStock then
                local vs = zP._aiVehicleStock
                check("MT-12.1.7", "_aiVehicleStock.isAll=false",  vs.isAll == false)
                check("MT-12.1.8", "init[Hummer]=2",
                      vs.init[VEH_TYPE] == 2, tostring(vs.init[VEH_TYPE]))
                check("MT-12.1.9", "current[Hummer]=2 (init)",
                      vs.current[VEH_TYPE] == 2, tostring(vs.current[VEH_TYPE]))
                check("MT-12.1.10", "pickMaxStock=0 (unlimited gate)",
                      zP.pickMaxStock == 0, tostring(zP.pickMaxStock))
            end
        end

        local sm = CTLDSceneManager.getInstance()
        check("MT-12.1.11", "Hummer is not a CTLDSceneManager scene",
              sm:getScene(VEH_TYPE) == nil)

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-12.1.12", "Clone '"..AI_UNIT.."' spawned from '"..AI_SRC.."'",
              cloneG ~= nil, tostring(cloneErr))

        local unit = Unit.getByName(AI_UNIT)

        local cm = CTLDCoreManager.getInstance()
        check("MT-12.1.13", "_aiTransportVehicle["..AI_UNIT.."] empty initially",
              cm._aiTransportVehicle[AI_UNIT] == nil)

        log("STEP 1 OK — C1 (physical) absent → C2 (virtual Hummer) applies")
        log("Waiting for landing on "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Wait for virtual pickup (_aiTransportVehicle populated) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — WAIT FOR VIRTUAL PICKUP (MT-12)\n"..
        "Heli "..AI_UNIT.." must land on "..AIZ_P..".\n"..
        "Detecting _aiTransportVehicle populated (C2 Hummer). Timeout: 300 s."
    )
    waitFor(
        function()
            local cm = CTLDCoreManager.getInstance()
            return cm._aiTransportVehicle[AI_UNIT] ~= nil
        end,
        3, 300,
        function()
            local cm = CTLDCoreManager.getInstance()
            local vEntry = cm._aiTransportVehicle[AI_UNIT]
            check("MT-12.2.1", "_aiTransportVehicle populated at pickup", vEntry ~= nil)
            if vEntry then
                check("MT-12.2.2", "type='Hummer'", vEntry.type == VEH_TYPE,
                      tostring(vEntry.type))
                check("MT-12.2.3", "isScene=false (DCS native, no scene)",
                      vEntry.isScene == false, tostring(vEntry.isScene))
                log("In transit: "..tostring(vEntry.type).." | isScene="..tostring(vEntry.isScene))
            end

            local zm = CTLDZoneManager.getInstance()
            local zP = zm._troopZones[AIZ_P]
            if zP and zP._aiVehicleStock then
                local cur = zP._aiVehicleStock.current[VEH_TYPE]
                check("MT-12.2.4", "Hummer stock decremented (1 consumed → current=1)",
                      cur == 1, "current="..tostring(cur))
            end
            advanceStep()
        end,
        function()
            -- C1/C2 diagnostic
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if ok and vs then
                local u = Unit.getByName(AI_UNIT)
                local loaded = u and u:isExist() and vs:findLoadedVehicles(u) or {}
                if #loaded > 0 then
                    fail("MT-12.2.0", "C1 (physical) took precedence: remove the DCS group from "..AIZ_P)
                else
                    fail("MT-12.2.1", "timeout 300s — _aiTransportVehicle not populated on "..AIZ_P)
                end
            else
                fail("MT-12.2.1", "timeout 300s — pickup not detected on "..AIZ_P)
            end
            advanceStep()
        end
    )
end

-- S3 — Wait for dropoff (_aiTransportVehicle cleared) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — WAIT FOR DROPOFF (MT-12)\n"..
        "Heli "..AI_UNIT.." must land on "..AIZ_D..".\n"..
        "Detecting the DCS Hummer spawn (_aiTransportVehicle=nil). Timeout: 600 s."
    )
    waitFor(
        function()
            local cm = CTLDCoreManager.getInstance()
            return cm._aiTransportVehicle[AI_UNIT] == nil
        end,
        3, 600,
        function()
            local cm = CTLDCoreManager.getInstance()
            local vEntry = cm._aiTransportVehicle[AI_UNIT]
            check("MT-12.3.1", "_aiTransportVehicle cleared after dropoff", vEntry == nil)
            log("Dropoff confirmed — Hummer appeared near "..AIZ_D)
            log("Expected coalition message: 'AI "..AI_UNIT.." delivered vehicle: "..VEH_TYPE.."'")
            advanceStep()
        end,
        function()
            fail("MT-12.3.1", "timeout 600s — dropoff not detected on "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalization [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALIZATION")
    waitThen(1, function()
        log("MT-12 ALL SUCCESS — virtual Hummer pickup (isScene=false) + stock decrement + DCS spawn confirmed")
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
    _SCN_MT12_RESULT = "[MT-12] ABORT"
    return _SCN_MT12_RESULT
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
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    _SCN_MT12_RESULT = "[MT-12] ABORT"
    cleanup() ; return _SCN_MT12_RESULT
end

S.groupId = playerObjStart.groupId

local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    _SCN_MT12_RESULT = "[MT-12] ABORT"
    cleanup() ; return _SCN_MT12_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_MT12_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." starting — "..#steps.." steps | "..S.transport:getName(), 8)
_SCN_MT12_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_MT12_RESULT until PASS/FAIL
advanceStep()

end  -- do isolation scope
return _SCN_MT12_RESULT
