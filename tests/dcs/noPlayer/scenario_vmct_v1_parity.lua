---@diagnostic disable
-- @tier: auto-check
-- =============================================================================
-- VPY — FEAT-VMCT-V1-PARITY live check (issues #327, #328).
--
--   1. Vehicle crate unpack (parachute auto-unpack branch): the vehicle group is created with
--      playerCanDrive = true (spawnedUnitsPlayerCanDrive default), and OnCrateUnpacked names that group.
--   2. AA assembly (KUB): the units are created with playerCanDrive = true, and OnAASystemDeployed names
--      the two consumed crates and the group.
--   3. AA rearm and 4. AA repair: OnAASystemRearmed / OnAASystemRepaired name the consumed crate.
--
-- DCS exposes no getter for playerCanDrive, so the scenario records what CTLD hands to coalition.addGroup
-- (a wrapper around the real function, removed at the end) and checks that DCS created the group.
-- The transport is a MOCK 3 km from the first BLUE player. Everything created is cleaned up at the end.
--
-- Result: _SCN_VPY_RESULT  ("[VPY] PASS n/n" | "[VPY] FAIL ..." | "[VPY] ABORT ...")
-- =============================================================================

if not ctld or not ctld.utils or not ctld.utils.spawnedUnitsPlayerCanDrive then
    _SCN_VPY_RESULT = "[VPY] ABORT: CTLD not initialized, or built without FEAT-VMCT-V1-PARITY"
    return _SCN_VPY_RESULT
end
if _SCN_VPY_RUNNING then return _SCN_VPY_RESULT or "[VPY] RUNNING" end
_SCN_VPY_RUNNING = true
_SCN_VPY_RESULT  = "[VPY] STARTED"

do
local TAG       = "[VPY]"
local MOCK      = "VPY_mock_transport"
local GROUP_ID  = 9999998
local BLUE      = coalition.side.BLUE
local VEH_TYPE  = "M1043 HMMWV Armament"
local passed, failed, reasons = 0, 0, {}

local function log(fmt, ...) ctld.utils.log("INFO", "%s " .. fmt, TAG, ...) end
local function check(id, ok, msg)
    if ok then passed = passed + 1; log("PASS %s", id)
    else failed = failed + 1; reasons[#reasons + 1] = id .. ": " .. msg; log("FAIL %s — %s", id, msg) end
end

local cm  = CTLDCrateManager.getInstance()
local aam = CTLDCrateAssemblyManager.getInstance()
local ed  = EventDispatcher.getInstance()

local player = coalition.getPlayers(BLUE)[1]
if not player then
    _SCN_VPY_RUNNING = false
    _SCN_VPY_RESULT  = "[VPY] ABORT: no BLUE player"
    return _SCN_VPY_RESULT
end

check("0.1 spawnedUnitsPlayerCanDrive is true by default", ctld.gs("spawnedUnitsPlayerCanDrive") == true,
      "setting=" .. tostring(ctld.gs("spawnedUnitsPlayerCanDrive")))

local pp = player:getPoint()
local S  = { x = pp.x, z = pp.z + 3000 }
S.y = land.getHeight({ x = S.x, y = S.z })
local pt = { x = S.x, y = S.y + 1, z = S.z }

local mock = {
    getName      = function() return MOCK end,
    isExist      = function() return true end,
    getCoalition = function() return BLUE end,
    getCountry   = function() return country.id.USA end,
    getTypeName  = function() return "UH-1H" end,
    getPoint     = function() return pt end,
    getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
    getGroup     = function() return { getID = function() return GROUP_ID end, getName = function() return "VPY_mock_group" end } end,
    inAir        = function() return false end,
    getDesc      = function() return { box = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } } } end,
    getPosition  = function()
        return { p = pt, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
    end,
}
local origGetByName = Unit.getByName
Unit.getByName = function(n) if n == MOCK then return mock end return origGetByName(n) end

-- Record what CTLD hands to DCS: group name -> list of playerCanDrive values of its units.
local handed = {}
local origAddGroup = coalition.addGroup
coalition.addGroup = function(cId, cat, data)
    local v = {}
    for i, u in ipairs(data.units or {}) do v[i] = u.playerCanDrive end
    handed[data.name] = v
    return origAddGroup(cId, cat, data)
end

local function allTrue(name)
    local v = handed[name]
    if not v or #v == 0 then return false, "nothing handed to coalition.addGroup for " .. tostring(name) end
    for i, b in ipairs(v) do if b ~= true then return false, "unit " .. i .. " playerCanDrive=" .. tostring(b) end end
    return true, ""
end

local function spawnPartCrate(desc, dx, dz)
    local pos = { x = S.x + dx, y = land.getHeight({ x = S.x + dx, y = S.z + dz }), z = S.z + dz }
    return cm:spawnCrate(desc, pos, BLUE, MOCK, CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, country.id.USA)
end

local function repairDescriptor(templateName)
    for _, d in pairs(cm._weightIndex or {}) do
        if d._repairFor == templateName then return d end
    end
end

local function sameSet(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    local seen = {}
    for _, x in ipairs(a) do seen[x] = (seen[x] or 0) + 1 end
    for _, x in ipairs(b) do
        if not seen[x] or seen[x] == 0 then return false end
        seen[x] = seen[x] - 1
    end
    return true
end

local events, subs = {}, {}
local function listen(name)
    events[name] = {}
    local cb = function(p) events[name][#events[name] + 1] = p end
    ed:subscribe(name, cb)
    subs[#subs + 1] = { name = name, cb = cb }
end
for _, n in ipairs({ "OnCrateUnpacked", "OnAASystemDeployed", "OnAASystemRearmed", "OnAASystemRepaired" }) do listen(n) end

local function finish()
    coalition.addGroup = origAddGroup
    for _, s in ipairs(subs) do ed:unsubscribe(s.name, s.cb) end
    for _, c in pairs(cm.crates) do
        if c.spawnedBy == MOCK or (c.position and math.abs(c.position.x - S.x) < 400 and math.abs(c.position.z - S.z) < 400) then
            cm:destroyCrate(c.crateName)
        end
    end
    for _, g in ipairs(coalition.getGroups(BLUE, Group.Category.GROUND) or {}) do
        local u = g:getUnit(1)
        if u then
            local p = u:getPoint()
            if math.abs(p.x - S.x) < 400 and math.abs(p.z - S.z) < 400 then
                aam._completeSystems[g:getName()] = nil
                CTLDVehicleSpawner.getInstance()._vehicles[g:getName()] = nil
                g:destroy()
            end
        end
    end
    Unit.getByName = origGetByName
    _SCN_VPY_RUNNING = false
    if failed == 0 then
        _SCN_VPY_RESULT = string.format("%s PASS %d/%d", TAG, passed, passed)
    else
        _SCN_VPY_RESULT = string.format("%s FAIL %d/%d: %s", TAG, failed, passed + failed, table.concat(reasons, " | "))
    end
    trigger.action.outText(_SCN_VPY_RESULT, 15)
    log("%s", _SCN_VPY_RESULT)
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

local ok, err = pcall(function()
    -- ── 1. Vehicle crate unpack (parachute auto-unpack) ──────────────────────
    local desc = cm:findDescriptorByUnitType(VEH_TYPE)
    local required = desc and desc.cratesRequired or 1
    local crates, names = {}, {}
    for i = 1, required do
        local c = spawnPartCrate(desc, 40 + 3 * i, -40)
        if c then
            c.position.y = c.position.y or land.getHeight({ x = c.position.x, y = c.position.z })
            c.fromParachute = true
            crates[#crates + 1] = c
            names[#names + 1] = c.crateName
        end
    end
    check("1.0 vehicle crates created", #crates == required, #crates .. " of " .. required)
    cm:_checkAutoUnpack(crates[#crates])
    local up = events.OnCrateUnpacked
    check("1.1 OnCrateUnpacked once per crate", #up == required, "published " .. #up .. ", expected " .. required)
    local gname = up[1] and up[1].groupName
    local sameGroup = gname ~= nil
    for _, p in ipairs(up) do sameGroup = sameGroup and p.groupName == gname end
    check("1.2 every OnCrateUnpacked names the same group", sameGroup, "groupName=" .. tostring(gname))
    check("1.3 that group exists in DCS", gname ~= nil and Group.getByName(gname) ~= nil, "no DCS group " .. tostring(gname))
    local drv, why = allTrue(gname)
    check("1.4 vehicle created with playerCanDrive = true", drv, why)

    -- ── 2. AA assembly (KUB) ─────────────────────────────────────────────────
    local tmpl = aam:getTemplateByName("KUB AA System")
    local launcher, radar
    for _, p in ipairs(tmpl.parts) do if p.launcher then launcher = p.DCSTypename else radar = p.DCSTypename end end
    local cLn = spawnPartCrate(cm:findDescriptorByUnitType(launcher), 100, 10)
    local cSr = spawnPartCrate(cm:findDescriptorByUnitType(radar), 100, -10)
    check("2.0 KUB part crates created", cLn ~= nil and cSr ~= nil, "a KUB part crate was not created")
    aam:tryUnpackOrRepair(mock, cLn, cm.crates, 500)
    local dep = events.OnAASystemDeployed[1]
    check("2.1 OnAASystemDeployed published", dep ~= nil, "not published")
    check("2.2 crateNames = the two consumed crates", dep ~= nil and sameSet(dep.crateNames, { cLn.crateName, cSr.crateName }),
          "crateNames=" .. (dep and type(dep.crateNames) == "table" and table.concat(dep.crateNames, ",") or tostring(dep and dep.crateNames)))
    check("2.3 groupName exists in DCS", dep ~= nil and Group.getByName(dep.groupName) ~= nil, "no DCS group")
    drv, why = allTrue(dep and dep.groupName)
    check("2.4 AA units created with playerCanDrive = true", drv, why)

    step(function()
        -- ── 3. AA rearm ──────────────────────────────────────────────────────
        local cl2 = spawnPartCrate(cm:findDescriptorByUnitType(launcher), 100, 50)
        aam:tryUnpackOrRepair(mock, cl2, cm.crates, 500)
        local re = events.OnAASystemRearmed[1]
        check("3.1 OnAASystemRearmed names the launcher crate", re ~= nil and sameSet(re.crateNames, { cl2.crateName }),
              "payload=" .. tostring(re and re.crateNames))
        check("3.2 rearmed group exists in DCS", re ~= nil and Group.getByName(re.groupName) ~= nil, "no DCS group")

        step(function()
            -- ── 4. AA repair ─────────────────────────────────────────────────
            local rc = spawnPartCrate(repairDescriptor("KUB AA System"), 100, 30)
            aam:tryUnpackOrRepair(mock, rc, cm.crates, 500)
            local rp = events.OnAASystemRepaired[1]
            check("4.1 OnAASystemRepaired names the repair crate", rp ~= nil and sameSet(rp.crateNames, { rc.crateName }),
                  "payload=" .. tostring(rp and rp.crateNames))
            check("4.2 repaired group exists in DCS", rp ~= nil and Group.getByName(rp.groupName) ~= nil, "no DCS group")
            step(finish)
        end)
    end)
end)
if not ok then
    failed = failed + 1
    reasons[#reasons + 1] = "error: " .. tostring(err)
    finish()
end

return _SCN_VPY_RESULT
end
