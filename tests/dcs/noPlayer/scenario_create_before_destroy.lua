---@diagnostic disable
-- @tier: auto-check
-- =============================================================================
-- CBD — FIX-CREATE-BEFORE-DESTROY (ADR 0028) live check, success path of each site.
--
-- DCS cannot be made to refuse a creation without tampering, so this checks that the new order
-- (create first, destroy the original once it exists) still does the whole job in a running mission:
--   1. Pack Vehicle      : the Humvee goes, its 3 crates exist, OnVehiclePacked carries 3.
--   2. Unpack (parachute): the 3 crates are consumed once the vehicle exists.
--   3. AA assembly       : a KUB system is built, its crates are consumed.
--   4. AA repair         : the new group exists, the damaged one and the repair crate go (the new group is
--                          spawned over the old one: DCS must accept it).
--   5. AA rearm          : same for a launcher crate.
--
-- The transport is a MOCK 3 km from the first BLUE player, so no crate is ever created next to a live
-- aircraft. Everything created is cleaned up at the end.
--
-- Result: _SCN_CBD_RESULT  ("[CBD] PASS n/n" | "[CBD] FAIL ..." | "[CBD] ABORT ...")
-- =============================================================================

if not ctld or not ctld.utils then
    _SCN_CBD_RESULT = "[CBD] ABORT: CTLD not initialized"
    return _SCN_CBD_RESULT
end
if _SCN_CBD_RUNNING then return _SCN_CBD_RESULT or "[CBD] RUNNING" end
_SCN_CBD_RUNNING = true
_SCN_CBD_RESULT  = "[CBD] STARTED"

do
local TAG       = "[CBD]"
local MOCK      = "CBD_mock_transport"
local GROUP_ID  = 9999999
local BLUE      = coalition.side.BLUE
local VEH_TYPE  = "M1043 HMMWV Armament"
local passed, failed, reasons = 0, 0, {}

local function log(fmt, ...) ctld.utils.log("INFO", "%s " .. fmt, TAG, ...) end
local function check(id, ok, msg)
    if ok then passed = passed + 1; log("PASS %s", id)
    else failed = failed + 1; reasons[#reasons + 1] = id .. ": " .. msg; log("FAIL %s — %s", id, msg) end
end

local cm  = CTLDCrateManager.getInstance()
local vs  = CTLDVehicleSpawner.getInstance()
local aam = CTLDCrateAssemblyManager.getInstance()
local ed  = EventDispatcher.getInstance()

local player = coalition.getPlayers(BLUE)[1]
if not player then
    _SCN_CBD_RUNNING = false
    _SCN_CBD_RESULT  = "[CBD] ABORT: no BLUE player"
    return _SCN_CBD_RESULT
end

-- Site: 3 km from the player; the mock transport faces +x.
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
    getGroup     = function() return { getID = function() return GROUP_ID end, getName = function() return "CBD_mock_group" end } end,
    inAir        = function() return false end,
    getDesc      = function() return { box = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } } } end,
    getPosition  = function()
        return { p = pt, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
    end,
}
local origGetByName = Unit.getByName
Unit.getByName = function(n) if n == MOCK then return mock end return origGetByName(n) end

-- ── helpers ──────────────────────────────────────────────────────────────────
local created = {}   -- group names this scenario made
local counter = 0
local function spawnGround(typeName, x, z)
    counter = counter + 1
    local gname, uname = "CBD_grp_" .. counter, "CBD_unit_" .. counter
    coalition.addGroup(country.id.USA, Group.Category.GROUND, {
        name = gname, task = "Ground Nothing", visible = false, hidden = false,
        units = { { type = typeName, name = uname, x = x, y = z, heading = 0, skill = "Average", playerCanDrive = false } },
    })
    created[#created + 1] = gname
    return gname, uname
end

local function cratesBy(spawner)
    local out = {}
    for _, c in pairs(cm.crates) do if c.spawnedBy == spawner then out[#out + 1] = c end end
    return out
end

local function staticExists(c) local s = StaticObject.getByName(c.crateName); return s ~= nil and s:isExist() end

local function unitExists(name) local u = Unit.getByName(name); return u ~= nil and u:isExist() end

local function descByUnit(unit) return cm:findDescriptorByUnitType(unit) end

local function aaDescriptor(unit)
    local d = descByUnit(unit)
    return d
end

local function repairDescriptor(templateName)
    for _, d in pairs(cm._weightIndex or {}) do
        if d._repairFor == templateName then return d end
    end
end

local function spawnPartCrate(desc, dx, dz)
    local pos = { x = S.x + dx, y = land.getHeight({ x = S.x + dx, y = S.z + dz }), z = S.z + dz }
    return cm:spawnCrate(desc, pos, BLUE, MOCK, CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, country.id.USA)
end

local events = {}
local subs = {}
local function listen(name)
    events[name] = {}
    local cb = function(p) events[name][#events[name] + 1] = p end
    ed:subscribe(name, cb)
    subs[#subs + 1] = { name = name, cb = cb }
end
for _, n in ipairs({ "OnVehiclePacked", "OnAASystemDeployed", "OnAASystemRepaired", "OnAASystemRearmed" }) do listen(n) end

local function finish()
    -- cleanup
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
            if math.abs(p.x - S.x) < 400 and math.abs(p.z - S.z) < 400 then g:destroy() end
        end
    end
    aam._completeSystems = {}
    Unit.getByName = origGetByName
    _SCN_CBD_RUNNING = false
    if failed == 0 then
        _SCN_CBD_RESULT = string.format("%s PASS %d/%d", TAG, passed, passed)
    else
        _SCN_CBD_RESULT = string.format("%s FAIL %d/%d: %s", TAG, failed, passed + failed, table.concat(reasons, " | "))
    end
    trigger.action.outText(_SCN_CBD_RESULT, 15)
    log("%s", _SCN_CBD_RESULT)
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

-- ── 1. Pack Vehicle ──────────────────────────────────────────────────────────
local vehGroup, vehUnit = spawnGround(VEH_TYPE, S.x + 40, S.z - 40)
check("1.0 vehicle spawned", unitExists(vehUnit), "the test Humvee was not created")
local desc = descByUnit(VEH_TYPE)
local required = desc and desc.cratesRequired or 1

vs:packVehicle(MOCK, vehUnit, { unitName = MOCK, groupId = GROUP_ID, coalition = BLUE })
local packed = events.OnVehiclePacked
check("1.1 OnVehiclePacked published once", #packed == 1, "published " .. #packed .. " time(s)")
check("1.2 cratesSpawned is the number created", packed[1] and packed[1].cratesSpawned == required,
      "cratesSpawned=" .. tostring(packed[1] and packed[1].cratesSpawned) .. " expected " .. required)
local packCrates = cratesBy(MOCK)
check("1.3 crates exist in the registry", #packCrates == required, #packCrates .. " crates, expected " .. required)

step(function()
    check("1.4 vehicle destroyed", not unitExists(vehUnit), "the Humvee is still there")
    local allStatic = #packCrates > 0
    for _, c in ipairs(packCrates) do allStatic = allStatic and staticExists(c) end
    check("1.5 every crate is a DCS static", allStatic, "a crate has no DCS static")

    -- ── 2. Unpack (parachute branch) ─────────────────────────────────────────
    local names = {}
    for _, c in ipairs(packCrates) do
        -- A parachuted crate lands with a full vec3; a packed crate's position is the 2D spawn point.
        c.position.y = c.position.y or land.getHeight({ x = c.position.x, y = c.position.z })
        c.fromParachute = true
        names[#names + 1] = c.crateName
    end
    local groupsBefore = #(coalition.getGroups(BLUE, Group.Category.GROUND) or {})
    cm:_checkAutoUnpack(packCrates[#packCrates])
    local consumed = true
    for _, n in ipairs(names) do consumed = consumed and cm.crates[n] == nil end
    check("2.1 crates consumed once the vehicle exists", consumed, "a crate is still registered after the unpack")
    local groupsAfter = #(coalition.getGroups(BLUE, Group.Category.GROUND) or {})
    check("2.2 a vehicle group was created", groupsAfter == groupsBefore + 1,
          "ground groups " .. groupsBefore .. " -> " .. groupsAfter)

    step(function()
        local gone = true
        for _, c in ipairs(packCrates) do gone = gone and not staticExists(c) end
        check("2.3 crate statics removed", gone, "a crate static is still in the world")

        -- ── 3. AA assembly ───────────────────────────────────────────────────
        local tmpl = aam:getTemplateByName("KUB AA System")
        local launcher, radar
        for _, p in ipairs(tmpl.parts) do if p.launcher then launcher = p.DCSTypename else radar = p.DCSTypename end end
        local cLn = spawnPartCrate(aaDescriptor(launcher), 100, 10)
        local cSr = spawnPartCrate(aaDescriptor(radar), 100, -10)
        check("3.0 AA part crates created", cLn ~= nil and cSr ~= nil, "a KUB part crate was not created")
        local before = aam:countComplete(BLUE)
        aam:tryUnpackOrRepair(mock, cLn, cm.crates, 500)
        check("3.1 OnAASystemDeployed published", #events.OnAASystemDeployed == 1, "published " .. #events.OnAASystemDeployed)
        check("3.2 system registered", aam:countComplete(BLUE) == before + 1, "complete systems " .. before .. " -> " .. aam:countComplete(BLUE))
        check("3.3 part crates consumed", cm.crates[cLn.crateName] == nil and cm.crates[cSr.crateName] == nil, "a part crate is still registered")
        local firstName = next(aam._completeSystems)

        step(function()
            check("3.4 system group exists", firstName ~= nil and Group.getByName(firstName) ~= nil, "no DCS group for the new system")

            -- ── 4. AA repair ─────────────────────────────────────────────────
            local rd = repairDescriptor("KUB AA System")
            check("4.0 repair descriptor found", rd ~= nil, "no KUB repair crate in the catalogue")
            local rc = spawnPartCrate(rd, 100, 30)
            local oldNames = {}
            for n in pairs(aam._completeSystems) do oldNames[n] = true end
            aam:tryUnpackOrRepair(mock, rc, cm.crates, 500)
            check("4.1 OnAASystemRepaired published", #events.OnAASystemRepaired == 1, "published " .. #events.OnAASystemRepaired)
            local newName
            for n in pairs(aam._completeSystems) do if not oldNames[n] then newName = n end end
            check("4.2 one system, the new group", newName ~= nil and aam:countComplete(BLUE) == 1,
                  "complete systems " .. aam:countComplete(BLUE) .. ", new group " .. tostring(newName))
            check("4.3 repair crate consumed", cm.crates[rc.crateName] == nil and rc.dcsStatic == nil,
                  "the repair crate is still registered (ghost crate)")

            step(function()
                local oldGone = true
                for n in pairs(oldNames) do if n ~= newName then oldGone = oldGone and (Group.getByName(n) == nil) end end
                check("4.4 damaged group destroyed", oldGone, "the old group is still in the world")
                check("4.5 new group alive", newName ~= nil and Group.getByName(newName) ~= nil, "the new group is not in the world")

                -- ── 5. AA rearm ──────────────────────────────────────────────
                local cl2 = spawnPartCrate(aaDescriptor(launcher), 100, 50)
                local before2 = {}
                for n in pairs(aam._completeSystems) do before2[n] = true end
                aam:tryUnpackOrRepair(mock, cl2, cm.crates, 500)
                check("5.1 OnAASystemRearmed published", #events.OnAASystemRearmed == 1, "published " .. #events.OnAASystemRearmed)
                check("5.2 launcher crate consumed", cm.crates[cl2.crateName] == nil and cl2.dcsStatic == nil,
                      "the launcher crate is still registered (ghost crate)")
                local rearmedName
                for n in pairs(aam._completeSystems) do if not before2[n] then rearmedName = n end end

                step(function()
                    check("5.3 rearmed system alive, still one", rearmedName ~= nil and Group.getByName(rearmedName) ~= nil
                          and aam:countComplete(BLUE) == 1, "rearmed group " .. tostring(rearmedName))
                    local old2Gone = true
                    for n in pairs(before2) do if n ~= rearmedName then old2Gone = old2Gone and (Group.getByName(n) == nil) end end
                    check("5.4 old group destroyed", old2Gone, "the pre-rearm group is still in the world")
                    finish()
                end)
            end)
        end)
    end)
end)

return _SCN_CBD_RESULT
end
