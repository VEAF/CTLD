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
