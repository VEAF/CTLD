---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- aiTransport_featureT_stockConsumption_F178.lua  [AUTO]
-- F-178 — Feature T: stock decrement on AI pickup
--
-- PREREQUISITE: CTLD initialized (classes available in memory).
--   Does not require DCS zones in the .miz.
--
-- GOAL: verify that aiConsumeTroopStock() and aiConsumeVehicleStock()
--   correctly decrement the current stock, without going below 0,
--   and have no effect when isAll=true.
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-178] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_F178_RESULT = "[F-178] ABORT: CTLD not initialized"
    return _SCN_F178_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F178_RUNNING then
    trigger.action.outText("[F-178] already running.", 10)
    return _SCN_F178_RESULT or "[F-178] RUNNING"
end
_SCN_F178_RUNNING = true
_SCN_F178_RESULT = "[F-178] STARTED"

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-178]"
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

    -- ═══════════════════════════════════════════════════════════════════════
    -- SECTION A — Troop stock consumption
    -- ═══════════════════════════════════════════════════════════════════════

    local zone = CTLDTroopZone:new({
        zoneName    = "TEST_CONSUME_T",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = false,
            init    = { ["Standard Group"] = 3 },
            current = { ["Standard Group"] = 3 },
        },
    })

    -- A.1: first consume → current = 2
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.1", "after 1 consume: current[Standard Group] = 2",
          zone._aiTroopStock.current["Standard Group"] == 2,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.2: second consume → current = 1
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.2", "after 2 consumes: current[Standard Group] = 1",
          zone._aiTroopStock.current["Standard Group"] == 1,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.3: third consume → current = 0
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.3", "after 3 consumes: current[Standard Group] = 0",
          zone._aiTroopStock.current["Standard Group"] == 0,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.4: fourth consume (on stock=0) → still 0, no negative
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.4", "consume on stock=0: still 0 (no negative)",
          zone._aiTroopStock.current["Standard Group"] == 0,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.5: consume of an absent key → no error, other keys intact
    zone._aiTroopStock.current["Standard Group"] = 2
    zone:aiConsumeTroopStock("Unknown Template")
    check("F-178.5", "consume absent template: Standard Group intact",
          zone._aiTroopStock.current["Standard Group"] == 2,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.6: isAll=true → consume is no-op (no current to modify)
    local zoneAll = CTLDTroopZone:new({
        zoneName     = "TEST_CONSUME_T_ALL",
        isAIPickup   = true,
        pickMaxStock = 0,
        _aiTroopStock = { isAll = true, init = {}, current = {} },
    })
    zoneAll:aiConsumeTroopStock("Standard Group")  -- must not error
    check("F-178.6", "isAll=true: consume is no-op (no error)", true)

    -- ═══════════════════════════════════════════════════════════════════════
    -- SECTION B — Vehicle stock consumption
    -- ═══════════════════════════════════════════════════════════════════════

    local zoneV = CTLDTroopZone:new({
        zoneName    = "TEST_CONSUME_V",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 2 },
            current = { ["Hummer"] = 2 },
        },
    })

    -- B.1: first vehicle consume → 1
    zoneV:aiConsumeVehicleStock("Hummer")
    check("F-178.7", "after 1 vehicle consume: current[Hummer] = 1",
          zoneV._aiVehicleStock.current["Hummer"] == 1,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.2: second consume → 0
    zoneV:aiConsumeVehicleStock("Hummer")
    check("F-178.8", "after 2 vehicle consumes: current[Hummer] = 0",
          zoneV._aiVehicleStock.current["Hummer"] == 0,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.3: third consume (stock=0) → still 0
    zoneV:aiConsumeVehicleStock("Hummer")
    check("F-178.9", "vehicle consume on stock=0: still 0",
          zoneV._aiVehicleStock.current["Hummer"] == 0,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.4: stock=-1 (unlimited) → consume is no-op (s=-1, condition s>0 false)
    local zoneVUnlimited = CTLDTroopZone:new({
        zoneName    = "TEST_CONSUME_V_UNLIMITED",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["M1025 HMMWV Armament"] = -1 },
            current = { ["M1025 HMMWV Armament"] = -1 },
        },
    })
    zoneVUnlimited:aiConsumeVehicleStock("M1025 HMMWV Armament")
    check("F-178.10", "stock=-1 (unlimited): consume is no-op, stays -1",
          zoneVUnlimited._aiVehicleStock.current["M1025 HMMWV Armament"] == -1,
          tostring(zoneVUnlimited._aiVehicleStock.current["M1025 HMMWV Armament"]))

    report("✅ F-178 ALL PASS — troop/vehicle stock decrement correct")

end)

if not _ok then
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_F178_RESULT = TAG .. " FAIL: " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ " .. _SCN_F178_RESULT, 60, true)
    _SCN_F178_RUNNING = false
    return _SCN_F178_RESULT
end

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
_SCN_F178_RESULT = TAG .. " PASS"
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F178_RUNNING = false

end  -- do isolation scope
return _SCN_F178_RESULT
