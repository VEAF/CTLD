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
-- Dependencies: class, CTLDSceneManager, CTLDCrateManager, CTLDZoneManager, CTLDPlayerManager,
-- CTLDDCSEventBridge, CTLDUtils (the scene: CTLDObjectRegistry)
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

--- Sets every weapon the warehouse lists to 0 (pcall: getInventory is an observation, not a contract).
local function clearWeapons(w)
    local ok, inv = pcall(w.getInventory, w)
    for name in pairs(ok and inv and inv.weapon or {}) do
        pcall(w.setItem, w, name, 0)
    end
end

--- Writes the stock into a FARP warehouse: jet fuel, every other liquid at 0, each stocked item, and
-- every other weapon the warehouse lists at 0. A weapon getInventory does not list is not reached:
-- a mission FARP measured with an unlimited stock listed none (ticket 06); a refilled cow FARP is to measure.
function CTLDFatCow:writeWarehouse(w)
    clearWeapons(w)
    w:setLiquidAmount(JET_FUEL, self.stock.fuelKg)
    for t = JET_FUEL + 1, LIQUID_LAST do
        w:setLiquidAmount(t, 0)
    end
    for name, count in pairs(self.stock.items) do
        w:setItem(name, count)
    end
end

--- Empties a FARP warehouse: every liquid and every weapon it lists.
function CTLDFatCow.emptyAnyWarehouse(w)
    clearWeapons(w)
    for t = JET_FUEL, LIQUID_LAST do
        w:setLiquidAmount(t, 0)
    end
end

--- Empties a FARP warehouse: a packed cow's FARP stays in the world, with nothing in it.
function CTLDFatCow:emptyWarehouse(w)
    CTLDFatCow.emptyAnyWarehouse(w)
    for name in pairs(self.stock.items) do
        w:setItem(name, 0)
    end
end

--- Reads the stock back from the FARP warehouse: what the players took is gone. A count that went up
-- was refilled by someone else (VMCT's GRASS refills every FARP on each player birth, evening run
-- 2026-10-26): the cow keeps its own count, and the next write puts it back. What was taken between
-- the last read and such a refill is not seen, so the stock stays at most what it was at that read.
function CTLDFatCow:readWarehouse(w)
    self.stock.fuelKg = math.min(self.stock.fuelKg, w:getLiquidAmount(JET_FUEL) or 0)
    for name, count in pairs(self.stock.items) do
        self.stock.items[name] = math.min(count, w:getItemCount(name) or 0)
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

--- What the players read for a warehouse item; an item not listed shows its DCS name.
-- Literal ctld.tr calls, so the dictionary generator sees each label.
local function itemLabel(name)
    if name == "weapons.missiles.AGM_114K" then return ctld.tr("laser Hellfire") end
    if name == "weapons.missiles.AGM_114" then return ctld.tr("radar Hellfire") end
    if name == "weapons.shells.M230_HEDP M789" then return ctld.tr("30 mm rounds") end
    if name == "weapons.missiles.Vikhr_M" then return ctld.tr("Vikhr") end
    if name == "weapons.missiles.Ataka_9M120" then return ctld.tr("Ataka") end
    if name == "weapons.missiles.AT_6" then return ctld.tr("Shturm") end
    if name == "weapons.shells.2A42_30_HE" then return ctld.tr("2A42 HE rounds") end
    if name == "weapons.shells.2A42_30_AP" then return ctld.tr("2A42 AP rounds") end
    if name == "weapons.shells.GSh_30_2K_HE" then return ctld.tr("GSh-30 rounds") end
    return (name:gsub("^weapons%.[%a_]+%.", ""))
end

--- "2400 kg of fuel, laser Hellfire x4" — for the players.
function CTLDFatCow.describeStock(stock)
    local parts = { ctld.tr("%1 kg of fuel", math.floor((stock.fuelKg or 0) + 0.5)) }
    local names = {}
    for name in pairs(stock.items or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        parts[#parts + 1] = string.format("%s x%d", itemLabel(name), stock.items[name])
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
    self._cows      = {}   -- unit name → CTLDFatCow
    self._farpNames = {}   -- unit name → the name of its FARP, kept across deployments
    self._freeFarps = {}   -- FARP names of AI cows gone, for the next cow to reuse
end

--- The cow's own FARP name: one heliport per cow, added again at each deployment and never destroyed.
-- "CTLD_" so other scripts can tell a cow FARP from a mission FARP. A name an AI cow left is reused,
-- so the map does not gain an empty FARP with every cow requested.
function CTLDFatCowManager:_farpNameFor(unitName)
    if not self._farpNames[unitName] then
        local name = table.remove(self._freeFarps)
        if not name then
            self._farpCounter = (self._farpCounter or 0) + 1
            name = string.format("CTLD_FatCow_FARP_%d", self._farpCounter)
        end
        self._farpNames[unitName] = name
    end
    return self._farpNames[unitName]
end

--- An AI cow is gone for good (despawned or dead): its FARP name goes back to the pool.
function CTLDFatCowManager:_releaseFarpName(unitName)
    local name = self._farpNames[unitName]
    if not name then return end
    self._farpNames[unitName] = nil
    self._freeFarps[#self._freeFarps + 1] = name
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
-- @return true, or false and a reason: "unknown", "airborne", "deployed", "empty", "scene" (not started),
-- "failed" (its FARP or fuel depot could not be added: the cow is stowed and its audience told)
function CTLDFatCowManager:deploy(unit)
    local cow = self._cows[unit:getName()]
    if not cow then return false, "unknown" end
    if unit:inAir() then return false, "airborne" end
    if cow.state ~= CTLDFatCow.STATE_STOWED then return false, "deployed" end
    if cow:isEmpty() then return false, "empty" end
    cow.state = CTLDFatCow.STATE_DEPLOYING
    local scene = CTLDSceneManager.getInstance():playScene(unit, CTLDFatCowManager.SCENE_NAME,
        { fatCow = cow, farpName = self:_farpNameFor(cow.unitName) })
    if not scene then
        cow.state = CTLDFatCow.STATE_STOWED
        return false, "scene"
    end
    -- The first step runs at once: a FARP that could not be added has already stowed the cow and said so.
    if cow.state == CTLDFatCow.STATE_STOWED then return false, "failed" end
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
        self:onSceneFailed(scene)
        return
    end
    cow:writeWarehouse(w)
    cow.state = CTLDFatCow.STATE_DEPLOYED
    ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' deployed, FARP '%s', %d kg of fuel",
        cow.unitName, cow.farpName, cow.stock.fuelKg)
    self:_notify(cow, ctld.tr("Fat Cow FARP open: %1", CTLDFatCow.describeStock(cow.stock)))
end

--- Called by the scene when its FARP or its fuel depot could not be added: the cow is stowed again
-- (its FARP, if added, stays empty).
function CTLDFatCowManager:onSceneFailed(scene)
    local cow = scene._params and scene._params.fatCow
    if not cow then return end
    CTLDSceneManager.getInstance():packScene(scene)
    local w = warehouseOf(scene._params.farpName)
    if w then CTLDFatCow.emptyAnyWarehouse(w) end
    cow.scene, cow.farpName = nil, nil
    cow.state = CTLDFatCow.STATE_STOWED
    ctld.utils.log("ERROR", "CTLDFatCowManager: FARP of cow '%s' not added", cow.unitName)
    self:_notify(cow, ctld.tr("The Fat Cow FARP could not be deployed."))
end

--- Tells the cow's audience (its own group when piloted, the escorted flight when AI).
function CTLDFatCowManager:_notify(cow, text)
    if cow.notifyGroupId then
        trigger.action.outTextForGroup(cow.notifyGroupId, text, 15)
    end
end

--- Reads what the players left back into the stock, empties the FARP, then removes the scene (the
-- FARP itself stays: see the scene's first step).
-- @return true when a deployed cow was packed
function CTLDFatCowManager:pack(unitName)
    local cow = self._cows[unitName]
    if not cow or cow.state == CTLDFatCow.STATE_STOWED then return false end
    if cow.state == CTLDFatCow.STATE_DEPLOYED then
        local w = warehouseOf(cow.farpName)
        if w then
            cow:readWarehouse(w)
            cow:emptyWarehouse(w)
        end
    else
        -- Still laying out: the FARP may exist already, its warehouse never written. Emptied, not read.
        local w = warehouseOf(cow.scene and cow.scene._params and cow.scene._params.farpName)
        if w then CTLDFatCow.emptyAnyWarehouse(w) end
    end
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

--- S_EVENT_BIRTH: a player arriving gets every cow FARP re-written (see _resyncFarps), now and again a
-- moment later: a script refilling FARPs on the same birth (VMCT) may run before or after CTLD.
function CTLDFatCowManager:onBirth(event)
    if self._started and next(ctld.gs("fatCowAICows") or {}) then self:_activateMissionCows() end
    local obj = event and event.initiator
    if not (obj and obj.getPlayerName) then return end
    local ok, playerName = pcall(obj.getPlayerName, obj)
    if not (ok and playerName) then return end
    -- A pilot taking the slot of a piloted cow whose FARP was left open (its pilot left the slot): the
    -- FARP closes, emptied, so the new pilot starts from a clean hold instead of "already deployed"
    -- and a pack that no longer finds the previous pilot's crates.
    local name = ctld.utils.safeObjectName(obj)
    local left = name and self._cows[name]
    if left and left.crates then self:removeCow(name) end
    self:_resyncFarps()
    local mgr = self
    ctld.scheduler.schedule(function() mgr:_resyncFarps() end, nil, timer.getTime() + 2)
end

-- How often every cow FARP is read and re-written: a refill run before CTLD reads hides what was taken
-- since the last read (see readWarehouse), so the reads are kept close together.
local RESYNC_PERIOD_S = 10
-- How often the "Take over a Fat Cow" entries are rebuilt, their distances with them, while there are any.
local TAKE_OVER_REFRESH_S = 30

--- Every cow FARP: an open one gets its stock read and written back (see resyncWarehouse), any other is
-- emptied (it stays in the world, and a refill would make it serve next to another cow's depot).
function CTLDFatCowManager:_resyncFarps()
    self:_forgetVanishedCows()
    local open = {}
    for _, cow in pairs(self._cows) do
        if cow.state == CTLDFatCow.STATE_DEPLOYED then
            open[cow.farpName or ""] = true
            local w = warehouseOf(cow.farpName)
            if w then cow:resyncWarehouse(w) end
        elseif cow.state == CTLDFatCow.STATE_DEPLOYING then
            open[(cow.scene and cow.scene._params and cow.scene._params.farpName) or ""] = true
        end
    end
    local names = {}
    for _, name in pairs(self._farpNames) do names[#names + 1] = name end
    for _, name in ipairs(self._freeFarps) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        if not open[name] then
            local w = warehouseOf(name)
            if w then CTLDFatCow.emptyAnyWarehouse(w) end
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
    local mgr = self
    ctld.scheduler.register("fatCow_resync", ctld.scheduler.schedule(function(_, now)
        mgr:_resyncFarps()
        return now + RESYNC_PERIOD_S
    end, nil, timer.getTime() + RESYNC_PERIOD_S))
    ctld.scheduler.register("fatCow_takeOverMenus", ctld.scheduler.schedule(function(_, now)
        mgr:_refreshTakeOverMenus()
        return now + TAKE_OVER_REFRESH_S
    end, nil, timer.getTime() + TAKE_OVER_REFRESH_S))
    pcall(self._logFarpWarehouses, self)
    ctld.utils.log("INFO", "CTLDFatCowManager: started, %d cow crate type(s)", #self._crateDescs)
end

--- One log line per mission FARP (10 at most): what DCS reports for its warehouse. A measurement, before
-- "FARP status" covers every FARP and not only Fat Cow ones: what an unlimited warehouse reads as is unknown.
function CTLDFatCowManager:_logFarpWarehouses()
    local n = 0
    for _, ab in ipairs(world.getAirbases() or {}) do
        local okD, desc = pcall(ab.getDesc, ab)
        if okD and desc and desc.category == Airbase.Category.HELIPAD and n < 10 then
            n = n + 1
            local okW, w = pcall(ab.getWarehouse, ab)
            if okW and w then
                local okI, inv = pcall(w.getInventory, w)
                local nW = 0
                for _ in pairs(okI and inv and inv.weapon or {}) do nW = nW + 1 end
                ctld.utils.log("INFO", "CTLDFatCowManager: FARP warehouse '%s': jet fuel %s, AGM_114K %s, %d weapon type(s)",
                    ab:getName(), tostring(w:getLiquidAmount(0)), tostring(w:getItemCount("weapons.missiles.AGM_114K")), nW)
            end
        end
    end
end

--- Turns fatCowCrates into crate descriptors the crate system knows (indexed by weight, as every
-- crate is), but keeps them out of the shared Request Equipment menu: the cow requests its own.
function CTLDFatCowManager:_injectCrateDescriptors()
    local cm = CTLDCrateManager.getInstance()
    self._crateDescs = {}
    self._kgPerItem  = {}
    for _, def in ipairs(ctld.gs("fatCowCrates") or {}) do
        local content = ((def.fuelKg or 0) > 0 and { fuelKg = def.fuelKg })
                     or (def.item and (def.count or 0) > 0 and { item = def.item, count = def.count })
        if not (content and def.desc and (def.weight or 0) > 0) then
            ctld.utils.log("WARN", "CTLDFatCowManager: fatCowCrates entry '%s' ignored: it needs desc, weight, and fuelKg or item + count",
                tostring(def.desc))
        else
            if content.item then self._kgPerItem[content.item] = def.weight / content.count end
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

--- In a friendly logistic zone that serves crates, on the ground: true, or false after telling why.
local function atLogistics(t, gid)
    if ctld.utils.inAir(t) then
        trigger.action.outTextForGroup(gid, ctld.tr("You must be landed to request a crate."), 10)
        return false
    end
    local zones = CTLDZoneManager.getInstance():getLogisticZonesAtPoint(t:getPoint(), t:getCoalition(), "cratesPickup")
    if not next(zones) then
        trigger.action.outTextForGroup(gid, ctld.tr("You are not close enough to friendly logistics to get a crate!"), 10)
        return false
    end
    return true
end

--- Splits a fatCowLoadouts entry into the cow crates that carry it: its fuel into fuel tanks, each item
-- into the crates of that item, every crate full but the last of each kind. Matching by content, not by
-- crate name: CTLDConfig translates every desc (evening run, 2026-10-26: refused on the French server).
-- @return list of { desc, content, fraction }, or nil and what no crate carries
function CTLDFatCowManager:cratesForLoadout(loadout)
    local fuelDesc, itemDesc = nil, {}
    for _, d in ipairs(self._crateDescs or {}) do
        if d.fatCow.fuelKg then
            fuelDesc = fuelDesc or d
        else
            itemDesc[d.fatCow.item] = itemDesc[d.fatCow.item] or d
        end
    end
    local out = {}
    local function split(d, total, makeContent, capacity)
        while total > 0 do
            local n = math.min(capacity, total)
            out[#out + 1] = { desc = d, content = makeContent(n), fraction = n / capacity }
            total = total - n
        end
    end
    if (loadout.fuelKg or 0) > 0 then
        if not fuelDesc then return nil, "fuel" end
        split(fuelDesc, loadout.fuelKg, function(n) return { fuelKg = n } end, fuelDesc.fatCow.fuelKg)
    end
    for _, it in ipairs(loadout.items or {}) do
        local d = itemDesc[it.item]
        if not d then return nil, tostring(it.item) end
        split(d, it.count or 0, function(n) return { item = it.item, count = n } end, d.fatCow.count)
    end
    return out
end

--- F10 "Load" > a loadout: a fatCowLoadouts entry, straight into the hold.
function CTLDFatCowManager:loadLoadout(unitName, index)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid = ctld.utils.getGroupId(t)
    local loadout = (ctld.gs("fatCowLoadouts") or {})[index]
    if not (loadout and atLogistics(t, gid)) then return end
    local wanted, missing = self:cratesForLoadout(loadout)
    if not wanted then
        ctld.utils.log("WARN", "CTLDFatCowManager: loadout '%s' needs '%s', which no fatCowCrates entry carries",
            tostring(loadout.desc), missing)
        trigger.action.outTextForGroup(gid, ctld.tr("This loadout cannot be loaded."), 10)
        return
    end
    local cm       = CTLDCrateManager.getInstance()
    local caps     = (ctld.gs("capabilitiesByType") or {})[t:getTypeName()] or {}
    local capacity = caps.maxCratesOnboard or 1
    local onboard  = #cm:cratesOnboard(unitName)
    if onboard + #wanted > capacity then
        trigger.action.outTextForGroup(gid,
            ctld.tr("Not enough room: %1 crate(s) on board, %2 more needed, %3 at most.", onboard, #wanted, capacity), 10)
        return
    end
    local loaded = {}
    for _, w in ipairs(wanted) do
        local crate = cm:loadIntoHold(w.desc, t, unitName)
        if w.fraction < 1 then
            crate.metadata.fatCow = w.content
            crate.metadata.massKg = w.desc.weight * w.fraction
        end
        loaded[#loaded + 1] = crate
    end
    ctld.utils.updateTransportWeight(unitName)
    trigger.action.outTextForGroup(gid,
        ctld.tr("Loaded into your hold: %1", CTLDFatCow.describeStock(CTLDFatCow.stockOfCrates(loaded))), 10)
end

--- F10 "Unload the Fat Cow crates": back to the logistic zone, to make up another loadout.
function CTLDFatCowManager:unloadHold(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid = ctld.utils.getGroupId(t)
    local cow = self._cows[unitName]
    if cow and cow.state ~= CTLDFatCow.STATE_STOWED then
        trigger.action.outTextForGroup(gid, ctld.tr("The Fat Cow FARP is already deployed."), 10)
        return
    end
    if not atLogistics(t, gid) then return end
    local cm = CTLDCrateManager.getInstance()
    local crates = cowCratesOnboard(unitName)
    for _, crate in ipairs(crates) do cm:destroyCrate(crate.crateName) end
    ctld.utils.updateTransportWeight(unitName)
    trigger.action.outTextForGroup(gid, ctld.tr("%1 Fat Cow crate(s) unloaded.", #crates), 10)
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
        if why == "failed" then return end   -- onSceneFailed has said so
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
    if name and self._cows[name] then self:_cowGone(name) end
    self:_checkFlightsLater()
end

--- A cow is gone for good: its FARP is packed and, for an AI cow, its name released and its flight freed.
function CTLDFatCowManager:_cowGone(name)
    local cow   = self._cows[name]
    local wasAI = cow.ai ~= nil
    self:removeCow(name)
    self:_forgetAICow(name)
    if wasAI then self:_releaseFarpName(name) end   -- a piloted slot keeps its FARP for the next pilot
    if wasAI and self:_isTakeable(cow) then self:_rebuildMenus(cow.coalitionId) end
end

--- An AI cow whose unit is no longer in the world is gone, event or not: one that struck a tree landing
-- fired S_EVENT_HIT and S_EVENT_KILL, never S_EVENT_DEAD, S_EVENT_CRASH nor S_EVENT_UNIT_LOST, and stayed
-- registered, its flight refused another cow (FIX-FAT-COW-AI-LANDING, 2026-10-30).
function CTLDFatCowManager:_forgetVanishedCows()
    local gone = {}
    for name, cow in pairs(self._cows) do
        local u = cow.ai and Unit.getByName(name)
        if cow.ai and not (u and u:isExist()) then gone[#gone + 1] = name end
    end
    for _, name in ipairs(gone) do
        ctld.utils.log("WARN", "CTLDFatCowManager: cow '%s' is no longer in the world, with no event: forgotten", name)
        self:_cowGone(name)
    end
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
            self:_returnHome(cow, true)
        end
    end
end

-- ── Menu section ────────────────────────────────────────────────────────────────────────────────

--- One command per fatCowLoadouts entry under `path`, calling manager method `method`(unitName, index):
-- the entries without a `menu` at the top (the Apache ones), the others in the Russian and Mixed
-- submenus (Zip: one CH-47 for everyone, the Russian and mixed loadouts one level down).
function CTLDFatCowManager:_addLoadoutCommands(menu, path, unitName, method)
    local subs = { russian = { ctld.tr("Russian"), 98 }, mixed = { ctld.tr("Mixed"), 99 } }
    local made = {}
    local mgr = CTLDFatCowManager.getInstance
    for i, l in ipairs(ctld.gs("fatCowLoadouts") or {}) do
        local where, sub = path, l.menu and subs[l.menu]
        if l.menu and not sub then
            ctld.utils.log("WARN", "CTLDFatCowManager: loadout '%s' has an unknown menu '%s': shown at the top",
                tostring(l.desc), tostring(l.menu))
        end
        if sub then
            where = {}
            for k, v in ipairs(path) do where[k] = v end
            where[#where + 1] = sub[1]
            if not made[l.menu] then
                menu:addSubMenu(path, sub[1], { order = sub[2] })
                made[l.menu] = true
            end
        end
        menu:addCommand(where, ctld.tr(l.desc or "?"),
            function(arg) local m = mgr(); m[arg.method](m, arg.unitName, arg.index) end,
            { unitName = unitName, index = i, method = method }, { order = i })
    end
end

function CTLDFatCowManager:buildMenuSection(playerObj, menu)
    local root, sub = ctld.tr("CTLD"), ctld.tr("Fat Cow")
    local path = { root, sub }
    if playerObj.isTransport and self:isCowType(playerObj.typeName) then
        menu:addSubMenu({ root }, sub, { order = 50 })
        local mgr = CTLDFatCowManager.getInstance
        local loadPath, cratePath = { root, sub, ctld.tr("Load") }, { root, sub, ctld.tr("Request a crate") }
        menu:addSubMenu(path, loadPath[3], { order = 1 })
        self:_addLoadoutCommands(menu, loadPath, playerObj.unitName, "loadLoadout")
        menu:addSubMenu(path, cratePath[3], { order = 2 })
        for i, d in ipairs(self._crateDescs or {}) do
            menu:addCommand(cratePath, d.desc,
                function(arg) mgr():requestCrate(arg.unitName, arg.weight) end,
                { unitName = playerObj.unitName, weight = d.weight }, { order = i })
        end
        menu:addCommand(path, ctld.tr("Unload the Fat Cow crates"),
            function(arg) mgr():unloadHold(arg.unitName) end, { unitName = playerObj.unitName }, { order = 19 })
        menu:addCommand(path, ctld.tr("Deploy the Fat Cow FARP"),
            function(arg) mgr():deployFromHold(arg.unitName) end, { unitName = playerObj.unitName }, { order = 20 })
        menu:addCommand(path, ctld.tr("Pack the Fat Cow FARP"),
            function(arg) mgr():packIntoHold(arg.unitName) end, { unitName = playerObj.unitName }, { order = 21 })
        menu:addCommand(path, ctld.tr("Fat Cow stock"),
            function(arg) mgr():reportStock(arg.unitName) end, { unitName = playerObj.unitName }, { order = 22 })
        menu:addCommand(path, ctld.tr("FARP status"),
            function(arg) mgr():reportFarpStatus(arg.unitName) end, { unitName = playerObj.unitName }, { order = 23 })
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

-- Internal fuel given to a scripted cow: 80 % of the CH-47Fbl1's M_fuel_max (3054.6 kg in DCS's
-- db.Units.lua), what a CH-47 usually flies with (Zip); the loadouts are sized for it. A scripted
-- aircraft created without fuel falls out of the sky.
local AI_COW_FUEL_KG   = 2444
local FOLLOW_OFFSET    = { x = -200, y = 60, z = 150 }   -- behind, above and to the right of the leader
local LAND_OFFSET_M    = 120                              -- landing point, to the leader's left
-- The clearing searched around it, within VMCT's helicopter search radius (veafAircraftSpawn
-- HELICOPTER_LZ_SEARCH, veaf.SPAWN_SEARCH_ATTEMPTS), and never on the leader. The clearance descends as
-- veaf.findSpawnPoint's does: the widest first. 30 m (VMCT's HELICOPTER_LZ_CLEARANCE, for a Mi-8) put the
-- cow next to the only tree of an open field, which a CH-47 drifting down at 3 m/s struck (2026-10-30).
local LZ_SEARCH_M          = 300
local LZ_CLEARANCES_M      = { 100, 50, 30 }
local LZ_ATTEMPTS          = 10
local LZ_MIN_FROM_LEADER_M = 60
local CRUISE_SPEED_MPS = 60
local CRUISE_ALT_M     = 150
local ORBIT_SPEED_MPS  = 40
-- Cruise speed used for the joining estimate: an assumption (about 235 km/h), to check in game.
local AI_COW_CRUISE_MPS = 65
-- How long a Land task keeps the cow down: a day, so it never lifts off on its own while serving.
-- The flight's take-off or a release re-tasks it long before.
local LAND_DURATION_S  = 86400
-- How far from its home point a returning cow may land and be despawned: the Land task puts it down
-- on the point itself.
local HOME_RADIUS_M    = 2000

--- The stock of a fatCowLoadouts entry, or nil when there is no such entry.
local function loadoutStock(index)
    local l = (ctld.gs("fatCowLoadouts") or {})[index]
    if not l then return nil end
    local stock = { fuelKg = l.fuelKg or 0, items = {} }
    for _, it in ipairs(l.items or {}) do
        if it.item and it.count then stock.items[it.item] = (stock.items[it.item] or 0) + it.count end
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

-- What a stock weighs: its fuel, and each item at its crate's mass per item (50 kg for an item no
-- crate carries, about a missile).
function CTLDFatCowManager:massOf(stock)
    local kg = stock.fuelKg or 0
    for item, count in pairs(stock.items) do
        kg = kg + count * ((self._kgPerItem or {})[item] or 50)
    end
    return kg
end

local function setCargoMass(cow)
    pcall(trigger.action.setUnitInternalCargo, cow.unitName, CTLDFatCowManager.getInstance():massOf(cow.stock))
end

--- Registers an AI cow already in the world.
-- @param groupName    string  the cow's group
-- @param flightGroup  string  the group it escorts
-- @param homePoint    vec3    where it goes back to despawn
-- @param loadoutIndex number  the fatCowLoadouts entry it carries
function CTLDFatCowManager:addAICow(groupName, flightGroup, homePoint, loadoutIndex)
    local unit  = firstUnitOf(groupName)
    local stock = loadoutStock(loadoutIndex)
    if not (unit and stock) then return nil end
    local cow = self:addCow(unit, stock)
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

--- The nearest point to `point` within LZ_SEARCH_M, `clearance` clear of scenery, on land and
-- LZ_MIN_FROM_LEADER_M from the leader, or nil (none, or the call failed).
local function clearingAt(point, leaderPoint, clearance)
    local ok, candidates = pcall(Disposition.getSimpleZones, point, LZ_SEARCH_M, clearance, LZ_ATTEMPTS)
    if not (ok and type(candidates) == "table") then return nil end
    local best, bestD
    for _, c in ipairs(candidates) do
        -- A candidate may be a vec2, whose y is the map's z (VMCT's horizontalDistance convention).
        local q = type(c) == "table" and c.x and { x = c.x, z = c.z or c.y }
        if q and q.z then
            local d = math.sqrt((q.x - point.x) ^ 2 + (q.z - point.z) ^ 2)
            local fromLeader = math.sqrt((q.x - leaderPoint.x) ^ 2 + (q.z - leaderPoint.z) ^ 2)
            local okS, s = pcall(land.getSurfaceType, { x = q.x, y = q.z })
            local wet = okS and (s == land.SurfaceType.WATER or s == land.SurfaceType.SHALLOW_WATER)
            if d <= LZ_SEARCH_M and fromLeader >= LZ_MIN_FROM_LEADER_M and not wet and (not bestD or d < bestD) then
                best, bestD = q, d
            end
        end
    end
    return best and { x = best.x, y = land.getHeight({ x = best.x, y = best.z }), z = best.z }
end

--- Where a cow lands near `point`: the nearest clearing with the widest clearance of LZ_CLEARANCES_M that
-- offers one, else `point`. Searched with Disposition.getSimpleZones, the undocumented DCS singleton VMCT's
-- veaf.findSpawnPoint lands its helicopters with (measured 2026-08-06: its points avoid buildings and
-- forests), so guarded: an absent singleton or an error keeps `point`. The cow sent 120 m left of its
-- leader struck a tree there (FIX-FAT-COW-AI-LANDING, 2026-10-30).
local function clearLandingPoint(point, leaderPoint)
    if not (Disposition and Disposition.getSimpleZones) then return point end
    for _, clearance in ipairs(LZ_CLEARANCES_M) do
        local q = clearingAt(point, leaderPoint, clearance)
        if q then return q end
    end
    return point
end

function CTLDFatCowManager:_landNextTo(cow, leader)
    local ctrl = controllerOf(cow.ai.groupName)
    if not ctrl then return end
    local p   = leader:getPoint()
    local hdg = ctld.utils.getHeadingInRadians("CTLDFatCowManager", leader, true)
    local left = hdg - math.pi / 2
    local asked = { x = p.x + math.cos(left) * LAND_OFFSET_M, y = p.y, z = p.z + math.sin(left) * LAND_OFFSET_M }
    local point = clearLandingPoint(asked, p)
    if point ~= asked then
        ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' lands in a clearing %d m from the asked point",
            cow.unitName, math.floor(math.sqrt((point.x - asked.x) ^ 2 + (point.z - asked.z) ^ 2) + 0.5))
    end
    ctrl:setTask(landMission(point))
    cow.ai.phase = CTLDFatCowManager.PHASE_LANDING
end

-- @param orphaned boolean  its flight is lost: the flights that could take it over are told
function CTLDFatCowManager:_returnHome(cow, orphaned)
    self:_cancelDeploy(cow)
    if cow.state ~= CTLDFatCow.STATE_STOWED then self:pack(cow.unitName) end
    local ctrl = controllerOf(cow.ai.groupName)
    if ctrl and cow.ai.home then ctrl:setTask(landMission(cow.ai.home)) end
    cow.ai.phase = CTLDFatCowManager.PHASE_RETURNING
    if self._aiByFlight then self._aiByFlight[cow.ai.flightGroup] = nil end
    if orphaned then self:_announceOrphan(cow) end
    self:_rebuildMenus(cow.coalitionId)
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
            -- Only a landing at home is the arrival: DCS also fires one when a cow on the ground is
            -- re-tasked to go home (Marteau du Golan, 2026-10-29: despawned on the spot, 0.98 s later).
            local d = cow.ai.home and ctld.utils.getDistance("CTLDFatCowManager", unit:getPoint(), cow.ai.home)
            if d and d > HOME_RADIUS_M then
                ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' landed %d m from home: not despawned",
                    name, math.floor(d))
                return
            end
            local g = Group.getByName(cow.ai.groupName)
            self._cows[name] = nil
            self:_releaseFarpName(name)
            if g and g:isExist() then g:destroy() end
            self:_rebuildMenus(cow.coalitionId)
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

--- Distance in metres from `me` to `it`, and the bearing to it in whole degrees.
local function rangeAndBearing(me, it)
    local d = ctld.utils.getDistance("CTLDFatCowManager", me, it)
    return d, math.floor((math.deg(math.atan2(it.z - me.z, it.x - me.x)) + 360) % 360 + 0.5)
end

--- F10 "Request a Fat Cow" > a loadout, from anywhere: it takes off from the friendly logistic zone
-- nearest to the requester, carrying that fatCowLoadouts entry, and joins the flight. One cow per flight.
function CTLDFatCowManager:requestAICow(unitName, loadoutIndex)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid    = ctld.utils.getGroupId(t)
    local flight = t:getGroup():getName()
    if self:aiCowOfFlight(flight) then
        trigger.action.outTextForGroup(gid, ctld.tr("Your flight already has a Fat Cow."), 10)
        return
    end
    if not loadoutStock(loadoutIndex) then return end
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
        local cow = mgr:addAICow(groupName, flight, home, loadoutIndex)
        if cow then cow.ai.homeName = zoneName end
    end, nil, timer.getTime() + 1)
    trigger.action.outTextForGroup(gid,
        ctld.tr("Fat Cow on its way from %1: %2 km, joining in about %3 min. Land here, Take off, Hold here and Join us command it.",
            zoneName, math.floor(distance / 1000 + 0.5), etaMinutes(distance)), 15)
end

--- F10 "RTB": it packs and goes home.
function CTLDFatCowManager:releaseAICow(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local cow = self:aiCowOfFlight(t:getGroup():getName())
    if not cow then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Your flight has no Fat Cow."), 10)
        return
    end
    self:_returnHome(cow)
    trigger.action.outTextForGroup(ctld.utils.getGroupId(t), ctld.tr("Fat Cow RTB."), 10)
end

--- F10 "Release the Fat Cow": it leaves the flight where it stands, for another flight to take over. On the
-- ground it keeps its FARP open; in the air it orbits there.
function CTLDFatCowManager:freeAICow(unitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid = ctld.utils.getGroupId(t)
    local cow, u = self:_flightCowFor(t)
    if not cow then return end
    self._aiByFlight[cow.ai.flightGroup] = nil
    cow.ai.released = true
    if u:inAir() and cow.ai.phase ~= CTLDFatCowManager.PHASE_LANDING then self:_orbit(cow, u:getPoint()) end
    trigger.action.outTextForGroup(gid, ctld.tr("Fat Cow released: it stays where it is, for another flight to take over."), 10)
    self:_announceOrphan(cow, true)
    self:_rebuildMenus(cow.coalitionId)
end

-- ── Taking over a free cow (FEAT-FAT-COW-TAKEOVER) ─────────────────────────────────────────────
-- A cow going home (sent with RTB or after losing its flight, empty or not) until it has landed there, or
-- one its flight released where it stands, can be taken over by a helicopter flight with no cow: F10
-- "Take over a Fat Cow" lists those of the coalition, nearest first. A cow that lost its flight, or was
-- released, also tells those flights.

--- True when the player flies a helicopter.
local function isHelicopter(p)
    local u = Unit.getByName(p.unitName)
    if not (u and u:isExist()) then return false end
    local ok, desc = pcall(u.getDesc, u)
    return ok and desc and desc.category == Unit.Category.HELICOPTER or false
end

--- True when the player may take a cow over: a helicopter of its coalition that sees the AI Fat Cow menu
-- (not a cow pilot), in a flight with no cow.
function CTLDFatCowManager:_mayTakeOver(p, coalitionId)
    return p.coalition == coalitionId and not self:aiCowOfFlight(p.groupName)
        and not (p.isTransport and self:isCowType(p.typeName)) and isHelicopter(p)
end

--- The player flights of a coalition that may take a cow over, one player of each.
-- @return list of CTLDPlayer
function CTLDFatCowManager:_takeOverCandidates(coalitionId)
    local out, seen = {}, {}
    for _, p in pairs(CTLDPlayerManager.getInstance()._players) do
        if not seen[p.groupName] and self:_mayTakeOver(p, coalitionId) then
            seen[p.groupName] = true
            out[#out + 1] = p
        end
    end
    return out
end

--- True when another flight may take the cow over: it is going home, or was released.
function CTLDFatCowManager:_isTakeable(cow)
    return cow.ai ~= nil and (cow.ai.phase == CTLDFatCowManager.PHASE_RETURNING or cow.ai.released == true)
end

--- The cows of a coalition another flight may take over, nearest to `point` first.
-- @return list of { cow, d } (d in metres)
function CTLDFatCowManager:_takeableCows(coalitionId, point)
    local out = {}
    for _, cow in pairs(self._cows) do
        local u = self:_isTakeable(cow) and cow.coalitionId == coalitionId and Unit.getByName(cow.unitName)
        if u and u:isExist() then
            out[#out + 1] = { cow = cow, d = ctld.utils.getDistance("CTLDFatCowManager", point, u:getPoint()) }
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

--- Rebuilds the menus of a coalition's players: "Take over a Fat Cow" comes, goes, or updates.
-- @param onlyCandidates boolean  only the players who may take a cow over (the periodic distance update)
function CTLDFatCowManager:_rebuildMenus(coalitionId, onlyCandidates)
    local pm = CTLDPlayerManager.getInstance()
    for _, p in pairs(pm._players) do
        if p.coalition == coalitionId and (not onlyCandidates or self:_mayTakeOver(p, coalitionId)) then
            pm:buildMenu(p)
        end
    end
end

--- The periodic update: the menus of whoever sees a cow going home get its distance again.
function CTLDFatCowManager:_refreshTakeOverMenus()
    local done = {}
    for _, cow in pairs(self._cows) do
        if self:_isTakeable(cow) and not done[cow.coalitionId] then
            done[cow.coalitionId] = true
            self:_rebuildMenus(cow.coalitionId, true)
        end
    end
end

--- One flight's message: where the cow is from its player, what it carries, how to take it.
function CTLDFatCowManager:_announceTo(p, cow, it, stock, released)
    local t = Unit.getByName(p.unitName)
    local d, bearing = rangeAndBearing(t:getPoint(), it)
    local km = string.format("%.1f", d / 1000)
    local text = released
        and ctld.tr("A Fat Cow was released and waits for a flight: %1 km at %2° from you, with %3. F10 CTLD > Fat Cow > Take over a Fat Cow makes it yours.",
            km, bearing, stock)
        or cow.ai.homeName
        and ctld.tr("A Fat Cow lost its flight and is going home to %1: %2 km at %3° from you, with %4. F10 CTLD > Fat Cow > Take over a Fat Cow makes it yours.",
            cow.ai.homeName, km, bearing, stock)
        or ctld.tr("A Fat Cow lost its flight and is going home: %1 km at %2° from you, with %3. F10 CTLD > Fat Cow > Take over a Fat Cow makes it yours.",
            km, bearing, stock)
    trigger.action.outTextForGroup(p.groupId, text, 20)
end

--- Tells each flight that could take the cow over where it is from them and what it carries.
-- @param released boolean  its flight let it go where it stands (else: it lost its flight, going home)
function CTLDFatCowManager:_announceOrphan(cow, released)
    local u = Unit.getByName(cow.unitName)
    if not (u and u:isExist()) then return end
    local it    = u:getPoint()
    local stock = CTLDFatCow.describeStock(cow.stock)
    for _, p in ipairs(self:_takeOverCandidates(cow.coalitionId)) do
        if p.groupName ~= cow.ai.flightGroup then self:_announceTo(p, cow, it, stock, released) end
    end
    ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' %s flight '%s', offered for take-over",
        cow.unitName, released and "released by" or "lost", cow.ai.flightGroup)
end

--- F10 "Take over a Fat Cow" > a cow: that cow, if still free, joins the requester's flight.
function CTLDFatCowManager:takeOverAICow(unitName, cowUnitName)
    local t = Unit.getByName(unitName)
    if not (t and t:isExist()) then return end
    local gid    = ctld.utils.getGroupId(t)
    local flight = t:getGroup():getName()
    if self:aiCowOfFlight(flight) then
        trigger.action.outTextForGroup(gid, ctld.tr("Your flight already has a Fat Cow."), 10)
        return
    end
    local cow = self._cows[cowUnitName]
    local u   = cow and self:_isTakeable(cow) and Unit.getByName(cowUnitName)
    if not (u and u:isExist()) then
        trigger.action.outTextForGroup(gid, ctld.tr("This Fat Cow is no longer available."), 10)
        return
    end
    local d = ctld.utils.getDistance("CTLDFatCowManager", t:getPoint(), u:getPoint())
    ctld.utils.log("INFO", "CTLDFatCowManager: cow '%s' taken over by flight '%s' (was '%s')",
        cow.unitName, flight, cow.ai.flightGroup)
    cow.ai.flightGroup = flight
    cow.ai.released    = nil
    self._aiByFlight = self._aiByFlight or {}
    self._aiByFlight[flight] = cow
    self:_readyToMove(cow)
    self:_follow(cow)
    trigger.action.outTextForGroup(gid,
        ctld.tr("Fat Cow joining your flight: %1 km, in about %2 min, with %3.",
            string.format("%.1f", d / 1000), etaMinutes(d), CTLDFatCow.describeStock(cow.stock)), 15)
    self:_rebuildMenus(cow.coalitionId)
end

--- The "Take over a Fat Cow" submenu: one entry per cow going home, nearest first, with its distance.
function CTLDFatCowManager:_addTakeOverCommands(playerObj, menu, path)
    if not self:_mayTakeOver(playerObj, playerObj.coalition) then return end
    local cows = self:_takeableCows(playerObj.coalition, Unit.getByName(playerObj.unitName):getPoint())
    if #cows == 0 then return end
    local sub = { path[1], path[2], ctld.tr("Take over a Fat Cow") }
    menu:addSubMenu(path, sub[3], { order = 10 })
    local mgr = CTLDFatCowManager.getInstance
    for i, c in ipairs(cows) do
        local km = math.floor(c.d / 1000 + 0.5)
        local label
        if c.cow.ai.released then
            label = ctld.tr("Fat Cow %1 km away, waiting", km)
        elseif c.cow.ai.homeName then
            label = ctld.tr("Fat Cow %1 km away, going home to %2", km, c.cow.ai.homeName)
        else
            label = ctld.tr("Fat Cow %1 km away, going home", km)
        end
        menu:addCommand(sub, label, function(arg) mgr():takeOverAICow(arg.unitName, arg.cow) end,
            { unitName = playerObj.unitName, cow = c.cow.unitName }, { order = i })
    end
end

function CTLDFatCowManager:_buildAIMenu(playerObj, menu, path)
    if ctld.gs("fatCowAIType") == "" then return end
    menu:addSubMenu({ path[1] }, path[2], { order = 50 })
    local mgr = CTLDFatCowManager.getInstance
    local u = { unitName = playerObj.unitName }
    local requestPath = { path[1], path[2], ctld.tr("Request a Fat Cow") }
    menu:addSubMenu(path, requestPath[3], { order = 1 })
    self:_addLoadoutCommands(menu, requestPath, playerObj.unitName, "requestAICow")
    menu:addCommand(path, ctld.tr("Land here"), function(arg) mgr():orderLandHere(arg.unitName) end, u, { order = 2 })
    menu:addCommand(path, ctld.tr("Take off"), function(arg) mgr():orderTakeOff(arg.unitName) end, u, { order = 3 })
    menu:addCommand(path, ctld.tr("Hold here"), function(arg) mgr():orderHoldHere(arg.unitName) end, u, { order = 4 })
    menu:addCommand(path, ctld.tr("Join us"), function(arg) mgr():orderJoin(arg.unitName) end, u, { order = 5 })
    menu:addCommand(path, ctld.tr("Fat Cow status"), function(arg) mgr():reportFlightCowStatus(arg.unitName) end, u, { order = 6 })
    menu:addCommand(path, ctld.tr("FARP status"), function(arg) mgr():reportFarpStatus(arg.unitName) end, u, { order = 7 })
    menu:addCommand(path, ctld.tr("RTB"), function(arg) mgr():releaseAICow(arg.unitName) end, u, { order = 8 })
    menu:addCommand(path, ctld.tr("Release the Fat Cow"), function(arg) mgr():freeAICow(arg.unitName) end, u, { order = 9 })
    self:_addTakeOverCommands(playerObj, menu, path)
end

-- Literal ctld.tr calls, so the dictionary generator sees each phase.
local function phaseText(cow)
    if cow.state == CTLDFatCow.STATE_DEPLOYED then return ctld.tr("FARP open") end
    local p = cow.ai.phase
    if p == CTLDFatCowManager.PHASE_HOLDING   then return ctld.tr("holding") end
    if p == CTLDFatCowManager.PHASE_FOLLOWING then return ctld.tr("following your flight") end
    if p == CTLDFatCowManager.PHASE_LANDING   then return ctld.tr("landing") end
    if p == CTLDFatCowManager.PHASE_LANDED    then return ctld.tr("on the ground") end
    if p == CTLDFatCowManager.PHASE_RETURNING then return ctld.tr("going home") end
    return tostring(p)
end

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
    local d, bearing = rangeAndBearing(t:getPoint(), u:getPoint())
    local lines   ={ ctld.tr("Fat Cow: %1, %2 km at %3°.", phaseText(cow), string.format("%.1f", d / 1000), bearing) }
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
-- Each entry { group = "<late-activated CH-47 group>", escort = "<flight group>", loadout = <index,
-- default 1> }. CTLD activates
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
    if not loadoutStock(entry.loadout or 1) then
        ctld.utils.log("ERROR", "CTLDFatCowManager: fatCowAICows entry '%s' names loadout %s, which fatCowLoadouts does not have: not activated",
            tostring(entry.group), tostring(entry.loadout or 1))
        return true
    end
    pcall(g.activate, g)
    local u = g:getUnit(1)
    local home = u and u:getPoint() or nil
    local mgr = self
    ctld.scheduler.schedule(function() mgr:addAICow(entry.group, entry.escort, home, entry.loadout or 1) end,
        nil, timer.getTime() + 1)
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
