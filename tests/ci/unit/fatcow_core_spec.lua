---@diagnostic disable
-- tests/ci/unit/fatcow_core_spec.lua
-- FEAT-FAT-COW ticket 02: a cow's stock, written into its FARP warehouse on deploy, read back on pack.
-- ============================================================

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

-- ── Manager: deploy, pack, re-sync ─────────────────────────────────────────────────────────────

describe("CTLDFatCowManager deploy / pack", function()
    local mgr, sm, w, played, packed
    local savedPlay, savedPack, savedAirbase

    local function cowUnit(name)
        return {
            getName      = function() return name end,
            isExist      = function() return true end,
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return 2 end,
            getPoint     = function() return { x = 0, y = 0, z = 0 } end,
            inAir        = function() return false end,
        }
    end

    before_each(function()
        CTLDFatCowManager._instance = nil
        mgr = CTLDFatCowManager.getInstance()
        sm  = CTLDSceneManager.getInstance()
        w   = newWarehouse()
        played, packed = nil, nil
        savedPlay, savedPack, savedAirbase = sm.playScene, sm.packScene, Airbase.getByName
        -- The scene is laid out at once: its last step hands it to the manager.
        sm.playScene = function(_, unit, modelName, params)
            played = { unit = unit, model = modelName, params = params }
            local scene = { _name = "Fat Cow FARP#1", _params = params }
            params.farpName = "FatCow_FARP-1"
            mgr:onSceneLaidOut(scene)
            return scene
        end
        sm.packScene = function(_, scene) packed = scene; return {} end
        Airbase.getByName = function(name)
            if name == "FatCow_FARP-1" then return { getWarehouse = function() return w end } end
        end
    end)

    after_each(function()
        sm.playScene, sm.packScene, Airbase.getByName = savedPlay, savedPack, savedAirbase
        CTLDFatCowManager._instance = nil
    end)

    it("deploys the Fat Cow scene and writes the stock into its FARP warehouse", function()
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 7200, items = { [HELLFIRE] = 6 } })
        assert.is_true(mgr:deploy(unit))
        assert.equals("Fat Cow FARP", played.model)
        assert.equals(7200, w.liquids[0])
        assert.equals(6, w.items[HELLFIRE])
        local cow = mgr:getCow("Cow-1")
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        assert.equals("FatCow_FARP-1", cow.farpName)
    end)

    it("refuses to deploy a cow that is already deployed, or an empty one", function()
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 100, items = {} })
        assert.is_true(mgr:deploy(unit))
        local ok, why = mgr:deploy(unit)
        assert.is_false(ok)
        assert.equals("deployed", why)

        local empty = cowUnit("Cow-2")
        mgr:addCow(empty, { fuelKg = 0, items = {} })
        ok, why = mgr:deploy(empty)
        assert.is_false(ok)
        assert.equals("empty", why)
    end)

    it("refuses to deploy a cow in the air", function()
        local unit = cowUnit("Cow-1")
        unit.inAir = function() return true end
        mgr:addCow(unit, { fuelKg = 100, items = {} })
        local ok, why = mgr:deploy(unit)
        assert.is_false(ok)
        assert.equals("airborne", why)
    end)

    it("packs: reads what is left back into the stock and removes the scene", function()
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 7200, items = { [HELLFIRE] = 6 } })
        mgr:deploy(unit)
        w.liquids[0] = 6908
        w.items[HELLFIRE] = 2
        assert.is_true(mgr:pack("Cow-1"))
        assert.is_not_nil(packed)
        local cow = mgr:getCow("Cow-1")
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        assert.equals(6908, cow.stock.fuelKg)
        assert.equals(2, cow.stock.items[HELLFIRE])
        assert.is_nil(cow.scene)
    end)

    it("packing a stowed cow does nothing", function()
        mgr:addCow(cowUnit("Cow-1"), { fuelKg = 100, items = {} })
        assert.is_false(mgr:pack("Cow-1"))
        assert.is_nil(packed)
    end)

    it("re-syncs every deployed cow's warehouse when a player is born", function()
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 7200, items = { [HELLFIRE] = 6 } })
        mgr:deploy(unit)
        w.liquids[0] = 4000
        local player = { getPlayerName = function() return "Zip" end }
        mgr:onBirth({ initiator = player })
        assert.equals(4000, mgr:getCow("Cow-1").stock.fuelKg)
        assert.equals(4000, w.liquids[0])
    end)

    it("removing a deployed cow packs it first", function()
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 100, items = {} })
        mgr:deploy(unit)
        mgr:removeCow("Cow-1")
        assert.is_not_nil(packed)
        assert.is_nil(mgr:getCow("Cow-1"))
    end)
end)
