---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- AUTO — Recon scan : OnReconScan payload (activeLayers / targets / markId)
-- =============================================================================
-- Re-integrates the dead relic F-009 which requires the REAL DCS engine (real LOS
-- raycast via land.isVisible against real enemy units), impossible to mock
-- in busted:
--
--   F-009: scan() → publishes OnReconScan with a payload {activeLayers, targets},
--          and creates a markId (> 0) for each enemy target detected in LOS.
--
-- The observer is a REAL ground unit spawned by the scenario (getUnitsLOS
-- resolves the observer via Unit.getByName — a mock would not be found). The
-- scan is resolved SYNCHRONOUSLY (targets computed + event published in the
-- same call) → tier `auto`. The auto-refresh timer left by scan() is
-- stopped in cleanup via stopScan().
--
-- Mission prerequisite: at least ONE enemy unit (RED or BLUE) present, otherwise
-- there is nothing to detect in LOS → clear ABORT. The markId assertions run
-- only if targets are actually detected (LOS depends on the
-- terrain/relief; the observer is spawned ~1500 m from an enemy to maximise
-- the odds, but a blocked LOS remains possible and is NOT a failure).
--
-- Signatures verified in src/CTLD_recon.lua (2026-07-11):
--   scan(playerUnit, player)  l.577  — gate: ctld.gs("reconF10Menu"), l.580
--   publish OnReconScan {player, activeLayers, targets, totalTargetsDetected, ...} l.650
--   _scanLOS via ctld.utils.getUnitsLOS (Unit.getByName on the observer) l.397
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[RCN] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_RCN_RESULT = "[RCN] ABORT: CTLD not initialized"
    return _SCN_RCN_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_RCN_RUNNING then
    trigger.action.outText("[RCN] already running — wait or restart DCS.", 10)
    return _SCN_RCN_RESULT or "[RCN] RUNNING"
end
_SCN_RCN_RUNNING = true
_SCN_RCN_RESULT  = "[RCN] STARTED"

do  -- isolation scope
local TAG    = "[RCN]"
local PLAYER = "RECON_TESTER"
local _t0    = os.clock()

local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
local _savedReconMenu      = cfg.settings["reconF10Menu"]
local _savedMinAlt         = cfg.settings["reconMinAltitude"]
local _savedRadius         = cfg.settings["reconSearchRadius"]
cfg.settings["debug"]             = true
cfg.settings["debugScreenLog"]    = true
cfg.settings["reconF10Menu"]      = true
cfg.settings["reconMinAltitude"]  = 0      -- allow ground-level observer (test env)
cfg.settings["reconSearchRadius"] = 15000

local passed, failed, failReasons = 0, 0, {}
local function pass(id, msg) passed = passed + 1; ctld.utils.log("INFO", "%s [PASS] %s: %s", TAG, id, msg or "") end
local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    ctld.utils.log("ERROR", "%s [FAIL] %s: %s", TAG, id, msg or "")
end
local function check(id, cond, detail) if cond then pass(id, detail) else fail(id, detail) end end

local rm  = CTLDReconManager.getInstance()
local ed  = EventDispatcher.getInstance()
local CATS = { Group.Category.GROUND, Group.Category.AIRPLANE,
               Group.Category.HELICOPTER, Group.Category.SHIP }

-- ── Determine which coalition holds units → observer is on the OPPOSITE side ─
local redNames  = ctld.utils.getUnitsListNamesByCategory("recon_scn", coalition.side.RED,  CATS)
local blueNames = ctld.utils.getUnitsListNamesByCategory("recon_scn", coalition.side.BLUE, CATS)

local observerCoa, observerCountry, observerType, enemyNames
if #redNames > 0 then
    observerCoa, observerCountry, observerType, enemyNames =
        coalition.side.BLUE, country.id.USA, "Soldier M4", redNames
elseif #blueNames > 0 then
    observerCoa, observerCountry, observerType, enemyNames =
        coalition.side.RED, country.id.RUSSIA, "Infantry AK", blueNames
end

-- ── ABORT if no enemy targets exist at all ──────────────────────────────────
if not enemyNames then
    -- restore config before bailing
    cfg.settings["debug"]             = _savedDebug
    cfg.settings["debugScreenLog"]    = _savedDebugScreenLog
    cfg.settings["reconF10Menu"]      = _savedReconMenu
    cfg.settings["reconMinAltitude"]  = _savedMinAlt
    cfg.settings["reconSearchRadius"] = _savedRadius
    _SCN_RCN_RUNNING = false
    _SCN_RCN_RESULT  = TAG .. " ABORT: no enemy units in mission (need >=1 unit on either coalition for recon LOS)"
    trigger.action.outText(_SCN_RCN_RESULT, 30, true)
    ctld.utils.log("WARN", _SCN_RCN_RESULT)
    return _SCN_RCN_RESULT
end

-- ── Anchor: ~1500 m from the first enemy unit to maximise LOS ────────────────
local enemyUnit = Unit.getByName(enemyNames[1])
local base      = enemyUnit and enemyUnit:getPoint() or { x = 0, y = 0, z = 0 }
local obsX, obsZ = base.x + 1500, base.z
local anchor = { x = obsX, y = land.getHeight({ x = obsX, y = obsZ }), z = obsZ }

-- ── Spawn the real observer unit ─────────────────────────────────────────────
local obsUid   = ctld.utils.getNextUniqId()
local obsGroup = "RCN_OBS_" .. obsUid
local groupData = {
    visible  = true,
    hidden   = false,
    category = Group.Category.GROUND,
    country  = observerCountry,
    name     = obsGroup,
    task     = {},
    units    = {
        { type = observerType, name = obsGroup, x = anchor.x, y = anchor.z,
          heading = 0, skill = "Average", playerCanDrive = false },
    },
}
local spawnRes  = ctld.utils.dynAdd("recon_scn:spawnObserver", groupData)
local obsUnit   = spawnRes and Group.getByName(spawnRes.name) and Group.getByName(spawnRes.name):getUnit(1) or nil

-- ── Event capture (unsubscribed in cleanup) ──────────────────────────────────
local reconPayload
local onScan = function(p) reconPayload = p end
ed:subscribe("OnReconScan", onScan)

-- ── Cleanup (always runs) ────────────────────────────────────────────────────
local function cleanup()
    ed:unsubscribe("OnReconScan", onScan)
    -- Stop RECON (removes auto-refresh timer + marks + clears _activeScans[player]).
    if obsUnit then pcall(function() rm:stopScan(obsUnit, PLAYER) end) end
    rm._activeScans[PLAYER] = nil
    rm._playerLayers[PLAYER] = nil
    if rm._farpMarks then rm._farpMarks[PLAYER] = nil end
    local g = Group.getByName(obsGroup)
    if g then g:destroy() end
    cfg.settings["debug"]             = _savedDebug
    cfg.settings["debugScreenLog"]    = _savedDebugScreenLog
    cfg.settings["reconF10Menu"]      = _savedReconMenu
    cfg.settings["reconMinAltitude"]  = _savedMinAlt
    cfg.settings["reconSearchRadius"] = _savedRadius
end

-- ── Test body (pcall — any crash still reaches cleanup) ──────────────────────
local _ok, _err = pcall(function()

    if not obsUnit then
        error("observer spawn failed — dynAdd/Group.getByName returned nil (invalid spawn position?)")
    end

    -- Enable ALL layers so any detected enemy category yields a target + markId.
    local layers = rm:_getPlayerLayers(PLAYER)
    for _, layer in ipairs(layers) do layer.enabled = true end

    reconPayload = nil
    rm:scan(obsUnit, PLAYER)

    -- ==== F-009 : OnReconScan payload contract =============================
    check("F-009.1", reconPayload ~= nil, "OnReconScan published after scan()")
    if reconPayload then
        check("F-009.2", reconPayload.player == PLAYER,
            "payload.player == '" .. PLAYER .. "' | got=" .. tostring(reconPayload.player))
        check("F-009.3", reconPayload.activeLayers ~= nil, "payload.activeLayers present")
        check("F-009.4", type(reconPayload.activeLayers) == "table" and #reconPayload.activeLayers > 0,
            "payload.activeLayers non-empty (all layers enabled) | n=" ..
            tostring(reconPayload.activeLayers and #reconPayload.activeLayers))
        check("F-009.5", reconPayload.targets ~= nil and type(reconPayload.targets) == "table",
            "payload.targets is a table")
        check("F-009.6", type(reconPayload.totalTargetsDetected) == "number",
            "payload.totalTargetsDetected is a number | got=" .. tostring(reconPayload.totalTargetsDetected))
    end

    -- Active scan registered for the player
    local scan = rm._activeScans[PLAYER]
    check("F-009.7", scan ~= nil, "active scan registered for player")

    -- markId assertions only when LOS actually detected targets
    if scan and #scan.targets > 0 then
        check("F-009.8", scan.targets[1].markId ~= nil, "first detected target has a markId")
        check("F-009.9", type(scan.targets[1].markId) == "number" and scan.targets[1].markId > 0,
            "markId > 0 | got=" .. tostring(scan.targets[1].markId))
        check("F-009.10", reconPayload and reconPayload.totalTargetsDetected == #scan.targets,
            string.format("payload.totalTargetsDetected == #targets | payload=%s scan=%d",
                tostring(reconPayload and reconPayload.totalTargetsDetected), #scan.targets))
    else
        pass("F-009.INFO", string.format(
            "0 enemy in LOS from observer (LOS blocked by terrain/relief) — %d enemy unit(s) exist; " ..
            "payload contract validated, markId assertions skipped", #enemyNames))
    end

end)

-- ── Result + cleanup ─────────────────────────────────────────────────────────
pcall(cleanup)
_SCN_RCN_RUNNING = false
local _ms = math.floor((os.clock() - _t0) * 1000)

if not _ok then
    _SCN_RCN_RESULT = TAG .. " FAIL: crash — " .. tostring(_err)
    trigger.action.outText(_SCN_RCN_RESULT, 60, true)
    ctld.utils.log("ERROR", _SCN_RCN_RESULT)
    return _SCN_RCN_RESULT
end

local total = passed + failed
if failed == 0 then
    _SCN_RCN_RESULT = TAG .. " PASS " .. passed .. "/" .. total .. " (" .. _ms .. "ms)"
else
    _SCN_RCN_RESULT = TAG .. " FAIL " .. failed .. "/" .. total .. ": " .. table.concat(failReasons, "; ")
end
trigger.action.outText(_SCN_RCN_RESULT, 30, true)
ctld.utils.log("INFO", _SCN_RCN_RESULT)
return _SCN_RCN_RESULT

end  -- do isolation scope
return _SCN_RCN_RESULT
