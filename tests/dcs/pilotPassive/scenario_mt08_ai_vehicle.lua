---@diagnostic disable
-- @tier: disabled  (QUARANTINE -- code AND mission are both correct: the Land-task point is
--   INSIDE the pickup zone (8 m from centre, verified in Test_CTLDNEXT_01.miz). But the DCS AI
--   helo orbits the LZ without ever landing on this exact spot (terrain/pathfinding, not CTLD),
--   so the whole-cycle test never completes -- fails even at a 900 s timeout. Logic coverage is
--   assured fast+deterministic by noPlayer aiTransport_featureT/U (F-176..182) and by the sibling
--   scenarios that pass (mt09/mt10/mt12/mt13). Excluded from every default sweep; reachable only
--   via `--tier disabled`. To re-enable: relocate this group's Land point to clearer terrain.)
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_mt08_ai_vehicle.lua
-- CTLD — AI auto-pickup / auto-dropoff: whole vehicle alone (landed → landed)
--
-- Interactive test mini-app: single injection, advances
-- automatically (waitFor) to detect loadVehicle and unloadVehicle.
--
-- Prerequisites:
--   - BLUE helo named "heliai_vehicle" (UH-1H), no human pilot
--   - Route: WP landed on AIZ_depot_B_P_V_10 → flight → WP landed on AIZ_livraison_B_D_G
--   - DCS trigger zone "AIZ_depot_B_P_V_10"  (radius ~200 m, V=vehicles only, stock=10)
--   - DCS trigger zone "AIZ_livraison_B_D_G" (radius ~200 m, delivery LZ)
--   - BLUE M1045 HMMWV named "hmmwv_cargo" positioned in AIZ_depot_B_P
--   - capabilitiesByType UH-1H: canTransportWholeVehicle=true
--   - BLUE slot occupied (human player for MenuManager)
--   - CTLD.lua injected before this script (wait 3-5 s)
--
-- Sequence (4 steps, single injection):
--   S1 [auto]  Init + AI helo activation
--   S2 [auto]  Wait for loadVehicle (vehicle loaded) via waitFor
--   S3 [auto]  Wait for unloadVehicle (vehicle unloaded) via waitFor
--   S4 [auto]  Finalization
--
-- @scenario  MT-08
-- @version   3.0 — 2026-06-30
-- @coverage  AI vehicle load, AI vehicle unload
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-08] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MT08_RESULT = "[MT-08] ABORT: CTLD not initialized"
    return _SCN_MT08_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT08_RUNNING then
    trigger.action.outText("[MT-08] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_MT08_RESULT or "[MT-08] RUNNING"
end
_SCN_MT08_RUNNING = true
_SCN_MT08_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT08_INSTR = ""
_SCN_MT08_SHOW  = function()
    trigger.action.outText(_SCN_MT08_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-08]"
local NAME      = "AI auto-pickup/dropoff whole vehicle"
local MENU_NAME = "CTLD Test"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

local AI_SRC  = "heliai_vehicle"      -- late-activation source in the .miz (never activated)
local AI_UNIT = "heliai_vehicle_run"  -- temporary clone (spawned + destroyed in cleanup)
local AIZ_P   = "AIZ_depot_B_P_V_10"
local AIZ_D   = "AIZ_livraison_B_D_G"

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

-- Clone helpers (ctld.utils.deepCopy returns nil — local deepCopy required)
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
    _SCN_MT08_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT08_INSTR, 360, true)
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
    local unit = Unit.getByName(AI_UNIT)
    if unit and unit:isExist() then
        local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok and vs then
            local loaded = vs:findLoadedVehicles(unit)
            if loaded and #loaded > 0 then
                vs:unloadVehicle(loaded[1], unit, nil, "menu_ctld")
            end
        end
    end
    destroyClone(AI_UNIT)
    _SCN_MT08_INSTR = nil ; _SCN_MT08_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT08_RUNNING = false
    _SCN_MT08_CLEANUP = nil
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
        summary = TAG.." PASS "..S.passed.."/"..total
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..
            table.concat(S.failReasons, "; ")
    end
    _SCN_MT08_RESULT = summary   -- polled by the runner for this async scenario
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT08_RUNNING = false end
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
        "Step 1/4 — INIT AI VEHICLE TRANSPORT (MT-08)\n"..
        "Initializing AI transports…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-08.1.1", "AIZ_P zone found: "..AIZ_P, zP ~= nil)
        if zP then check("MT-08.1.2", "AIZ_P.isAIPickup=true", zP.isAIPickup == true) end
        check("MT-08.1.3", "AIZ_D zone found: "..AIZ_D, zD ~= nil)
        if zD then
            check("MT-08.1.4", "AIZ_D.isAIDropoff=true", zD.isAIDropoff == true)
            check("MT-08.1.5", "AIZ_D.aiDropMode='G'", zD.aiDropMode == "G",
                "aiDropMode="..tostring(zD.aiDropMode))
        end

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-08.1.6", "Clone '"..AI_UNIT.."' spawned from '"..AI_SRC.."'",
              cloneG ~= nil, tostring(cloneErr))

        local unit = Unit.getByName(AI_UNIT)
        if unit then
            check("MT-08.1.7", "No human pilot", unit:getPlayerName() == nil)
            local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()] or {}
            check("MT-08.1.8", "canTransportWholeVehicle configured", caps.canTransportWholeVehicle == true)
        end

        local okVS, vs = pcall(CTLDVehicleSpawner.getInstance)
        if okVS and vs then
            local dcsZone = trigger.misc.getZone(AIZ_P)
            local vehInZone = 0
            if dcsZone then
                local zPt = dcsZone.point
                local zR  = dcsZone.radius
                for _, veh in pairs(vs._vehicles) do
                    if veh:getState() == CTLDVehicle.STATE.WAITING and veh.unit and veh.unit:isExist() then
                        local d = ctld.utils.getDistance("MT-08.1.9", zPt, veh.unit:getPoint())
                        if d <= zR then vehInZone = vehInZone + 1 end
                    end
                end
            end
            check("MT-08.1.9", "At least 1 WAITING vehicle in zone "..AIZ_P, vehInZone > 0,
                "count_in_zone="..vehInZone)
        end

        local lv = cfg.settings["loadableVehiclesBLUE"] or {}
        local hvFound = false
        for _, t in ipairs(lv) do if t == "Hummer" then hvFound = true; break end end
        if not hvFound then table.insert(lv, "Hummer"); cfg.settings["loadableVehiclesBLUE"] = lv end

        log("STEP 1 OK — helo activated, waiting for landing on "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Wait for loadVehicle (vehicle loaded) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — WAIT FOR VEHICLE LOAD (MT-08)\n"..
        "Helo "..AI_UNIT.." must land on "..AIZ_P.." with the HMMWV.\n"..
        "Automatic load detection.\n"..
        "Timeout: 300 s."
    )
    waitFor(
        function()
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then return false end
            local loaded = vs:findLoadedVehicles(unit)
            return loaded and #loaded > 0
        end,
        3, 300,
        function()
            local unit = Unit.getByName(AI_UNIT)
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then
                fail("MT-08.2.1", "CTLDVehicleSpawner unavailable")
                advanceStep() ; return
            end
            local loaded = vs:findLoadedVehicles(unit)
            local hasVeh = loaded and #loaded > 0
            check("MT-08.2.1", "Vehicle loaded aboard after landing on "..AIZ_P, hasVeh,
                "nb_loaded="..tostring(loaded and #loaded or 0))
            if hasVeh then
                local veh = loaded[1]
                log("Vehicle loaded: id="..tostring(veh.id).." type="..tostring(veh.vehicleType))
                local vehDcsUnit = veh.unit
                check("MT-08.2.2", "DCS vehicle hidden (LOADED state)",
                    vehDcsUnit == nil or not vehDcsUnit:isExist() or veh:getState() == CTLDVehicle.STATE.LOADED)
            end
            advanceStep()
        end,
        function()
            fail("MT-08.2.1", "timeout 300s — no load on "..AIZ_P)
            advanceStep()
        end
    )
end

-- S3 — Wait for unloadVehicle (vehicle unloaded) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — WAIT FOR VEHICLE UNLOAD (MT-08)\n"..
        "Helo "..AI_UNIT.." must land on "..AIZ_D..".\n"..
        "Automatic unload detection.\n"..
        "Timeout: 600 s."
    )
    waitFor(
        function()
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then return false end
            local loaded = vs:findLoadedVehicles(unit)
            return not (loaded and #loaded > 0)
        end,
        3, 600,
        function()
            local unit = Unit.getByName(AI_UNIT)
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then
                fail("MT-08.3.1", "CTLDVehicleSpawner unavailable")
                advanceStep() ; return
            end
            local loaded = vs:findLoadedVehicles(unit)
            local hasVeh = loaded and #loaded > 0
            check("MT-08.3.1", "Vehicle unloaded after landing on "..AIZ_D, not hasVeh,
                "nb_loaded="..tostring(loaded and #loaded or 0))
            log("Unload confirmed — HMMWV appeared near "..AIZ_D)
            advanceStep()
        end,
        function()
            fail("MT-08.3.1", "timeout 600s — no unload on "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalisation [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALIZATION")
    waitThen(1, function()
        log("MT-08 full cycle (pickup "..AIZ_P.." → unload "..AIZ_D..")")
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
    _SCN_MT08_RESULT = TAG.." ABORT: no BLUE player"
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot before injection.", 20)
    cleanup()
    return _SCN_MT08_RESULT
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
    _SCN_MT08_RESULT = TAG.." ABORT: no CTLD playerObj for transport"
    trigger.action.outText(TAG.." ABORT: no CTLD playerObj for transport.", 20)
    cleanup() ; return _SCN_MT08_RESULT
end

S.groupId = playerObjStart.groupId

local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    _SCN_MT08_RESULT = TAG.." ABORT: no CTLD MenuManager menu for player group"
    trigger.action.outText(TAG.." ABORT: no CTLD MenuManager menu for player group.", 20)
    cleanup() ; return _SCN_MT08_RESULT
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_MT08_CLEANUP = cleanup

_SCN_MT08_RESULT = TAG.." STARTED"   -- async: runner polls _SCN_MT08_RESULT until PASS/FAIL
log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." start — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return _SCN_MT08_RESULT
