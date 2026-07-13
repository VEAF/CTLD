---@diagnostic disable
-- @tier: auto-check  (needs a BLUE slot for position; spawns its own FOB crates + auto-unpacks,
--                     no piloting/F10 -- RUNNING step machine re-injected on a timer)
-- =============================================================================
-- scenarios/scenario_fob_scene.lua
-- PT6 — FOB scene visual validation
--
-- Steps:
--   Step 1 — cleanup + spawn 3 FOB crates in front of the helo
--             + automatic trigger of unpackFOBCrates after 2 s
--   Step 2 — (inject at ~T+130) verify FOB registered in CTLDFOBManager
--   Step 99 — final summary
--
-- Prerequisites:
--   • UH-1H BLUE slot occupied, helo on the ground
--   • Helo position > 500 m from any existing logistic zone
--     (otherwise the _isTooCloseToZone guard blocks the build)
--   • enable_debug.lua injected before this script
-- =============================================================================

-- ── CTLD-ready guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FOB-SCN] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_FOBSCN_RESULT = "[FOB-SCN] ABORT: CTLD not initialized"
    return _SCN_FOBSCN_RESULT
end

local TAG      = "[FOB-SCN]"
local STEP_VAR = "_FOB_SCN_STEP"

-- ── HEADER — shown on every injection ─────────────────────────────────────────
trigger.action.outText(
    "[FOB-SCN] === PT6 : FOB Scene validation ===\n"
    .. "PRE : UH-1H BLUE on the ground, > 500 m from any logistic zone\n"
    .. "      Statics f1-f7 + fh1-fh3 placed in the mission\n"
    .. "RUN : 1) Inject => 3 crates spawn + auto unpack in 2 s\n"
    .. "      2) Watch the 120 s animation (progressive spawn + FOB + cleanup)\n"
    .. "      3) Re-inject at T+130 => verify FOB registered",
    30)

-- ── helpers ───────────────────────────────────────────────────────────────────

local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 40)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end

local function pass(msg)
    report("[PASS] " .. msg)
end

local function fail(msg)
    report("[FAIL] " .. msg)
    error(msg)
end

local function check(id, desc, cond, detail)
    if cond then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (detail and (" | " .. detail) or ""))
    end
end

-- Resolve the player-controlled transport (first BLUE player). Replaces the dead FullGas
-- `ctld_test.getTransport()` helper (nil, same cause as the ~194 CLEANUP-LEGACY-DCS-TESTS relics).
local function getTransport()
    for _, grp in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        for _, unit in ipairs(grp:getUnits() or {}) do
            if unit and unit:isExist() and unit:getPlayerName() then return unit end
        end
    end
    return nil
end

-- ── init debug ────────────────────────────────────────────────────────────────

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]             = true
cfg.settings["debugScreenLog"]    = false
cfg.settings["debugScreenLogDuration"] = 12

-- ── state machine ─────────────────────────────────────────────────────────────

_G[STEP_VAR] = _G[STEP_VAR] or 1
local step = _G[STEP_VAR]

report("==== START " .. os.date("%H:%M:%S") .. " | step=" .. step .. " ====")

local _done = false   -- set true by the terminal step so the return logic emits PASS (else the
                      -- state machine loops 1->2->99->1 forever under an automated re-inject loop)

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Spawn 3 FOB crates + automatic unpack at T+2
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    local transport = getTransport()
    if not transport then fail("no BLUE player") end

    local playerName = transport:getName()
    local pPos       = transport:getPoint()
    local hdg        = ctld.utils.getHeadingInRadians("fob_scn", transport, true)
    local cId        = transport:getCoalition()

    -- Cleanup existing FOBs (permanent objects + beacon + logistic zones + registry)
    local fobMgr       = CTLDFOBManager.getInstance()
    local beaconMgr    = CTLDBeaconManager.getInstance()
    local existingFobs = fobMgr:getFOBsForCoalition(cId)
    for _, fob in ipairs(existingFobs) do
        -- Permanent scene objects
        for _, obj in ipairs(fob.sceneObjects) do
            if obj then pcall(function() if obj:isExist() then obj:destroy() end end) end
        end
        -- FOB radio beacon
        if fob.beacon then
            local bn = fob.beacon.beaconName
            if beaconMgr._beacons[bn] then
                pcall(function() beaconMgr:_destroyBeaconUnits(fob.beacon) end)
                pcall(function() beaconMgr:_freeFrequencies(fob.beacon) end)
                pcall(function() beaconMgr:_removeBeaconFromLayers(fob.beacon) end)
                beaconMgr._beacons[bn] = nil
                report("Purge beacon: " .. bn)
            end
        end
        -- Logistic zone
        pcall(function() CTLDZoneManager.getInstance():unregisterLogistic(fob.name) end)
        fobMgr._fobs[fob.fobId] = nil
        report("Purge FOB: " .. fob.name)
    end
    fobMgr._objectToFOB = {}

    -- Clean up leftover FOB crates from the previous session
    local cm       = CTLDCrateManager.getInstance()
    local leftover = cm:getCratesInRange(pPos, 750)
    local purged   = 0
    for _, c in ipairs(leftover) do
        if c.coalition == cId and c.descriptor and c.descriptor.unit == "FOB" then
            cm:destroyCrate(c.crateName)
            purged = purged + 1
        end
    end
    if purged > 0 then
        report("Purge: " .. purged .. " leftover FOB crate(s)")
    end

    -- FOB descriptor (unit = "FOB", cratesRequired = 3)
    local fobDesc = cm:findDescriptorByUnitType("FOB")
    check("F-SCN.1", "FOB descriptor present in config", fobDesc ~= nil)

    local required = (fobDesc and fobDesc.cratesRequired) or 3

    -- Spawn N crates in a line in front of the helo, 5 m apart
    local spawnedCount = 0
    for i = 1, required do
        local dist = 15 + (i - 1) * 5   -- 15 m, 20 m, 25 m ...
        local nx   = pPos.x + math.cos(hdg) * dist
        local nz   = pPos.z + math.sin(hdg) * dist
        local pos  = { x = nx, y = land.getHeight({ x = nx, y = nz }), z = nz }
        local crate = cm:spawnCrate(
            fobDesc, pos, cId, "scenario_fob_scene", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
        if crate then spawnedCount = spawnedCount + 1 end
    end

    check("F-SCN.2", "3 FOB crates spawned", spawnedCount == required,
        "spawned=" .. spawnedCount .. " required=" .. required)

    -- FOB centroid: 100 m at 12 o'clock in front of the helo
    local fx  = pPos.x + math.cos(hdg) * 100
    local fz  = pPos.z + math.sin(hdg) * 100
    local centroid = { x = fx, y = land.getHeight({x = fx, y = fz}), z = fz }

    -- Destroy the crates (simulates the unpackFOBCrates consume)
    for _, c in ipairs(cm:getCratesInRange(pPos, 750)) do
        if c.coalition == cId and c.descriptor and c.descriptor.unit == "FOB" then
            cm:destroyCrate(c.crateName)
        end
    end

    -- Start the scene directly (bypass guards for visual testing).
    -- Step 21 (func-only) calls CTLDFOBManager:_registerDeployedFOB(ctx.scene)
    -- automatically — no need for an onComplete callback here.
    local sceneStarted = CTLDSceneManager.getInstance():playScene(
        transport, "FOB",
        {
            player        = playerName,
            centroid      = centroid,
            coalitionId   = cId,
            countryId     = transport:getCountry(),
            transportName = transport:getName(),
            cratesUsed    = {},
        }
    )
    check("F-SCN.3", "fobScene scene started", sceneStarted ~= nil)

    report("Crates spawned (" .. spawnedCount .. "). Unpack in 2 s.")
    report("Watch the construction scene (120 s).")
    report("Re-inject this script at T+130 to verify the FOB.")

    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify FOB registered (~T+130)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local transport = getTransport()
    local cId = transport and transport:getCoalition() or coalition.side.BLUE

    local fobMgr = CTLDFOBManager.getInstance()
    local fobs   = fobMgr:getFOBsForCoalition(cId)

    -- The FOB scene takes ~120s to build and self-register (its func-step calls
    -- _registerDeployedFOB at the end). An automated runner re-injects every ~2s, so step 2 can
    -- be reached long before the scene finishes -- retry (bounded) instead of a false FAIL, so
    -- the re-inject loop waits the scene out. ~90 retries * 2s ≈ 180s covers the build.
    if #fobs < 1 then
        local retries = (_G["_FOB_SCN_STEP2_RETRIES"] or 0) + 1
        _G["_FOB_SCN_STEP2_RETRIES"] = retries
        if retries <= 90 then
            -- Stay on step 2 (don't advance _G[STEP_VAR]); the bottom emits RUNNING and the
            -- runner re-injects, re-checking until the scene registers the FOB (~120s).
            report("Step 2 [retry "..retries.."/90] FOB scene still building — re-inject")
            return
        end
        -- past the retry budget: fall through so check() records a real FAIL
    end
    _G["_FOB_SCN_STEP2_RETRIES"] = nil

    check("F-SCN.3", "at least 1 FOB registered for BLUE", #fobs >= 1,
        "count=" .. #fobs)

    if #fobs >= 1 then
        local fob = fobs[1]
        check("F-SCN.4", "FOB isAlive()", fob:isAlive())

        local intPct = math.floor(fob:getIntegrityPercent() * 100 + 0.5)
        check("F-SCN.5", "integrity = 100%", intPct == 100, "integrity=" .. intPct .. "%")

        report(string.format("FOB '%s' @ (%.0f, %.0f) — %d%% integrity",
            fob.name, fob.position.x, fob.position.z, intPct))

        if fob.beacon then
            report(string.format("Beacon: VHF %.1f kHz / UHF %.1f MHz / FM %.1f MHz",
                fob.beacon.vhf / 1000,
                fob.beacon.uhf / 1000000,
                fob.beacon.fm  / 1000000))
        end
    end

    pass("Step 2 — FOB verification complete")
    _G[STEP_VAR] = 99

-- ══════════════════════════════════════════════════════════════════════════════
-- FINAL STEP — Summary
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then
    report("═══════════════════════════════════")
    report("FOB-SCN — ALL STEPS COMPLETE")
    report("═══════════════════════════════════")
    _G[STEP_VAR] = 1
    _done = true

else
    fail("step=" .. step .. " has no branch — reset with _reset_steps.lua")
end

end)  -- end pcall

-- ── cleanup debug ─────────────────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

-- ── dcs-bridge return value ───────────────────────────────────────────────────
if not _ok then
    _SCN_FOBSCN_RESULT = TAG .. " FAIL: step=" .. step .. " — " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return _SCN_FOBSCN_RESULT
end
if _done then
    -- Terminal step reached — emit the definitive PASS (without this the state machine loops
    -- 1->2->99->1 forever under an automated re-inject loop, never producing a verdict).
    _SCN_FOBSCN_RESULT = TAG .. " PASS"
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS", 30, true)
    return _SCN_FOBSCN_RESULT
end
-- Multi-step re-injection scenario: a step success is intermediate — runner re-injects.
_SCN_FOBSCN_RESULT = TAG .. " RUNNING: step=" .. step .. " SUCCESS"
trigger.action.outText(TAG .. " ✅ step=" .. step .. " SUCCESS", 30, true)
return _SCN_FOBSCN_RESULT
