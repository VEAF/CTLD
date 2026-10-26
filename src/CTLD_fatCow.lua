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
