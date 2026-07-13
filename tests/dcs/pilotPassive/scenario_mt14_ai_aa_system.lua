---@diagnostic disable
-- @tier: disabled  (QUARANTINE -- code AND mission are both correct: the Land-task point is
--   INSIDE the pickup zone (48 m from centre, verified in Test_CTLDNEXT_01.miz). But the DCS AI
--   helo orbits the LZ without ever landing on this exact spot (terrain/pathfinding, not CTLD),
--   so the whole-cycle test never completes. AA-assembly logic is covered fast+deterministic by
--   noPlayer aiTransport_featureU spawnSystemAt (F-182). Excluded from every default sweep;
--   reachable only via `--tier disabled`. To re-enable: relocate this group's Land point to
--   clearer terrain.)
-- =============================================================================
-- scenario_mt14_ai_aa_system.lua  [INTERACTIVE]
-- MT-14 — AI auto-pickup of an AA system (HAWK) via vehicleStock (Feature U)
--
-- MISSION PREREQUISITES:
--   - BLUE heli named "heliai_mt14" (UH-60L or any aircraft with canTransportWholeVehicle=true)
--   - Route: WP1 = landed on AIZ_mt14_B_P_V → WP2 = airborne → WP3 = landed on AIZ_mt14_B_D
--   - DCS trigger zone "AIZ_mt14_B_P_V" (radius ~200 m, centered on WP1)
--   - DCS trigger zone "AIZ_mt14_B_D"   (radius ~200 m, centered on WP3)
--   - NO DCS vehicle group in AIZ_mt14_B_P_V — the physical scan (C1) would take
--     precedence over the virtual stock (C2) and _aiTransportVehicle would not be populated.
--   - Clear space near AIZ_mt14_B_D (HAWK deploys ~10 units in a 50 m circle)
--   - enable_debug.lua injected before this script
--   - ctldLogPath defined in the .miz (MISSION START trigger)
--
-- USE CASE:
--   Zone AIZ_mt14_B_P_V: vehicleStock = { ["HAWK AA System"] = 1 }
--   C1: DCS physical scan — no vehicle present → no loadVehicle()
--   C2: aiPickVehicleEntry() → { type="HAWK AA System", isScene=false, isAASystem=true }
--        CTLDCrateAssemblyManager:getTemplateByName("HAWK AA System") != nil
--        → _aiTransportVehicle[unitName] populated + aiConsumeVehicleStock → current=0
--   On dropoff: CTLDCrateAssemblyManager:spawnSystemAt("HAWK AA System", pt, coa, country)
--                Deploys the 10 HAWK units (3 ln + 2 tr + 2 sr + 1 pcp + 2 cwar) in a circle
--                Coalition message "AI heliai_mt14 delivered vehicle: HAWK AA System"
--   IMPORTANT: vehicleStock=nil would block the pickup (rule A).
--
-- PROTOCOL:
--   Step 1 — Register heliai_mt14 + check vehicleStock + isAASystem=true
--   Step 2 — Verify virtual pickup (isAASystem=true + stock 1→0)
--             Re-inject after the heli has landed on AIZ_mt14_B_P_V (~2s)
--   Step 3 — Verify dropoff (spawnSystemAt triggered = 10 HAWK units visible +
--             _aiTransportVehicle emptied + message "delivered vehicle: HAWK AA System")
--             Re-inject after the heli has landed on AIZ_mt14_B_D
--   Step 4 — Cleanup
-- =============================================================================


-- ── CTLD-ready guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-14] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MT14_RESULT = "[MT-14] ABORT: CTLD not initialized"
    return _SCN_MT14_RESULT
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[MT-14]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT14_STEP"

local AI_SRC    = "heliai_mt14"      -- late-activation source in the .miz (never activated)
local AI_UNIT   = "heliai_mt14_run"  -- temporary clone (spawned + destroyed in cleanup)
local AIZ_P     = "AIZ_mt14_B_P_V"
local AIZ_D     = "AIZ_mt14_B_D"
local AA_NAME   = "HAWK AA System"

local function log(msg)    ctld.utils.log("INFO",  TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end

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
-- STEP 1 — Init zones + vehicleStock check + isAASystem
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    -- Check that "HAWK AA System" is indeed a CTLDCrateAssemblyManager template
    local aam = CTLDCrateAssemblyManager.getInstance()
    local tmpl = aam:getTemplateByName(AA_NAME)
    check("MT-14.1.1", "getTemplateByName('" .. AA_NAME .. "') non-nil", tmpl ~= nil)
    if tmpl then
        check("MT-14.1.2", "template.parts non-empty",
              type(tmpl.parts) == "table" and #tmpl.parts > 0,
              "#parts=" .. tostring(tmpl.parts and #tmpl.parts))
        -- HAWK: 5 part types (ln, tr, sr, pcp, cwar)
        check("MT-14.1.3", "HAWK has 5 part types",
              #tmpl.parts == 5, "#parts=" .. tostring(#tmpl.parts))
    end

    -- Check that "HAWK AA System" is NOT in CTLDSceneManager (not a scene)
    local sm = CTLDSceneManager.getInstance()
    check("MT-14.1.4", "'" .. AA_NAME .. "' absent from CTLDSceneManager (not a scene)",
          sm:getScene(AA_NAME) == nil)

    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-14.1.5", "AIZ_P found: " .. AIZ_P, zP ~= nil)
    check("MT-14.1.6", "AIZ_D found: " .. AIZ_D, zD ~= nil)
    if zP then
        check("MT-14.1.7", "AIZ_P.isAIPickup=true",        zP.isAIPickup == true)
        check("MT-14.1.8", "AIZ_P.aiCargoType='V'",         zP.aiCargoType == "V",
              tostring(zP.aiCargoType))
        check("MT-14.1.9", "AIZ_P._aiVehicleStock non-nil", zP._aiVehicleStock ~= nil)
        if zP._aiVehicleStock then
            local vs = zP._aiVehicleStock
            check("MT-14.1.10", "_aiVehicleStock.isAll=false", vs.isAll == false)
            check("MT-14.1.11", "init['" .. AA_NAME .. "']=1",
                  vs.init[AA_NAME] == 1, tostring(vs.init[AA_NAME]))
            check("MT-14.1.12", "current['" .. AA_NAME .. "']=1 (init)",
                  vs.current[AA_NAME] == 1, tostring(vs.current[AA_NAME]))
        end
    end

    -- Check that aiPickVehicleEntry correctly detects isAASystem=true
    if zP then
        local entry = zP:aiPickVehicleEntry()
        check("MT-14.1.13", "aiPickVehicleEntry returns non-nil", entry ~= nil)
        if entry then
            check("MT-14.1.14", "entry.type='" .. AA_NAME .. "'",
                  entry.type == AA_NAME, tostring(entry.type))
            check("MT-14.1.15", "entry.isAASystem=true (CTLDCrateAssemblyManager)",
                  entry.isAASystem == true, tostring(entry.isAASystem))
            check("MT-14.1.16", "entry.isScene=false (not a CTLDSceneManager scene)",
                  entry.isScene == false, tostring(entry.isScene))
        end
    end

    -- Spawn clone from the late-activation source (repeatable without a DCS restart)
    local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
    check("MT-14.1.17", "Clone '" .. AI_UNIT .. "' spawned from '" .. AI_SRC .. "'",
          cloneG ~= nil, tostring(cloneErr))

    local unit = Unit.getByName(AI_UNIT)

    local cm = CTLDCoreManager.getInstance()
    check("MT-14.1.18", "_aiTransportVehicle[" .. AI_UNIT .. "] empty initially",
          cm._aiTransportVehicle[AI_UNIT] == nil)

    report("STEP 1 OK — Land the heli on " .. AIZ_P .. ", wait 3s, re-inject for STEP 2")
    report("   C1 (physical) = no DCS vehicle in the zone → C2 (HAWK AA System isAASystem=true) applies")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify virtual pickup C2 (isAASystem=true + stock decremented)
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
                fail("MT-14.2.0 — C1 (physical) took precedence: a DCS vehicle is loaded — remove any DCS group from " .. AIZ_P)
            end
        end
        report("_aiTransportVehicle[" .. AI_UNIT .. "]=nil — is the heli actually landed in " .. AIZ_P .. " ?")
        report("   Wait 2 more seconds and re-inject STEP 2.")
        _result = "step=2 WAITING"
        return
    end

    check("MT-14.2.1", "_aiTransportVehicle populated at pickup", vEntry ~= nil)
    check("MT-14.2.2", "type='" .. AA_NAME .. "'",
          vEntry.type == AA_NAME, tostring(vEntry.type))
    check("MT-14.2.3", "isAASystem=true (CTLDCrateAssemblyManager)",
          vEntry.isAASystem == true, tostring(vEntry.isAASystem))
    check("MT-14.2.4", "isScene=false (not a CTLDSceneManager scene)",
          vEntry.isScene == false, tostring(vEntry.isScene))
    report("In transit: " .. tostring(vEntry.type) .. " | isAASystem=" .. tostring(vEntry.isAASystem))

    -- Verify stock decremented (1→0)
    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    if zP and zP._aiVehicleStock then
        local cur = zP._aiVehicleStock.current[AA_NAME]
        check("MT-14.2.5", "stock '" .. AA_NAME .. "' decremented (1→0)",
              cur == 0, "current=" .. tostring(cur))
    end

    report("STEP 2 OK — Send the heli to " .. AIZ_D .. " (landed), re-inject for STEP 3")
    report("   The HAWK system will deploy: 3 Hawk ln + 2 Hawk tr + 2 Hawk sr + 1 Hawk pcp + 2 Hawk cwar")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Verify dropoff (spawnSystemAt + _aiTransportVehicle emptied)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local cm = CTLDCoreManager.getInstance()
    local vEntry = cm._aiTransportVehicle[AI_UNIT]

    if vEntry ~= nil then
        report("_aiTransportVehicle still populated — is the heli actually landed in " .. AIZ_D .. " ?")
        _result = "step=3 WAITING"
        return
    end

    check("MT-14.3.1", "_aiTransportVehicle emptied after dropoff (spawnSystemAt called)", vEntry == nil)

    -- Verify that _completeSystems contains a HAWK entry
    local aam = CTLDCrateAssemblyManager.getInstance()
    local hawkFound = false
    for _, entry in pairs(aam._completeSystems) do
        if entry.template and entry.template.name == AA_NAME then
            hawkFound = true
        end
    end
    check("MT-14.3.2", "_completeSystems contains a '" .. AA_NAME .. "' entry", hawkFound)

    report("AA system dropoff confirmed — check on the F10 map that the HAWK units appeared near " .. AIZ_D)
    report("   Expected: 3x Hawk ln (launcher) + 2x Hawk tr + 2x Hawk sr + 1x Hawk pcp + 2x Hawk cwar = 10 units")
    report("   Expected coalition message: 'AI " .. AI_UNIT .. " delivered vehicle: " .. AA_NAME .. "'")
    report("   Expected AA message: 'AI deployed a full " .. AA_NAME .. ".'")
    report("Re-inject for STEP 4 (cleanup)")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("MT-14 ALL SUCCESS — AA system pickup '" .. AA_NAME .. "' (isAASystem=true) + stock 1→0 + spawnSystemAt confirmed")
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
    _SCN_MT14_RESULT = TAG .. " FAIL: step=" .. step .. " — " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return _SCN_MT14_RESULT
end
if _result == "ALL SUCCESS" then
    _SCN_MT14_RESULT = TAG .. " PASS (" .. _ms .. "ms)"
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return _SCN_MT14_RESULT
end
_SCN_MT14_RESULT = TAG .. " RUNNING: " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
                             :gsub("WAITING", "WAITING (" .. _ms .. "ms)")
return _SCN_MT14_RESULT
