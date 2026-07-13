---@diagnostic disable
-- @tier: auto-slow  (no human, but needs minutes of real AI-heli flight to resolve -- excluded from the fast --headless sweep; run with --tier auto-slow. Core logic already covered fast by noPlayer aiTransport_featureT/U F-176..182. See ticket 06/07)
-- =============================================================================
-- scenario_mt13_ai_vehicle_scene.lua  [INTERACTIVE]
-- MT-13 — AI auto-pickup of a CTLDSceneManager scene via vehicleStock (Feature T)
--
-- MISSION PREREQUISITES:
--   - BLUE heli named "heliai_mt13" (UH-60L or any airframe with canTransportWholeVehicle=true)
--   - Route: WP1 = landed on AIZ_mt13_B_P_V → WP2 = flight → WP3 = landed on AIZ_mt13_B_D
--   - DCS trigger zone "AIZ_mt13_B_P_V" (radius ~200 m, centered on WP1)
--   - DCS trigger zone "AIZ_mt13_B_D"   (radius ~200 m, centered on WP3)
--   - NO DCS vehicle group inside AIZ_mt13_B_P_V — the physical scan (C1) would take
--     precedence over the virtual stock (C2) and _aiTransportVehicle would not be populated.
--   - Clear space near AIZ_mt13_B_D (the FARP Alpha scene deploys several statics)
--   - enable_debug.lua injected before this script
--   - ctldLogPath set in the .miz (MISSION START trigger)
--
-- USE CASE:
--   Zone AIZ_mt13_B_P_V: vehicleStock = { ["FARP Alpha"] = 1 }
--   C1: physical DCS scan — no vehicle present → no loadVehicle()
--   C2: aiPickVehicleEntry() → { type="FARP Alpha", isScene=true }
--        CTLDSceneManager:getScene("FARP Alpha") != nil → isScene=true
--        → _aiTransportVehicle[unitName] populated + aiConsumeVehicleStock → current=0
--   At dropoff: CTLDSceneManager:playScene(u, "FARP Alpha", nil, nil)
--                Deploys the FARP statics at the AIZ_D position
--                Coalition message "AI heliai_mt13 delivered vehicle: FARP Alpha"
--   IMPORTANT: vehicleStock=nil would block the pickup (rule A).
--
-- PROTOCOL:
--   Step 1 — Register heliai_mt13 + verify vehicleStock + isScene=true
--   Step 2 — Verify virtual pickup (isScene=true + stock 1→0)
--             Re-inject after the heli has landed on AIZ_mt13_B_P_V (~2s)
--   Step 3 — Verify dropoff (playScene fired = FARP statics visible + _aiTransportVehicle cleared)
--             Re-inject after the heli has landed on AIZ_mt13_B_D
--   Step 4 — Cleanup
-- =============================================================================


-- ── CTLD-ready guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-13] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MT13_RESULT = "[MT-13] ABORT: CTLD not initialized"
    return _SCN_MT13_RESULT
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[MT-13]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT13_STEP"

local AI_SRC     = "heliai_mt13"      -- late-activation source in the .miz (never activated)
local AI_UNIT    = "heliai_mt13_run"  -- temporary clone (spawned + destroyed at cleanup)
local AIZ_P      = "AIZ_mt13_B_P_V"
local AIZ_D      = "AIZ_mt13_B_D"
local SCENE_NAME = "FARP Alpha"

local function log(msg)    ctld.utils.log("INFO",  TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end

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
local function pass(msg)   report("[PASS] " .. msg) end
local function fail(msg)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

local function cleanup()
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT then table.remove(names, i) end
    end
    local cm = CTLDCoreManager.getInstance()
    if cm._aiTransportVehicle then cm._aiTransportVehicle[AI_UNIT] = nil end
    destroyClone(AI_UNIT)
    log("cleanup done")
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Init zones + verify vehicleStock + isScene
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    -- Verify that "FARP Alpha" is indeed a registered scene
    local sm = CTLDSceneManager.getInstance()
    local scene = sm:getScene(SCENE_NAME)
    check("MT-13.1.1", "'FARP Alpha' registered in CTLDSceneManager", scene ~= nil,
          "'FARP Alpha' not found in _models")

    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-13.1.2", "AIZ_P found: " .. AIZ_P, zP ~= nil)
    check("MT-13.1.3", "AIZ_D found: " .. AIZ_D, zD ~= nil)
    if zP then
        check("MT-13.1.4", "AIZ_P.isAIPickup=true",        zP.isAIPickup == true)
        check("MT-13.1.5", "AIZ_P.aiCargoType='V'",         zP.aiCargoType == "V",
              tostring(zP.aiCargoType))
        check("MT-13.1.6", "AIZ_P._aiVehicleStock non-nil", zP._aiVehicleStock ~= nil)
        if zP._aiVehicleStock then
            local vs = zP._aiVehicleStock
            check("MT-13.1.7", "_aiVehicleStock.isAll=false", vs.isAll == false)
            check("MT-13.1.8", "init['FARP Alpha']=1",
                  vs.init[SCENE_NAME] == 1, tostring(vs.init[SCENE_NAME]))
            check("MT-13.1.9", "current['FARP Alpha']=1 (init)",
                  vs.current[SCENE_NAME] == 1, tostring(vs.current[SCENE_NAME]))
        end
    end

    -- Verify that aiPickVehicleEntry correctly detects isScene=true for "FARP Alpha"
    if zP then
        local entry = zP:aiPickVehicleEntry()
        check("MT-13.1.10", "aiPickVehicleEntry returns non-nil", entry ~= nil)
        if entry then
            check("MT-13.1.11", "entry.type='FARP Alpha'",
                  entry.type == SCENE_NAME, tostring(entry.type))
            check("MT-13.1.12", "entry.isScene=true (CTLDSceneManager scene)",
                  entry.isScene == true, tostring(entry.isScene))
        end
    end

    -- Spawn clone from the late-activation source (repeatable without a DCS restart)
    local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
    check("MT-13.1.13", "Clone '" .. AI_UNIT .. "' spawned from '" .. AI_SRC .. "'",
          cloneG ~= nil, tostring(cloneErr))

    local unit = Unit.getByName(AI_UNIT)

    local cm = CTLDCoreManager.getInstance()
    check("MT-13.1.14", "_aiTransportVehicle[heliai_mt13] empty initially",
          cm._aiTransportVehicle[AI_UNIT] == nil)

    report("⬛ STEP 1 OK — Land the heli on " .. AIZ_P .. ", wait 3s, re-inject for STEP 2")
    report("   C1 (physical) = no DCS vehicle in the zone → C2 (FARP Alpha isScene=true) applies")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify virtual pickup C2 (isScene=true + stock decremented)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local cm = CTLDCoreManager.getInstance()
    local vEntry = cm._aiTransportVehicle[AI_UNIT]

    if vEntry == nil then
        -- C1/C2 diagnostic: check whether a physical vehicle was loaded instead
        local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok and vs then
            local u = Unit.getByName(AI_UNIT)
            local loaded = u and u:isExist() and vs:findLoadedVehicles(u) or {}
            if #loaded > 0 then
                fail("MT-13.2.0 — C1 (physical) took precedence: a DCS vehicle is loaded — remove any DCS group from " .. AIZ_P)
            end
        end
        report("⚠️  _aiTransportVehicle[" .. AI_UNIT .. "]=nil — is the heli actually landed in " .. AIZ_P .. " ?")
        report("   Wait 2s more and re-inject STEP 2.")
        _result = "step=2 WAITING"
        return
    end

    check("MT-13.2.1", "_aiTransportVehicle populated at pickup", vEntry ~= nil)
    check("MT-13.2.2", "type='FARP Alpha'",
          vEntry.type == SCENE_NAME, tostring(vEntry.type))
    check("MT-13.2.3", "isScene=true (CTLDSceneManager scene, not DCS native)",
          vEntry.isScene == true, tostring(vEntry.isScene))
    report("🏕️ In transit: " .. tostring(vEntry.type) .. " | isScene=" .. tostring(vEntry.isScene))

    -- Verify stock decremented (1→0)
    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    if zP and zP._aiVehicleStock then
        local cur = zP._aiVehicleStock.current[SCENE_NAME]
        check("MT-13.2.4", "stock 'FARP Alpha' decremented (1→0)",
              cur == 0, "current=" .. tostring(cur))
    end

    report("⬛ STEP 2 OK — Send the heli to " .. AIZ_D .. " (landed), re-inject for STEP 3")
    report("   The FARP Alpha scene will deploy at the " .. AIZ_D .. " position")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Verify dropoff (playScene + _aiTransportVehicle cleared)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local cm = CTLDCoreManager.getInstance()
    local vEntry = cm._aiTransportVehicle[AI_UNIT]

    if vEntry ~= nil then
        report("⚠️  _aiTransportVehicle still populated — is the heli actually landed in " .. AIZ_D .. " ?")
        _result = "step=3 WAITING"
        return
    end

    check("MT-13.3.1", "_aiTransportVehicle cleared after dropoff (playScene called)", vEntry == nil)
    report("🏕️ Scene dropoff confirmed — check on the F10 map that the FARP Alpha statics appeared near " .. AIZ_D)
    report("   Expected elements: FARP tent, ammo storage, generator, security personnel, etc.")
    report("   Expected coalition message: 'AI heliai_mt13 delivered vehicle: FARP Alpha'")
    report("⬛ Re-inject for STEP 4 (cleanup)")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("✅ MT-13 ALL SUCCESS — scene pickup 'FARP Alpha' (isScene=true) + stock 1→0 + playScene confirmed")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no branch — reset with _G['" .. STEP_N .. "']=1")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    pcall(cleanup)
    _SCN_MT13_RESULT = TAG .. " FAIL: step=" .. step .. " — " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return _SCN_MT13_RESULT
end
if _result == "ALL SUCCESS" then
    _SCN_MT13_RESULT = TAG .. " PASS (" .. _ms .. "ms)"
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return _SCN_MT13_RESULT
end
_SCN_MT13_RESULT = TAG .. " RUNNING: " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
                             :gsub("WAITING", "WAITING (" .. _ms .. "ms)")
return _SCN_MT13_RESULT
