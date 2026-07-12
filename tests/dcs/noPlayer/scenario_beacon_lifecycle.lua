---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- AUTO — Beacon lifecycle : dropBeacon / removeClosestBeacon / FOB beacon
-- =============================================================================
-- Ré-intègre 3 reliques mortes qui exigent le VRAI moteur DCS (spawn réel de
-- 3 groupes TACAN_beacon + Group.getByName), impossibles à mocker en busted :
--
--   F-006 : dropBeacon (non-FOB) → 3 unités DCS spawnées, 3 fréquences assignées,
--           batterie temporaire (batteryEndTime != -1), event OnBeaconDropped.
--   F-007 : removeClosestBeacon (< 500 m) → beacon retiré de _beacons,
--           event OnBeaconRemoved avec reason="manual" + frequenciesFreed.
--   F-092 : dropBeacon(isFOB=true, overridePosition=centroid) → beacon spawné
--           au centroid exact (pas sous l'hélico), batterie infinie (=-1).
--
-- Le transport est un mock (fournit position/coalition/pays) : la partie NON
-- mockable — le spawn réel des unités beacon et leur comptage via Group.getByName
-- — passe par le vrai moteur. Résolution 100 % synchrone → tier `auto`.
--
-- Pré-requis mission : AUCUN (le transport est mocké, les beacons sont spawnés
-- par le scénario ; ancre positionnelle dérivée d'une unité existante ou (0,0)).
--
-- Signatures vérifiées dans src/CTLD_beacon.lua (2026-07-11) :
--   dropBeacon(transport, player, isFOB, overridePosition)  l.324
--     publish OnBeaconDropped {player, coalition, beacon, timestamp}  l.410
--     isFOB → batteryEndTime = -1 (batterie infinie)  l.376
--   removeClosestBeacon(transport, player)  l.424  (rayon 500 m)
--     publish OnBeaconRemoved {reason="manual", frequenciesFreed, ...}  l.453
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[BCN] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_BCN_RESULT = "[BCN] ABORT: CTLD not initialized"
    return _SCN_BCN_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_BCN_RUNNING then
    trigger.action.outText("[BCN] already running — wait or restart DCS.", 10)
    return _SCN_BCN_RESULT or "[BCN] RUNNING"
end
_SCN_BCN_RUNNING = true
_SCN_BCN_RESULT  = "[BCN] STARTED"

do  -- isolation scope
local TAG = "[BCN]"
local _t0 = os.clock()

-- ── Config: force beacon feature ON, save previous state ─────────────────────
local cfg                   = CTLDConfig.get()
local _savedDebug           = cfg.settings["debug"]
local _savedDebugScreenLog  = cfg.settings["debugScreenLog"]
local _savedEnabled         = cfg.settings["enabledRadioBeaconDrop"]
local _savedBattery         = cfg.settings["deployedBeaconBattery"]
cfg.settings["debug"]                  = true
cfg.settings["debugScreenLog"]         = true
cfg.settings["enabledRadioBeaconDrop"] = true
cfg.settings["deployedBeaconBattery"]  = 30

-- ── Test helpers ─────────────────────────────────────────────────────────────
local passed, failed, failReasons = 0, 0, {}
local function pass(id, msg) passed = passed + 1; ctld.utils.log("INFO", "%s [PASS] %s: %s", TAG, id, msg or "") end
local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    ctld.utils.log("ERROR", "%s [FAIL] %s: %s", TAG, id, msg or "")
end
local function check(id, cond, detail) if cond then pass(id, detail) else fail(id, detail) end end

local bm = CTLDBeaconManager.getInstance()

-- ── Positional anchor: reuse an existing unit's position, else map origin ────
local function anchorPos()
    local cats = { Group.Category.GROUND, Group.Category.AIRPLANE,
                   Group.Category.HELICOPTER, Group.Category.SHIP }
    for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        for _, cat in ipairs(cats) do
            local groups = coalition.getGroups(side, cat)
            if groups then
                for _, g in ipairs(groups) do
                    local u = g:getUnit(1)
                    if u and u:isExist() then return u:getPoint() end
                end
            end
        end
    end
    return { x = 0, y = land.getHeight({ x = 0, y = 0 }), z = 0 }
end

local anchor = anchorPos()
anchor.y = land.getHeight({ x = anchor.x, y = anchor.z })

-- ── Mock transport (BLUE / USA) at the anchor ────────────────────────────────
local mockTransport = {
    getName       = function() return "MOCK_BCN_TRANSPORT" end,
    getCoalition  = function() return coalition.side.BLUE end,
    getCountry    = function() return country.id.USA end,
    getPoint      = function() return { x = anchor.x, y = anchor.y, z = anchor.z } end,
    getPosition   = function() return {
        p = { x = anchor.x, y = anchor.y, z = anchor.z },
        x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 },
    } end,
    getDesc       = function() return { box = { min = { x = -8, y = 0, z = -3 },
                                                max = { x = 8, y = 4, z = 3 } } } end,
    inAir         = function() return false end,
    isExist       = function() return true end,
}

-- ── Event capture (unsubscribed in cleanup) ──────────────────────────────────
local droppedPayload, removedPayload
local onDropped = function(p) droppedPayload = p end
local onRemoved = function(p) removedPayload = p end
local ed = EventDispatcher.getInstance()
ed:subscribe("OnBeaconDropped", onDropped)
ed:subscribe("OnBeaconRemoved", onRemoved)

-- Track spawned beacon group names for guaranteed teardown.
local spawnedGroups = {}
local function trackBeacon(b)
    if not b then return end
    spawnedGroups[#spawnedGroups + 1] = b.vhfGroupName
    spawnedGroups[#spawnedGroups + 1] = b.uhfGroupName
    spawnedGroups[#spawnedGroups + 1] = b.fmGroupName
end

-- ── Cleanup (always runs) ────────────────────────────────────────────────────
local function cleanup()
    ed:unsubscribe("OnBeaconDropped", onDropped)
    ed:unsubscribe("OnBeaconRemoved", onRemoved)
    -- Destroy any beacon group still on the map and purge the manager registry.
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
    cfg.settings["debug"]                  = _savedDebug
    cfg.settings["debugScreenLog"]         = _savedDebugScreenLog
    cfg.settings["enabledRadioBeaconDrop"] = _savedEnabled
    cfg.settings["deployedBeaconBattery"]  = _savedBattery
end

-- ── Test body (pcall — any crash still reaches cleanup) ──────────────────────
local _ok, _err = pcall(function()

    -- ==== F-006 : dropBeacon (non-FOB) ======================================
    droppedPayload = nil
    local b1 = bm:dropBeacon(mockTransport, "TestPilot", false)
    trackBeacon(b1)
    check("F-006.0", b1 ~= nil, "dropBeacon returned a beacon (non-FOB)")
    if b1 then
        check("F-006.1", type(b1.vhf) == "number" and b1.vhf > 0, "vhf assigned > 0 | got=" .. tostring(b1.vhf))
        check("F-006.2", type(b1.uhf) == "number" and b1.uhf > 0, "uhf assigned > 0 | got=" .. tostring(b1.uhf))
        check("F-006.3", type(b1.fm)  == "number" and b1.fm  > 0, "fm assigned > 0 | got="  .. tostring(b1.fm))
        check("F-006.4", b1.batteryEndTime ~= -1, "temporary battery (batteryEndTime != -1) | got=" .. tostring(b1.batteryEndTime))
        check("F-006.5", b1:isBatteryAlive() == true, "battery alive right after drop")
        local alive1 = b1:countAliveUnits()
        check("F-006.6", alive1 == 3, "3 DCS beacon units spawned | expected=3 got=" .. tostring(alive1))
    end
    check("F-006.7", droppedPayload ~= nil, "OnBeaconDropped published")
    if droppedPayload then
        check("F-006.8", droppedPayload.player == "TestPilot",
            "payload.player == 'TestPilot' | got=" .. tostring(droppedPayload.player))
        check("F-006.9", droppedPayload.beacon ~= nil, "payload.beacon present")
        check("F-006.10", droppedPayload.beacon ~= nil and droppedPayload.beacon.frequencies ~= nil,
            "payload.beacon.frequencies present")
        check("F-006.11", droppedPayload.coalition == coalition.side.BLUE,
            "payload.coalition == BLUE | got=" .. tostring(droppedPayload.coalition))
    end

    -- ==== F-007 : removeClosestBeacon (< 500 m) =============================
    removedPayload = nil
    local countBefore = 0
    for _ in pairs(bm._beacons) do countBefore = countBefore + 1 end
    check("F-007.0", b1 ~= nil and countBefore >= 1, "at least 1 beacon present before remove | count=" .. tostring(countBefore))

    if b1 then
        bm:removeClosestBeacon(mockTransport, "TestPilot")
        local countAfter = 0
        for _ in pairs(bm._beacons) do countAfter = countAfter + 1 end
        check("F-007.1", countAfter == countBefore - 1,
            "beacon count decreased by 1 | before=" .. countBefore .. " after=" .. countAfter)
        check("F-007.2", bm._beacons[b1.beaconName] == nil, "removed beacon absent from _beacons registry")
        check("F-007.3", removedPayload ~= nil, "OnBeaconRemoved published")
        if removedPayload then
            check("F-007.4", removedPayload.reason == "manual",
                "payload.reason == 'manual' | got=" .. tostring(removedPayload.reason))
            check("F-007.5", removedPayload.player == "TestPilot",
                "payload.player == 'TestPilot' | got=" .. tostring(removedPayload.player))
            check("F-007.6", removedPayload.beacon ~= nil, "payload.beacon present")
            check("F-007.7", removedPayload.frequenciesFreed ~= nil, "payload.frequenciesFreed present")
        end
    end

    -- ==== F-092 : FOB beacon at centroid (overridePosition, isFOB) ==========
    droppedPayload = nil
    -- Centroid = 100 m devant l'ancre (heading 0 sur le mock → +X).
    local centroid = {
        x = anchor.x + 100,
        z = anchor.z,
        y = land.getHeight({ x = anchor.x + 100, y = anchor.z }),
    }
    local b2 = bm:dropBeacon(mockTransport, "TestPilot", true, centroid)
    trackBeacon(b2)
    check("F-092.0", b2 ~= nil, "dropBeacon returned a beacon (FOB, overridePosition)")
    if b2 then
        local dx = math.abs(b2.position.x - centroid.x)
        local dz = math.abs(b2.position.z - centroid.z)
        check("F-092.1", dx < 1 and dz < 1,
            string.format("beacon spawned at centroid (not under aircraft) | dx=%.2f dz=%.2f", dx, dz))
        check("F-092.2", type(b2.vhf) == "number" and b2.vhf > 0, "vhf assigned > 0")
        check("F-092.3", type(b2.uhf) == "number" and b2.uhf > 0, "uhf assigned > 0")
        check("F-092.4", type(b2.fm)  == "number" and b2.fm  > 0, "fm assigned > 0")
        check("F-092.5", b2.batteryEndTime == -1,
            "infinite battery (FOB → batteryEndTime == -1) | got=" .. tostring(b2.batteryEndTime))
        check("F-092.6", b2.isFOB == true, "beacon.isFOB == true")
        local alive2 = b2:countAliveUnits()
        check("F-092.7", alive2 == 3, "3 DCS beacon groups spawned for FOB | expected=3 got=" .. tostring(alive2))
    end
    check("F-092.8", droppedPayload ~= nil, "OnBeaconDropped published for FOB beacon")
    if droppedPayload then
        check("F-092.9", droppedPayload.player == "TestPilot",
            "payload.player == 'TestPilot' | got=" .. tostring(droppedPayload.player))
    end

end)

-- ── Result + cleanup ─────────────────────────────────────────────────────────
pcall(cleanup)
_SCN_BCN_RUNNING = false
local _ms = math.floor((os.clock() - _t0) * 1000)

if not _ok then
    _SCN_BCN_RESULT = TAG .. " FAIL: crash — " .. tostring(_err)
    trigger.action.outText(_SCN_BCN_RESULT, 60, true)
    ctld.utils.log("ERROR", _SCN_BCN_RESULT)
    return _SCN_BCN_RESULT
end

local total = passed + failed
if failed == 0 then
    _SCN_BCN_RESULT = TAG .. " PASS " .. passed .. "/" .. total .. " (" .. _ms .. "ms)"
else
    _SCN_BCN_RESULT = TAG .. " FAIL " .. failed .. "/" .. total .. ": " .. table.concat(failReasons, "; ")
end
trigger.action.outText(_SCN_BCN_RESULT, 30, true)
ctld.utils.log("INFO", _SCN_BCN_RESULT)
return _SCN_BCN_RESULT

end  -- do isolation scope
return _SCN_BCN_RESULT
