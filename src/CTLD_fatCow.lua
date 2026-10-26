---@diagnostic disable
-- CTLD_fatCow.lua
-- Fat Cow — a CH-47 that lands in the field and becomes a forward refuel/rearm point (FEAT-FAT-COW).
--
-- DCS has no fuel-transfer API: the cow is a FARP scene laid out next to it (CTLD_fatCowScene.lua),
-- whose warehouse holds what the cow carries. Measured in DCS 2.9.30.28738 (ticket 01): a runtime
-- Invisible FARP has a warehouse, starts empty, and serves its stock until it runs out.
--
-- CTLDFatCow        — one cow: its stock (fuel kg + weapon items by warehouse name) and its state.
-- CTLDFatCowManager — singleton, cows by unit name; deploy, pack, re-sync on player birth.
--
-- Dependencies: class, CTLDSceneManager, CTLDUtils
-- ====================================================================================================

-- Warehouse liquid types: 0 jet fuel, 1 aviation gasoline, 2 MW50, 3 diesel. A cow carries jet fuel.
local JET_FUEL    = 0
local LIQUID_LAST = 3

-- ====================================================================================================
-- CTLDFatCow
-- ====================================================================================================

CTLDFatCow = class()

CTLDFatCow.STATE_STOWED    = "stowed"      -- the FARP is packed, the stock is on board
CTLDFatCow.STATE_DEPLOYING = "deploying"   -- the scene is being laid out
CTLDFatCow.STATE_DEPLOYED  = "deployed"    -- the FARP is open: its warehouse holds the stock

-- @param unitName    string  the cow's DCS unit name
-- @param coalitionId number
-- @param stock       table   { fuelKg = number, items = { [warehouse item name] = count } } (copied)
function CTLDFatCow:init(unitName, coalitionId, stock)
    self.unitName    = unitName
    self.coalitionId = coalitionId
    self.stock       = { fuelKg = (stock and stock.fuelKg) or 0, items = {} }
    for name, count in pairs((stock and stock.items) or {}) do
        self.stock.items[name] = count
    end
    self.state    = CTLDFatCow.STATE_STOWED
    self.scene    = nil
    self.farpName = nil
end

function CTLDFatCow:isEmpty()
    if (self.stock.fuelKg or 0) > 0 then return false end
    for _, count in pairs(self.stock.items) do
        if count > 0 then return false end
    end
    return true
end

--- Writes the stock into a FARP warehouse: jet fuel, every other liquid at 0, each stocked item.
function CTLDFatCow:writeWarehouse(w)
    w:setLiquidAmount(JET_FUEL, self.stock.fuelKg)
    for t = JET_FUEL + 1, LIQUID_LAST do
        w:setLiquidAmount(t, 0)
    end
    for name, count in pairs(self.stock.items) do
        w:setItem(name, count)
    end
end

--- Reads the stock back from the FARP warehouse: what the players took is gone.
function CTLDFatCow:readWarehouse(w)
    self.stock.fuelKg = w:getLiquidAmount(JET_FUEL) or 0
    for name in pairs(self.stock.items) do
        self.stock.items[name] = w:getItemCount(name) or 0
    end
end

--- Writes back what the server's warehouse holds. Ticket 01 did not measure whether a client sees
-- the server's warehouse; VMCT re-applies FARP warehouses on every birth for that reason.
function CTLDFatCow:resyncWarehouse(w)
    self:readWarehouse(w)
    self:writeWarehouse(w)
end

-- ── Cow crates (piloted cow) ────────────────────────────────────────────────────────────────────
-- A cow crate's descriptor carries `fatCow = { fuelKg }` or `fatCow = { item, count }`: what it holds
-- when full. Once it has served, crate.metadata.fatCow holds what is left and crate.metadata.massKg
-- what it weighs.

local function contentOf(crate)
    return crate.metadata and crate.metadata.fatCow or crate.descriptor.fatCow
end

local function isCowCrate(crate)
    return crate and crate.descriptor and crate.descriptor.fatCow ~= nil
end

--- "2400 kg of fuel, AGM_114K x4" — for the players.
function CTLDFatCow.describeStock(stock)
    local parts = { ctld.tr("%1 kg of fuel", math.floor((stock.fuelKg or 0) + 0.5)) }
    local names = {}
    for name in pairs(stock.items or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        parts[#parts + 1] = string.format("%s x%d", (name:gsub("^weapons%.[%a_]+%.", "")), stock.items[name])
    end
    return table.concat(parts, ", ")
end

--- Sums the cow crates of a list (other crates are ignored) into one stock.
function CTLDFatCow.stockOfCrates(crates)
    local stock = { fuelKg = 0, items = {} }
    for _, crate in ipairs(crates) do
        if isCowCrate(crate) then
            local c = contentOf(crate)
            if c.fuelKg then
                stock.fuelKg = stock.fuelKg + c.fuelKg
            elseif c.item then
                stock.items[c.item] = (stock.items[c.item] or 0) + (c.count or 0)
            end
        end
    end
    return stock
end

--- Puts what is left of a stock back into the cow crates it came from, in order, each up to what it
-- held when the FARP opened. Sets each crate's metadata (content and mass).
-- @return the crates left empty, for the caller to remove
function CTLDFatCow.refillCrates(stock, crates)
    local fuelLeft  = stock.fuelKg or 0
    local itemsLeft = {}
    for name, count in pairs(stock.items or {}) do itemsLeft[name] = count end
    local emptied = {}
    for _, crate in ipairs(crates) do
        if isCowCrate(crate) then
            local full   = crate.descriptor.fatCow
            local before = contentOf(crate)
            local now, fraction
            if before.fuelKg then
                local kg = math.min(before.fuelKg, fuelLeft)
                fuelLeft = fuelLeft - kg
                now      = { fuelKg = kg }
                fraction = full.fuelKg > 0 and kg / full.fuelKg or 0
            else
                local n = math.min(before.count or 0, itemsLeft[before.item] or 0)
                itemsLeft[before.item] = (itemsLeft[before.item] or 0) - n
                now      = { item = before.item, count = n }
                fraction = (full.count or 0) > 0 and n / full.count or 0
            end
            crate.metadata.fatCow = now
            crate.metadata.massKg = crate.descriptor.weight * fraction
            if fraction <= 0 then emptied[#emptied + 1] = crate end
        end
    end
    return emptied
end

-- ====================================================================================================
-- CTLDFatCowManager
-- ====================================================================================================

CTLDFatCowManager = class()
CTLDFatCowManager._instance = nil

CTLDFatCowManager.SCENE_NAME = "Fat Cow FARP"

function CTLDFatCowManager.getInstance()
    if not CTLDFatCowManager._instance then
        local o = setmetatable({}, CTLDFatCowManager)
        o:init()
        CTLDFatCowManager._instance = o
    end
    return CTLDFatCowManager._instance
end

function CTLDFatCowManager:init()
    self._cows = {}   -- unit name → CTLDFatCow
end

--- Declares a unit a cow with the given stock (replaces a previous declaration of the same unit).
-- @return CTLDFatCow
function CTLDFatCowManager:addCow(unit, stock)
    local cow = CTLDFatCow:new(unit:getName(), unit:getCoalition(), stock)
    self._cows[cow.unitName] = cow
    return cow
end

function CTLDFatCowManager:getCow(unitName)
    return self._cows[unitName]
end

--- Packs the cow if it is deployed, then forgets it.
function CTLDFatCowManager:removeCow(unitName)
    if not self._cows[unitName] then return end
    self:pack(unitName)
    self._cows[unitName] = nil
end

local function warehouseOf(farpName)
    local ab = farpName and Airbase.getByName(farpName)
    return ab and ab:getWarehouse() or nil
end

--- Lays out the Fat Cow scene at the cow. The warehouse is written when the scene is laid out
-- (onSceneLaidOut), not here: the FARP does not exist yet.
-- @return true, or false and a reason: "unknown", "airborne", "deployed", "empty", "scene"
function CTLDFatCowManager:deploy(unit)
    local cow = self._cows[unit:getName()]
    if not cow then return false, "unknown" end
    if unit:inAir() then return false, "airborne" end
    if cow.state ~= CTLDFatCow.STATE_STOWED then return false, "deployed" end
    if cow:isEmpty() then return false, "empty" end
    cow.state = CTLDFatCow.STATE_DEPLOYING
    local scene = CTLDSceneManager.getInstance():playScene(unit, CTLDFatCowManager.SCENE_NAME, { fatCow = cow })
    if not scene then
        cow.state = CTLDFatCow.STATE_STOWED
        return false, "scene"
    end
    cow.scene = scene
    return true
end

--- Called by the scene's last step: the FARP exists, its warehouse gets the stock.
function CTLDFatCowManager:onSceneLaidOut(scene)
    local cow = scene._params and scene._params.fatCow
    if not cow then return end
    cow.scene    = scene
    cow.farpName = scene._params.farpName
    local w = warehouseOf(cow.farpName)
    if not w then
        ctld.utils.log("ERROR", "CTLDFatCowManager: no warehouse for FARP '%s' of cow '%s'",
            tostring(cow.farpName), cow.unitName)
        return
    end
    cow:writeWarehouse(w)
    cow.state = CTLDFatCow.STATE_DEPLOYED
    ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' deployed, FARP '%s', %d kg of fuel",
        cow.unitName, cow.farpName, cow.stock.fuelKg)
    self:_notify(cow, ctld.tr("Fat Cow FARP open: %1", CTLDFatCow.describeStock(cow.stock)))
end

--- Tells the cow's audience (its own group when piloted, the escorted flight when AI).
function CTLDFatCowManager:_notify(cow, text)
    if cow.notifyGroupId then
        trigger.action.outTextForGroup(cow.notifyGroupId, text, 15)
    end
end

--- Reads what the players left back into the stock, then removes the scene.
-- @return true when a deployed cow was packed
function CTLDFatCowManager:pack(unitName)
    local cow = self._cows[unitName]
    if not cow or cow.state == CTLDFatCow.STATE_STOWED then return false end
    local w = warehouseOf(cow.farpName)
    if w then cow:readWarehouse(w) end
    if cow.scene then
        -- A scene still laying out would go on spawning after the pack: stop it first.
        if cow.state == CTLDFatCow.STATE_DEPLOYING and cow.scene.abort then
            cow.scene:abort("Fat Cow packed while deploying")
        end
        CTLDSceneManager.getInstance():packScene(cow.scene)
    end
    cow.scene, cow.farpName = nil, nil
    cow.state = CTLDFatCow.STATE_STOWED
    ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' packed, %d kg of fuel left",
        cow.unitName, cow.stock.fuelKg)
    return true
end

--- S_EVENT_BIRTH: a player arriving gets every open FARP's warehouse re-written (see resyncWarehouse).
function CTLDFatCowManager:onBirth(event)
    if self._started and next(ctld.gs("fatCowAICows") or {}) then self:_activateMissionCows() end
    local obj = event and event.initiator
    if not (obj and obj.getPlayerName) then return end
    local ok, playerName = pcall(obj.getPlayerName, obj)
    if not (ok and playerName) then return end
    for _, cow in pairs(self._cows) do
        if cow.state == CTLDFatCow.STATE_DEPLOYED then
            local w = warehouseOf(cow.farpName)
            if w then cow:resyncWarehouse(w) end
        end
    end
end

-- ====================================================================================================
-- Start-up: crate descriptors and DCS events (called by CTLDCoreManager:init when fatCowEnabled)
-- ====================================================================================================

function CTLDFatCowManager:start()
    if self._started then return end
    self._started = true
    self:_injectCrateDescriptors()
    local bridge = CTLDDCSEventBridge.getInstance()
    bridge:register(self, world.event.S_EVENT_BIRTH,   "onBirth")
    bridge:register(self, world.event.S_EVENT_TAKEOFF, "onTakeoff")
    bridge:register(self, world.event.S_EVENT_LAND,    "onLand")
    bridge:register(self, world.event.S_EVENT_DEAD,    "onDead")
    bridge:register(self, world.event.S_EVENT_CRASH,   "onDead")
    bridge:register(self, world.event.S_EVENT_PLAYER_LEAVE_UNIT, "onPlayerLeave")
    self:_activateMissionCows()
    ctld.utils.log("INFO", "CTLDFatCowManager: started, %d cow crate type(s)", #self._crateDescs)
end

--- Turns fatCowCrates into crate descriptors the crate system knows (indexed by weight, as every
-- crate is), but keeps them out of the shared Request Equipment menu: the cow requests its own.
function CTLDFatCowManager:_injectCrateDescriptors()
    local cm = CTLDCrateManager.getInstance()
    self._crateDescs = {}
    for _, def in ipairs(ctld.gs("fatCowCrates") or {}) do
        local content = (def.fuelKg and { fuelKg = def.fuelKg })
                     or (def.item and def.count and { item = def.item, count = def.count })
        if not (content and def.desc and (def.weight or 0) > 0) then
            ctld.utils.log("WARN", "CTLDFatCowManager: fatCowCrates entry '%s' ignored: it needs desc, weight, and fuelKg or item + count",
                tostring(def.desc))
        else
            local d = cm:registerDescriptor({
                weight         = def.weight,
                desc           = ctld.tr(def.desc),
                unit           = "FatCow:" .. def.desc,
                cratesRequired = 1,
                showSets       = false,
                fatCow         = content,
            })
            self._crateDescs[#self._crateDescs + 1] = d
        end
    end
end

function CTLDFatCowManager:isCowType(typeName)
    for _, t in ipairs(ctld.gs("fatCowTypes") or {}) do
        if t == typeName then return true end
    end
    return false
end

-- ====================================================================================================
-- Piloted cow (ticket 03): F10 > CTLD > Fat Cow, for the types listed in fatCowTypes
-- ====================================================================================================

--- The cow crates in a unit's hold.
local function cowCratesOnboard(unitName)
    local out = {}
    for _, crate in ipairs(CTLDCrateManager.getInstance():cratesOnboard(unitName)) do
        if crate.descriptor and crate.descriptor.fatCow then out[#out + 1] = crate end
    end
    return out
end

function CTLDFatCowManager:requestCrate(unitName, weight)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid = ctld.utils.getGroupId(t)
    if ctld.utils.inAir(t) then
        trigger.action.outTextForGroup(gid, ctld.tr("You must be landed to request a crate."), 10)
        return
    end
    local zones = CTLDZoneManager.getInstance():getLogisticZonesAtPoint(t:getPoint(), t:getCoalition(), "cratesPickup")
    if not next(zones) then
        trigger.action.outTextForGroup(gid, ctld.tr("You are not close enough to friendly logistics to get a crate!"), 10)
        return
    end
    local desc
    for _, d in ipairs(self._crateDescs or {}) do
        if d.weight == weight then desc = d end
    end
    if not desc then return end
    local count = CTLDCrateManager.getInstance():spawnCratesAligned({ desc }, t, t:getCoalition(), unitName,
        CTLDCrate.SPAWN_METHOD.MENU_CTLD)
    if (count or 0) < 1 then
        trigger.action.outTextForGroup(gid, ctld.tr("Request failed: the equipment could not be brought out."), 10)
        return
    end
    trigger.action.outTextForGroup(gid, ctld.tr("%1 is next to you: load it into your hold.", desc.desc), 10)
end

--- Deploys the FARP with the cow crates on board as its stock. The crates stay on board.
function CTLDFatCowManager:deployFromHold(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid = ctld.utils.getGroupId(t)
    local existing = self._cows[unitName]
    if existing and existing.state ~= CTLDFatCow.STATE_STOWED then
        trigger.action.outTextForGroup(gid, ctld.tr("The Fat Cow FARP is already deployed."), 10)
        return
    end
    if ctld.utils.inAir(t) then
        trigger.action.outTextForGroup(gid, ctld.tr("Land to deploy the Fat Cow FARP."), 10)
        return
    end
    local crates = cowCratesOnboard(unitName)
    if #crates == 0 then
        trigger.action.outTextForGroup(gid, ctld.tr("No Fat Cow crate on board: load a fuel tank or an ammo crate first."), 10)
        return
    end
    local cow = self:addCow(t, CTLDFatCow.stockOfCrates(crates))
    cow.crates        = crates
    cow.notifyGroupId = gid
    local ok, why = self:deploy(t)
    if not ok then
        self._cows[unitName] = nil
        local text = (why == "empty") and ctld.tr("The Fat Cow crates on board are empty.")
                  or ctld.tr("The Fat Cow FARP could not be deployed.")
        trigger.action.outTextForGroup(gid, text, 10)
        return
    end
    trigger.action.outTextForGroup(gid, ctld.tr("Deploying the Fat Cow FARP..."), 10)
end

--- Packs a piloted cow: what is left goes back into its crates, emptied crates are removed.
-- @param quiet boolean  no "nothing to pack" message (take-off)
function CTLDFatCowManager:packIntoHold(unitName, quiet)
    local cow = self._cows[unitName]
    local t   = Unit.getByName(unitName)
    local gid = t and t:isExist() and ctld.utils.getGroupId(t)
    if not (cow and cow.crates and self:pack(unitName)) then
        if gid and not quiet then
            trigger.action.outTextForGroup(gid, ctld.tr("No Fat Cow FARP deployed."), 10)
        end
        return
    end
    -- Every crate the FARP was opened with gets its share back, wherever it is now (one unloaded
    -- while the FARP was open included); a crate destroyed meanwhile is gone with its share.
    local cm = CTLDCrateManager.getInstance()
    local stillThere = {}
    for _, crate in ipairs(cow.crates) do
        if cm.crates[crate.crateName] == crate then stillThere[#stillThere + 1] = crate end
    end
    for _, crate in ipairs(CTLDFatCow.refillCrates(cow.stock, stillThere)) do
        cm:destroyCrate(crate.crateName)
    end
    ctld.utils.updateTransportWeight(unitName)
    self._cows[unitName] = nil
    if gid then
        trigger.action.outTextForGroup(gid, ctld.tr("Fat Cow FARP packed: %1 left.", CTLDFatCow.describeStock(cow.stock)), 10)
    end
end

-- @param toGroupId number|nil  who is told (default: the cow's own group)
function CTLDFatCowManager:reportStock(unitName, toGroupId)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow = self._cows[unitName]
    local stock
    if cow and cow.state == CTLDFatCow.STATE_DEPLOYED then
        local w = warehouseOf(cow.farpName)
        if w then cow:readWarehouse(w) end
        stock = cow.stock
    else
        stock = CTLDFatCow.stockOfCrates(cowCratesOnboard(unitName))
    end
    trigger.action.outTextForGroup(toGroupId or ctld.utils.getGroupId(t), ctld.tr("Fat Cow stock: %1", CTLDFatCow.describeStock(stock)), 15)
end

--- S_EVENT_TAKEOFF: a piloted cow taking off packs its FARP (AI cows: see onTakeoff below).
function CTLDFatCowManager:onTakeoff(event)
    local unit = event and event.initiator
    local name = ctld.utils.safeObjectName(unit)
    if not name then return end
    local cow = self._cows[name]
    if cow and cow.crates and cow.state ~= CTLDFatCow.STATE_STOWED then
        self:packIntoHold(name, true)
    end
    self:_onAITakeoff(name)
end

--- S_EVENT_DEAD / S_EVENT_CRASH: a dead cow's FARP goes with it. Any loss (and a player leaving,
-- below) may also leave an AI cow with no flight to escort: checked a moment later, once DCS has
-- removed the unit.
function CTLDFatCowManager:onDead(event)
    local name = ctld.utils.safeObjectName(event and event.initiator)
    if name and self._cows[name] then
        self:removeCow(name)
        self:_forgetAICow(name)
    end
    self:_checkFlightsLater()
end

function CTLDFatCowManager:onPlayerLeave(_)
    self:_checkFlightsLater()
end

function CTLDFatCowManager:_checkFlightsLater()
    if not next(self._aiByFlight or {}) then return end
    local mgr = self
    ctld.scheduler.schedule(function() mgr:_sendHomeOrphans() end, nil, timer.getTime() + 2)
end

--- An AI cow whose flight is no longer in the world packs and goes home.
function CTLDFatCowManager:_sendHomeOrphans()
    for flight, cow in pairs(self._aiByFlight or {}) do
        local g = Group.getByName(flight)
        if not (g and g:isExist() and g:getUnit(1)) then
            self:_returnHome(cow)
        end
    end
end

-- ── Menu section ────────────────────────────────────────────────────────────────────────────────

function CTLDFatCowManager:buildMenuSection(playerObj, menu)
    local root, sub = ctld.tr("CTLD"), ctld.tr("Fat Cow")
    local path = { root, sub }
    if playerObj.isTransport and self:isCowType(playerObj.typeName) then
        menu:addSubMenu({ root }, sub, { order = 50 })
        local mgr = CTLDFatCowManager.getInstance
        for i, d in ipairs(self._crateDescs or {}) do
            menu:addCommand(path, ctld.tr("Request %1", d.desc),
                function(arg) mgr():requestCrate(arg.unitName, arg.weight) end,
                { unitName = playerObj.unitName, weight = d.weight }, { order = i })
        end
        menu:addCommand(path, ctld.tr("Deploy the Fat Cow FARP"),
            function(arg) mgr():deployFromHold(arg.unitName) end, { unitName = playerObj.unitName }, { order = 20 })
        menu:addCommand(path, ctld.tr("Pack the Fat Cow FARP"),
            function(arg) mgr():packIntoHold(arg.unitName) end, { unitName = playerObj.unitName }, { order = 21 })
        menu:addCommand(path, ctld.tr("Fat Cow stock"),
            function(arg) mgr():reportStock(arg.unitName) end, { unitName = playerObj.unitName }, { order = 22 })
    else
        self:_buildAIMenu(playerObj, menu, path)
    end
end

-- The section's manager resolves the singleton at build time, so a reset instance is never reached.
CTLDPlayerManager.deferMenuSection({
    key       = "fatCow",
    manager   = { buildMenuSection = function(_, playerObj, menu)
        CTLDFatCowManager.getInstance():buildMenuSection(playerObj, menu)
    end },
    method    = "buildMenuSection",
    configKey = "fatCowEnabled",
    order     = 50,
})

-- ====================================================================================================
-- AI cow (ticket 04): requested by a flight on the ground in a logistic zone, or placed in the
-- mission and declared in fatCowAICows. It follows the flight, lands next to its leader, deploys
-- after fatCowDeployDelay, packs when the leader takes off, and goes home when empty or released.
-- ====================================================================================================

CTLDFatCowManager.PHASE_FOLLOWING = "following"
CTLDFatCowManager.PHASE_LANDING   = "landing"     -- sent to land next to the leader
CTLDFatCowManager.PHASE_LANDED    = "landed"      -- on the ground, deployment pending or done
CTLDFatCowManager.PHASE_RETURNING = "returning"   -- going home to despawn
CTLDFatCowManager.PHASE_HOLDING   = "holding"     -- orbiting, on "Take off" or "Hold here"

-- Internal fuel given to a scripted cow: the CH-47Fbl1's M_fuel_max in DCS's db.Units.lua.
-- A scripted aircraft created without fuel falls out of the sky.
local AI_COW_FUEL_KG   = 3054
local FOLLOW_OFFSET    = { x = -200, y = 60, z = 150 }   -- behind, above and to the right of the leader
local LAND_OFFSET_M    = 120                              -- landing point, to the leader's left
local CRUISE_SPEED_MPS = 60
local CRUISE_ALT_M     = 150
local ORBIT_SPEED_MPS  = 40
-- Cruise speed used for the joining estimate: an assumption (about 235 km/h), to check in game.
local AI_COW_CRUISE_MPS = 65
-- How long a Land task keeps the cow down: a day, so it never lifts off on its own while serving.
-- The flight's take-off or a release re-tasks it long before.
local LAND_DURATION_S  = 86400

local function aiStockFromConfig()
    local stock = { fuelKg = ctld.gs("fatCowAIFuelKg"), items = {} }
    for _, it in ipairs(ctld.gs("fatCowAIItems") or {}) do
        if it.item and it.count then stock.items[it.item] = it.count end
    end
    return stock
end

local function controllerOf(groupName)
    local g = Group.getByName(groupName)
    return g and g:isExist() and g:getController() or nil
end

local function firstUnitOf(groupName)
    local g = Group.getByName(groupName)
    return g and g:isExist() and g:getUnit(1) or nil
end

-- A route to `point` whose single turning point carries a Land task: VMCT measured that a scripted
-- helicopter given a Land *waypoint* lands on the nearest airfield instead (known limitation
-- helicopter-land-waypoint-goes-to-the-nearest-airfield).
local function landMission(point)
    return {
        id = "Mission",
        params = { route = { points = { {
            type = "Turning Point", action = "Turning Point",
            x = point.x, y = point.z, alt = CRUISE_ALT_M, alt_type = "RADIO",
            speed = CRUISE_SPEED_MPS, speed_locked = true,
            task = { id = "ComboTask", params = { tasks = { {
                number = 1, auto = false, enabled = true, id = "Land",
                params = { point = { x = point.x, y = point.z }, durationFlag = true, duration = LAND_DURATION_S },
            } } } },
        } } } },
    }
end

local function setCargoMass(cow)
    local kg = cow.stock.fuelKg or 0
    for _, count in pairs(cow.stock.items) do kg = kg + 50 * count end   -- ~50 kg a missile
    pcall(trigger.action.setUnitInternalCargo, cow.unitName, kg)
end

--- Registers an AI cow already in the world.
-- @param groupName   string  the cow's group
-- @param flightGroup string  the group it escorts
-- @param homePoint   vec3    where it goes back to despawn
function CTLDFatCowManager:addAICow(groupName, flightGroup, homePoint)
    local unit = firstUnitOf(groupName)
    if not unit then return nil end
    local cow = self:addCow(unit, aiStockFromConfig())
    cow.ai = { groupName = groupName, flightGroup = flightGroup, home = homePoint,
               phase = CTLDFatCowManager.PHASE_FOLLOWING }
    self._aiByFlight = self._aiByFlight or {}
    self._aiByFlight[flightGroup] = cow
    setCargoMass(cow)
    self:_follow(cow)
    return cow
end

function CTLDFatCowManager:aiCowOfFlight(flightGroup)
    return self._aiByFlight and self._aiByFlight[flightGroup] or nil
end

function CTLDFatCowManager:_follow(cow)
    local flight = Group.getByName(cow.ai.flightGroup)
    local ctrl   = controllerOf(cow.ai.groupName)
    if not (flight and flight:isExist() and ctrl) then return false end
    ctrl:setTask({ id = "Follow", params = { groupId = flight:getID(), pos = FOLLOW_OFFSET, lastWptIndexFlag = false } })
    cow.ai.phase = CTLDFatCowManager.PHASE_FOLLOWING
    return true
end

function CTLDFatCowManager:_landNextTo(cow, leader)
    local ctrl = controllerOf(cow.ai.groupName)
    if not ctrl then return end
    local p   = leader:getPoint()
    local hdg = ctld.utils.getHeadingInRadians("CTLDFatCowManager", leader, true)
    local left = hdg - math.pi / 2
    ctrl:setTask(landMission({ x = p.x + math.cos(left) * LAND_OFFSET_M, y = p.y, z = p.z + math.sin(left) * LAND_OFFSET_M }))
    cow.ai.phase = CTLDFatCowManager.PHASE_LANDING
end

function CTLDFatCowManager:_returnHome(cow)
    self:_cancelDeploy(cow)
    if cow.state ~= CTLDFatCow.STATE_STOWED then self:pack(cow.unitName) end
    local ctrl = controllerOf(cow.ai.groupName)
    if ctrl and cow.ai.home then ctrl:setTask(landMission(cow.ai.home)) end
    cow.ai.phase = CTLDFatCowManager.PHASE_RETURNING
    if self._aiByFlight then self._aiByFlight[cow.ai.flightGroup] = nil end
end

function CTLDFatCowManager:_cancelDeploy(cow)
    if cow.ai and cow.ai.deployTimer then
        ctld.scheduler.remove(cow.ai.deployTimer)
        cow.ai.deployTimer = nil
    end
end

--- The flight's group name when `unit` leads it (its first unit), else nil: a wingman landing or
-- taking off first must not move the cow or close the FARP under the others.
local function flightLedBy(unit)
    local okG, group = pcall(unit.getGroup, unit)
    if not (okG and group) then return nil end
    local leader = group:getUnit(1)
    if not (leader and leader:getName() == unit:getName()) then return nil end
    return group:getName()
end

--- True when a player flies in the group: its cow then moves only on the F10 commands (Zip, 2026-10-26:
-- a cow that took off whenever the leader hopped onto its FARP). An AI flight cannot use the menu, so
-- its cow (a mission-placed one, fatCowAICows) keeps landing and taking off with the leader.
local function flightHasPlayer(groupName)
    local g = Group.getByName(groupName)
    if not (g and g:isExist()) then return false end
    for _, u in ipairs(g:getUnits() or {}) do
        local ok, pn = pcall(function() return u:getPlayerName() end)
        if ok and pn then return true end
    end
    return false
end

--- The flight's group id, for messages: the cow talks to the flight it serves.
local function flightGroupId(cow)
    local g = Group.getByName(cow.ai.flightGroup)
    return g and g:isExist() and g:getID() or nil
end

--- S_EVENT_LAND: the cow lands → it deploys after fatCowDeployDelay, or despawns when it was going home;
-- an AI flight's leader lands → its cow lands next to it (a player flight uses "Land here").
function CTLDFatCowManager:onLand(event)
    local unit = event and event.initiator
    local name = ctld.utils.safeObjectName(unit)
    if not name then return end

    local cow = self._cows[name]
    if cow and cow.ai then
        if cow.ai.phase == CTLDFatCowManager.PHASE_RETURNING then
            local g = Group.getByName(cow.ai.groupName)
            self._cows[name] = nil
            if g and g:isExist() then g:destroy() end
        elseif cow.ai.phase == CTLDFatCowManager.PHASE_LANDING then
            cow.ai.phase = CTLDFatCowManager.PHASE_LANDED
            local mgr = self
            cow.ai.deployTimer = ctld.scheduler.schedule(function()
                cow.ai.deployTimer = nil
                local u = Unit.getByName(cow.unitName)
                if cow.ai.phase == CTLDFatCowManager.PHASE_LANDED and u and u:isExist() then
                    cow.notifyGroupId = flightGroupId(cow)
                    mgr:deploy(u)
                end
            end, nil, timer.getTime() + ctld.gs("fatCowDeployDelay"))
        end
        return
    end

    local flight = flightLedBy(unit)
    local escort = flight and self:aiCowOfFlight(flight)
    if escort and escort.ai.phase == CTLDFatCowManager.PHASE_FOLLOWING and not flightHasPlayer(flight) then
        self:_landNextTo(escort, unit)
    end
end

--- An AI flight's leader takes off → its cow packs and follows again, or goes home if empty (a player
-- flight uses "Take off" / "Join us").
function CTLDFatCowManager:_onAITakeoff(name)
    local unit = Unit.getByName(name)
    if not unit then return end
    local flight = flightLedBy(unit)
    local cow = flight and self:aiCowOfFlight(flight)
    if not cow or cow.ai.phase == CTLDFatCowManager.PHASE_FOLLOWING or flightHasPlayer(flight) then return end
    self:_cancelDeploy(cow)
    if cow.state ~= CTLDFatCow.STATE_STOWED then self:pack(cow.unitName) end
    setCargoMass(cow)
    if cow:isEmpty() then
        self:_returnHome(cow)
    else
        self:_follow(cow)
    end
end

-- ── F10 orders to the flight's cow ─────────────────────────────────────────────────────────────

--- Packs the FARP (if open) and stops a pending deployment: the cow is about to move.
function CTLDFatCowManager:_readyToMove(cow)
    self:_cancelDeploy(cow)
    if cow.state ~= CTLDFatCow.STATE_STOWED then self:pack(cow.unitName) end
    setCargoMass(cow)
end

function CTLDFatCowManager:_orbit(cow, point)
    local ctrl = controllerOf(cow.ai.groupName)
    if not ctrl then return end
    ctrl:setTask({ id = "Orbit", params = { pattern = "Circle", point = { x = point.x, y = point.z },
        altitude = land.getHeight({ x = point.x, y = point.z }) + CRUISE_ALT_M, speed = ORBIT_SPEED_MPS } })
    cow.ai.phase = CTLDFatCowManager.PHASE_HOLDING
end

--- The cow of the requester's flight, or nil after telling the requester there is none.
function CTLDFatCowManager:_flightCowFor(t)
    local cow = self:aiCowOfFlight(t:getGroup():getName())
    local u   = cow and Unit.getByName(cow.unitName)
    if u and u:isExist() then return cow, u end
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Your flight has no Fat Cow."), 10)
    return nil
end

--- "Land here": the cow lands next to the requester and opens its FARP fatCowDeployDelay later.
function CTLDFatCowManager:orderLandHere(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow, u = self:_flightCowFor(t)
    if not cow then return end
    if not u:inAir() then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("The Fat Cow is already on the ground."), 10)
        return
    end
    self:_landNextTo(cow, t)
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
        ctld.tr("Fat Cow landing next to you: FARP open %1 s after touchdown.", ctld.gs("fatCowDeployDelay")), 10)
end

--- "Take off": the cow packs its FARP, lifts off and orbits where it stands.
function CTLDFatCowManager:orderTakeOff(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow, u = self:_flightCowFor(t)
    if not cow then return end
    self:_readyToMove(cow)
    self:_orbit(cow, u:getPoint())
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Fat Cow taking off: it orbits where it stands."), 10)
end

--- "Hold here": the cow packs its FARP if needed and orbits over the requester's position.
function CTLDFatCowManager:orderHoldHere(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow = self:_flightCowFor(t)
    if not cow then return end
    self:_readyToMove(cow)
    self:_orbit(cow, t:getPoint())
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Fat Cow holding over your position."), 10)
end

--- "Join us": the cow packs its FARP if needed and follows the flight.
function CTLDFatCowManager:orderJoin(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow = self:_flightCowFor(t)
    if not cow then return end
    self:_readyToMove(cow)
    self:_follow(cow)
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Fat Cow joining your flight."), 10)
end

function CTLDFatCowManager:_forgetAICow(name)
    for flight, cow in pairs(self._aiByFlight or {}) do
        if cow.unitName == name then self._aiByFlight[flight] = nil end
    end
end

--- True when a point is on land: a cow neither appears nor goes home over water (a carrier is a
-- logistic zone too).
local function onLand(p)
    if not (land.getSurfaceType and land.SurfaceType) then return true end
    local ok, s = pcall(land.getSurfaceType, { x = p.x, y = p.z })
    return not ok or (s ~= land.SurfaceType.WATER and s ~= land.SurfaceType.SHALLOW_WATER)
end

--- The friendly logistic zone on land nearest to a point, and its distance, or nil.
function CTLDFatCowManager:nearestHomeZone(point, coalitionId)
    local best, bestD
    for _, zone in ipairs(CTLDZoneManager.getInstance():getLogisticZonesForCoalition(coalitionId)) do
        local c = zone:getCenter()
        if c and onLand(c) then
            local d = ctld.utils.getDistance("CTLDFatCowManager", point, c)
            if not bestD or d < bestD then best, bestD = zone, d end
        end
    end
    return best, bestD
end

local function etaMinutes(distanceM)
    return math.max(1, math.floor(distanceM / AI_COW_CRUISE_MPS / 60 + 0.5))
end

--- F10 "Request a Fat Cow", from anywhere: it takes off from the friendly logistic zone nearest to
-- the requester and joins the flight. One cow per flight.
function CTLDFatCowManager:requestAICow(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid    = ctld.utils.getGroupId(t)
    local flight = t:getGroup():getName()
    if self:aiCowOfFlight(flight) then
        trigger.action.outTextForGroup(gid, ctld.tr("Your flight already has a Fat Cow."), 10)
        return
    end
    local p = t:getPoint()
    local zone, distance = self:nearestHomeZone(p, t:getCoalition())
    if not zone then
        trigger.action.outTextForGroup(gid, ctld.tr("No friendly logistic zone to send a Fat Cow from."), 10)
        return
    end
    self._aiCounter = (self._aiCounter or 0) + 1
    local home = zone:getCenter()
    local hdg  = math.atan2(p.z - home.z, p.x - home.x)                 -- towards the requester
    local alt  = land.getHeight({ x = home.x, y = home.z }) + CRUISE_ALT_M
    local groupName = string.format("Fat Cow %s #%d", flight, self._aiCounter)
    -- An air start over the zone: no parking, no trees, and a carrier zone is never chosen (onLand).
    local data = {
        name  = groupName,
        task  = "Transport",
        route = { points = { {
            type = "Turning Point", action = "Turning Point",
            x = home.x, y = home.z, alt = alt, alt_type = "BARO", speed = CRUISE_SPEED_MPS, speed_locked = true,
            task = { id = "ComboTask", params = { tasks = {} } },
        } } },
        units = { {
            name = groupName .. "-1", type = ctld.gs("fatCowAIType"), skill = "High",
            x = home.x, y = home.z, alt = alt, alt_type = "BARO", speed = CRUISE_SPEED_MPS, heading = hdg,
            payload = { fuel = AI_COW_FUEL_KG, flare = 0, chaff = 0, gun = 100, pylons = {} },
        } },
    }
    local ok, g = pcall(coalition.addGroup, t:getCountry(), Group.Category.HELICOPTER, data)
    if not (ok and g) then
        ctld.utils.log("ERROR", "CTLDFatCowManager: Fat Cow for '%s' not created: %s", flight, tostring(g))
        trigger.action.outTextForGroup(gid, ctld.tr("The Fat Cow could not be brought in."), 10)
        return
    end
    local mgr      = self
    local zoneName = zone.name
    -- The group exists at once, its controller takes a task better on the next frame.
    ctld.scheduler.schedule(function()
        local cow = mgr:addAICow(groupName, flight, home)
        if cow then cow.ai.homeName = zoneName end
    end, nil, timer.getTime() + 1)
    trigger.action.outTextForGroup(gid,
        ctld.tr("Fat Cow on its way from %1: %2 km, joining in about %3 min. Land here, Take off, Hold here and Join us command it.",
            zoneName, math.floor(distance / 1000 + 0.5), etaMinutes(distance)), 15)
end

--- F10 "Release the Fat Cow": it packs and goes home.
function CTLDFatCowManager:releaseAICow(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow = self:aiCowOfFlight(t:getGroup():getName())
    if not cow then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Your flight has no Fat Cow."), 10)
        return
    end
    self:_returnHome(cow)
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Fat Cow released: it goes home."), 10)
end

function CTLDFatCowManager:_buildAIMenu(playerObj, menu, path)
    if ctld.gs("fatCowAIType") == "" then return end
    menu:addSubMenu({ path[1] }, path[2], { order = 50 })
    local mgr = CTLDFatCowManager.getInstance
    local u = { unitName = playerObj.unitName }
    menu:addCommand(path, ctld.tr("Request a Fat Cow"), function(arg) mgr():requestAICow(arg.unitName) end, u, { order = 1 })
    menu:addCommand(path, ctld.tr("Land here"), function(arg) mgr():orderLandHere(arg.unitName) end, u, { order = 2 })
    menu:addCommand(path, ctld.tr("Take off"), function(arg) mgr():orderTakeOff(arg.unitName) end, u, { order = 3 })
    menu:addCommand(path, ctld.tr("Hold here"), function(arg) mgr():orderHoldHere(arg.unitName) end, u, { order = 4 })
    menu:addCommand(path, ctld.tr("Join us"), function(arg) mgr():orderJoin(arg.unitName) end, u, { order = 5 })
    menu:addCommand(path, ctld.tr("Fat Cow status"), function(arg) mgr():reportFlightCowStatus(arg.unitName) end, u, { order = 6 })
    menu:addCommand(path, ctld.tr("FARP status"), function(arg) mgr():reportFarpStatus(arg.unitName) end, u, { order = 7 })
    menu:addCommand(path, ctld.tr("Release the Fat Cow"), function(arg) mgr():releaseAICow(arg.unitName) end, u, { order = 8 })
end

local PHASE_TEXT = {
    holding   = "holding",
    following = "following your flight",
    landing   = "landing next to your leader",
    landed    = "on the ground",
    returning = "going home",
}

--- F10 "Fat Cow status": where the flight's cow is, when it joins, and what it holds.
function CTLDFatCowManager:reportFlightCowStatus(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid = ctld.utils.getGroupId(t)
    local cow = self:aiCowOfFlight(t:getGroup():getName())
    local u   = cow and Unit.getByName(cow.unitName)
    if not (u and u:isExist()) then
        trigger.action.outTextForGroup(gid, ctld.tr("Your flight has no Fat Cow."), 10)
        return
    end
    local me, it = t:getPoint(), u:getPoint()
    local d       = ctld.utils.getDistance("CTLDFatCowManager", me, it)
    local bearing = math.floor((math.deg(math.atan2(it.z - me.z, it.x - me.x)) + 360) % 360 + 0.5)
    local phase   = (cow.state == CTLDFatCow.STATE_DEPLOYED) and "FARP open" or PHASE_TEXT[cow.ai.phase] or cow.ai.phase
    local lines   = { ctld.tr("Fat Cow: %1, %2 km at %3°.", ctld.tr(phase), string.format("%.1f", d / 1000), bearing) }
    if cow.ai.phase == CTLDFatCowManager.PHASE_FOLLOWING and d > 1500 then
        lines[#lines + 1] = ctld.tr("Joining in about %1 min.", etaMinutes(d))
    end
    lines[#lines + 1] = ctld.tr("Stock: %1", CTLDFatCow.describeStock(self:liveStock(cow)))
    trigger.action.outTextForGroup(gid, table.concat(lines, "\n"), 15)
end

--- The cow's stock as it stands: read from its FARP when the FARP is open.
function CTLDFatCowManager:liveStock(cow)
    if cow.state == CTLDFatCow.STATE_DEPLOYED then
        local w = warehouseOf(cow.farpName)
        if w then cow:readWarehouse(w) end
    end
    return cow.stock
end

local FARP_STATUS_RANGE_M = 2000

--- F10 "FARP status": what the Fat Cow FARP the player is at still holds, whoever it belongs to.
function CTLDFatCowManager:reportFarpStatus(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local me = t:getPoint()
    local best, bestD
    for _, cow in pairs(self._cows) do
        local farp = cow.state == CTLDFatCow.STATE_DEPLOYED and cow.farpName and StaticObject.getByName(cow.farpName)
        if farp and farp:isExist() then
            local d = ctld.utils.getDistance("CTLDFatCowManager", me, farp:getPoint())
            if d <= FARP_STATUS_RANGE_M and (not bestD or d < bestD) then best, bestD = cow, d end
        end
    end
    local gid = ctld.utils.getGroupId(t)
    if not best then
        trigger.action.outTextForGroup(gid, ctld.tr("No Fat Cow FARP within %1 km.", FARP_STATUS_RANGE_M / 1000), 10)
        return
    end
    trigger.action.outTextForGroup(gid,
        ctld.tr("Fat Cow FARP %1 m away: %2", math.floor(bestD + 0.5), CTLDFatCow.describeStock(self:liveStock(best))), 15)
end

-- ── Mission-placed cows (fatCowAICows): the VMCT contract ──────────────────────────────────────
-- Each entry { group = "<late-activated CH-47 group>", escort = "<flight group>" }. CTLD activates
-- the cow when the escorted flight is in the world (at start, or when its first unit is born).

--- True when the group has a unit actually in the world: a late-activated group exists to scripts
-- before it is activated (known limitation late-activated-group-is-visible).
local function inWorld(group)
    if not (group and group:isExist()) then return false end
    local u = group:getUnit(1)
    if not u then return false end
    local ok, active = pcall(function() return u:isActive() end)
    return not ok or active ~= false
end

function CTLDFatCowManager:_activateMissionCow(entry)
    local g = Group.getByName(entry.group)
    local flight = Group.getByName(entry.escort)
    if not (g and inWorld(flight)) then return false end
    if self:aiCowOfFlight(entry.escort) then return true end
    pcall(g.activate, g)
    local u = g:getUnit(1)
    local home = u and u:getPoint() or nil
    local mgr = self
    ctld.scheduler.schedule(function() mgr:addAICow(entry.group, entry.escort, home) end, nil, timer.getTime() + 1)
    return true
end

function CTLDFatCowManager:_activateMissionCows()
    for _, entry in ipairs(ctld.gs("fatCowAICows") or {}) do
        if entry.group and entry.escort and not (self._missionCowsDone and self._missionCowsDone[entry.group]) then
            if self:_activateMissionCow(entry) then
                self._missionCowsDone = self._missionCowsDone or {}
                self._missionCowsDone[entry.group] = true
            end
        end
    end
end
