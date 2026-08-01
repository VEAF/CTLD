---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- AUTO — Scripted beacon API : createAtPoint / removeBeacon (no transport, no player)
-- =============================================================================
-- FEAT-VMCT-INTEGRATION ticket 03. What busted cannot prove is the part that needs
-- the real engine: three TACAN_beacon groups actually spawned at the requested point
-- and countable through Group.getByName. The rest — silence, battery, frequency pool
-- — is asserted here too, so one run covers the whole contract.
--
--   B-01: createAtPoint() with no unit in the mission → beacon returned, 3 units
--         spawned at the exact point, three distinct frequencies readable back.
--   B-02: it announces nothing and publishes no OnBeaconDropped — a scripted beacon
--         is not a pilot drop.
--   B-03: enabledRadioBeaconDrop = false does not block it (that setting gates the
--         pilot's F10 action), while dropBeacon still refuses.
--   B-04: batteryMinutes = -1 → infinite battery, as isFOB does.
--   B-05: removeBeacon(name) destroys the units and frees the three frequencies.
--
-- Mission prerequisites: NONE. 100% synchronous resolution → tier `auto`.
--
-- Signatures verified in src/CTLD_beacon.lua:
--   createAtPoint(point, coalitionId, countryId, opts) → CTLDBeacon|nil
--   removeBeacon(name) → boolean
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[BSA] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_BSA_RESULT = "[BSA] ABORT: CTLD not initialized"
    return _SCN_BSA_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_BSA_RUNNING then
    trigger.action.outText("[BSA] already running — wait or restart DCS.", 10)
    return _SCN_BSA_RESULT or "[BSA] RUNNING"
end
_SCN_BSA_RUNNING = true
_SCN_BSA_RESULT  = "[BSA] STARTED"

do  -- isolation scope
local TAG = "[BSA]"
local _t0 = os.clock()

local cfg           = CTLDConfig.get()
local _savedEnabled = cfg.settings["enabledRadioBeaconDrop"]
local _savedBattery = cfg.settings["deployedBeaconBattery"]
cfg.settings["enabledRadioBeaconDrop"] = true
cfg.settings["deployedBeaconBattery"]  = 30

local passed, failed, failReasons = 0, 0, {}
local function pass(id, msg) passed = passed + 1; ctld.utils.log("INFO", "%s [PASS] %s: %s", TAG, id, msg or "") end
local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    ctld.utils.log("ERROR", "%s [FAIL] %s: %s", TAG, id, msg or "")
end
local function check(id, cond, detail) if cond then pass(id, detail) else fail(id, detail) end end

local bm = CTLDBeaconManager.getInstance()

-- ── Position: an arbitrary point, deliberately not derived from any unit ─────
local point = { x = 0, z = 0 }
point.y = land.getHeight({ x = point.x, y = point.z })

-- ── Event capture ────────────────────────────────────────────────────────────
local droppedPayload
local onDropped = function(p) droppedPayload = p end
local ed = EventDispatcher.getInstance()
ed:subscribe("OnBeaconDropped", onDropped)

local spawnedGroups = {}
local function trackBeacon(b)
    if not b then return end
    spawnedGroups[#spawnedGroups + 1] = b.vhfGroupName
    spawnedGroups[#spawnedGroups + 1] = b.uhfGroupName
    spawnedGroups[#spawnedGroups + 1] = b.fmGroupName
end

local function cleanup()
    ed:unsubscribe("OnBeaconDropped", onDropped)
    for _, gname in ipairs(spawnedGroups) do
        if gname then
            local g = Group.getByName(gname)
            if g then
                pcall(function() trigger.action.stopRadioTransmission(gname) end)
                g:destroy()
            end
            bm._beacons[gname] = nil
        end
    end
    cfg.settings["enabledRadioBeaconDrop"] = _savedEnabled
    cfg.settings["deployedBeaconBattery"]  = _savedBattery
end

local _ok, _err = pcall(function()

    -- ==== B-01 : createAtPoint spawns for real ==============================
    droppedPayload = nil
    local b1 = bm:createAtPoint(point, coalition.side.BLUE, country.id.USA,
        { name = "SCRIPTED NDB 1" })
    trackBeacon(b1)
    check("B-01.0", b1 ~= nil, "createAtPoint returned a beacon with no transport and no player")
    if b1 then
        check("B-01.1", b1.name == "SCRIPTED NDB 1", "display name honoured | got=" .. tostring(b1.name))
        local dx = math.abs(b1.position.x - point.x)
        local dz = math.abs(b1.position.z - point.z)
        check("B-01.2", dx < 1 and dz < 1,
            string.format("spawned at the requested point | dx=%.2f dz=%.2f", dx, dz))
        check("B-01.3", type(b1.vhf) == "number" and b1.vhf > 0, "vhf readable | got=" .. tostring(b1.vhf))
        check("B-01.4", type(b1.uhf) == "number" and b1.uhf > 0, "uhf readable | got=" .. tostring(b1.uhf))
        check("B-01.5", type(b1.fm)  == "number" and b1.fm  > 0, "fm readable | got="  .. tostring(b1.fm))
        check("B-01.6", b1.vhf ~= b1.uhf and b1.uhf ~= b1.fm and b1.vhf ~= b1.fm, "three distinct frequencies")
        local alive = b1:countAliveUnits()
        check("B-01.7", alive == 3, "3 DCS beacon units spawned | expected=3 got=" .. tostring(alive))
        check("B-01.8", bm._beacons[b1.beaconName] ~= nil, "registered in the manager")
    end

    -- ==== B-02 : silent — not a pilot drop ==================================
    check("B-02.0", droppedPayload == nil, "no OnBeaconDropped published by createAtPoint")

    -- ==== B-03 : enabledRadioBeaconDrop gates the pilot action only =========
    cfg.settings["enabledRadioBeaconDrop"] = false
    local b2 = bm:createAtPoint({ x = point.x + 200, y = land.getHeight({ x = point.x + 200, y = point.z }), z = point.z },
        coalition.side.BLUE, country.id.USA, { name = "SCRIPTED NDB 2" })
    trackBeacon(b2)
    check("B-03.0", b2 ~= nil, "createAtPoint works while the pilot action is disabled")

    local mockTransport = {
        getName      = function() return "MOCK_BSA_TRANSPORT" end,
        getCoalition = function() return coalition.side.BLUE end,
        getCountry   = function() return country.id.USA end,
        getPoint     = function() return { x = point.x, y = point.y, z = point.z } end,
        getDesc      = function() return { box = { min = { x = -8, y = 0, z = -3 },
                                                   max = { x = 8, y = 4, z = 3 } } } end,
        isExist      = function() return true end,
    }
    local b3 = bm:dropBeacon(mockTransport, "TestPilot", false)
    trackBeacon(b3)
    check("B-03.1", b3 == nil, "dropBeacon still refuses when the pilot action is disabled")
    cfg.settings["enabledRadioBeaconDrop"] = true

    -- ==== B-04 : battery ====================================================
    local b4 = bm:createAtPoint({ x = point.x + 400, y = land.getHeight({ x = point.x + 400, y = point.z }), z = point.z },
        coalition.side.BLUE, country.id.USA, { name = "SCRIPTED NDB 3", batteryMinutes = -1 })
    trackBeacon(b4)
    check("B-04.0", b4 ~= nil and b4.batteryEndTime == -1,
        "batteryMinutes = -1 → infinite battery | got=" .. tostring(b4 and b4.batteryEndTime))
    check("B-04.1", b4 ~= nil and b4:isBatteryAlive() == true, "infinite battery reads as alive")
    if b1 then
        check("B-04.2", b1.batteryEndTime ~= -1,
            "default battery is finite (deployedBeaconBattery) | got=" .. tostring(b1.batteryEndTime))
    end

    -- ==== B-05 : removeBeacon by name =======================================
    if b1 then
        local freeVHFBefore = #bm._freeVHF
        local removed = bm:removeBeacon("SCRIPTED NDB 1")
        check("B-05.0", removed == true, "removeBeacon returned true for a known name")
        check("B-05.1", bm._beacons[b1.beaconName] == nil, "beacon gone from the registry")
        check("B-05.2", #bm._freeVHF == freeVHFBefore + 1,
            "vhf frequency returned to the pool | before=" .. freeVHFBefore .. " after=" .. #bm._freeVHF)
        local aliveAfter = b1:countAliveUnits()
        check("B-05.3", aliveAfter == 0, "DCS units destroyed | expected=0 got=" .. tostring(aliveAfter))
        check("B-05.4", bm:removeBeacon("SCRIPTED NDB 1") == false, "removing it twice returns false")
    end

end)

-- ── Result + cleanup ─────────────────────────────────────────────────────────
pcall(cleanup)
_SCN_BSA_RUNNING = false
local _ms = math.floor((os.clock() - _t0) * 1000)

if not _ok then
    _SCN_BSA_RESULT = TAG .. " FAIL: crash — " .. tostring(_err)
    trigger.action.outText(_SCN_BSA_RESULT, 60, true)
    ctld.utils.log("ERROR", _SCN_BSA_RESULT)
    return _SCN_BSA_RESULT
end

local total = passed + failed
if failed == 0 then
    _SCN_BSA_RESULT = TAG .. " PASS " .. passed .. "/" .. total .. " (" .. _ms .. "ms)"
else
    _SCN_BSA_RESULT = TAG .. " FAIL " .. failed .. "/" .. total .. ": " .. table.concat(failReasons, "; ")
end
trigger.action.outText(_SCN_BSA_RESULT, 30, true)
ctld.utils.log("INFO", _SCN_BSA_RESULT)
return _SCN_BSA_RESULT

end  -- do isolation scope
return _SCN_BSA_RESULT
