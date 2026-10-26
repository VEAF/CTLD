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
    self:_notify(cow, ctld.tr("Fat Cow FARP open — %1", CTLDFatCow.describeStock(cow.stock)))
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
            local w = def.weight
            while cm._weightIndex[w] do
                w = math.floor(w * 100 + 1.5) / 100
            end
            if w ~= def.weight then
                ctld.utils.log("WARN", "CTLDFatCowManager: crate '%s' weight %.2f taken — reassigned to %.2f",
                    def.desc, def.weight, w)
            end
            local d = {
                weight         = w,
                desc           = ctld.tr(def.desc),
                unit           = "FatCow:" .. def.desc,
                cratesRequired = 1,
                showSets       = false,
                fatCow         = content,
            }
            cm._weightIndex[w] = d
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

local function groupIdOf(unit)
    return ctld.utils.getGroupId(unit)
end

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
    local gid = groupIdOf(t)
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
    local gid = groupIdOf(t)
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
    trigger.action.outTextForGroup(gid, ctld.tr("Deploying the Fat Cow FARP…"), 10)
end

--- Packs a piloted cow: what is left goes back into its crates, emptied crates are removed.
-- @param quiet boolean  no "nothing to pack" message (take-off)
function CTLDFatCowManager:packIntoHold(unitName, quiet)
    local cow = self._cows[unitName]
    local t   = Unit.getByName(unitName)
    local gid = t and t:isExist() and groupIdOf(t)
    if not (cow and cow.crates and self:pack(unitName)) then
        if gid and not quiet then
            trigger.action.outTextForGroup(gid, ctld.tr("No Fat Cow FARP deployed."), 10)
        end
        return
    end
    local cm = CTLDCrateManager.getInstance()
    local stillOnboard = {}
    for _, crate in ipairs(cow.crates) do
        if crate:isLoaded() and cm:isCarriedBy(crate, unitName) then stillOnboard[#stillOnboard + 1] = crate end
    end
    for _, crate in ipairs(CTLDFatCow.refillCrates(cow.stock, stillOnboard)) do
        cm:destroyCrate(crate.crateName)
    end
    ctld.utils.updateTransportWeight(unitName)
    self._cows[unitName] = nil
    if gid then
        trigger.action.outTextForGroup(gid, ctld.tr("Fat Cow FARP packed — %1 left.", CTLDFatCow.describeStock(cow.stock)), 10)
    end
end

function CTLDFatCowManager:reportStock(unitName)
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
    trigger.action.outTextForGroup(groupIdOf(t), ctld.tr("Fat Cow stock: %1", CTLDFatCow.describeStock(stock)), 15)
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

--- S_EVENT_DEAD / S_EVENT_CRASH: a dead cow's FARP goes with it.
function CTLDFatCowManager:onDead(event)
    local name = ctld.utils.safeObjectName(event and event.initiator)
    if name and self._cows[name] then
        self:removeCow(name)
        self:_forgetAICow(name)
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

-- AI cow hooks — defined with the AI cow (ticket 04).
function CTLDFatCowManager:onLand(_) end
function CTLDFatCowManager:_onAITakeoff(_) end
function CTLDFatCowManager:_forgetAICow(_) end
function CTLDFatCowManager:_buildAIMenu(_, _, _) end
