---@diagnostic disable
-- tests/ci/unit/crate_lifecycle_spec.lua
-- busted specs for CTLDCrateManager lifecycle methods + their published events.
-- Re-integrates coverage that previously lived ONLY in the dead FullGas relics
-- (framework ctld_test, never re-tooled at the VEAF bootstrap):
--   F-027 registerMMCrate — register + guards
--   F-028 loadCrate       — LOADED + OnCrateLoaded
--   F-030 unpackCrate     — UNPACKED + OnCrateUnpacked + registry removal
--   F-041 registerMMCrate — OnMMCrateDetected event
-- crate_manager_spec.lua covers the entity-level crate:load/unload/unpack transitions;
-- this file covers the *manager* methods, their event contracts, and their guards.
-- ============================================================

describe("CTLDCrateManager lifecycle + events", function()

    local cm

    -- Capture every payload published for `eventName` during fn(), then clean up.
    local function capture(eventName, fn)
        local ed    = EventDispatcher.getInstance()
        local fired = {}
        local cb    = function(p) fired[#fired + 1] = p end
        ed:subscribe(eventName, cb)
        local ok, err = pcall(fn)
        ed:unsubscribe(eventName, cb)
        assert(ok, err)
        return fired
    end

    local function transport(name)
        return {
            getName = function() return name or "heli_test" end,
            isExist = function() return true end,
        }
    end

    local function makeCrate(name, xPos)
        return CTLDCrate:new({
            crateName   = name,
            descriptor  = { unit = "M92_Ammo_Pallet", cratesRequired = 1 },
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = { x = xPos or 0, y = 0, z = 0 },
            coalition   = coalition.side.BLUE,
        })
    end

    before_each(function()
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}
    end)

    -- ── F-028 : loadCrate ─────────────────────────────────────────────────────
    describe("loadCrate (F-028)", function()

        it("transitions the crate to LOADED", function()
            cm.crates["c1"] = makeCrate("c1")
            cm:loadCrate("c1", transport("heli1"))
            assert.equals(CTLDCrate.STATE.LOADED, cm.crates["c1"].state)
        end)

        it("publishes OnCrateLoaded once with the carrier unit name", function()
            cm.crates["c1"] = makeCrate("c1")
            local fired = capture("OnCrateLoaded", function()
                cm:loadCrate("c1", transport("heli1"))
            end)
            assert.equals(1,       #fired)
            assert.equals("c1",    fired[1].crateName)
            assert.equals("heli1", fired[1].carrierUnitName)
        end)

        it("does nothing for an unknown crate name (no error, no event)", function()
            local fired = capture("OnCrateLoaded", function()
                cm:loadCrate("does_not_exist", transport())
            end)
            assert.equals(0, #fired)
        end)

        it("does not re-load a crate that is not on the ground", function()
            cm.crates["c1"] = makeCrate("c1")
            cm:loadCrate("c1", transport("heli1"))   -- now LOADED
            local fired = capture("OnCrateLoaded", function()
                cm:loadCrate("c1", transport("heli2"))  -- guard: not on ground
            end)
            assert.equals(0, #fired)
        end)

    end)

    -- ── F-030 : unpackCrate ───────────────────────────────────────────────────
    describe("unpackCrate (F-030)", function()

        it("transitions the crate to UNPACKED", function()
            local crate = makeCrate("c1")
            cm.crates["c1"] = crate
            cm:unpackCrate("c1", transport("heli1"))
            -- crate is unregistered afterwards, so hold our own reference to check final state
            assert.equals(CTLDCrate.STATE.UNPACKED, crate.state)
        end)

        it("publishes OnCrateUnpacked once", function()
            cm.crates["c1"] = makeCrate("c1")
            local fired = capture("OnCrateUnpacked", function()
                cm:unpackCrate("c1", transport("heli1"))
            end)
            assert.equals(1,    #fired)
            assert.equals("c1", fired[1].crateName)
        end)

        it("removes the crate from the registry", function()
            cm.crates["c1"] = makeCrate("c1")
            cm:unpackCrate("c1", transport("heli1"))
            assert.is_nil(cm.crates["c1"])
        end)

        it("does not unpack a crate that is not on the ground", function()
            cm.crates["c1"] = makeCrate("c1")
            cm:loadCrate("c1", transport("heli1"))   -- LOADED, not on ground
            local fired = capture("OnCrateUnpacked", function()
                cm:unpackCrate("c1", transport("heli1"))
            end)
            assert.equals(0,           #fired)
            assert.is_not_nil(cm.crates["c1"])       -- still registered
        end)

    end)

    -- ── F-027 / F-041 : registerMMCrate ───────────────────────────────────────
    describe("registerMMCrate (F-027, F-041)", function()

        -- A valid cargo typeName is one whose descriptor.unit matches (findDescriptorByTypeName).
        -- Derive it from the config rather than hardcoding, so the test tracks the real dataset.
        local function validTypeName()
            local d = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
            return d and d.unit
        end

        local function mmStatic(name, typeName)
            return {
                getName      = function() return name end,
                getPoint     = function() return { x = 10, y = 0, z = 20 } end,
                getCoalition = function() return coalition.side.BLUE end,
                getDesc      = function() return { typeName = typeName } end,
            }
        end

        it("registers a mission-maker crate in the registry", function()
            local tn = validTypeName()
            assert.is_not_nil(tn)
            cm:registerMMCrate(mmStatic("mm_1", tn), { typeName = tn })
            assert.is_not_nil(cm.crates["mm_1"])
            assert.equals(CTLDCrate.SPAWN_METHOD.MISSION_MAKER, cm.crates["mm_1"].spawnMethod)
        end)

        it("publishes OnMMCrateDetected once for a valid crate", function()
            local tn = validTypeName()
            local fired = capture("OnMMCrateDetected", function()
                cm:registerMMCrate(mmStatic("mm_2", tn), { typeName = tn })
            end)
            assert.equals(1,      #fired)
            assert.equals("mm_2", fired[1].crateName)
        end)

        it("skips an unknown cargo type (no register, no event)", function()
            local fired = capture("OnMMCrateDetected", function()
                cm:registerMMCrate(mmStatic("mm_bad", "__NotACargoType__"),
                    { typeName = "__NotACargoType__" })
            end)
            assert.equals(0, #fired)
            assert.is_nil(cm.crates["mm_bad"])
        end)

        it("does not register the same crate name twice", function()
            local tn = validTypeName()
            cm:registerMMCrate(mmStatic("mm_3", tn), { typeName = tn })
            local fired = capture("OnMMCrateDetected", function()
                cm:registerMMCrate(mmStatic("mm_3", tn), { typeName = tn })  -- duplicate
            end)
            assert.equals(0, #fired)
        end)

    end)

    -- ── F-029 : unloadCrate ───────────────────────────────────────────────────
    -- Re-spawns (unloads) a DCS static on the ground → mock coalition.addStaticObject +
    -- StaticObject.getByName (same proven approach as crate_manager_spec's spawnCrate block).
    --
    -- F-031 / F-032 covered CTLDCrateManager:dropCrate, removed in FIX-CATALOGUE-TRUTH: no menu
    -- entry ever called it and the airborne drop it implemented is served by parachuteCrates.
    describe("unloadCrate (F-029)", function()

        local origAddStatic, origGetByName, origGetAbsTime

        before_each(function()
            origAddStatic  = coalition.addStaticObject
            origGetByName  = StaticObject.getByName
            origGetAbsTime = timer.getAbsTime
            local spawned = {}
            coalition.addStaticObject = function(cId, data)
                spawned[data.name] = true
                return { getName = function() return data.name end }
            end
            StaticObject.getByName = function(name)
                return spawned[name] and { _name = name } or nil
            end
            timer.getAbsTime = function() return 100 end
        end)

        after_each(function()
            coalition.addStaticObject = origAddStatic
            StaticObject.getByName    = origGetByName
            timer.getAbsTime          = origGetAbsTime
        end)

        it("unloadCrate transitions LOADED → LANDED (F-029)", function()
            local crate = makeCrate("c1")
            cm.crates["c1"] = crate
            cm:loadCrate("c1", transport("heli1"))
            cm:unloadCrate("c1", { x = 100, y = 0, z = 100 }, "menu_ctld")
            assert.equals(CTLDCrate.STATE.LANDED, crate.state)
        end)

        it("unloadCrate publishes OnCrateUnloaded with the method (F-029)", function()
            local crate = makeCrate("c1")
            cm.crates["c1"] = crate
            cm:loadCrate("c1", transport("heli1"))
            local fired = capture("OnCrateUnloaded", function()
                cm:unloadCrate("c1", { x = 100, y = 0, z = 100 }, "menu_ctld")
            end)
            assert.equals(1,           #fired)
            assert.equals("menu_ctld", fired[1].method)
        end)

        it("unloadCrate re-registers the crate on the ground (F-029)", function()
            local crate = makeCrate("c1")
            cm.crates["c1"] = crate
            cm:loadCrate("c1", transport("heli1"))
            cm:unloadCrate("c1", { x = 100, y = 0, z = 100 }, "menu_ctld")
            -- crate may have been renamed by the respawn; look it up by its (updated) name
            assert.equals(crate, cm.crates[crate.crateName])
        end)


    end)

end)
