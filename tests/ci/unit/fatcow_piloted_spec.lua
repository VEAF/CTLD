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

describe("Piloted cow commands", function()
    local mgr, cm, sm, w, unit, messages, saved

    before_each(function()
        CTLDFatCowManager._instance = nil
        mgr = CTLDFatCowManager.getInstance()
        mgr._crateDescs = {
            { weight = 2400, desc = "Fat Cow fuel tank", unit = "FatCow:fuel", fatCow = { fuelKg = 2400 } },
        }
        cm, sm = CTLDCrateManager.getInstance(), CTLDSceneManager.getInstance()
        w = { liquids = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }, items = {} }
        function w:getLiquidAmount(t) return self.liquids[t] end
        function w:setLiquidAmount(t, v) self.liquids[t] = v end
        function w:getItemCount(n) return self.items[n] or 0 end
        function w:setItem(n, v) self.items[n] = v end
        messages = {}
        unit = {
            airborne     = false,
            getName      = function() return "Cow-1" end,
            isExist      = function() return true end,
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return 2 end,
            getPoint     = function() return { x = 0, y = 0, z = 0 } end,
            inAir        = function(self) return self.airborne end,
        }
        saved = {
            unitGet = Unit.getByName, inAir = ctld.utils.inAir, gid = ctld.utils.getGroupId,
            outGroup = trigger.action.outTextForGroup, crates = cm.crates, play = sm.playScene,
            pack = sm.packScene, airbase = Airbase.getByName, weight = ctld.utils.updateTransportWeight,
            zones = CTLDZoneManager.getInstance().getLogisticZonesAtPoint, aligned = cm.spawnCratesAligned,
        }
        Unit.getByName = function(n) if n == "Cow-1" then return unit end end
        ctld.utils.inAir = function(u) return u.airborne end
        ctld.utils.getGroupId = function() return 7 end
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end
        ctld.utils.updateTransportWeight = function() end
        cm.crates = {}
        sm.playScene = function(_, u, model, params)
            local scene = { _name = "Fat Cow FARP#1", _params = params }
            mgr:onSceneLaidOut(scene)
            return scene
        end
        sm.packScene = function() return {} end
        Airbase.getByName = function(n) if n == "CTLD_FatCow_FARP_1" then return { getWarehouse = function() return w end } end end
    end)

    after_each(function()
        Unit.getByName, ctld.utils.inAir, ctld.utils.getGroupId = saved.unitGet, saved.inAir, saved.gid
        trigger.action.outTextForGroup, cm.crates = saved.outGroup, saved.crates
        sm.playScene, sm.packScene, Airbase.getByName = saved.play, saved.pack, saved.airbase
        ctld.utils.updateTransportWeight = saved.weight
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = saved.zones
        cm.spawnCratesAligned = saved.aligned
        CTLDFatCowManager._instance = nil
    end)

    local function loadFuelCrate(name)
        local c = CTLDCrate:new({ crateName = name, descriptor = mgr._crateDescs[1] })
        c.state, c.loadedBy = CTLDCrate.STATE.LOADED, unit
        cm.crates[name] = c
        return c
    end

    it("deploys with the cow crates on board as the FARP's stock", function()
        loadFuelCrate("a"); loadFuelCrate("b")
        mgr:deployFromHold("Cow-1")
        assert.equals(4800, w.liquids[0])
        assert.equals(CTLDFatCow.STATE_DEPLOYED, mgr:getCow("Cow-1").state)
    end)

    it("refuses to deploy without a cow crate on board, or in the air", function()
        mgr:deployFromHold("Cow-1")
        assert.is_nil(mgr:getCow("Cow-1"))
        loadFuelCrate("a")
        unit.airborne = true
        mgr:deployFromHold("Cow-1")
        assert.is_nil(mgr:getCow("Cow-1"))
        assert.equals(2, #messages)
    end)

    it("packs what is left into the hold and removes the crates left empty", function()
        local a, b = loadFuelCrate("a"), loadFuelCrate("b")
        mgr:deployFromHold("Cow-1")
        w.liquids[0] = 1000
        mgr:packIntoHold("Cow-1")
        assert.is_nil(mgr:getCow("Cow-1"))
        assert.equals(1000, a.metadata.fatCow.fuelKg)
        assert.is_nil(cm.crates["b"])
        -- Deploying again starts from what is left.
        mgr:deployFromHold("Cow-1")
        assert.equals(1000, w.liquids[0])
    end)

    it("gives a crate unloaded while the FARP was open its share back", function()
        local a, b = loadFuelCrate("a"), loadFuelCrate("b")
        mgr:deployFromHold("Cow-1")
        b.state, b.loadedBy = CTLDCrate.STATE.LANDED, nil   -- unloaded meanwhile
        w.liquids[0] = 4800                                 -- nobody refuelled
        mgr:packIntoHold("Cow-1")
        assert.equals(2400, a.metadata.fatCow.fuelKg)
        assert.equals(2400, b.metadata.fatCow.fuelKg)
    end)

    it("packs on take-off", function()
        loadFuelCrate("a")
        mgr:deployFromHold("Cow-1")
        w.liquids[0] = 2000
        unit.airborne = true
        mgr:onTakeoff({ initiator = unit })
        assert.is_nil(mgr:getCow("Cow-1"))
        assert.equals(2000, cm.crates["a"].metadata.fatCow.fuelKg)
    end)

    it("requests a cow crate only on the ground inside a logistic zone", function()
        local spawned = 0
        cm.spawnCratesAligned = function() spawned = spawned + 1; return 1 end
        local inZone = false
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function()
            return inZone and { {} } or {}
        end
        mgr:requestCrate("Cow-1", 2400)
        assert.equals(0, spawned)
        inZone = true
        unit.airborne = true
        mgr:requestCrate("Cow-1", 2400)
        assert.equals(0, spawned)
        unit.airborne = false
        mgr:requestCrate("Cow-1", 2400)
        assert.equals(1, spawned)
    end)
end)

describe("Fat Cow loadouts", function()
    local mgr, cm, unit, messages, saved

    before_each(function()
        CTLDFatCowManager._instance = nil
        mgr, cm, messages = CTLDFatCowManager.getInstance(), CTLDCrateManager.getInstance(), {}
        local zm = CTLDZoneManager.getInstance()
        saved = { unitGet = Unit.getByName, inAir = ctld.utils.inAir, gid = ctld.utils.getGroupId,
                  outGroup = trigger.action.outTextForGroup, crates = cm.crates, index = cm._weightIndex,
                  weight = ctld.utils.updateTransportWeight, zones = zm.getLogisticZonesAtPoint }
        cm.crates = {}
        cm._weightIndex = {}
        unit = {
            airborne = false,
            getName = function() return "Cow-1" end, isExist = function() return true end,
            getTypeName = function() return "CH-47Fbl1" end,
            getCoalition = function() return coalition.side.BLUE end, getCountry = function() return 2 end,
            getPoint = function() return { x = 0, y = 0, z = 0 } end,
            inAir = function(self) return self.airborne end,
        }
        Unit.getByName = function(n) if n == "Cow-1" then return unit end end
        ctld.utils.inAir = function(u) return u.airborne end
        ctld.utils.getGroupId = function() return 7 end
        ctld.utils.updateTransportWeight = function() end
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end
        zm.getLogisticZonesAtPoint = function() return { {} } end
        mgr:_injectCrateDescriptors()
    end)

    after_each(function()
        local zm = CTLDZoneManager.getInstance()
        Unit.getByName, ctld.utils.inAir, ctld.utils.getGroupId = saved.unitGet, saved.inAir, saved.gid
        trigger.action.outTextForGroup, cm.crates, cm._weightIndex = saved.outGroup, saved.crates, saved.index
        ctld.utils.updateTransportWeight, zm.getLogisticZonesAtPoint = saved.weight, saved.zones
        CTLDFatCowManager._instance = nil
    end)

    -- The default loadouts: 1 = 40 Hellfires (25 laser, 15 radar) + 2400 rounds, 2 = 60 (38 + 22) + 1200,
    -- 3 = 40 laser + 2400, 4 = 60 laser + 1200; all with 4800 kg of fuel.
    local RADAR, ROUNDS = "weapons.missiles.AGM_114", "weapons.shells.M230_HEDP M789"

    it("splits a loadout into crates, the last of each kind part-full, straight into the hold", function()
        mgr:loadLoadout("Cow-1", 1)
        local onboard = cm:cratesOnboard("Cow-1")
        assert.equals(7, #onboard)                           -- 2 tanks, 20 + 5 laser, 15 radar, 2 x 1200 rounds
        local stock = CTLDFatCow.stockOfCrates(onboard)
        assert.equals(4800, stock.fuelKg)
        assert.equals(25, stock.items[HELLFIRE])
        assert.equals(15, stock.items[RADAR])
        assert.equals(2400, stock.items[ROUNDS])
        local mass = 0
        for _, c in ipairs(onboard) do
            assert.is_nil(c.dcsStatic)                       -- nothing left on the ground
            mass = mass + (c.metadata.massKg or c.descriptor.weight)
        end
        assert.is_true(math.abs(mass - 7867.5) < 0.5)        -- 4800 + 25 x 45.3 + 15 x 49 + 2400 x 0.5
    end)

    it("fits every default loadout into the CH-47F's hold, under what it lifts with 80 % internal fuel", function()
        local caps = ctld.gs("capabilitiesByType")["CH-47Fbl1"]
        for i = 1, #ctld.gs("fatCowLoadouts") do
            local crates = mgr:cratesForLoadout(ctld.gs("fatCowLoadouts")[i])
            local mass = 0
            for _, c in ipairs(crates) do mass = mass + c.desc.weight * c.fraction end
            assert.is_true(#crates <= caps.maxCratesOnboard)
            assert.is_true(mass <= 22680 - 11400 - 2444)        -- db.Units.lua: M_max, M_empty, 80 % of M_fuel_max
        end
    end)

    it("lists the Apache loadouts at the top, the Russian and mixed ones in their submenus", function()
        local subs, cmds = {}, {}
        local menu = {
            addSubMenu = function(_, path, name) subs[#subs + 1] = table.concat(path, "/") .. "/" .. name end,
            addCommand = function(_, path, label, fn, arg) cmds[#cmds + 1] = { path = table.concat(path, "/"), label = label, fn = fn, arg = arg } end,
        }
        mgr:_addLoadoutCommands(menu, { "CTLD", "Fat Cow", "Load" }, "Cow-1", "loadLoadout")
        assert.same({ "CTLD/Fat Cow/Load/Russian", "CTLD/Fat Cow/Load/Mixed" }, subs)
        local where = {}
        for _, c in ipairs(cmds) do where[c.path] = (where[c.path] or 0) + 1 end
        assert.equals(4, where["CTLD/Fat Cow/Load"])
        assert.equals(4, where["CTLD/Fat Cow/Load/Russian"])
        assert.equals(2, where["CTLD/Fat Cow/Load/Mixed"])
        local called
        local savedLoad = mgr.loadLoadout
        mgr.loadLoadout = function(_, unitName, index) called = { unitName, index } end
        cmds[5].fn(cmds[5].arg)
        mgr.loadLoadout = savedLoad
        assert.same({ "Cow-1", 5 }, called)
    end)

    it("finds the crates by what they carry, whatever their translated name", function()
        mgr._crateDescs = {
            { weight = 2400, desc = "Réservoir Fat Cow (800 gal)", fatCow = { fuelKg = 2400 } },
            { weight = 906, desc = "Hellfire laser Fat Cow (x20)", fatCow = { item = HELLFIRE, count = 20 } },
        }
        local crates = mgr:cratesForLoadout({ fuelKg = 3000, items = { { item = HELLFIRE, count = 20 } } })
        assert.equals(3, #crates)
        assert.equals(600, crates[2].content.fuelKg)
        assert.equals(0.25, crates[2].fraction)
        local none, missing = mgr:cratesForLoadout({ fuelKg = 0, items = { { item = RADAR, count = 1 } } })
        assert.is_nil(none)
        assert.equals(RADAR, missing)
    end)

    it("refuses a loadout the hold has no room for, and outside a logistic zone", function()
        mgr:loadLoadout("Cow-1", 1)
        mgr:loadLoadout("Cow-1", 3)                           -- 7 + 6 > 8
        assert.equals(7, #cm:cratesOnboard("Cow-1"))
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function() return {} end
        mgr:unloadHold("Cow-1")
        assert.equals(7, #cm:cratesOnboard("Cow-1"))
    end)

    it("unloads the cow crates in a logistic zone", function()
        mgr:loadLoadout("Cow-1", 4)
        mgr:unloadHold("Cow-1")
        assert.equals(0, #cm:cratesOnboard("Cow-1"))
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

    it("indexes an outside descriptor on the first free weight", function()
        local savedIndex = cm._weightIndex
        cm._weightIndex = { [2400] = { unit = "other" } }
        local d = cm:registerDescriptor({ weight = 2400, desc = "Fat Cow fuel tank" })
        assert.equals(2400.01, d.weight)
        assert.equals(d, cm._weightIndex[2400.01])
        cm._weightIndex = savedIndex
    end)

    it("never offers a cow crate to Unpack", function()
        local c = CTLDCrate:new({ crateName = "a", descriptor = { weight = 2400, fatCow = { fuelKg = 2400 } } })
        assert.is_false(c.canBeUnpacked)
        local v = CTLDCrate:new({ crateName = "v", descriptor = { weight = 1000.01 } })
        assert.is_true(v.canBeUnpacked)
    end)
end)
