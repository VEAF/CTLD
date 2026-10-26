---@diagnostic disable
-- @tier: ia (fly)  -- a player lands, opens the ground crew window and reads what it offers
-- =============================================================================
-- tests/dcs/pilotActive/scenario_fatcow_spike.lua
-- FEAT-FAT-COW ticket 01 — in-game spike, before any Fat Cow code is written.
--
-- Pure DCS API, no CTLD: it measures what DCS does, not what CTLD does.
-- Embedded in missions/Test_FatCow_Spike.miz (mission start trigger), or injected
-- over dcs-bridge in any mission with a player helicopter.
--
-- Questions (see .backlog/FEAT-FAT-COW/tickets/01-spike-runtime-farp.md):
--   (a) does a FARP spawned mid-mission refuel/rearm a player already in game?
--   (b) is a finite warehouse stock respected, and seen identically by the server
--       and by a client (rearm window)?
--   (c) does an Invisible FARP need a fuel/ammo vehicle in range?
--
-- Each player group gets an F10 menu "Fat Cow spike":
--   1. Invisible FARP under me       — spawns an Invisible FARP at the caller's position
--   2. Finite stock (300 kg, 2 HF)    — sets the FARP warehouse to a small known stock
--   3. Read stock + my aircraft       — prints the warehouse and the caller's fuel/ammo
--   4. Add fuel + ammo trucks          — spawns an M978 and an M 818 30 m from the FARP
--   5. Single pad FARP ahead (variant) — SINGLE_HELIPAD 40 m ahead, if 1 has no warehouse
--   6. Remove everything               — destroys what the spike spawned
--
-- Every result line goes to the screen (60 s) and to dcs.log, prefixed [FCSPIKE].
-- _SCN_FCSPIKE_RESULT holds the lines measured so far.
-- =============================================================================

if FCSPIKE and FCSPIKE.loaded then
    trigger.action.outText("[FCSPIKE] already loaded", 10)
    return _SCN_FCSPIKE_RESULT
end

FCSPIKE = { loaded = true }
local S = FCSPIKE

local TAG            = "[FCSPIKE]"
local MENU_NAME      = "Fat Cow spike"
local STOCK_FUEL_KG  = 300   -- below what a 30 % Apache takes to fill up, so a cap shows
local STOCK_HELLFIRE = 2
-- Warehouse item names tried for the Hellfire; the readout says which ones DCS accepts.
local HELLFIRE_ITEMS = {
    "weapons.missiles.AGM_114K",
    "weapons.missiles.AGM_114L",
    "weapons.missiles.AGM_114",
}
local LIQUID_NAMES = { [0] = "jet fuel", [1] = "avgas", [2] = "MW50", [3] = "diesel" }

S.objects  = {}     -- statics spawned (names)
S.groups   = {}     -- ground groups spawned (names)
S.farpName = nil
S.counter  = 0
S.lines    = {}
_SCN_FCSPIKE_RESULT = "[FCSPIKE] STARTED"

local function say(msg)
    local line = TAG .. " " .. msg
    trigger.action.outText(line, 60)
    env.info(line)
    S.lines[#S.lines + 1] = msg
    _SCN_FCSPIKE_RESULT = "[FCSPIKE] RUNNING: " .. table.concat(S.lines, " | ")
end

local function nextName(prefix)
    S.counter = S.counter + 1
    return "FCSPIKE_" .. prefix .. "_" .. S.counter
end

local function callerUnit(groupName)
    local g = Group.getByName(groupName)
    if not g then return nil end
    local u = g:getUnit(1)
    if u and u:isExist() then return u end
    return nil
end

local function headingOf(unit)
    local p = unit:getPosition()
    local h = math.atan2(p.x.z, p.x.x)
    if h < 0 then h = h + 2 * math.pi end
    return h
end

local function smoke(x, z)
    trigger.action.smoke({ x = x, y = land.getHeight({ x = x, y = z }), z = z }, trigger.smokeColor.Green)
end

-- -----------------------------------------------------------------------------
-- Readouts
-- -----------------------------------------------------------------------------

local function warehouseOf(farpName)
    if not farpName then return nil, "no FARP spawned yet (command 1 or 5 first)" end
    local ok, ab = pcall(Airbase.getByName, farpName)
    if not ok or not ab then return nil, "Airbase.getByName('" .. farpName .. "') = nil" end
    local okW, w = pcall(ab.getWarehouse, ab)
    if not okW then return nil, "getWarehouse() raised: " .. tostring(w) end
    if not w then return nil, "getWarehouse() = nil" end
    return w, nil
end

local function readWarehouse(label)
    local w, err = warehouseOf(S.farpName)
    if not w then
        say(label .. ": " .. err)
        return
    end
    local parts = {}
    for i = 0, 3 do
        local ok, v = pcall(w.getLiquidAmount, w, i)
        parts[#parts + 1] = LIQUID_NAMES[i] .. "=" .. (ok and tostring(v) or ("ERR " .. tostring(v)))
    end
    for _, item in ipairs(HELLFIRE_ITEMS) do
        local ok, v = pcall(w.getItemCount, w, item)
        parts[#parts + 1] = item:gsub("weapons.missiles.", "") .. "=" .. (ok and tostring(v) or "ERR")
    end
    local okI, inv = pcall(w.getInventory, w)
    if okI and inv then
        local nW, nA = 0, 0
        for _ in pairs(inv.weapon or {}) do nW = nW + 1 end
        for _ in pairs(inv.aircraft or {}) do nA = nA + 1 end
        parts[#parts + 1] = "inventory: " .. nW .. " weapon types, " .. nA .. " aircraft types"
    else
        parts[#parts + 1] = "getInventory() unavailable"
    end
    say(label .. " [" .. S.farpName .. "] " .. table.concat(parts, ", "))
end

local function readUnit(unit)
    local desc = unit:getDesc()
    local fuelKg = math.floor(unit:getFuel() * (desc.fuelMassMax or 0) + 0.5)
    local ammo = {}
    for _, a in ipairs(unit:getAmmo() or {}) do
        local tn = a.desc and a.desc.typeName or "?"
        ammo[#ammo + 1] = tn .. " x" .. tostring(a.count)
    end
    if #ammo == 0 then ammo[1] = "none" end
    say("AIRCRAFT " .. unit:getName() .. " (" .. desc.typeName .. "): fuel " .. fuelKg .. " kg / "
        .. tostring(desc.fuelMassMax) .. " kg, ammo: " .. table.concat(ammo, ", "))
end

-- -----------------------------------------------------------------------------
-- Commands
-- -----------------------------------------------------------------------------

local function spawnFarp(groupName, variant)
    local unit = callerUnit(groupName)
    if not unit then say("no unit for group " .. groupName) return end
    local p   = unit:getPoint()
    local hdg = headingOf(unit)
    local x, z = p.x, p.z
    local sd
    if variant == "single" then
        x = p.x + math.cos(hdg) * 40
        z = p.z + math.sin(hdg) * 40
        -- Same type and shape as CTLD's SINGLE_HELIPAD registry entry (farpAlphaScene).
        sd = { type = "SINGLE_HELIPAD", shape_name = "FARP", category = "Heliports" }
    else
        sd = { type = "Invisible FARP", shape_name = "invisiblefarp", category = "Heliports" }
    end
    sd.name                 = nextName(variant == "single" and "PAD" or "FARP")
    sd.x                    = x
    sd.y                    = z
    sd.heading              = hdg
    sd.dead                 = false
    sd.heliport_frequency   = "127.5"
    sd.heliport_callsign_id = 1
    sd.heliport_modulation  = 0
    local ok, obj = pcall(coalition.addStaticObject, unit:getCountry(), sd)
    if not ok or not obj then
        say("SPAWN " .. sd.type .. " FAILED: " .. tostring(obj))
        return
    end
    S.objects[#S.objects + 1] = sd.name
    S.farpName = sd.name
    smoke(x, z)
    say("SPAWNED " .. sd.type .. " '" .. sd.name .. "' at t=" .. math.floor(timer.getTime())
        .. " s (green smoke). No vehicle around it.")
    timer.scheduleFunction(function()
        readWarehouse("INITIAL STOCK (2 s after spawn)")
        return nil
    end, nil, timer.getTime() + 2)
end

local function setFiniteStock()
    local w, err = warehouseOf(S.farpName)
    if not w then say("SET STOCK: " .. err) return end
    pcall(w.setLiquidAmount, w, 0, STOCK_FUEL_KG)
    for i = 1, 3 do pcall(w.setLiquidAmount, w, i, 0) end
    for i, item in ipairs(HELLFIRE_ITEMS) do
        pcall(w.setItem, w, item, i == 1 and STOCK_HELLFIRE or 0)
    end
    say("SET STOCK requested: jet fuel " .. STOCK_FUEL_KG .. " kg, AGM_114K " .. STOCK_HELLFIRE
        .. ", other Hellfire names 0")
    readWarehouse("STOCK READ BACK")
end

local function readAll(groupName)
    readWarehouse("STOCK NOW")
    local unit = callerUnit(groupName)
    if unit then readUnit(unit) end
end

local function addTrucks(groupName)
    local unit = callerUnit(groupName)
    if not unit then say("no unit for group " .. groupName) return end
    local farp = S.farpName and StaticObject.getByName(S.farpName)
    local p = (farp and farp:isExist()) and farp:getPoint() or unit:getPoint()
    local gName = nextName("TRUCKS")
    local data = {
        name  = gName,
        task  = "Ground Nothing",
        units = {
            { name = gName .. "_fuel", type = "M978 HEMTT Tanker", x = p.x + 30, y = p.z,      heading = 0, skill = "Average" },
            { name = gName .. "_ammo", type = "M 818",             x = p.x + 30, y = p.z + 10, heading = 0, skill = "Average" },
        },
    }
    local ok, g = pcall(coalition.addGroup, unit:getCountry(), Group.Category.GROUND, data)
    if not ok or not g then say("TRUCKS FAILED: " .. tostring(g)) return end
    S.groups[#S.groups + 1] = gName
    say("TRUCKS spawned 30 m north of the FARP: M978 HEMTT Tanker + M 818")
end

local function removeAll()
    for _, n in ipairs(S.objects) do
        local o = StaticObject.getByName(n)
        if o and o:isExist() then o:destroy() end
    end
    for _, n in ipairs(S.groups) do
        local g = Group.getByName(n)
        if g and g:isExist() then g:destroy() end
    end
    S.objects, S.groups, S.farpName = {}, {}, nil
    say("REMOVED everything the spike spawned")
end

-- -----------------------------------------------------------------------------
-- Menus: one per player group, rebuilt on every birth
-- -----------------------------------------------------------------------------

local function buildMenu(unit)
    local g = unit:getGroup()
    if not g then return end
    local gid, gName = g:getID(), g:getName()
    missionCommands.removeItemForGroup(gid, { MENU_NAME })
    local root = missionCommands.addSubMenuForGroup(gid, MENU_NAME)
    missionCommands.addCommandForGroup(gid, "1. Invisible FARP under me", root, spawnFarp, gName)
    missionCommands.addCommandForGroup(gid, "2. Finite stock (300 kg, 2 Hellfire)", root, setFiniteStock)
    missionCommands.addCommandForGroup(gid, "3. Read stock + my aircraft", root, readAll, gName)
    missionCommands.addCommandForGroup(gid, "4. Add fuel + ammo trucks", root, addTrucks, gName)
    missionCommands.addCommandForGroup(gid, "5. Single pad FARP ahead (variant)", root,
        function(n) spawnFarp(n, "single") end, gName)
    missionCommands.addCommandForGroup(gid, "6. Remove everything", root, removeAll)
end

S.handler = {}
function S.handler:onEvent(e)
    if e.id ~= world.event.S_EVENT_BIRTH or not e.initiator then return end
    local ok, pn = pcall(function() return e.initiator:getPlayerName() end)
    if ok and pn then
        buildMenu(e.initiator)
        say("BIRTH of " .. pn .. " in " .. e.initiator:getName() .. " at t=" .. math.floor(timer.getTime())
            .. " s — FARP present: " .. tostring(S.farpName))
        if S.farpName then readWarehouse("STOCK AT BIRTH") end
    end
end
world.addEventHandler(S.handler)

for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
    for _, u in ipairs(coalition.getPlayers(side) or {}) do buildMenu(u) end
end

trigger.action.outText(TAG .. " loaded — F10 > Other > " .. MENU_NAME, 20)
env.info(TAG .. " loaded")
return _SCN_FCSPIKE_RESULT
