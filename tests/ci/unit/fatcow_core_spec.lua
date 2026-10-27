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
    function w:getInventory()
        local weapon = {}
        for n, v in pairs(self.items) do if v > 0 then weapon[n] = v end end
        return { weapon = weapon }
    end
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

    it("keeps its own count when someone else refills the warehouse, and puts it back", function()
        local w = newWarehouse()
        local cow = CTLDFatCow:new("cow", 2, { fuelKg = 4800, items = { [HELLFIRE] = 6 } })
        cow:writeWarehouse(w)
        w.liquids[0] = 4500                                   -- an Apache took 300 kg
        cow:resyncWarehouse(w)                                -- a player is born: CTLD reads first
        w.liquids[0], w.liquids[1] = w.liquids[0] + 50000, 50000   -- then VMCT's GRASS refill
        w.items[HELLFIRE], w.items["weapons.nurs.HYDRA_70_M151"] = 5000, 5000
        cow:resyncWarehouse(w)
        assert.equals(4500, cow.stock.fuelKg)
        assert.equals(6, cow.stock.items[HELLFIRE])
        assert.equals(4500, w.liquids[0])
        assert.equals(0, w.liquids[1])
        assert.equals(6, w.items[HELLFIRE])
        assert.equals(0, w.items["weapons.nurs.HYDRA_70_M151"])   -- not the cow's: removed
    end)

    it("empties the warehouse", function()
        local w = newWarehouse()
        local cow = CTLDFatCow:new("cow", 2, { fuelKg = 4800, items = { [HELLFIRE] = 6 } })
        cow:writeWarehouse(w)
        cow:emptyWarehouse(w)
        assert.equals(0, w.liquids[0])
        assert.equals(0, w.items[HELLFIRE])
    end)
end)

-- ── The scene itself ───────────────────────────────────────────────────────────────────────────

describe("Fat Cow FARP scene", function()
    local ROOT = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]unit[\\/]") or ""
    local saved

    before_each(function()
        if not CTLDSceneManager.getInstance():getModel("Fat Cow FARP") then
            dofile(ROOT .. "src/scenes/CTLD_fatCowScene.lua")
        end
        saved = { spawn = CTLDObjectRegistry.spawnObject, addStatic = coalition.addStaticObject,
                  laidOut = CTLDFatCowManager.onSceneLaidOut, schedule = ctld.scheduler.schedule }
        -- The scene waits between steps: run each delayed step at once.
        ctld.scheduler.schedule = function(fn, arg) fn(arg) end
    end)

    after_each(function()
        CTLDObjectRegistry.spawnObject, coalition.addStaticObject = saved.spawn, saved.addStatic
        CTLDFatCowManager.onSceneLaidOut = saved.laidOut
        ctld.scheduler.schedule = saved.schedule
    end)

    it("lays out a FARP, a fuel depot, dressing and a crew — no vehicle, no tent, no ammo dump", function()
        local spawned, statics, laidOut, farpName = {}, {}, nil, nil
        local function obj(name) return { getName = function() return name end, isExist = function() return true end } end
        CTLDObjectRegistry.spawnObject = function(key, coa, cid, x, z, hdg, overrides)
            local types = CTLDTypeCollector.typesOfDescriptor(CTLDObjectRegistry.get(key))
            for _, t in ipairs(types) do spawned[#spawned + 1] = t end
            if key == "Invisible_FARP" then farpName = overrides and overrides.name end
            return obj((overrides and overrides.name) or (key .. "-1"))
        end
        coalition.addStaticObject = function(_, sd) statics[#statics + 1] = sd; return obj(sd.name) end
        CTLDFatCowManager.onSceneLaidOut = function(_, scene) laidOut = scene end
        local unit = {
            getName = function() return "Cow-1" end, isExist = function() return true end,
            getCoalition = function() return coalition.side.BLUE end, getCountry = function() return 2 end,
            getPoint = function() return { x = 0, y = 0, z = 0 } end,
            getPosition = function() return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 0, z = 0 } } end,
        }
        local scene = CTLDSceneManager.getInstance():playScene(unit, "Fat Cow FARP", { farpName = "CTLD_FatCow_FARP_1" })
        local all = {}
        for _, t in ipairs(spawned) do all[t] = true end
        for _, sd in ipairs(statics) do all[sd.type] = true end
        assert.is_true(all["Invisible FARP"])
        assert.is_true(all["FARP Fuel Depot"])
        assert.is_true(all["Soldier M4"])
        for _, banned in ipairs({ "M978 HEMTT Tanker", "M 818", "FARP Tent", "FARP Ammo Dump Coating" }) do
            assert.is_nil(all[banned])
        end
        assert.equals(3, #statics)
        for _, sd in ipairs(statics) do
            assert.equals("CTLD_", sd.name:sub(1, 5))   -- never registered as a loadable crate
        end
        assert.is_not_nil(laidOut)
        assert.equals("CTLD_FatCow_FARP_1", farpName)
        for _, o in ipairs(scene._spawnedObjs) do                  -- packing never destroys the FARP
            assert.is_true(o:getName() ~= "CTLD_FatCow_FARP_1")
        end
        CTLDSceneManager.getInstance():packScene(scene)
    end)

    it("stows the cow again when its FARP cannot be added", function()
        CTLDObjectRegistry.spawnObject = function() return nil end
        local failed
        local savedFailed = CTLDFatCowManager.onSceneFailed
        CTLDFatCowManager.onSceneFailed = function(_, scene) failed = scene end
        local unit = {
            getName = function() return "Cow-1" end, isExist = function() return true end,
            getCoalition = function() return coalition.side.BLUE end, getCountry = function() return 2 end,
            getPoint = function() return { x = 0, y = 0, z = 0 } end,
            getPosition = function() return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 0, z = 0 } } end,
        }
        local scene = CTLDSceneManager.getInstance():playScene(unit, "Fat Cow FARP", { farpName = "CTLD_FatCow_FARP_1" })
        CTLDFatCowManager.onSceneFailed = savedFailed
        assert.equals(scene, failed)
        assert.is_true(scene._aborted)
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
            mgr:onSceneLaidOut(scene)
            return scene
        end
        sm.packScene = function(_, scene) packed = scene; return {} end
        Airbase.getByName = function(name)
            if name:find("^CTLD_FatCow_FARP_") then return { getWarehouse = function() return w end } end
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
        assert.equals("CTLD_FatCow_FARP_1", cow.farpName)
    end)

    it("gives each cow one FARP name, the same at every deployment", function()
        local a, b = cowUnit("Cow-1"), cowUnit("Cow-2")
        mgr:addCow(a, { fuelKg = 100, items = {} })
        mgr:deploy(a)
        mgr:pack("Cow-1")
        mgr:addCow(b, { fuelKg = 100, items = {} })
        mgr:deploy(b)
        assert.equals("CTLD_FatCow_FARP_2", played.params.farpName)
        mgr:addCow(a, { fuelKg = 100, items = {} })          -- a piloted cow is declared again each time
        mgr:deploy(a)
        assert.equals("CTLD_FatCow_FARP_1", played.params.farpName)
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
        assert.equals(0, w.liquids[0])                       -- the FARP stays, emptied
        assert.equals(0, w.items[HELLFIRE])
    end)

    it("packing while the scene is still laying out stops it", function()
        local scene = { _name = "Fat Cow FARP#1", aborted = false }
        function scene:abort() self.aborted = true end
        sm.playScene = function(_, _, _, params) scene._params = params; return scene end   -- not laid out yet
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 100, items = {} })
        mgr:deploy(unit)
        assert.equals(CTLDFatCow.STATE_DEPLOYING, mgr:getCow("Cow-1").state)
        assert.is_true(mgr:pack("Cow-1"))
        assert.is_true(scene.aborted)
        assert.equals(scene, packed)
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
        local later = {}
        local savedSchedule = ctld.scheduler.schedule
        ctld.scheduler.schedule = function(fn) later[#later + 1] = fn end
        mgr:onBirth({ initiator = player })
        ctld.scheduler.schedule = savedSchedule
        assert.equals(4000, mgr:getCow("Cow-1").stock.fuelKg)
        assert.equals(4000, w.liquids[0])
        w.liquids[0] = 54000                                 -- a refill run after CTLD on the same birth
        assert.equals(1, #later)
        later[1]()
        assert.equals(4000, w.liquids[0])
    end)

    it("empties, without reading it, the FARP of a cow packed while still laying out", function()
        sm.playScene = function(_, _, _, params)
            local scene = { _name = "Fat Cow FARP#1", _params = params, abort = function() end }
            return scene                                     -- step 1 done, the warehouse not written yet
        end
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 100, items = { [HELLFIRE] = 6 } })
        mgr:deploy(unit)
        w.liquids[0], w.items["weapons.nurs.HYDRA_70_M151"] = 50000, 5000   -- whatever a new FARP holds
        mgr:pack("Cow-1")
        assert.equals(0, w.liquids[0])
        assert.equals(0, w.items["weapons.nurs.HYDRA_70_M151"])
        assert.equals(100, mgr:getCow("Cow-1").stock.fuelKg)   -- not read back as empty
    end)

    it("reports a deployment whose FARP could not be added as failed", function()
        sm.playScene = function(_, _, _, params)
            local scene = { _name = "Fat Cow FARP#1", _params = params }
            mgr:onSceneFailed(scene)                          -- what the scene's first step does
            return scene
        end
        local unit = cowUnit("Cow-1")
        mgr:addCow(unit, { fuelKg = 100, items = {} })
        local ok, why = mgr:deploy(unit)
        assert.is_false(ok)
        assert.equals("failed", why)
        assert.equals(CTLDFatCow.STATE_STOWED, mgr:getCow("Cow-1").state)
        assert.is_nil(mgr:getCow("Cow-1").scene)
    end)

    it("empties the FARP of a packed cow when it is re-synced, and refills nothing", function()
        local farps = { CTLD_FatCow_FARP_1 = newWarehouse(), CTLD_FatCow_FARP_2 = newWarehouse() }
        Airbase.getByName = function(n) local wh = farps[n]; return wh and { getWarehouse = function() return wh end } end
        local a, b = cowUnit("Cow-1"), cowUnit("Cow-2")
        mgr:addCow(a, { fuelKg = 100, items = {} })
        mgr:deploy(a)
        mgr:pack("Cow-1")
        mgr:addCow(b, { fuelKg = 200, items = {} })
        mgr:deploy(b)
        farps.CTLD_FatCow_FARP_1.liquids[0] = 50000          -- a refill of every FARP
        farps.CTLD_FatCow_FARP_2.liquids[0] = 50000
        mgr:_resyncFarps()
        assert.equals(0, farps.CTLD_FatCow_FARP_1.liquids[0])
        assert.equals(200, farps.CTLD_FatCow_FARP_2.liquids[0])
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
