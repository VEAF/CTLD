---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- aiTransport_featureT_stockRestore_F179.lua  [AUTO]
-- F-179 — Feature T: stock restore on AI dropoff (shuttle)
--
-- PREREQUISITE: CTLD initialized (classes available in memory).
--   Does not require DCS zones in the .miz.
--
-- GOAL: verify that aiRestoreTroopStock() and aiRestoreVehicleStock()
--   correctly restore the current stock, without exceeding the init cap,
--   and have no effect when isAll=true or stock=-1 (unlimited).
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-179] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_F179_RESULT = "[F-179] ABORT: CTLD not initialized"
    return _SCN_F179_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F179_RUNNING then
    trigger.action.outText("[F-179] already running.", 10)
    return _SCN_F179_RESULT or "[F-179] RUNNING"
end
_SCN_F179_RUNNING = true
_SCN_F179_RESULT = "[F-179] STARTED"

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-179]"
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
    -- SECTION A — Troop stock restore
    -- ═══════════════════════════════════════════════════════════════════════

    local zone = CTLDTroopZone:new({
        zoneName     = "TEST_RESTORE_T",
        isAIPickup   = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = false,
            init    = { ["Standard Group"] = 3 },
            current = { ["Standard Group"] = 1 },  -- partially consumed
        },
    })

    -- A.1: restore 1 → current = 2
    zone:aiRestoreTroopStock("Standard Group", 1)
    check("F-179.1", "restore 1: current = 2",
          zone._aiTroopStock.current["Standard Group"] == 2,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.2: restore 1 → current = 3 (cap reached)
    zone:aiRestoreTroopStock("Standard Group", 1)
    check("F-179.2", "restore 1: current = 3 (init cap)",
          zone._aiTroopStock.current["Standard Group"] == 3,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.3: restore at cap → does not exceed init (3)
    zone:aiRestoreTroopStock("Standard Group", 1)
    check("F-179.3", "restore at cap: current stays 3",
          zone._aiTroopStock.current["Standard Group"] == 3,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.4: restore with n > 1 (stays capped)
    zone._aiTroopStock.current["Standard Group"] = 0
    zone:aiRestoreTroopStock("Standard Group", 10)
    check("F-179.4", "restore n=10 capped at init=3",
          zone._aiTroopStock.current["Standard Group"] == 3,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.5: restore without n (default=1)
    zone._aiTroopStock.current["Standard Group"] = 0
    zone:aiRestoreTroopStock("Standard Group")
    check("F-179.5", "restore without n: +1 (default)",
          zone._aiTroopStock.current["Standard Group"] == 1,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.6: isAll=true → restore is no-op
    local zoneAll = CTLDTroopZone:new({
        zoneName     = "TEST_RESTORE_T_ALL",
        isAIPickup   = true,
        pickMaxStock = 0,
        _aiTroopStock = { isAll = true, init = {}, current = {} },
    })
    zoneAll:aiRestoreTroopStock("Standard Group", 1)  -- must not error
    check("F-179.6", "isAll=true: restore is no-op (no error)", true)

    -- A.7: restore of an absent key → no-op (maxS=nil → return early)
    zone:aiRestoreTroopStock("Unknown Template", 1)
    check("F-179.7", "restore absent key: no-op (no error)", true)

    -- ═══════════════════════════════════════════════════════════════════════
    -- SECTION B — Vehicle stock restore
    -- ═══════════════════════════════════════════════════════════════════════

    local zoneV = CTLDTroopZone:new({
        zoneName    = "TEST_RESTORE_V",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 2 },
            current = { ["Hummer"] = 0 },  -- fully consumed
        },
    })

    -- B.1: vehicle restore → 1
    zoneV:aiRestoreVehicleStock("Hummer")
    check("F-179.8", "vehicle restore: current[Hummer] = 1",
          zoneV._aiVehicleStock.current["Hummer"] == 1,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.2: restore → cap 2
    zoneV:aiRestoreVehicleStock("Hummer")
    check("F-179.9", "vehicle restore: current[Hummer] = 2 (cap)",
          zoneV._aiVehicleStock.current["Hummer"] == 2,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.3: restore at cap → stays 2
    zoneV:aiRestoreVehicleStock("Hummer")
    check("F-179.10", "vehicle restore at cap: stays 2",
          zoneV._aiVehicleStock.current["Hummer"] == 2,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.4: stock=-1 (unlimited in init) → restore is no-op (maxS==-1 → return early)
    local zoneVUnlim = CTLDTroopZone:new({
        zoneName    = "TEST_RESTORE_V_UNLIM",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["M1025 HMMWV Armament"] = -1 },
            current = { ["M1025 HMMWV Armament"] = -1 },
        },
    })
    zoneVUnlim:aiRestoreVehicleStock("M1025 HMMWV Armament")  -- no-op
    check("F-179.11", "vehicle stock=-1: restore no-op, stays -1",
          zoneVUnlim._aiVehicleStock.current["M1025 HMMWV Armament"] == -1,
          tostring(zoneVUnlim._aiVehicleStock.current["M1025 HMMWV Armament"]))

    report("✅ F-179 ALL PASS — troop/vehicle stock restore correct")

end)

if not _ok then
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_F179_RESULT = TAG .. " FAIL: " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F179_RUNNING = false
    return _SCN_F179_RESULT
end

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
_SCN_F179_RESULT = TAG .. " PASS"
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F179_RUNNING = false

end  -- do isolation scope
return _SCN_F179_RESULT
