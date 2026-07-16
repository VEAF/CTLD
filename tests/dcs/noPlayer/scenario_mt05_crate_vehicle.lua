---@diagnostic disable
-- @tier: auto
-- ============================================================
-- MT-05 AUTO — Crate + whole vehicle: cross-isolation
-- ============================================================
-- Verifies that loading a crate AND a whole vehicle simultaneously
-- on the same transport causes no state interference.
-- No real DCS spawn — tests the internal registries only.
--
-- Pre-requisites: none (fully mocked)
-- Family        : auto (no human intervention)
-- ============================================================

-- ── CTLD-ready guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-05] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_MT05_RESULT = "[MT-05] ABORT: CTLD not initialized"
    return _SCN_MT05_RESULT
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_MT05_RUNNING then
    trigger.action.outText("[MT-05] already running.", 10)
    return _SCN_MT05_RESULT or "[MT-05] RUNNING"
end
_SCN_MT05_RUNNING = true
_SCN_MT05_RESULT = "[MT-05] STARTED"

do  -- isolation scope
trigger.action.outText("[MT-05] START — crate + whole vehicle isolation", 8)

local TRANSPORT_NAME = "mock_transport_MT05"
local CRATE_NAME     = "mock_crate_MT05"
local VEHICLE_ID     = 99901
local VEHICLE_TYPE   = "M1045 HMMWV TOW"
local CRATE_WEIGHT   = 2000

-- ── Mock transport unit ──────────────────────────────────────
local mockTransport = {
    getName  = function() return TRANSPORT_NAME end,
    getPoint = function() return { x = 0, y = 0, z = 0 } end,
    isExist  = function() return true end,
}

-- ── Setup ────────────────────────────────────────────────────
local cm = CTLDCrateManager.getInstance()
local vs = CTLDVehicleSpawner.getInstance()

-- ── Test helpers ─────────────────────────────────────────────
local passed = 0
local failed = 0
local failures = {}
local function pass(_) passed = passed + 1 end
local function fail(label) failed = failed + 1; table.insert(failures, label) end
local function check(label, cond) if cond then pass(label) else fail(label) end end

-- Registered here (outside the pcall) so the guaranteed cleanup block below can always
-- remove them from the shared singletons, even if the test body errors partway through.
local crate, vehicle

-- pcall-wrapped body: any internal crash must still reach cleanup + _SCN_MT05_RUNNING reset
-- below, otherwise a leaked mock crate/vehicle pollutes every other scenario sharing these
-- singletons, and the double-injection guard stays stuck forever (found 2026-07-10: exactly
-- this happened, leaking "mock_crate_MT05" into CTLDCrateManager.crates and freezing this
-- scenario's own _SCN_MT05_RUNNING at true).
local _ok, _err = pcall(function()
    -- Mock descriptor with known weight
    local mockDescriptor = { desc = "Mock Hummer", weight = CRATE_WEIGHT, unitTypes = { VEHICLE_TYPE } }

    -- Register crate in LOADED state
    crate = CTLDCrate:new({
        crateName   = CRATE_NAME,
        descriptor  = mockDescriptor,
        spawnMethod = "ctld",
        position    = { x = 0, y = 0, z = 0 },
        heading     = 0,
        coalition   = 2,
    })
    crate:load(mockTransport)
    cm.crates[CRATE_NAME] = crate

    -- Register vehicle in LOADED state
    vehicle = CTLDVehicle:new({
        id          = VEHICLE_ID,
        vehicleType = VEHICLE_TYPE,
        spawnData   = nil,
    })
    vehicle:setState(CTLDVehicle.STATE.LOADED)
    vehicle.loadTransportName = TRANSPORT_NAME
    vehicle.loadMethod        = "menu_ctld"
    vs._vehicles[VEHICLE_ID]  = vehicle

    -- ── F-MT05-1 : crate detected as loaded via CTLD ────────────
    check("F-MT05-1 crate isLoadedByCTLD", crate:isLoadedByCTLD() == true)

    -- ── F-MT05-2 : vehicle detected as loaded on transport ──────
    local loadedVehs = vs:findLoadedVehicles(mockTransport)
    check("F-MT05-2 findLoadedVehicles returns vehicle", #loadedVehs == 1 and loadedVehs[1].id == VEHICLE_ID)

    -- ── F-MT05-3 : crate weight aggregated correctly ────────────
    local crateW = cm:getLoadedCrateWeight(TRANSPORT_NAME)
    check("F-MT05-3 getLoadedCrateWeight = " .. tostring(crateW), crateW == CRATE_WEIGHT)

    -- ── F-MT05-4 : vehicle weight aggregated correctly ──────────
    local vehicleWeights = ctld.gs("groundVehicleWeights") or {}
    local expectedVW = vehicleWeights[VEHICLE_TYPE] or 2500
    local vehicleW = vs:getLoadedVehicleWeight(TRANSPORT_NAME)
    check("F-MT05-4 getLoadedVehicleWeight = " .. tostring(vehicleW), vehicleW == expectedVW)

    -- ── F-MT05-5 : unload crate → vehicle unchanged ─────────────
    crate:unload()
    check("F-MT05-5a crate state after unload = LANDED", crate.state == CTLDCrate.STATE.LANDED)
    check("F-MT05-5b vehicle state unchanged after crate unload", vehicle:getState() == CTLDVehicle.STATE.LOADED)
    check("F-MT05-5c vehicle.loadTransportName unchanged", vehicle.loadTransportName == TRANSPORT_NAME)
    -- Restore crate for next tests
    crate:load(mockTransport)

    -- ── F-MT05-6 : unload vehicle → crate unchanged ─────────────
    vehicle:setState(CTLDVehicle.STATE.WAITING)
    vehicle.loadTransportName = nil
    check("F-MT05-6a vehicle state after unload = WAITING", vehicle:getState() == CTLDVehicle.STATE.WAITING)
    check("F-MT05-6b crate isLoadedByCTLD unchanged", crate:isLoadedByCTLD() == true)
    check("F-MT05-6c crate.loadedBy unchanged", crate.loadedBy ~= nil)
    -- Restore vehicle for next tests
    vehicle:setState(CTLDVehicle.STATE.LOADED)
    vehicle.loadTransportName = TRANSPORT_NAME

    -- ── F-MT05-7 : after crate unload, findLoadedVehicles intact ─
    crate:unload()
    local vehs7 = vs:findLoadedVehicles(mockTransport)
    check("F-MT05-7 findLoadedVehicles still 1 after crate unload", #vehs7 == 1)
    crate:load(mockTransport)

    -- ── F-MT05-8 : after vehicle unload, crate weight intact ─────
    vehicle:setState(CTLDVehicle.STATE.WAITING)
    vehicle.loadTransportName = nil
    local crateW8 = cm:getLoadedCrateWeight(TRANSPORT_NAME)
    check("F-MT05-8 getLoadedCrateWeight intact after vehicle unload", crateW8 == CRATE_WEIGHT)
end)

-- ── Cleanup (always runs, even if the pcall above errored) ────
if crate then cm.crates[CRATE_NAME] = nil end
if vehicle then vs._vehicles[VEHICLE_ID] = nil end

if not _ok then
    _SCN_MT05_RESULT = "[MT-05] FAIL: crash — " .. tostring(_err)
    trigger.action.outText(_SCN_MT05_RESULT, 60, true)
    ctld.utils.log("ERROR", _SCN_MT05_RESULT)
    _SCN_MT05_RUNNING = false
    return _SCN_MT05_RESULT
end

-- ── Result ───────────────────────────────────────────────────
local total = passed + failed
local msg = string.format("[MT-05] %d/%d PASS", passed, total)
trigger.action.outText(msg, 12, true)
ctld.utils.log("INFO", msg)
if failed > 0 then
    ctld.utils.log("ERROR", "[MT-05] FAILED tests: " .. failed)
end

if #failures > 0 then
    msg = msg .. " | FAIL: " .. table.concat(failures, ", ")
end
if failed == 0 then
    _SCN_MT05_RESULT = "[MT-05] PASS " .. passed .. "/" .. total
else
    _SCN_MT05_RESULT = "[MT-05] FAIL " .. failed .. "/" .. total .. ": " .. table.concat(failures, ", ")
end
_SCN_MT05_RUNNING = false
return _SCN_MT05_RESULT
end  -- do isolation scope
return _SCN_MT05_RESULT
