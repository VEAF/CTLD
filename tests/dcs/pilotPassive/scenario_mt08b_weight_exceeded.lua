---@diagnostic disable
-- @tier: auto-slow
-- =============================================================================
-- scenario_mt08b_weight_exceeded.lua
-- CTLD — Diagnostic: AI helo lands near HMMWV that exceeds maxVehicleWeight.
--
-- Purpose: reproduce and analyse the "Leopard 2 near helo" observation.
-- NO weight override — HMMWV (2400 kg) > UH-1H maxVehicleWeight (1360 kg)
-- so C1 is expected to reject the load.
-- The scenario then monitors the dropoff zone for any vehicle appearing
-- that CTLD did NOT manage, and captures its typeName.
--
-- Prerequisites: same as MT-08 (heliai_vehicle, AIZ_depot_B_P_V_10,
--   AIZ_livraison_B_D_G, hmmwv_cargo, BLUE slot occupied, CTLD injected).
--
-- @scenario  MT-08B
-- @version   1.0 — 2026-07-17
-- @coverage  diagnostic — weight-exceeded C1 path, unexpected dropoff spawn
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-08B] ABORT: CTLD not initialized.", 15)
    _SCN_MT08B_RESULT = "[MT-08B] ABORT: CTLD not initialized"
    return _SCN_MT08B_RESULT
end

-- ── 2. Double-injection guard ─────────────────────────────────────────────────
if _SCN_MT08B_RUNNING then
    trigger.action.outText("[MT-08B] already running.", 10)
    return _SCN_MT08B_RESULT or "[MT-08B] RUNNING"
end
_SCN_MT08B_RUNNING = true
_SCN_MT08B_CLEANUP = nil

do  -- isolation scope
-- ── 3. Debug ON ───────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
-- NOTE: NO weight override — this is the diagnostic scenario.
-- HMMWV real weight = 2400 kg, UH-1H maxVehicleWeight = 1360 kg → C1 must reject.
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 4. Constants ──────────────────────────────────────────────────────────────
local TAG     = "[MT-08B]"
local AI_SRC  = "heliai_vehicle"
local AI_UNIT = "heliai_vehicle_run"
local AIZ_P   = "AIZ_depot_B_P_V_10"
local AIZ_D   = "AIZ_livraison_B_D_G"

-- ── 5. State ──────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    timerHandle = nil,
    timerGen    = 0,
}

-- ── 6. Helpers ────────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

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
    if not tmpl then return nil, "not found in env.mission: "..srcName end
    local clone = deepCopy(tmpl)
    clone.name            = cloneName
    clone.units[1].name   = cloneName
    clone.groupId         = nil
    clone.units[1].unitId = nil
    clone.lateActivation  = false
    local ok, _ = pcall(coalition.addGroup, ctryId, Group.Category.HELICOPTER, clone)
    if not ok then return nil, "coalition.addGroup failed for "..cloneName end
    local g = Group.getByName(cloneName)
    if not g then return nil, "group not found after spawn: "..cloneName end
    return g, nil
end

local function destroyClone(cloneName)
    local g = Group.getByName(cloneName)
    if g and g:isExist() then pcall(function() g:destroy() end) end
end

local function instruct(msg)
    log("[INSTR] "..msg)
    trigger.action.outText(TAG.."\n"..msg, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end
local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc..(details and (" | "..details) or "")) end
end

-- Snapshot: returns set of {unitName → typeName} for all ground units within
-- radius of a DCS zone (by zone name).
local function snapshotGroundUnitsInZone(zoneName)
    local snapshot = {}
    local dcsZone = trigger.misc.getZone(zoneName)
    if not dcsZone then return snapshot end
    local zPt = dcsZone.point
    local zR  = dcsZone.radius
    for _, coa in ipairs({coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL}) do
        for _, grp in ipairs(coalition.getGroups(coa, Group.Category.GROUND) or {}) do
            for _, unit in ipairs(grp:getUnits() or {}) do
                if unit and unit:isExist() then
                    local d = ctld.utils.getDistance("mt08b_snap", zPt, unit:getPoint())
                    if d <= zR then
                        snapshot[unit:getName()] = unit:getTypeName()
                    end
                end
            end
        end
    end
    return snapshot
end

-- Returns list of {name, typeName} present in current but not in baseline.
local function newUnitsVsSnapshot(baseline, zoneName)
    local current = snapshotGroundUnitsInZone(zoneName)
    local new = {}
    for uName, uType in pairs(current) do
        if not baseline[uName] then
            new[#new + 1] = { name = uName, typeName = uType }
        end
    end
    return new
end

-- ── 7. Cleanup ────────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    destroyClone(AI_UNIT)
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT08B_RUNNING = false
    _SCN_MT08B_CLEANUP = nil
    log("cleanup done")
end

-- ── 8. Timer helpers ──────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then pcall(timer.removeFunction, S.timerHandle) ; S.timerHandle = nil end
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
        S.timerHandle = nil ; callback()
    end, nil, timer.getTime() + delayS)
end

-- ── 9. Finalization ───────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." PASS "..S.passed.."/"..total
    else
        summary = TAG.." FAIL "..S.failed.."/"..total..": "..table.concat(S.failReasons, "; ")
    end
    _SCN_MT08B_RESULT = summary
    log(summary)
    trigger.action.outText(summary, 360, true)
    pcall(cleanup)
end

-- ── 10. Steps ─────────────────────────────────────────────────────────────────
local steps = {}
local advanceStep
advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then finalizeScenario() ; return end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        advanceStep()
    end
end

-- ── S1: Init — verify weight mismatch, spawn clone ───────────────────────────
steps[1] = function()
    instruct("S1/4 — INIT (MT-08B)\nNo weight override. C1 must reject HMMWV (too heavy).")
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        -- Verify the weight mismatch that will cause C1 to reject
        local caps    = (ctld.gs("capabilitiesByType") or {})["UH-1H"] or {}
        local maxW    = caps.maxVehicleWeight
        local weights = ctld.gs("groundVehicleWeights") or {}
        local hummerW = weights["Hummer"] or 0
        check("MT-08B.1.1", "UH-1H maxVehicleWeight configured", maxW ~= nil,
            "maxVehicleWeight="..tostring(maxW))
        check("MT-08B.1.2", "Hummer weight > UH-1H limit (C1 will reject)",
            maxW ~= nil and hummerW > maxW,
            "hummer="..hummerW.." kg, limit="..tostring(maxW).." kg")

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-08B.1.3", "Clone '"..AI_UNIT.."' spawned", cloneG ~= nil, tostring(cloneErr))

        log("STEP 1 OK — helo clone spawned, weight mismatch confirmed, waiting for landing on "..AIZ_P)
        advanceStep()
    end)
end

-- ── S2: Wait for helo to land at pickup — verify CTLD did NOT load ────────────
steps[2] = function()
    instruct(
        "S2/4 — WAIT FOR PICKUP ATTEMPT (MT-08B)\n"..
        "Helo must land on "..AIZ_P..". CTLD should reject (weight exceeded).\n"..
        "Timeout: 600 s."
    )
    -- Poll until helo lands in pickup zone (unit inside zone radius)
    waitFor(
        function()
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local dcsZone = trigger.misc.getZone(AIZ_P)
            if not dcsZone then return false end
            local d = ctld.utils.getDistance("mt08b_s2", dcsZone.point, unit:getPoint())
            return d <= (dcsZone.radius + 50)  -- +50 m tolerance for landing
        end,
        3, 600,
        function()
            -- Helo is in/near pickup zone — wait 10 s for onAILand to fire and CTLD to react
            waitThen(10, function()
                local unit = Unit.getByName(AI_UNIT)
                local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
                local loaded = (ok and vs) and vs:findLoadedVehicles(unit) or {}
                -- C1 must have been rejected: no physical vehicle loaded
                check("MT-08B.2.1", "C1 rejected: no physical vehicle loaded by CTLD",
                    #loaded == 0, "nb_loaded="..#loaded)
                -- C2 check: _aiTransportVehicle must also be nil
                local core = CTLDCoreManager.getInstance()
                local virtualEntry = core._aiTransportVehicle and core._aiTransportVehicle[AI_UNIT]
                check("MT-08B.2.2", "C2 did not load virtual vehicle",
                    virtualEntry == nil,
                    virtualEntry and ("virtual type="..tostring(virtualEntry.type)) or "nil")
                -- HMMWV survival check: the physical vehicle must still be alive in the zone
                local dcsZone = trigger.misc.getZone(AIZ_P)
                local hummerAlive = false
                local hummerType  = "?"
                if ok and vs and dcsZone then
                    for _, v in pairs(vs._vehicles) do
                        if v.unit and v.unit:isExist() then
                            local d = ctld.utils.getDistance("mt08b_hummer_alive", dcsZone.point, v.unit:getPoint())
                            if d <= dcsZone.radius + 100 then
                                hummerAlive = true
                                hummerType  = v.vehicleType or "?"
                            end
                        end
                    end
                end
                check("MT-08B.2.3", "HMMWV still alive in pickup zone after C1 rejection",
                    hummerAlive, "typeName_found="..hummerType)
                -- Log helo position at pickup for comparison with dropoff detection
                if unit and unit:isExist() then
                    local pt = unit:getPoint()
                    log("Helo position at pickup check: x="..string.format("%.0f", pt.x)
                        .." z="..string.format("%.0f", pt.z))
                    local zD = trigger.misc.getZone(AIZ_D)
                    if zD then
                        local dToDropoff = ctld.utils.getDistance("mt08b_dist_to_D", zD.point, pt)
                        log("Distance helo→AIZ_D at pickup time: "..string.format("%.0f", dToDropoff)
                            .." m (AIZ_D radius="..string.format("%.0f", zD.radius).." m, threshold="
                            ..string.format("%.0f", zD.radius + 50).." m)")
                    end
                end
                log("S2 done — C1 rejected, C2 state checked, HMMWV survival checked.")
                advanceStep()
            end)
        end,
        function()
            fail("MT-08B.2.1", "timeout 600s — helo never reached "..AIZ_P)
            fail("MT-08B.2.2", "skipped — S2 timed out")
            advanceStep()
        end
    )
end

-- ── S3: Wait for helo to LAND at dropoff, then check for unexpected spawns ────
-- Detects actual touchdown via speed < 2 m/s inside the zone, not just proximity.
-- This prevents false positives when the helo is still airborne over the zone,
-- and ensures cleanup (destroyClone) only runs AFTER the full sequence completes.
steps[3] = function()
    instruct(
        "S3/4 — MONITOR DROPOFF (MT-08B)\n"..
        "Waiting for helo to LAND at "..AIZ_D.." (speed < 2 m/s in zone).\n"..
        "Timeout: 600 s."
    )
    -- Snapshot before helo reaches dropoff
    local baseline = snapshotGroundUnitsInZone(AIZ_D)
    log("Dropoff snapshot: "..#baseline.." unit(s) already present")

    waitFor(
        function()
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local dcsZone = trigger.misc.getZone(AIZ_D)
            if not dcsZone then return false end
            local pt = unit:getPoint()
            local d = ctld.utils.getDistance("mt08b_s3", dcsZone.point, pt)
            if d > dcsZone.radius + 50 then return false end
            -- In zone — check landed (speed ≈ 0)
            local vel = unit:getVelocity()
            local spd = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
            log("Helo near dropoff: d="..string.format("%.0f",d).."m spd="..string.format("%.1f",spd).."m/s")
            return spd < 2.0
        end,
        3, 600,
        function()
            -- Helo confirmed landed — give CTLD 10 s to process onAILand
            log("Helo landed at dropoff confirmed — waiting 10 s for onAILand")
            waitThen(10, function()
                local newUnits = newUnitsVsSnapshot(baseline, AIZ_D)
                if #newUnits == 0 then
                    pass("MT-08B.3.1", "No unexpected vehicle spawned at dropoff — correct behaviour")
                    log("Dropoff clean: no new units. CTLD correctly ignored the overweight vehicle.")
                else
                    local typeList = {}
                    for _, u in ipairs(newUnits) do
                        typeList[#typeList + 1] = u.name.." ("..u.typeName..")"
                    end
                    local detail = table.concat(typeList, ", ")
                    fail("MT-08B.3.1", "Unexpected vehicle(s) spawned at dropoff: "..detail)
                    log("UNEXPECTED SPAWN at "..AIZ_D..": "..detail)
                end
                -- Wait for helo to take off again before cleanup,
                -- so the full DCS AI route completes and the clone is not destroyed mid-sequence.
                log("Waiting for helo to take off from dropoff (spd > 5 m/s)...")
                waitFor(
                    function()
                        local unit = Unit.getByName(AI_UNIT)
                        if not unit or not unit:isExist() then return true end  -- already gone
                        local vel = unit:getVelocity()
                        local spd = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
                        return spd > 5.0
                    end,
                    2, 120,
                    function() log("Helo took off from dropoff — sequence complete.") ; advanceStep() end,
                    function() log("Timeout waiting for helo takeoff — proceeding anyway.") ; advanceStep() end
                )
            end)
        end,
        function()
            fail("MT-08B.3.1", "timeout 600s — helo never landed at "..AIZ_D)
            advanceStep()
        end
    )
end

-- ── S4: Finalization ──────────────────────────────────────────────────────────
steps[4] = function()
    instruct("S4/4 — FINALIZATION (MT-08B)")
    waitThen(1, function()
        log("MT-08B diagnostic complete")
        advanceStep()
    end)
end

-- ── 11. Start ─────────────────────────────────────────────────────────────────
-- Require a BLUE slot for MenuManager
local playerFound = false
local ok_pm, pm = pcall(CTLDPlayerManager.getInstance)
if ok_pm and pm and pm._players then
    for unitName in pairs(pm._players) do
        local u = Unit.getByName(unitName)
        if u and u:isExist() then playerFound = true ; break end
    end
end
if not playerFound then
    _SCN_MT08B_RESULT = TAG.." ABORT: no BLUE player"
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot first.", 20)
    cleanup()
    return _SCN_MT08B_RESULT
end

_SCN_MT08B_CLEANUP = cleanup
instruct("MT-08B démarré — diagnostic poids HMMWV vs UH-1H")
advanceStep()

end  -- isolation scope
return "[MT-08B] STARTED"
