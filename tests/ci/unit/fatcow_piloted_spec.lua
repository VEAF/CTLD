---@diagnostic disable
-- tests/ci/unit/fatcow_piloted_spec.lua
-- FEAT-FAT-COW ticket 03: a piloted cow's stock is the cow crates in its hold.
-- FEAT-FAT-COW-LEAVE-FARP: a loadout sets its crates on the ground, deploying consumes them, the FARP stays
-- open when its helicopter leaves, and any piloted cow of the coalition packs it into crates on the ground.
-- ============================================================

local HELLFIRE = "weapons.missiles.AGM_114K"

local function crate(name, fatCow, weight)
    return { crateName = name, descriptor = { weight = weight or 2400, fatCow = fatCow }, metadata = {} }
end

local function fuelCrate(name)     return crate(name, { fuelKg = 2400 }, 2400) end
local function hellfireCrate(name) return crate(name, { item = HELLFIRE, count = 4 }, 250) end

--- A stand-in for CTLDCrateManager:spawnCratesAligned: each crate on the ground next to the transport, with
-- the metadata spawnCrate would give it (crate_manager_spec checks spawnCrate itself), its static mass noted.
local function fakeSpawnAligned(cm, statics)
    local n = 0
    return function(_, descriptors, transport, coalitionId, spawnedBy, spawnMethod, metadatas)
        local out = {}
        for i, d in ipairs(descriptors) do
            n = n + 1
            local c = CTLDCrate:new({ crateName = "ground-" .. n, descriptor = d, coalition = coalitionId,
                position = transport:getPoint(), spawnedBy = spawnedBy, spawnMethod = spawnMethod })
            for k, v in pairs(metadatas and metadatas[i] or {}) do c.metadata[k] = v end
            statics[c.crateName] = (metadatas and metadatas[i] and metadatas[i].massKg) or d.weight
            cm.crates[c.crateName] = c
            out[#out + 1] = c
        end
        return #out, {}, out
    end
end

--- The cow crates on the ground, by name order.
local function cratesOnGround(cm)
    local out = {}
    for _, c in pairs(cm.crates) do
        if c:isOnGround() then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.crateName < b.crateName end)
    return out
end

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
end)

describe("Piloted cow commands", function()
    local mgr, cm, sm, units, farps, statics, messages, weighed, saved

    -- A piloted CH-47 at a point; `airborne` flips inAir.
    local function cowUnit(name, p)
        return {
            airborne     = false,
            getName      = function() return name end,
            isExist      = function() return true end,
            getTypeName  = function() return "CH-47Fbl1" end,
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return 2 end,
            getPoint     = function() return p end,
            inAir        = function(self) return self.airborne end,
        }
    end

    local function newWarehouse()
        local w = { liquids = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }, items = {} }
        function w:getLiquidAmount(t) return self.liquids[t] end
        function w:setLiquidAmount(t, v) self.liquids[t] = v end
        function w:getItemCount(n) return self.items[n] or 0 end
        function w:setItem(n, v) self.items[n] = v end
        return w
    end

    before_each(function()
        CTLDFatCowManager._instance = nil
        mgr = CTLDFatCowManager.getInstance()
        mgr._crateDescs = {
            { weight = 2400, desc = "Fat Cow fuel tank", unit = "FatCow:fuel", fatCow = { fuelKg = 2400 } },
            { weight = 250, desc = "Fat Cow Hellfire", unit = "FatCow:hf", fatCow = { item = HELLFIRE, count = 4 } },
        }
        cm, sm = CTLDCrateManager.getInstance(), CTLDSceneManager.getInstance()
        units = { ["Cow-1"] = cowUnit("Cow-1", { x = 0, y = 0, z = 0 }) }
        farps, statics, messages, weighed = {}, {}, {}, {}
        saved = {
            unitGet = Unit.getByName, inAir = ctld.utils.inAir, gid = ctld.utils.getGroupId,
            outGroup = trigger.action.outTextForGroup, crates = cm.crates, play = sm.playScene,
            pack = sm.packScene, airbase = Airbase.getByName, static = StaticObject.getByName,
            weight = ctld.utils.updateTransportWeight, zones = CTLDZoneManager.getInstance().getLogisticZonesAtPoint,
            aligned = cm.spawnCratesAligned, schedule = ctld.scheduler.schedule,
        }
        Unit.getByName = function(n) return units[n] end
        ctld.utils.inAir = function(u) return u.airborne end
        ctld.utils.getGroupId = function() return 7 end
        trigger.action.outTextForGroup = function(_, text) messages[#messages + 1] = text end
        ctld.utils.updateTransportWeight = function(n) weighed[#weighed + 1] = n end
        ctld.scheduler.schedule = function() end
        cm.crates = {}
        cm.spawnCratesAligned = fakeSpawnAligned(cm, statics)
        -- The scene is laid out at once, its FARP where the helicopter stands.
        sm.playScene = function(_, u, _, params)
            farps[params.farpName] = { w = newWarehouse(), p = u:getPoint() }
            local scene = { _name = "Fat Cow FARP#1", _params = params }
            mgr:onSceneLaidOut(scene)
            return scene
        end
        sm.packScene = function() return {} end
        Airbase.getByName = function(n)
            local f = farps[n]
            return f and { getWarehouse = function() return f.w end }
        end
        StaticObject.getByName = function(n)
            local f = farps[n]
            return f and { isExist = function() return true end, getPoint = function() return f.p end }
        end
    end)

    after_each(function()
        Unit.getByName, ctld.utils.inAir, ctld.utils.getGroupId = saved.unitGet, saved.inAir, saved.gid
        trigger.action.outTextForGroup, cm.crates = saved.outGroup, saved.crates
        sm.playScene, sm.packScene, Airbase.getByName = saved.play, saved.pack, saved.airbase
        StaticObject.getByName, ctld.utils.updateTransportWeight = saved.static, saved.weight
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = saved.zones
        cm.spawnCratesAligned, ctld.scheduler.schedule = saved.aligned, saved.schedule
        CTLDFatCowManager._instance = nil
    end)

    local function loadCrateInto(name, desc, unit)
        local c = CTLDCrate:new({ crateName = name, descriptor = desc or mgr._crateDescs[1] })
        c.state, c.loadedBy = CTLDCrate.STATE.LOADED, unit or units["Cow-1"]
        cm.crates[name] = c
        return c
    end

    local function loadEveryCrateOnGround(unit)
        for _, c in ipairs(cratesOnGround(cm)) do cm:loadCrate(c.crateName, unit) end
    end

    local function openFarp(name)
        for _, cow in pairs(mgr._cows) do
            if cow.farpName == name then return cow end
        end
    end

    it("deploys with the cow crates on board as the FARP's stock, and takes them out of the hold", function()
        loadCrateInto("a"); loadCrateInto("b"); loadCrateInto("h", mgr._crateDescs[2])
        mgr:deployFromHold("Cow-1")
        local farp = farps.CTLD_FatCow_FARP_1
        assert.equals(4800, farp.w.liquids[0])
        assert.equals(4, farp.w.items[HELLFIRE])
        assert.equals(CTLDFatCow.STATE_DEPLOYED, openFarp("CTLD_FatCow_FARP_1").state)
        assert.equals(0, #cm:cratesOnboard("Cow-1"))
        assert.is_nil(next(cm.crates))
        assert.equals("Cow-1", weighed[#weighed])             -- the helicopter is lighter
    end)

    it("refuses to deploy without a cow crate on board, or in the air", function()
        mgr:deployFromHold("Cow-1")
        assert.is_nil(next(mgr._cows))
        loadCrateInto("a")
        units["Cow-1"].airborne = true
        mgr:deployFromHold("Cow-1")
        assert.is_nil(next(mgr._cows))
        assert.equals(2, #messages)
        assert.is_not_nil(cm.crates["a"])                    -- still on board
    end)

    it("leaves out of the FARP a crate DCS still holds in its own cargo system", function()
        local native = loadCrateInto("n")
        native.loadedByDCSNative = true
        mgr:deployFromHold("Cow-1")
        assert.is_nil(next(mgr._cows))
        assert.equals(native, cm.crates["n"])
        assert.is_truthy(messages[#messages]:find("Fit parachute", 1, true))
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        assert.equals(2400, farps.CTLD_FatCow_FARP_1.w.liquids[0])
        assert.equals(native, cm.crates["n"])                    -- still on board, untouched
    end)

    it("does not open a second FARP with crates a FARP still laying out was opened with", function()
        sm.playScene = function(_, _, _, params) return { _name = "Fat Cow FARP#1", _params = params } end
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        mgr:deployFromHold("Cow-1")
        local n = 0
        for _ in pairs(mgr._cows) do n = n + 1 end
        assert.equals(1, n)
        assert.equals("The Fat Cow FARP is already deployed.", messages[#messages])
    end)

    it("leaves the FARP open on take-off, and tells its pilot what it holds", function()
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        farps.CTLD_FatCow_FARP_1.w.liquids[0] = 2000
        units["Cow-1"].airborne = true
        mgr:onTakeoff({ initiator = units["Cow-1"] })
        local cow = openFarp("CTLD_FatCow_FARP_1")
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        assert.equals(2000, farps.CTLD_FatCow_FARP_1.w.liquids[0])
        assert.is_truthy(messages[#messages]:find("CTLD_FatCow_FARP_1", 1, true))
        assert.is_truthy(messages[#messages]:find("2000", 1, true))
    end)

    it("leaves the FARP open, its stock intact, when the helicopter dies or a new pilot takes the slot", function()
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        farps.CTLD_FatCow_FARP_1.w.liquids[0] = 1500
        mgr:onDead({ initiator = units["Cow-1"] })
        local newPilot = cowUnit("Cow-1", { x = 0, y = 0, z = 0 })
        newPilot.getPlayerName = function() return "Griffin" end
        mgr:onBirth({ initiator = newPilot })
        assert.equals(CTLDFatCow.STATE_DEPLOYED, openFarp("CTLD_FatCow_FARP_1").state)
        assert.equals(1500, farps.CTLD_FatCow_FARP_1.w.liquids[0])
    end)

    it("keeps re-syncing a FARP whose helicopter is gone", function()
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        units["Cow-1"] = nil
        farps.CTLD_FatCow_FARP_1.w.liquids[0] = 1800              -- what the players left
        mgr:_resyncFarps()
        farps.CTLD_FatCow_FARP_1.w.liquids[0] = 50000             -- a refill of every FARP
        mgr:_resyncFarps()
        assert.equals(1800, farps.CTLD_FatCow_FARP_1.w.liquids[0])
    end)

    it("packs from another CH-47 into crates on the ground, which open the same FARP again elsewhere", function()
        loadCrateInto("a"); loadCrateInto("b"); loadCrateInto("h", mgr._crateDescs[2])
        mgr:deployFromHold("Cow-1")
        local w = farps.CTLD_FatCow_FARP_1.w
        w.liquids[0], w.items[HELLFIRE] = 3000, 3
        units["Cow-1"] = nil                                       -- its pilot is gone
        units["Cow-2"] = cowUnit("Cow-2", { x = 100, y = 0, z = 0 })
        mgr:packFarp("Cow-2")
        assert.is_nil(next(mgr._cows))
        assert.equals(0, w.liquids[0])                             -- the FARP is emptied
        local ground = cratesOnGround(cm)
        assert.equals(3, #ground)                                  -- 2400 + 600 kg of fuel, 3 Hellfires
        local stock = CTLDFatCow.stockOfCrates(ground)
        assert.equals(3000, stock.fuelKg)
        assert.equals(3, stock.items[HELLFIRE])
        for _, c in ipairs(ground) do
            assert.equals(c.metadata.massKg or c.descriptor.weight, statics[c.crateName])
        end
        -- Loaded and deployed elsewhere: the FARP's name is reused, with what was packed.
        units["Cow-2"] = cowUnit("Cow-2", { x = 50000, y = 0, z = 0 })
        loadEveryCrateOnGround(units["Cow-2"])
        assert.equals(3, #cm:cratesOnboard("Cow-2"))
        mgr:deployFromHold("Cow-2")
        assert.equals(3000, farps.CTLD_FatCow_FARP_1.w.liquids[0])
        assert.equals(3, farps.CTLD_FatCow_FARP_1.w.items[HELLFIRE])
    end)

    it("refuses to pack beyond 150 m or in the air, with the reason", function()
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        units["Cow-2"] = cowUnit("Cow-2", { x = 151, y = 0, z = 0 })
        mgr:packFarp("Cow-2")
        assert.equals("No Fat Cow FARP within 150 m.", messages[#messages])
        units["Cow-2"] = cowUnit("Cow-2", { x = 149, y = 0, z = 0 })
        units["Cow-2"].airborne = true
        mgr:packFarp("Cow-2")
        assert.equals("Land to pack the Fat Cow FARP.", messages[#messages])
        assert.equals(CTLDFatCow.STATE_DEPLOYED, openFarp("CTLD_FatCow_FARP_1").state)
        assert.equals(0, #cratesOnGround(cm))
    end)

    it("packs an emptied FARP into no crate at all", function()
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        farps.CTLD_FatCow_FARP_1.w.liquids[0] = 0
        mgr:packFarp("Cow-1")
        assert.is_nil(next(mgr._cows))
        assert.equals(0, #cratesOnGround(cm))
    end)

    it("opens two FARPs at once under two names, and gives a packed FARP's name to the next one", function()
        loadCrateInto("a")
        mgr:deployFromHold("Cow-1")
        units["Cow-1"] = cowUnit("Cow-1", { x = 20000, y = 0, z = 0 })
        loadCrateInto("b")
        mgr:deployFromHold("Cow-1")
        assert.equals(CTLDFatCow.STATE_DEPLOYED, openFarp("CTLD_FatCow_FARP_1").state)
        assert.equals(CTLDFatCow.STATE_DEPLOYED, openFarp("CTLD_FatCow_FARP_2").state)
        mgr:packFarp("Cow-1")                                    -- the second one, at 20 km
        assert.is_nil(openFarp("CTLD_FatCow_FARP_2"))
        loadEveryCrateOnGround(units["Cow-1"])
        mgr:deployFromHold("Cow-1")
        assert.equals(CTLDFatCow.STATE_DEPLOYED, openFarp("CTLD_FatCow_FARP_2").state)
        assert.is_nil(farps.CTLD_FatCow_FARP_3)
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
        units["Cow-1"].airborne = true
        mgr:requestCrate("Cow-1", 2400)
        assert.equals(0, spawned)
        units["Cow-1"].airborne = false
        mgr:requestCrate("Cow-1", 2400)
        assert.equals(1, spawned)
    end)
end)

describe("Fat Cow loadouts", function()
    local mgr, cm, unit, messages, statics, saved

    before_each(function()
        CTLDFatCowManager._instance = nil
        mgr, cm, messages, statics = CTLDFatCowManager.getInstance(), CTLDCrateManager.getInstance(), {}, {}
        local zm = CTLDZoneManager.getInstance()
        saved = { unitGet = Unit.getByName, inAir = ctld.utils.inAir, gid = ctld.utils.getGroupId,
                  outGroup = trigger.action.outTextForGroup, crates = cm.crates, index = cm._weightIndex,
                  weight = ctld.utils.updateTransportWeight, zones = zm.getLogisticZonesAtPoint,
                  aligned = cm.spawnCratesAligned }
        cm.crates = {}
        cm._weightIndex = {}
        cm.spawnCratesAligned = fakeSpawnAligned(cm, statics)
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
        cm.spawnCratesAligned = saved.aligned
        CTLDFatCowManager._instance = nil
    end)

    -- The default loadouts: 1 = 40 Hellfires (25 laser, 15 radar) + 2400 rounds, 2 = 60 (38 + 22) + 1200,
    -- 3 = 40 laser + 2400, 4 = 60 laser + 1200; all with 4800 kg of fuel.
    local RADAR, ROUNDS = "weapons.missiles.AGM_114", "weapons.shells.M230_HEDP M789"

    it("sets a loadout's crates down next to the helicopter, the last of each kind part-full, none in the hold", function()
        mgr:loadLoadout("Cow-1", 1)
        assert.equals(0, #cm:cratesOnboard("Cow-1"))
        local ground = cratesOnGround(cm)
        assert.equals(7, #ground)                            -- 2 tanks, 20 + 5 laser, 15 radar, 2 x 1200 rounds
        local stock = CTLDFatCow.stockOfCrates(ground)
        assert.equals(4800, stock.fuelKg)
        assert.equals(25, stock.items[HELLFIRE])
        assert.equals(15, stock.items[RADAR])
        assert.equals(2400, stock.items[ROUNDS])
        local mass = 0
        for _, c in ipairs(ground) do
            mass = mass + statics[c.crateName]               -- what each static weighs on the ground
        end
        assert.is_true(math.abs(mass - 7867.5) < 0.5)        -- 4800 + 25 x 45.3 + 15 x 49 + 2400 x 0.5
    end)

    it("keeps a part-full crate's content and mass through the CTLD load", function()
        mgr:loadLoadout("Cow-1", 1)
        for _, c in ipairs(cratesOnGround(cm)) do cm:loadCrate(c.crateName, unit) end
        local onboard = cm:cratesOnboard("Cow-1")
        assert.equals(7, #onboard)
        local stock = CTLDFatCow.stockOfCrates(onboard)
        assert.equals(25, stock.items[HELLFIRE])
        assert.equals(15, stock.items[RADAR])
        assert.is_true(math.abs(cm:getLoadedCrateWeight("Cow-1") - 7867.5) < 0.5)
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

    it("refuses a loadout outside a logistic zone, or in the air", function()
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function() return {} end
        mgr:loadLoadout("Cow-1", 1)
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function() return { {} } end
        unit.airborne = true
        mgr:loadLoadout("Cow-1", 1)
        assert.equals(0, #cratesOnGround(cm))
        assert.equals(2, #messages)
    end)

    it("unloads the cow crates in a logistic zone, not elsewhere", function()
        mgr:loadLoadout("Cow-1", 4)
        for _, c in ipairs(cratesOnGround(cm)) do cm:loadCrate(c.crateName, unit) end
        local loaded = #cm:cratesOnboard("Cow-1")
        assert.is_true(loaded > 0)
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function() return {} end
        mgr:unloadHold("Cow-1")
        assert.equals(loaded, #cm:cratesOnboard("Cow-1"))
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = function() return { {} } end
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
