---@diagnostic disable
-- @tier: auto-check
-- =============================================================================
-- TGE — FEAT-TROOP-GESTURE-EVENTS (issue #308) live check.
--
-- The four troop gestures that published nothing now announce themselves. This plays them for real in a running
-- mission (real DCS groups, the real troop manager and event bus) and checks the events received:
--   1. OnTroopsLoaded     load in a pickup zone                 (zone name, empty player for an AI-style unit)
--   2. OnTroopsReturned   give the troops back to the zone
--   3. OnTroopsUnloaded   ground drop            method 'ground',    destination combat
--   4. OnTroopsExtracted  pick the dropped group up again in the field
--   5. OnTroopsUnloaded   drop by fast-rope      method 'fast_rope'
--   6. OnTroopsUnloaded   drop into an extraction zone           destination 'extraction_zone' + zone name
--   7. 'Unload All' with two groups publishes two OnTroopsUnloaded; the player name appears for a player transport
--   8. A refused drop (no troops on board) publishes nothing.
--
-- The transport is a MOCK 3 km from the first BLUE player: nothing is ever created next to a live aircraft.
-- Everything created is cleaned up at the end.
--
-- Result: _SCN_TGE_RESULT  ("[TGE] PASS n/n" | "[TGE] FAIL ..." | "[TGE] ABORT ...")
-- =============================================================================

if not ctld or not ctld.utils then
    _SCN_TGE_RESULT = "[TGE] ABORT: CTLD not initialized"
    return _SCN_TGE_RESULT
end
if _SCN_TGE_RUNNING then return _SCN_TGE_RESULT or "[TGE] RUNNING" end
_SCN_TGE_RUNNING = true
_SCN_TGE_RESULT  = "[TGE] STARTED"

do
local TAG   = "[TGE]"
local MOCK  = "TGE_mock_transport"
local BLUE  = coalition.side.BLUE
local passed, failed, reasons = 0, 0, {}

local function log(fmt, ...) ctld.utils.log("INFO", "%s " .. fmt, TAG, ...) end
local function check(id, ok, msg)
    if ok then passed = passed + 1; log("PASS %s", id)
    else failed = failed + 1; reasons[#reasons + 1] = id .. ": " .. msg; log("FAIL %s — %s", id, msg) end
end

local tm  = CTLDTroopManager.getInstance()
local zm  = CTLDZoneManager.getInstance()
local ed  = EventDispatcher.getInstance()
local cfg = CTLDConfig.get()

local player = coalition.getPlayers(BLUE)[1]
if not player then
    _SCN_TGE_RUNNING = false
    _SCN_TGE_RESULT  = "[TGE] ABORT: no BLUE player"
    return _SCN_TGE_RESULT
end

-- A template with no JTAC (a JTAC would register with the JTAC manager) and a size every aircraft carries.
local template
for _, t in ipairs(tm._templates or {}) do
    if (t.jtac or 0) == 0 and (t.total or 99) <= 6 then template = t; break end
end
if not template then
    _SCN_TGE_RUNNING = false
    _SCN_TGE_RESULT  = "[TGE] ABORT: no small troop template without JTAC in this mission"
    return _SCN_TGE_RESULT
end

local pp = player:getPoint()
local S  = { x = pp.x, z = pp.z + 3000 }
S.y = land.getHeight({ x = S.x, y = S.z })
local pt = { x = S.x, y = S.y + 1, z = S.z }
local airborne = false

local mock = {
    getName      = function() return MOCK end,
    isExist      = function() return true end,
    getCoalition = function() return BLUE end,
    getCountry   = function() return country.id.USA end,
    getTypeName  = function() return "UH-1H" end,
    getPoint     = function() return pt end,
    getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
    getGroup     = function() return { getID = function() return 9999997 end, getName = function() return "TGE_mock_group" end } end,
    inAir        = function() return airborne end,
    getPlayerName = function() return nil end,
    getDesc      = function() return { box = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } } } end,
    getPosition  = function()
        return { p = pt, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
    end,
}
local origGetByName = Unit.getByName
Unit.getByName = function(n) if n == MOCK then return mock end return origGetByName(n) end

local savedFastRope = cfg.settings["enableFastRopeInsertion"]

-- A pickup zone and an extraction zone around the site, built directly (not registered unless a gesture needs it).
local pickupZone = CTLDTroopZone:new({
    dcsName = "TGE_TRZ", zoneName = "TGE_TRZ", coalition = BLUE, center = { x = S.x, y = S.y, z = S.z },
    radius = 400, pickMaxStock = 0,
})
local exzZone = CTLDTroopZone:new({
    dcsName = "TGE_EXZ", zoneName = "TGE_EXZ", coalition = BLUE, center = { x = S.x, y = S.y, z = S.z },
    radius = 400, objectiveFlag = "TGE_flag",
})

local events, subs = {}, {}
for _, n in ipairs({ "OnTroopsLoaded", "OnTroopsReturned", "OnTroopsUnloaded", "OnTroopsExtracted" }) do
    events[n] = {}
    local cb = function(p) events[n][#events[n] + 1] = p end
    ed:subscribe(n, cb)
    subs[#subs + 1] = { name = n, cb = cb }
end
local function count(n) return #events[n] end
local function last(n) return events[n][#events[n]] end

local droppedBefore = {}
for _, nm in ipairs(tm._droppedGroups[BLUE] or {}) do droppedBefore[nm] = true end

local function finish()
    for _, s in ipairs(subs) do ed:unsubscribe(s.name, s.cb) end
    -- groups this scenario dropped, whatever their registration
    for _, nm in ipairs(tm._droppedGroups[BLUE] or {}) do
        if not droppedBefore[nm] then local g = Group.getByName(nm); if g then g:destroy() end end
    end
    tm._droppedGroups[BLUE] = (function()
        local keep = {}
        for _, nm in ipairs(tm._droppedGroups[BLUE] or {}) do if droppedBefore[nm] then keep[#keep + 1] = nm end end
        return keep
    end)()
    tm._inTransit[MOCK] = nil
    zm._troopZones["TGE_EXZ"] = nil
    trigger.action.setUserFlag("TGE_flag", 0)
    CTLDPlayerManager.getInstance()._players[MOCK] = nil
    cfg.settings["enableFastRopeInsertion"] = savedFastRope
    for _, g in ipairs(coalition.getGroups(BLUE, Group.Category.GROUND) or {}) do
        local u = g:getUnit(1)
        if u then
            local p = u:getPoint()
            if math.abs(p.x - S.x) < 400 and math.abs(p.z - S.z) < 400 then g:destroy() end
        end
    end
    Unit.getByName = origGetByName
    _SCN_TGE_RUNNING = false
    if failed == 0 then _SCN_TGE_RESULT = string.format("%s PASS %d/%d", TAG, passed, passed)
    else _SCN_TGE_RESULT = string.format("%s FAIL %d/%d: %s", TAG, failed, passed + failed, table.concat(reasons, " | ")) end
    trigger.action.outText(_SCN_TGE_RESULT, 15)
    log("%s", _SCN_TGE_RESULT)
end

local function step(fn, delay)
    timer.scheduleFunction(function()
        local ok, err = pcall(fn)
        if not ok then
            failed = failed + 1
            reasons[#reasons + 1] = "error: " .. tostring(err)
            log("ERROR in step: %s", tostring(err))
            finish()
        end
    end, nil, timer.getTime() + (delay or 2))
end

-- ── 1-2. Load in a pickup zone, give the troops back ─────────────────────────
local loaded = tm:embarkFromTroopZone(mock, pickupZone, template)
check("1.0 load succeeded", loaded == true, "embarkFromTroopZone returned " .. tostring(loaded))
check("1.1 OnTroopsLoaded published once", count("OnTroopsLoaded") == 1, "published " .. count("OnTroopsLoaded"))
local ev = last("OnTroopsLoaded") or {}
check("1.2 OnTroopsLoaded payload", ev.zone == "TGE_TRZ" and ev.carrierUnitName == MOCK and ev.player == nil
      and ev.troops ~= nil and ev.troops.templateName == template.name and type(ev.timestamp) == "number",
      "zone=" .. tostring(ev.zone) .. " carrier=" .. tostring(ev.carrierUnitName) .. " player=" .. tostring(ev.player))

local returned = tm:returnToTroopZone(mock, pickupZone)
check("2.0 return succeeded", returned == true, "returnToTroopZone returned " .. tostring(returned))
check("2.1 OnTroopsReturned published once, with the zone", count("OnTroopsReturned") == 1
      and (last("OnTroopsReturned") or {}).zone == "TGE_TRZ", "published " .. count("OnTroopsReturned"))

-- ── 3. Ground drop ───────────────────────────────────────────────────────────
tm:embarkFromTroopZone(mock, pickupZone, template)
local dropped = tm:disembark(mock)
check("3.0 ground drop succeeded", dropped == true, "disembark returned " .. tostring(dropped))
ev = last("OnTroopsUnloaded") or {}
check("3.1 OnTroopsUnloaded: ground, combat", count("OnTroopsUnloaded") == 1 and ev.method == "ground"
      and ev.destination and ev.destination.type == "combat" and ev.destination.troopZone == nil,
      "count=" .. count("OnTroopsUnloaded") .. " method=" .. tostring(ev.method))

step(function()
    -- ── 4. Extract the dropped group again ───────────────────────────────────
    local extracted = tm:embarkFromField(mock)
    check("4.0 extraction succeeded", extracted == true, "embarkFromField returned " .. tostring(extracted))
    ev = last("OnTroopsExtracted") or {}
    check("4.1 OnTroopsExtracted published once, carrier and troops", count("OnTroopsExtracted") == 1
          and ev.carrierUnitName == MOCK and ev.troops ~= nil and ev.player == nil,
          "count=" .. count("OnTroopsExtracted"))

    -- ── 5. Fast-rope drop ────────────────────────────────────────────────────
    cfg.settings["enableFastRopeInsertion"] = true
    airborne = true
    pt = { x = S.x, y = S.y + 10, z = S.z }
    local before = count("OnTroopsUnloaded")
    local roped = tm:disembark(mock)
    airborne = false
    pt = { x = S.x, y = S.y + 1, z = S.z }
    check("5.0 fast-rope drop succeeded", roped == true, "disembark returned " .. tostring(roped))
    ev = last("OnTroopsUnloaded") or {}
    check("5.1 OnTroopsUnloaded: fast_rope", count("OnTroopsUnloaded") == before + 1 and ev.method == "fast_rope",
          "count=" .. count("OnTroopsUnloaded") .. " method=" .. tostring(ev.method))
    cfg.settings["enableFastRopeInsertion"] = savedFastRope

    step(function()
        -- ── 6. Drop into an extraction zone ──────────────────────────────────
        tm:embarkFromTroopZone(mock, pickupZone, template)
        zm._troopZones["TGE_EXZ"] = exzZone
        local n0 = count("OnTroopsUnloaded")
        local inExz = tm:disembark(mock)
        zm._troopZones["TGE_EXZ"] = nil
        check("6.0 extraction-zone drop succeeded", inExz == true, "disembark returned " .. tostring(inExz))
        ev = last("OnTroopsUnloaded") or {}
        check("6.1 OnTroopsUnloaded: extraction_zone with the zone name", count("OnTroopsUnloaded") == n0 + 1
              and ev.destination and ev.destination.type == "extraction_zone" and ev.destination.troopZone == "TGE_EXZ",
              "destination=" .. tostring(ev.destination and ev.destination.type) .. "/" .. tostring(ev.destination and ev.destination.troopZone))

        -- ── 7. Unload All, and a player transport ────────────────────────────
        CTLDPlayerManager.getInstance()._players[MOCK] = {
            unitName = MOCK, groupId = 9999997, groupName = "TGE_mock_group", coalition = BLUE,
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
        tm:embarkFromTroopZone(mock, pickupZone, template)
        tm:embarkFromTroopZone(mock, pickupZone, template)
        check("7.0 a player transport's load carries its slot unit name", (last("OnTroopsLoaded") or {}).player == MOCK,
              "player=" .. tostring((last("OnTroopsLoaded") or {}).player))
        local n1 = count("OnTroopsUnloaded")
        tm:disembarkAll(mock)
        check("7.1 'Unload All' publishes one event per group", count("OnTroopsUnloaded") == n1 + 2,
              "published " .. (count("OnTroopsUnloaded") - n1))
        check("7.2 the player name is on the unload", (last("OnTroopsUnloaded") or {}).player == MOCK,
              "player=" .. tostring((last("OnTroopsUnloaded") or {}).player))

        -- ── 8. A refused drop publishes nothing ──────────────────────────────
        local n2 = count("OnTroopsUnloaded")
        local refused = tm:disembark(mock)
        check("8.0 no troops on board: refused, nothing published", refused == false and count("OnTroopsUnloaded") == n2,
              "returned " .. tostring(refused) .. ", published " .. (count("OnTroopsUnloaded") - n2))
        finish()
    end)
end)

return _SCN_TGE_RESULT
end
