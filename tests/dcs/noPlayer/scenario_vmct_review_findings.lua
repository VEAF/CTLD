---@diagnostic disable
-- @tier: auto-check
-- =============================================================================
-- VRF — FIX-VMCT-REVIEW-FINDINGS live check (ticket 06).
--
--   1. #322 parachute : a blue Standard Group and a blue Mortar Squad parachuted from a mock transport land
--                       with their template's types, in order (not "Soldier AK"); the mortars keep their servants.
--   2. #324 repair    : "HAWK Repair" requested through the real Request Equipment menu callback, in a
--                       temporary logistic zone, brings its crate out (no "Request failed").
--   3. #325 AA names  : two HAWK systems spawned in the same second both exist, under two group names.
--
-- The transport is a MOCK 3 km from the first BLUE player, so nothing is created next to a live aircraft.
-- Everything created is cleaned up at the end (groups, crates, the temporary zone, the mock's menu).
--
-- Result: _SCN_VRF_RESULT  ("[VRF] PASS n/n" | "[VRF] FAIL ..." | "[VRF] ABORT ...")
-- =============================================================================

if not ctld or not ctld.utils then
    _SCN_VRF_RESULT = "[VRF] ABORT: CTLD not initialized"
    return _SCN_VRF_RESULT
end
if _SCN_VRF_RUNNING then return _SCN_VRF_RESULT or "[VRF] RUNNING" end
_SCN_VRF_RUNNING = true
_SCN_VRF_RESULT  = "[VRF] STARTED"

do
local TAG      = "[VRF]"
local MOCK     = "VRF_mock_transport"
local GROUP_ID = 9999998
local BLUE     = coalition.side.BLUE
local LGZ      = "VRF_temp_logistics"
local passed, failed, reasons = 0, 0, {}

local function log(fmt, ...) ctld.utils.log("INFO", "%s " .. fmt, TAG, ...) end
local function check(id, ok, msg)
    if ok then passed = passed + 1; log("PASS %s", id)
    else failed = failed + 1; reasons[#reasons + 1] = id .. ": " .. msg; log("FAIL %s — %s", id, msg) end
end

local cm  = CTLDCrateManager.getInstance()
local tm  = CTLDTroopManager.getInstance()
local aam = CTLDCrateAssemblyManager.getInstance()
local zm  = CTLDZoneManager.getInstance()
local ed  = EventDispatcher.getInstance()

local player = coalition.getPlayers(BLUE)[1]
if not player then
    _SCN_VRF_RUNNING = false
    _SCN_VRF_RESULT  = "[VRF] ABORT: no BLUE player"
    return _SCN_VRF_RESULT
end

-- Site: 3 km from the player. The mock flies 250 m above it for the parachute, then lands for the request.
local pp = player:getPoint()
local S  = { x = pp.x, z = pp.z + 3000 }
S.y = land.getHeight({ x = S.x, y = S.z })
local pt = { x = S.x, y = S.y + 250, z = S.z }
local airborne = true

local mock = {
    getName       = function() return MOCK end,
    isExist       = function() return true end,
    getCoalition  = function() return BLUE end,
    getCountry    = function() return country.id.USA end,
    getTypeName   = function() return "UH-1H" end,
    getPlayerName = function() return nil end,
    getPoint      = function() return pt end,
    getVelocity   = function() return { x = 0, y = 0, z = 0 } end,
    getGroup      = function() return { getID = function() return GROUP_ID end, getName = function() return "VRF_mock_group" end } end,
    inAir         = function() return airborne end,
    getDesc       = function() return { box = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } } } end,
    getPosition   = function()
        return { p = pt, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
    end,
}
local origGetByName = Unit.getByName
Unit.getByName = function(n) if n == MOCK then return mock end return origGetByName(n) end
local origInAir = ctld.utils.inAir
ctld.utils.inAir = function(u) if u == mock then return airborne end return origInAir(u) end

local landed, subs = {}, {}
local function onLanded(p) landed[#landed + 1] = p end
ed:subscribe("OnTroopsParachuteLanded", onLanded)
subs[#subs + 1] = { name = "OnTroopsParachuteLanded", cb = onLanded }

local aaGroups = {}

local function finish()
    for _, s in ipairs(subs) do ed:unsubscribe(s.name, s.cb) end
    for _, c in pairs(cm.crates) do
        if c.spawnedBy == MOCK or (c.position and math.abs(c.position.x - S.x) < 600 and math.abs(c.position.z - S.z) < 600) then
            cm:destroyCrate(c.crateName)
        end
    end
    for _, g in ipairs(coalition.getGroups(BLUE, Group.Category.GROUND) or {}) do
        local u = g:getUnit(1)
        if u then
            local p = u:getPoint()
            if math.abs(p.x - S.x) < 600 and math.abs(p.z - S.z) < 600 then
                aam._completeSystems[g:getName()] = nil
                g:destroy()
            end
        end
    end
    for _, n in ipairs(aaGroups) do aam._completeSystems[n] = nil end
    zm._logisticZones[LGZ] = nil
    pcall(function() ctld.MenuManager:getInstance():teardownGroup(GROUP_ID) end)
    tm._inTransit[MOCK] = nil
    Unit.getByName  = origGetByName
    ctld.utils.inAir = origInAir
    _SCN_VRF_RUNNING = false
    if failed == 0 then
        _SCN_VRF_RESULT = string.format("%s PASS %d/%d", TAG, passed, passed)
    else
        _SCN_VRF_RESULT = string.format("%s FAIL %d/%d: %s", TAG, failed, passed + failed, table.concat(reasons, " | "))
    end
    trigger.action.outText(_SCN_VRF_RESULT, 15)
    log("%s", _SCN_VRF_RESULT)
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

-- ── helpers ──────────────────────────────────────────────────────────────────
local function template(name)
    for _, t in ipairs(tm._templates or {}) do if t.name == name then return t end end
end

local function expectedTypes(tmpl)
    local out = {}
    for _, u in ipairs(CTLDObjectRegistry._db[tmpl._dbKey].units) do
        out[#out + 1] = type(u.unitType) == "function" and u.unitType(BLUE) or u.unitType
    end
    return out
end

local function load(tmpl)
    local troopGroup = CTLDTroopGroup:new({
        templateKey = tmpl._dbKey, templateName = tmpl.name, unitTotal = tmpl.total,
        weight = 100 * tmpl.total, coalitionId = BLUE, countryId = country.id.USA,
        state = CTLDTroopGroup.STATE.TRZ_LOADED, _aliveUnits = {}, _jtacUnits = {},
        specificParams = tmpl.specificParams or {},
    })
    tm._inTransit[MOCK] = tm._inTransit[MOCK] or {}
    table.insert(tm._inTransit[MOCK], troopGroup)
end

local function spawnedTypes(groupName)
    local g = Group.getByName(groupName)
    if not g then return nil end
    local out = {}
    for _, u in ipairs(g:getUnits() or {}) do out[#out + 1] = u:getTypeName() end
    return out
end

local function sameList(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

-- ── 1. #322 parachute ────────────────────────────────────────────────────────
local std, mortar = template("Standard Group"), template("Mortar Squad")
check("1.0 templates found", std ~= nil and mortar ~= nil, "Standard Group / Mortar Squad not in the templates")
local wantStd, wantMortar = expectedTypes(std), expectedTypes(mortar)
log("expected Standard Group: %s", table.concat(wantStd, ", "))
log("expected Mortar Squad: %s", table.concat(wantMortar, ", "))
load(std)
load(mortar)
local playerObj = { unitName = MOCK, groupId = GROUP_ID, groupName = "VRF_mock_group", coalition = BLUE }
tm:parachuteTroops(mock, playerObj)
tm:parachuteTroops(mock, playerObj)

local waited = 0
local function afterLanding()
    if #landed < 2 and waited < 120 then
        waited = waited + 5
        step(afterLanding, 5)
        return
    end
    check("1.1 both groups landed", #landed == 2, #landed .. " landing(s) after " .. waited .. " s")
    for _, p in ipairs(landed) do
        local gname = p.spawnedGroup and p.spawnedGroup:getName()
        local got = gname and spawnedTypes(gname)
        local want = p.troops.templateName == "Standard Group" and wantStd or wantMortar
        log("landed %s (%s): %s", tostring(p.troops.templateName), tostring(gname), got and table.concat(got, ", ") or "nil")
        check("1.2 " .. p.troops.templateName .. " lands with its template's types", sameList(want, got),
              "got " .. (got and table.concat(got, ", ") or "nil"))
    end

    -- ── 2. #324 HAWK Repair through the real menu callback ──────────────────
    airborne = false
    pt = { x = S.x, y = S.y, z = S.z }
    zm._logisticZones[LGZ] = CTLDLogisticZone:new({
        name = LGZ, coalition = BLUE, center = { x = S.x, y = S.y, z = S.z }, radius = 300, active = true,
    })
    CTLDPlayerManager.getInstance():buildMenu({
        unitName = MOCK, groupId = GROUP_ID, groupName = "VRF_mock_group", coalition = BLUE,
        typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
    })
    local menu = ctld.MenuManager:getInstance():getMenuByGroupId(GROUP_ID)
    local function find(node)
        if node.type == "command" then
            local a = node.anyArgument
            if type(a) == "table" and type(a.desc) == "string" and a.desc:find("HAWK Repair", 1, true) == 1
               and a.zoneName == LGZ then return node end
            return nil
        end
        for _, c in ipairs(node.children or {}) do local f = find(c); if f then return f end end
    end
    local root = menu and menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Request Equipment") })
    local cmd = root and find(root)
    check("2.0 Request Equipment lists HAWK Repair in the temporary zone", cmd ~= nil, "no such menu entry")
    if cmd then
        local before = {}
        for n in pairs(cm.crates) do before[n] = true end
        cmd.functionToCall(cmd.anyArgument)
        local newCrate
        for n, c in pairs(cm.crates) do if not before[n] then newCrate = c end end
        check("2.1 a HAWK Repair crate was brought out", newCrate ~= nil and newCrate.descriptor
              and newCrate.descriptor._repairFor == "HAWK AA System",
              "new crate: " .. tostring(newCrate and newCrate.descriptor and newCrate.descriptor.desc))
        step(function()
            local s = newCrate and StaticObject.getByName(newCrate.crateName)
            check("2.2 the crate is a DCS static", s ~= nil and s:isExist(), "no DCS static for the crate")

            -- ── 3. #325 two HAWKs in the same second ─────────────────────────
            local before3 = {}
            for n in pairs(aam._completeSystems) do before3[n] = true end
            local t0 = timer.getAbsTime()
            local ok1 = aam:spawnSystemAt("HAWK AA System", { x = S.x + 150, y = S.y, z = S.z + 150 }, BLUE, country.id.USA)
            local ok2 = aam:spawnSystemAt("HAWK AA System", { x = S.x - 150, y = S.y, z = S.z - 150 }, BLUE, country.id.USA)
            check("3.0 both spawns accepted in the same second", ok1 and ok2 and math.floor(timer.getAbsTime()) == math.floor(t0),
                  "ok1=" .. tostring(ok1) .. " ok2=" .. tostring(ok2))
            for n in pairs(aam._completeSystems) do if not before3[n] then aaGroups[#aaGroups + 1] = n end end
            log("AA groups: %s", table.concat(aaGroups, ", "))
            step(function()
                check("3.1 two distinct group names", #aaGroups == 2 and aaGroups[1] ~= aaGroups[2],
                      #aaGroups .. " new system(s)")
                local alive = 0
                for _, n in ipairs(aaGroups) do
                    local g = Group.getByName(n)
                    if g and g:isExist() and #(g:getUnits() or {}) > 0 then alive = alive + 1 end
                end
                check("3.2 both systems exist in the world", alive == 2, alive .. " of 2 alive")
                finish()
            end)
        end)
    else
        finish()
    end
end
step(afterLanding, 5)

return _SCN_VRF_RESULT
end
