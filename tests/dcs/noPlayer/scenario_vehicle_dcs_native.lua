---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- AUTO — Vehicle dcs_native : loadVehicle / unloadVehicle (C-130 physique)
-- =============================================================================
-- Ré-intègre 2 reliques mortes qui exigent le VRAI moteur DCS (spawn réel d'un
-- véhicule au sol + récupération de l'unité vivante via Group.getByName après
-- load), impossibles à mocker en busted :
--
--   F-018 : loadVehicle(method="dcs_native") → état LOADED, event OnVehicleLoaded
--           avec method="dcs_native". En dcs_native l'unité DCS reste VIVANTE
--           (physiquement liée dans l'avion) — elle N'EST PAS détruite ni mise
--           à nil (cf. src l.455-460 : seul le reverse-lookup est purgé).
--   F-019 : unloadVehicle(method="dcs_native") au sol → l'unité est récupérée du
--           groupe toujours vivant, état WAITING (re-loadable), event
--           OnVehicleUnloaded avec method="dcs_native".
--
-- Le transport (C-130) est un mock (position/coalition/pays) ; la partie NON
-- mockable — spawnVehicleForTransport qui crée un vrai groupe GROUND, puis
-- Group.getByName au unload — passe par le vrai moteur. 100 % synchrone → `auto`.
--
-- NOTE de parité : la relique F-018 asserte `vehicle.unit == nil` après load —
-- c'est PÉRIMÉ. Le src courant garde l'unité vivante en dcs_native (l.456-460).
-- Ce scénario asserte donc `vehicle.unit ~= nil`.
--
-- Pré-requis mission : AUCUN (transport mocké, véhicule spawné par le scénario ;
-- ancre positionnelle dérivée d'une unité existante ou (0,0)).
--
-- Signatures vérifiées dans src/CTLD_vehicle.lua (2026-07-11) :
--   spawnVehicleForTransport(vehicleType, spawner, logisticZone) → CTLDVehicle WAITING  l.249
--   loadVehicle(vehicle, transport, player, method)  l.418  (WAITING → LOADED)
--     dcs_native : unité conservée vivante l.455-460 ; publish OnVehicleLoaded l.499
--   unloadVehicle(vehicle, transport, player, method, rearSector)  l.532  (LOADED → WAITING)
--     dcs_native : unit = Group.getByName(sd.groupName):getUnit(1) l.543-546 ;
--     publish OnVehicleUnloaded l.615
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[VEH] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_VEH_RESULT = "[VEH] ABORT: CTLD not initialized"
    return _SCN_VEH_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_VEH_RUNNING then
    trigger.action.outText("[VEH] already running — wait or restart DCS.", 10)
    return _SCN_VEH_RESULT or "[VEH] RUNNING"
end
_SCN_VEH_RUNNING = true
_SCN_VEH_RESULT  = "[VEH] STARTED"

do  -- isolation scope
local TAG = "[VEH]"
local _t0 = os.clock()

local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local passed, failed, failReasons = 0, 0, {}
local function pass(id, msg) passed = passed + 1; ctld.utils.log("INFO", "%s [PASS] %s: %s", TAG, id, msg or "") end
local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    ctld.utils.log("ERROR", "%s [FAIL] %s: %s", TAG, id, msg or "")
end
local function check(id, cond, detail) if cond then pass(id, detail) else fail(id, detail) end end

local vs          = CTLDVehicleSpawner.getInstance()
local VEHICLE_TYPE = "M1045 HMMWV TOW"

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

-- ── Mock transport (C-130, BLUE / USA) at the anchor ─────────────────────────
local mockTransport = {
    getName       = function() return "MOCK_VEH_C130" end,
    getTypeName   = function() return "Hercules" end,
    getCoalition  = function() return coalition.side.BLUE end,
    getCountry    = function() return country.id.USA end,
    getPoint      = function() return { x = anchor.x, y = anchor.y, z = anchor.z } end,
    getPosition   = function() return {
        p = { x = anchor.x, y = anchor.y, z = anchor.z },
        x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 },
    } end,
    getDesc       = function() return { box = { min = { x = -15, y = 0, z = -20 },
                                                max = { x = 15, y = 8, z = 20 } } } end,
    inAir         = function() return false end,
    isExist       = function() return true end,
}

-- ── Event capture (unsubscribed in cleanup) ──────────────────────────────────
local loadedPayload, unloadedPayload
local onLoaded   = function(p) loadedPayload = p end
local onUnloaded = function(p) unloadedPayload = p end
local ed = EventDispatcher.getInstance()
ed:subscribe("OnVehicleLoaded",   onLoaded)
ed:subscribe("OnVehicleUnloaded", onUnloaded)

-- Track spawned vehicle for guaranteed teardown.
local vehicle          -- assigned inside pcall, cleaned up below
local spawnedGroupName  -- DCS group name to destroy

-- ── Cleanup (always runs) ────────────────────────────────────────────────────
local function cleanup()
    ed:unsubscribe("OnVehicleLoaded",   onLoaded)
    ed:unsubscribe("OnVehicleUnloaded", onUnloaded)
    if spawnedGroupName then
        local g = Group.getByName(spawnedGroupName)
        if g then g:destroy() end
        vs._unitToVehicle[spawnedGroupName] = nil
    end
    if vehicle then
        vs._vehicles[vehicle.id] = nil
    end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
end

-- ── Test body (pcall — any crash still reaches cleanup) ──────────────────────
local _ok, _err = pcall(function()

    -- Spawn a real DCS ground vehicle near the (mock) transport.
    vehicle = vs:spawnVehicleForTransport(VEHICLE_TYPE, mockTransport, nil)
    if not vehicle then
        error("spawnVehicleForTransport returned nil — dynAdd failed (invalid spawn position?)")
    end
    spawnedGroupName = vehicle.spawnData and vehicle.spawnData.groupName

    check("SETUP.1", vehicle:getState() == CTLDVehicle.STATE.WAITING,
        "vehicle spawned in WAITING | got=" .. tostring(vehicle:getState()))
    check("SETUP.2", vehicle.unit ~= nil, "spawned DCS unit is live before load")

    -- ==== F-018 : loadVehicle dcs_native → LOADED + OnVehicleLoaded =========
    loadedPayload = nil
    vs:loadVehicle(vehicle, mockTransport, "TestPlayer", "dcs_native")

    check("F-018.1", vehicle:getState() == CTLDVehicle.STATE.LOADED,
        "state LOADED after dcs_native load | got=" .. tostring(vehicle:getState()))
    check("F-018.2", vehicle.unit ~= nil,
        "dcs_native keeps the unit alive (NOT destroyed) — parity note vs stale relic")
    check("F-018.3", vehicle.loadMethod == "dcs_native",
        "loadMethod == 'dcs_native' | got=" .. tostring(vehicle.loadMethod))
    check("F-018.4", vehicle.loadTransportName == "MOCK_VEH_C130",
        "loadTransportName recorded | got=" .. tostring(vehicle.loadTransportName))
    check("F-018.5", loadedPayload ~= nil, "OnVehicleLoaded published")
    if loadedPayload then
        check("F-018.6", loadedPayload.vehicleId == vehicle.id,
            "payload.vehicleId correct | expected=" .. tostring(vehicle.id) .. " got=" .. tostring(loadedPayload.vehicleId))
        check("F-018.7", loadedPayload.method == "dcs_native",
            "payload.method == 'dcs_native' | got=" .. tostring(loadedPayload.method))
        check("F-018.8", loadedPayload.transportUnitObject ~= nil, "payload.transportUnitObject present")
        check("F-018.9", loadedPayload.position ~= nil, "payload.position present")
        check("F-018.10", loadedPayload.timestamp ~= nil, "payload.timestamp present")
        check("F-018.11", loadedPayload.dcsUnitObject ~= nil,
            "payload.dcsUnitObject present (dcs_native → live unit)")
    end

    -- ==== F-019 : unloadVehicle dcs_native (au sol) → WAITING + OnVehicleUnloaded
    unloadedPayload = nil
    vs:unloadVehicle(vehicle, mockTransport, "TestPlayer", "dcs_native")

    check("F-019.1", vehicle:getState() == CTLDVehicle.STATE.WAITING,
        "state WAITING after dcs_native unload (re-loadable) | got=" .. tostring(vehicle:getState()))
    check("F-019.2", vehicle.unit ~= nil,
        "unit recovered from live group after unload")
    check("F-019.3", unloadedPayload ~= nil, "OnVehicleUnloaded published")
    if unloadedPayload then
        check("F-019.4", unloadedPayload.vehicleId == vehicle.id,
            "payload.vehicleId correct | expected=" .. tostring(vehicle.id) .. " got=" .. tostring(unloadedPayload.vehicleId))
        check("F-019.5", unloadedPayload.vehicleType == VEHICLE_TYPE,
            "payload.vehicleType correct | got=" .. tostring(unloadedPayload.vehicleType))
        check("F-019.6", unloadedPayload.method == "dcs_native",
            "payload.method == 'dcs_native' | got=" .. tostring(unloadedPayload.method))
        check("F-019.7", unloadedPayload.transportUnitObject ~= nil, "payload.transportUnitObject present")
        check("F-019.8", unloadedPayload.position ~= nil, "payload.position present")
        check("F-019.9", unloadedPayload.timestamp ~= nil, "payload.timestamp present")
    end

end)

-- ── Result + cleanup ─────────────────────────────────────────────────────────
pcall(cleanup)
_SCN_VEH_RUNNING = false
local _ms = math.floor((os.clock() - _t0) * 1000)

if not _ok then
    _SCN_VEH_RESULT = TAG .. " FAIL: crash — " .. tostring(_err)
    trigger.action.outText(_SCN_VEH_RESULT, 60, true)
    ctld.utils.log("ERROR", _SCN_VEH_RESULT)
    return _SCN_VEH_RESULT
end

local total = passed + failed
if failed == 0 then
    _SCN_VEH_RESULT = TAG .. " PASS " .. passed .. "/" .. total .. " (" .. _ms .. "ms)"
else
    _SCN_VEH_RESULT = TAG .. " FAIL " .. failed .. "/" .. total .. ": " .. table.concat(failReasons, "; ")
end
trigger.action.outText(_SCN_VEH_RESULT, 30, true)
ctld.utils.log("INFO", _SCN_VEH_RESULT)
return _SCN_VEH_RESULT

end  -- do isolation scope
return _SCN_VEH_RESULT
