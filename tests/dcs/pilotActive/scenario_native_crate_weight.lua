---@diagnostic disable
-- @tier: human (menu) -- the pilot loads a crate through the DCS cargo UI (and optionally one through the CTLD menu)
-- =============================================================================
-- CTLD — weight CTLD adds for a crate loaded through the DCS cargo UI (FIX-NATIVE-CRATE-CTLD-ACTIONS)
--
-- DCS accounts for what is loaded through its own cargo UI. CTLD must add a weight only for what it
-- virtualised through its menu (as it already does for whole vehicles). This scenario measures what CTLD
-- really sends to DCS for the player's transport once at least one crate is on board in native carry.
--
-- Steps for the pilot (in a native-cargo aircraft: C-130J-30, CH-47F, Mi-8MT, UH-1H, Mi-24P):
--   1. Request a crate (F10 > CTLD > Request Equipment) and stay on the ground next to it.
--   2. Load it with the DCS cargo UI (not the CTLD menu).  [optional: also load one through CTLD > Load Crate]
-- The scenario polls every 2 s, then measures once and returns the verdict.
--
-- Measured (all in kg):
--   native / virtual   crates on board, by loading mode, and their descriptor weights
--   ctldCrateWeight    what CTLD counts for the crates (CTLDCrateManager:getLoadedCrateWeight)
--   sentToDcs          the value CTLD passes to trigger.action.setUnitInternalCargo for this unit
--   dcsListed          weights DCS itself lists for the on-board cargo (getCargosOnBoard)
-- PASS: ctldCrateWeight equals the weight of the VIRTUAL crates only (native counted as zero).
-- On a build that still counts native crates the verdict is FAIL and the numbers show the double count.
--
-- @scenario  NCW
-- @version   1.0 — 2026-10-03
-- =============================================================================

if not ctld or not ctld.utils or not CTLDCrateManager then
    _SCN_NCW_RESULT = "[NCW] ABORT: CTLD not initialized"
    return _SCN_NCW_RESULT
end
if _SCN_NCW_RUNNING then return _SCN_NCW_RESULT or "[NCW] RUNNING" end
_SCN_NCW_RUNNING = true

do
local TAG = "[NCW]"
local TIMEOUT_S, POLL_S = 600, 2
local waited = 0

local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end
local function weightOf(crate) return (crate.descriptor and crate.descriptor.weight) or 0 end

local function findPlayerUnit()
    local pm = CTLDPlayerManager.getInstance()
    for unitName in pairs(pm._players) do
        local u = Unit.getByName(unitName)
        if u and u:isExist() then return unitName, u end
    end
end

local function measure(unitName, unit)
    local cm = CTLDCrateManager.getInstance()
    local nativeW, virtualW, nNative, nVirtual = 0, 0, 0, 0
    for _, c in pairs(cm.crates) do
        if c:isLoaded() and cm:isCarriedBy(c, unitName) then
            if c.loadedByDCSNative then nativeW = nativeW + weightOf(c); nNative = nNative + 1
            else virtualW = virtualW + weightOf(c); nVirtual = nVirtual + 1 end
        end
    end
    if nNative == 0 then return nil end

    local ctldCrateWeight = cm:getLoadedCrateWeight(unitName)

    -- What CTLD really passes to DCS: capture setUnitInternalCargo while CTLD recomputes the weight.
    local sent
    local orig = trigger.action.setUnitInternalCargo
    trigger.action.setUnitInternalCargo = function(name, mass) if name == unitName then sent = mass end; return orig(name, mass) end
    local ok, err = pcall(ctld.utils.updateTransportWeight, unitName)
    trigger.action.setUnitInternalCargo = orig
    if not ok then log("updateTransportWeight failed: " .. tostring(err)) end

    local listed, parts = 0, {}
    local okL, list = pcall(function() return unit:getCargosOnBoard() end)
    if okL and type(list) == "table" then
        for _, cargo in ipairs(list) do
            local okW, w = pcall(function() return cargo:getCargoWeight() end)
            if okW and type(w) == "number" then listed = listed + w; parts[#parts + 1] = tostring(w) end
        end
    end

    local ok2 = (ctldCrateWeight == virtualW)
    local verdict = string.format(
        "%s %s native=%d(%dkg) virtual=%d(%dkg) ctldCrateWeight=%dkg sentToDcs=%skg dcsListed=%dkg[%s] type=%s",
        TAG, ok2 and "PASS" or "FAIL", nNative, nativeW, nVirtual, virtualW, ctldCrateWeight,
        tostring(sent), listed, table.concat(parts, ","), tostring(unit:getTypeName()))
    return verdict
end

local function poll()
    waited = waited + POLL_S
    local unitName, unit = findPlayerUnit()
    local verdict = unitName and measure(unitName, unit)
    if verdict then
        _SCN_NCW_RESULT = verdict
        _SCN_NCW_RUNNING = false
        log(verdict)
        trigger.action.outText(verdict, 60, true)
        return nil
    end
    if waited >= TIMEOUT_S then
        _SCN_NCW_RESULT = TAG .. " ABORT: no crate loaded through the DCS cargo UI within " .. TIMEOUT_S .. " s"
        _SCN_NCW_RUNNING = false
        return nil
    end
    return timer.getTime() + POLL_S
end

_SCN_NCW_RESULT = TAG .. " STARTED"
trigger.action.outText(TAG .. "\nRequest a crate, then load it with the DCS cargo UI (not the CTLD menu).", 30, true)
timer.scheduleFunction(function() return poll() end, nil, timer.getTime() + POLL_S)
end
return _SCN_NCW_RESULT
