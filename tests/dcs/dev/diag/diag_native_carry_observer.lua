---@diagnostic disable
-- diag_native_carry_observer.lua
-- FIX-NATIVE-CARRY-DETECTION ticket 07 -- observer for the manual live checklist. It asserts
-- nothing: it only records, in dcs.log (tag [NCOBS]) and briefly on screen, what DCS reports on board
-- each player aircraft and how CTLD follows it, so a tester doing the checklist by hand (loadmaster
-- tablet, DCS cargo UI) gets a verifiable trace.
--
--   * DCS side : every 2 s, the on-board cargo list of each player aircraft (name, type, weight),
--                logged whenever it changes.
--   * CTLD side: OnVehicleLoaded / OnVehicleUnloaded / OnVehicleDead / OnCrateLoaded /
--                OnCrateUnloaded events (method, aircraft), and the state of every tracked vehicle and
--                native-carry crate, logged whenever it changes.
--
-- Inject with the runner's HTTP path (never the MCP tool), after CTLD.lua. Re-injecting restarts it;
-- `_NCOBS.stop()` stops it. Lua 5.1.
-- =============================================================================

if not ctld or not ctld.utils then
    trigger.action.outText("[NCOBS] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    return "[NCOBS] ABORT: CTLD not initialized"
end

if _NCOBS and _NCOBS.stop then _NCOBS.stop() end

local TAG       = "[NCOBS]"
local POLL_S    = 2
local obs       = { running = true, lastList = {}, lastCtld = "", subs = {} }
_NCOBS = obs

local function out(msg, screen)
    env.info(TAG .. " " .. msg)
    if screen then trigger.action.outText(TAG .. " " .. msg, 10) end
end

-- ── DCS side: the on-board cargo list of each player aircraft ───────────────────────────────────
local function describeList(unit)
    if not unit.getCargosOnBoard then return nil, "no getCargosOnBoard" end
    local ok, list = pcall(unit.getCargosOnBoard, unit)
    if not ok then return nil, "error: " .. tostring(list) end
    local items = {}
    for _, cargo in ipairs(list or {}) do
        local name, typeName, weight = "?", "?", "?"
        pcall(function() name = cargo:getName() end)
        pcall(function() typeName = cargo:getTypeName() end)
        pcall(function() weight = cargo:getCargoWeight() end)
        items[#items + 1] = string.format("%s[%s,%skg]", tostring(name), tostring(typeName), tostring(weight))
    end
    table.sort(items)
    return #items == 0 and "(empty)" or table.concat(items, " ")
end

-- ── CTLD side: tracked vehicles and native-carry crates ─────────────────────────────────────────
local function describeCtld()
    local parts = {}
    local okV, vs = pcall(CTLDVehicleSpawner.getInstance)
    if okV and vs then
        for id, veh in pairs(vs._vehicles) do
            local unitOk = veh.unit and veh.unit.isExist and veh.unit:isExist() and "unit" or "no-unit"
            parts[#parts + 1] = string.format("veh %s=%s/%s/%s->%s", id, tostring(veh:getState()),
                tostring(veh.loadMethod), unitOk, tostring(veh.loadTransportName))
        end
    end
    local okC, cm = pcall(CTLDCrateManager.getInstance)
    if okC and cm then
        for name, crate in pairs(cm.crates) do
            if crate.state ~= "spawned" or crate.loadedByDCSNative then
                parts[#parts + 1] = string.format("crate %s=%s%s", tostring(name), tostring(crate.state),
                    crate.loadedByDCSNative and "/dcs-native" or "")
            end
        end
    end
    table.sort(parts)
    return #parts == 0 and "(nothing tracked beyond spawned crates)" or table.concat(parts, " | ")
end

local function poll()
    if not obs.running then return nil end
    local okP, pm = pcall(CTLDPlayerManager.getInstance)
    if okP and pm then
        for unitName in pairs(pm._players) do
            local unit = Unit.getByName(unitName)
            if unit and unit:isExist() then
                local desc, err = describeList(unit)
                local airborne = ctld.utils.inAir(unit) and "AIR" or "GROUND"
                local text = desc or err
                local key = airborne .. text
                if obs.lastList[unitName] ~= key then
                    obs.lastList[unitName] = key
                    out(string.format("LIST %s (%s, %s): %s", unitName, tostring(unit:getTypeName()), airborne, text), true)
                end
            end
        end
    end
    local ctldNow = describeCtld()
    if ctldNow ~= obs.lastCtld then
        obs.lastCtld = ctldNow
        out("CTLD " .. ctldNow, false)
    end
    return timer.getTime() + POLL_S
end

local function listen(eventName, fmt)
    local ed = EventDispatcher.getInstance()
    local cb = function(p)
        local ok, text = pcall(fmt, p)
        out("EVENT " .. eventName .. " " .. (ok and text or ("(format error: " .. tostring(text) .. ")")), true)
    end
    ed:subscribe(eventName, cb)
    obs.subs[#obs.subs + 1] = { name = eventName, cb = cb }
end

listen("OnVehicleLoaded", function(p)
    return string.format("vehicle=%s method=%s transport=%s", tostring(p.vehicleId), tostring(p.method),
        p.transportUnitObject and p.transportUnitObject:getName() or "?")
end)
listen("OnVehicleUnloaded", function(p)
    return string.format("vehicle=%s method=%s", tostring(p.vehicleId), tostring(p.method))
end)
listen("OnVehicleDead", function(p) return "vehicle=" .. tostring(p.vehicleId) end)
listen("OnCrateLoaded", function(p)
    return string.format("crate=%s method=%s carrier=%s", tostring(p.crateName), tostring(p.method), tostring(p.carrierUnitName))
end)
listen("OnCrateUnloaded", function(p)
    return string.format("crate=%s method=%s", tostring(p.crateName), tostring(p.method))
end)

function obs.stop()
    obs.running = false
    local ed = EventDispatcher.getInstance()
    for _, s in ipairs(obs.subs) do pcall(ed.unsubscribe, ed, s.name, s.cb) end
    obs.subs = {}
    out("stopped", true)
end

timer.scheduleFunction(function() return poll() end, nil, timer.getTime() + 1)
out("observer started (list every " .. POLL_S .. " s, CTLD events, vehicle and crate states)", true)
return "[NCOBS] STARTED"
