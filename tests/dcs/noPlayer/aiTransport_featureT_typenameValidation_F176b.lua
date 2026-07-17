---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- aiTransport_featureT_typenameValidation_F176b.lua  [AUTO]
-- F-176b — Feature T: vehicleStock typeName validation at zone-load time
--
-- PREREQUISITE: CTLD initialized, AIZ_depot_B_P_V_10 present in the .miz
--   (vehicleStock = { ["Hummer"] = 3, ["M1045 HMMWV TOW"] = -1 })
--
-- GOAL: verify that invalid DCS typeNames in vehicleStock are rejected at
--   zone-load time (logged ERROR + absent from _aiVehicleStock.current), and
--   that valid typeNames are retained.
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-176b] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_F176B_RESULT = "[F-176b] ABORT: CTLD not initialized"
    return _SCN_F176B_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F176B_RUNNING then
    trigger.action.outText("[F-176b] already running.", 10)
    return _SCN_F176B_RESULT or "[F-176b] RUNNING"
end
_SCN_F176B_RUNNING = true
_SCN_F176B_RESULT  = "[F-176b] STARTED"

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-176b]"
local START = os.date("%Y-%m-%d %H:%M:%S")

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 20); log(msg) end
local function pass(id, desc)   report("[PASS] " .. id .. " — " .. desc) end
local function fail(id, desc, details)
    local msg = "[FAIL] " .. id .. " — " .. desc .. (details and (" | " .. details) or "")
    trigger.action.outText(TAG .. " !! " .. msg, 60); log(msg)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id, desc) else fail(id, desc, details) end
end

report("==== START " .. START .. " ====")

local _ok, _err = pcall(function()

    -- Inject an invalid typeName into the zone config, then re-init AI zones
    local savedZones = cfg.settings["aiZones"]
    cfg.settings["aiZones"] = {
        { dcsZoneName = "AIZ_depot_B_P_V_10", coalition = "BLUE",
          isPickup = true, cargoType = "V",
          vehicleStock = { ["Hummer"] = 3, ["INVALID_TYPENAME_XYZ"] = 2 } },
    }

    CTLDCoreManager.getInstance():_initAITransports()

    local zm   = CTLDZoneManager.getInstance()
    local zVeh = zm._troopZones["AIZ_depot_B_P_V_10"]
    check("F-176b.1", "zone AIZ_depot_B_P_V_10 exists", zVeh ~= nil)

    if zVeh then
        local vs = zVeh._aiVehicleStock
        check("F-176b.2", "_aiVehicleStock non-nil", vs ~= nil)

        -- Valid typeName must be retained
        check("F-176b.3", "valid typeName 'Hummer' retained in init",
              vs and vs.init["Hummer"] == 3,
              tostring(vs and vs.init["Hummer"]))
        check("F-176b.4", "valid typeName 'Hummer' retained in current",
              vs and vs.current["Hummer"] == 3,
              tostring(vs and vs.current["Hummer"]))

        -- Invalid typeName must be absent
        check("F-176b.5", "invalid typeName absent from init",
              vs and vs.init["INVALID_TYPENAME_XYZ"] == nil,
              tostring(vs and vs.init["INVALID_TYPENAME_XYZ"]))
        check("F-176b.6", "invalid typeName absent from current",
              vs and vs.current["INVALID_TYPENAME_XYZ"] == nil,
              tostring(vs and vs.current["INVALID_TYPENAME_XYZ"]))
    end

    -- Restore original config and re-init so other tests are not affected
    cfg.settings["aiZones"] = savedZones
    CTLDCoreManager.getInstance():_initAITransports()

    report("F-176b ALL PASS — invalid vehicleStock typeNames rejected at load time")

end)

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

if not _ok then
    _SCN_F176B_RESULT = TAG .. " FAIL: " .. tostring(_err)
    trigger.action.outText(TAG .. " FAIL: " .. tostring(_err), 60, true)
    _SCN_F176B_RUNNING = false
    return _SCN_F176B_RESULT
end

_SCN_F176B_RESULT = TAG .. " PASS"
trigger.action.outText(TAG .. " ALL PASS", 30, true)
_SCN_F176B_RUNNING = false

end  -- do isolation scope
return _SCN_F176B_RESULT
