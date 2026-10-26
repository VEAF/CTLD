---@diagnostic disable
-- tests/ci/unit/fatcow_piloted_spec.lua
-- FEAT-FAT-COW ticket 03: a piloted cow's stock is the cow crates in its hold; packing puts what is
-- left back into them.
-- ============================================================

local HELLFIRE = "weapons.missiles.AGM_114K"

local function crate(name, fatCow, weight)
    return { crateName = name, descriptor = { weight = weight or 2400, fatCow = fatCow }, metadata = {} }
end

local function fuelCrate(name)     return crate(name, { fuelKg = 2400 }, 2400) end
local function hellfireCrate(name) return crate(name, { item = HELLFIRE, count = 4 }, 250) end

describe("Fat Cow crates on board", function()

    it("sums the cow crates into one stock", function()
        local stock = CTLDFatCow.stockOfCrates({ fuelCrate("a"), fuelCrate("b"), hellfireCrate("h") })
        assert.equals(4800, stock.fuelKg)
        assert.equals(4, stock.items[HELLFIRE])
    end)

    it("reads a crate's remaining content once it has served", function()
        local a = fuelCrate("a")
        a.metadata.fatCow = { fuelKg = 600 }
        local stock = CTLDFatCow.stockOfCrates({ a, fuelCrate("b") })
        assert.equals(3000, stock.fuelKg)
    end)

    it("ignores crates that are not cow crates", function()
        local other = { crateName = "x", descriptor = { weight = 1000.01 }, metadata = {} }
        local stock = CTLDFatCow.stockOfCrates({ other, fuelCrate("a") })
        assert.equals(2400, stock.fuelKg)
    end)

    it("puts what is left back into the crates, in order, and lists the emptied ones", function()
        local a, b, h = fuelCrate("a"), fuelCrate("b"), hellfireCrate("h")
        local emptied = CTLDFatCow.refillCrates({ fuelKg = 3000, items = { [HELLFIRE] = 0 } }, { a, b, h })
        assert.equals(2400, a.metadata.fatCow.fuelKg)
        assert.equals(600, b.metadata.fatCow.fuelKg)
        assert.equals(2400, a.metadata.massKg)
        assert.equals(600, b.metadata.massKg)
        assert.equals(1, #emptied)
        assert.equals("h", emptied[1].crateName)
    end)

    it("scales a part-used ammo crate's mass to what it still holds", function()
        local h = hellfireCrate("h")
        local emptied = CTLDFatCow.refillCrates({ fuelKg = 0, items = { [HELLFIRE] = 1 } }, { h })
        assert.equals(0, #emptied)
        assert.equals(1, h.metadata.fatCow.count)
        assert.equals(62.5, h.metadata.massKg)
    end)

    it("never fills a crate beyond what it held when the FARP opened", function()
        local a = fuelCrate("a")
        a.metadata.fatCow = { fuelKg = 500 }
        CTLDFatCow.refillCrates({ fuelKg = 2000, items = {} }, { a })
        assert.equals(500, a.metadata.fatCow.fuelKg)
    end)
end)

describe("CTLDCrateManager:getLoadedCrateWeight with a part-used crate", function()
    local cm, saved

    before_each(function()
        cm = CTLDCrateManager.getInstance()
        saved = cm.crates
        cm.crates = {}
    end)

    after_each(function()
        cm.crates = saved
    end)

    it("counts a crate's metadata mass when it has one, its descriptor weight otherwise", function()
        local function loaded(name, weight, massKg)
            local c = CTLDCrate:new({ crateName = name, descriptor = { weight = weight } })
            c.state = CTLDCrate.STATE.LOADED
            c.loadedBy = { getName = function() return "Cow-1" end }
            c.metadata.massKg = massKg
            cm.crates[name] = c
        end
        loaded("a", 2400, 600)
        loaded("b", 250, nil)
        assert.equals(850, cm:getLoadedCrateWeight("Cow-1"))
    end)

    it("never offers a cow crate to Unpack", function()
        local c = CTLDCrate:new({ crateName = "a", descriptor = { weight = 2400, fatCow = { fuelKg = 2400 } } })
        assert.is_false(c.canBeUnpacked)
        local v = CTLDCrate:new({ crateName = "v", descriptor = { weight = 1000.01 } })
        assert.is_true(v.canBeUnpacked)
    end)
end)
