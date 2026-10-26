---@diagnostic disable
-- tests/ci/unit/fatcow_core_spec.lua
-- FEAT-FAT-COW ticket 02: a cow's stock, written into its FARP warehouse on deploy, read back on pack.
-- ============================================================

local _root = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]unit[\\/]fatcow_core_spec%.lua$") or ""
dofile(_root .. "src/CTLD_fatCow.lua")

-- A warehouse double holding liquids (0..3) and items by name, as DCS's Warehouse does.
local function newWarehouse()
    local w = { liquids = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }, items = {} }
    function w:getLiquidAmount(t) return self.liquids[t] end
    function w:setLiquidAmount(t, v) self.liquids[t] = v end
    function w:getItemCount(n) return self.items[n] or 0 end
    function w:setItem(n, v) self.items[n] = v end
    return w
end

local HELLFIRE = "weapons.missiles.AGM_114K"

describe("CTLDFatCow stock", function()

    it("is empty only when it holds no fuel and no item", function()
        assert.is_true(CTLDFatCow:new("cow", 2, { fuelKg = 0, items = {} }):isEmpty())
        assert.is_false(CTLDFatCow:new("cow", 2, { fuelKg = 1, items = {} }):isEmpty())
        assert.is_false(CTLDFatCow:new("cow", 2, { fuelKg = 0, items = { [HELLFIRE] = 1 } }):isEmpty())
        assert.is_true(CTLDFatCow:new("cow", 2, { fuelKg = 0, items = { [HELLFIRE] = 0 } }):isEmpty())
    end)

    it("copies the stock it is given, so the caller's table is never changed", function()
        local given = { fuelKg = 100, items = { [HELLFIRE] = 6 } }
        local cow = CTLDFatCow:new("cow", 2, given)
        cow.stock.fuelKg = 0
        cow.stock.items[HELLFIRE] = 0
        assert.equals(100, given.fuelKg)
        assert.equals(6, given.items[HELLFIRE])
    end)

    it("writes jet fuel and the stocked items, and zeroes the other liquids", function()
        local w = newWarehouse()
        w.liquids[1], w.liquids[3] = 50, 70
        CTLDFatCow:new("cow", 2, { fuelKg = 7200, items = { [HELLFIRE] = 6 } }):writeWarehouse(w)
        assert.equals(7200, w.liquids[0])
        assert.equals(0, w.liquids[1])
        assert.equals(0, w.liquids[2])
        assert.equals(0, w.liquids[3])
        assert.equals(6, w.items[HELLFIRE])
    end)

    it("reads back what the players left: fuel and items consumed are gone", function()
        local w = newWarehouse()
        local cow = CTLDFatCow:new("cow", 2, { fuelKg = 7200, items = { [HELLFIRE] = 6 } })
        cow:writeWarehouse(w)
        w.liquids[0] = 6908          -- an Apache took 292 kg
        w.items[HELLFIRE] = 2        -- and 4 Hellfires
        cow:readWarehouse(w)
        assert.equals(6908, cow.stock.fuelKg)
        assert.equals(2, cow.stock.items[HELLFIRE])
    end)

    it("reads an emptied warehouse back as an empty stock", function()
        local w = newWarehouse()
        local cow = CTLDFatCow:new("cow", 2, { fuelKg = 300, items = { [HELLFIRE] = 2 } })
        cow:writeWarehouse(w)
        w.liquids[0] = 0
        w.items[HELLFIRE] = 0
        cow:readWarehouse(w)
        assert.is_true(cow:isEmpty())
    end)

    it("re-syncs by writing back what the warehouse holds, not the stock it started with", function()
        local w = newWarehouse()
        local cow = CTLDFatCow:new("cow", 2, { fuelKg = 7200, items = { [HELLFIRE] = 6 } })
        cow:writeWarehouse(w)
        w.liquids[0] = 5000
        w.items[HELLFIRE] = 1
        local writes = 0
        local set = w.setLiquidAmount
        w.setLiquidAmount = function(self, t, v) writes = writes + 1; return set(self, t, v) end
        cow:resyncWarehouse(w)
        assert.equals(5000, w.liquids[0])
        assert.equals(1, w.items[HELLFIRE])
        assert.equals(5000, cow.stock.fuelKg)
        assert.is_true(writes > 0)
    end)
end)
