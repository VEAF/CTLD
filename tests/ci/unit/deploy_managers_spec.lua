---@diagnostic disable
-- tests/ci/unit/deploy_managers_spec.lua
-- busted specs for the three "deployment" managers and their published events.
-- Re-integrates coverage that previously lived ONLY in the dead FullGas relics
-- (tests/dcs/noPlayer/F-0NN_*.lua), recomputed against the CURRENT src/:
--   F-021 CTLDCrateAssemblyManager assembly (complete)   → OnAASystemDeployed
--   F-022 CTLDCrateAssemblyManager assembly (incomplete)  → no deployment
--   F-023 CTLDCrateAssemblyManager repair                 → OnAASystemRepaired
--   F-012 CTLDFOBManager:_registerDeployedFOB             → OnFOBDeployed
--   F-013 CTLDFOBManager:onDead / _destroyFOB             → OnFOBDestroyed
--   F-099 CTLDVehicleSpawner findPackableVehicles/packVehicle → OnVehiclePacked
--
-- The relics ran against a live DCS mission (real transport, real dynAdd). Here the
-- DCS group/static spawn is mocked so the logic, event contracts and registry
-- side-effects are exercised deterministically under busted.
-- ============================================================

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

-- ============================================================
-- F-021 / F-022 / F-023 : CTLDCrateAssemblyManager
-- ============================================================
describe("CTLDCrateAssemblyManager assembly + repair", function()

    local aam
    local origDynAdd, origGetByName, origHeading

    -- name → fake DCS Group built by the mocked dynAdd. Each fake group exposes the
    -- subset of the API the manager touches (getName/getCoalition/getUnits/destroy).
    local spawnedGroups

    -- Pull the KUB template straight from the live TEMPLATES so the test tracks the
    -- real dataset (2 parts, both required, count=2) instead of hardcoding type names.
    local function kubTemplate()
        local t = aam:getTemplateByName("KUB AA System")
        if not t then return nil end
        local launcher, radar
        for _, p in ipairs(t.parts) do
            if p.launcher then launcher = p.DCSTypename else radar = p.DCSTypename end
        end
        return t, launcher, radar
    end

    local function heli(coa)
        return {
            getPoint     = function() return { x = 0, y = 0, z = 0 } end,
            getCoalition = function() return coa or coalition.side.BLUE end,
            getCountry   = function() return country.id.USA end,
            getName      = function() return "heli_aa" end,
            getGroup     = function() return { getID = function() return 1 end } end,
        }
    end

    -- Duck-typed CTLDCrate stand-in (same shape the manager consumes: descriptor,
    -- position, isOnGround, destroy). Tracks how many times it was destroyed.
    -- The crate is also registered in CTLDCrateManager so that _assemble() can
    -- reach it via CTLDCrateManager:destroyCrate(c.crateName).
    local _crateIdx = 0
    local function aaCrate(unitName, repairFor)
        _crateIdx = _crateIdx + 1
        local name = "aa_test_crate_" .. _crateIdx
        local c = {
            crateName      = name,
            descriptor     = { unit = unitName, _repairFor = repairFor, cratesRequired = 1 },
            position       = { x = 100, y = 0, z = 0 },
            coalition      = coalition.side.BLUE,
            destroyedCount = 0,
        }
        function c:isOnGround() return true end
        function c:destroy() self.destroyedCount = self.destroyedCount + 1 end
        CTLDCrateManager.getInstance().crates[name] = c
        return c
    end

    before_each(function()
        aam = CTLDCrateAssemblyManager.getInstance()
        aam._completeSystems = {}
        _crateIdx = 0
        CTLDCrateManager._instance = nil

        spawnedGroups = {}
        origDynAdd    = ctld.utils.dynAdd
        origGetByName = Group.getByName
        origHeading   = ctld.utils.getHeadingInRadians

        -- Deterministic north-up heading everywhere the manager asks.
        ctld.utils.getHeadingInRadians = function() return 0 end

        -- Fake group spawner: materialise one unit mock per groupData.units entry.
        ctld.utils.dynAdd = function(_caller, gd)
            local units = {}
            for _, u in ipairs(gd.units) do
                units[#units + 1] = {
                    getPoint    = function() return { x = u.x, y = 0, z = u.y } end,
                    getTypeName = function() return u.type end,
                    getName     = function() return u.name end,
                    getLife     = function() return 1 end,
                }
            end
            local g = {
                getName      = function() return gd.name end,
                getCoalition = function() return coalition.side.BLUE end,
                getUnits     = function() return units end,
                destroy      = function() end,
            }
            spawnedGroups[gd.name] = g
            return { name = gd.name }
        end
        Group.getByName = function(name) return spawnedGroups[name] end
    end)

    after_each(function()
        ctld.utils.dynAdd              = origDynAdd
        Group.getByName                = origGetByName
        ctld.utils.getHeadingInRadians = origHeading
        CTLDCrateManager._instance     = nil
    end)

    -- ── F-021 : complete assembly ─────────────────────────────────────────────
    describe("assembly of a complete system (F-021)", function()

        it("tryUnpackOrRepair returns true for an AA part crate", function()
            local t, launcher, radar = kubTemplate()
            assert.is_not_nil(t)
            local crateLn = aaCrate(launcher)
            local all = { kub_ln = crateLn, kub_sr = aaCrate(radar) }
            assert.is_true(aam:tryUnpackOrRepair(heli(), crateLn, all, 500))
        end)

        it("publishes OnAASystemDeployed with the KUB payload", function()
            local t, launcher, radar = kubTemplate()
            assert.is_not_nil(t)
            local crateLn = aaCrate(launcher)
            local all = { kub_ln = crateLn, kub_sr = aaCrate(radar) }
            local fired = capture("OnAASystemDeployed", function()
                aam:tryUnpackOrRepair(heli(), crateLn, all, 500)
            end)
            assert.equals(1, #fired)
            assert.equals("KUB AA System",   fired[1].systemName)
            assert.is_not_nil(fired[1].groupName)
            assert.is_not_nil(fired[1].position)
            assert.equals(coalition.side.BLUE, fired[1].coalition)
            assert.is_not_nil(fired[1].timestamp)
        end)

        it("registers the system and counts it as complete", function()
            local t, launcher, radar = kubTemplate()
            local crateLn = aaCrate(launcher)
            aam:tryUnpackOrRepair(heli(), crateLn, { kub_ln = crateLn, kub_sr = aaCrate(radar) }, 500)

            local n = 0
            for _ in pairs(aam._completeSystems) do n = n + 1 end
            assert.equals(1, n)
            assert.equals(1, aam:countComplete(coalition.side.BLUE))
        end)

        it("destroys the consumed crates", function()
            local t, launcher, radar = kubTemplate()
            local crateLn = aaCrate(launcher)
            local crateSr = aaCrate(radar)
            aam:tryUnpackOrRepair(heli(), crateLn, { kub_ln = crateLn, kub_sr = crateSr }, 500)
            assert.is_true(crateLn.destroyedCount >= 1)
            assert.is_true(crateSr.destroyedCount >= 1)
        end)

    end)

    -- ── F-022 : incomplete assembly ───────────────────────────────────────────
    describe("assembly with missing parts (F-022)", function()

        it("recognises the AA crate (returns true) but does not deploy", function()
            local t, launcher = kubTemplate()
            assert.is_not_nil(t)
            local crateLn = aaCrate(launcher)         -- launcher only, radar missing
            local all     = { kub_ln = crateLn }
            local result

            local fired = capture("OnAASystemDeployed", function()
                result = aam:tryUnpackOrRepair(heli(), crateLn, all, 500)
            end)

            assert.is_true(result)          -- AA type recognised even if incomplete
            assert.equals(0, #fired)        -- but no deployment event
        end)

        it("leaves the registry empty and consumes no crate", function()
            local t, launcher = kubTemplate()
            local crateLn = aaCrate(launcher)
            aam:tryUnpackOrRepair(heli(), crateLn, { kub_ln = crateLn }, 500)

            local n = 0
            for _ in pairs(aam._completeSystems) do n = n + 1 end
            assert.equals(0, n)
            assert.equals(0, aam:countComplete(coalition.side.BLUE))
            assert.equals(0, crateLn.destroyedCount)
        end)

    end)

    -- ── F-023 : repair ────────────────────────────────────────────────────────
    describe("repair of an existing system (F-023)", function()

        it("getTemplateForUnit resolves a repair marker to its template", function()
            local t = kubTemplate()
            assert.is_not_nil(t)
            local tmpl, isRepair = aam:getTemplateForUnit(nil, "KUB AA System")
            assert.is_not_nil(tmpl)
            assert.equals("KUB AA System", tmpl.name)
            assert.is_true(isRepair)
        end)

        it("publishes OnAASystemRepaired and keeps exactly one system registered", function()
            local t, launcher, radar = kubTemplate()
            assert.is_not_nil(t)

            -- STEP 1: deploy a complete KUB so there is something to repair.
            local crateLn = aaCrate(launcher)
            aam:tryUnpackOrRepair(heli(), crateLn, { kub_ln = crateLn, kub_sr = aaCrate(radar) }, 500)
            local before = 0
            for _ in pairs(aam._completeSystems) do before = before + 1 end
            assert.equals(1, before)

            -- STEP 2: repair it with a repair crate (descriptor._repairFor = template name).
            local repairCrate = aaCrate(nil, "KUB AA System")
            local result
            local fired = capture("OnAASystemRepaired", function()
                result = aam:tryUnpackOrRepair(heli(), repairCrate, {}, 500)
            end)

            assert.is_true(result)
            assert.equals(1, #fired)
            assert.equals("KUB AA System",    fired[1].systemName)
            assert.is_not_nil(fired[1].groupName)
            assert.equals(coalition.side.BLUE, fired[1].coalition)
            assert.is_not_nil(fired[1].timestamp)

            assert.is_true(repairCrate.destroyedCount >= 1)

            local after = 0
            for _ in pairs(aam._completeSystems) do after = after + 1 end
            assert.equals(1, after)   -- old system replaced, not duplicated
        end)

    end)

end)

-- ============================================================
-- F-012 / F-013 : CTLDFOBManager
-- ============================================================
describe("CTLDFOBManager deploy + destroy", function()

    local fm

    -- Scene object stand-in with a mutable alive flag (drives getIntegrityPercent).
    local function sceneObj(name)
        local o = { _alive = true, getName = function() return name end }
        o.isExist = function() return o._alive end
        return o
    end

    local FOB_CENTROID = { x = 10, y = 0, z = 20 }

    -- Minimal completed-scene stand-in: _registerDeployedFOB reads _params + _spawnedObjs.
    -- No transportName → the beacon branch (Unit.getByName / CTLDBeaconManager) is skipped.
    local function scene(objs)
        return {
            _params = {
                centroid    = FOB_CENTROID,
                coalitionId = coalition.side.BLUE,
                countryId   = country.id.USA,
                player      = "auto-unpack",
                cratesUsed  = { "c1", "c2" },
            },
            _spawnedObjs = objs,
            _refHdgRad   = 0,
        }
    end

    local function resetFOBManager()
        fm._fobs        = {}
        fm._objectToFOB = {}
        fm._fobCount    = 0
    end

    before_each(function()
        fm = CTLDFOBManager.getInstance()
        resetFOBManager()
    end)

    -- ── F-012 : deploy ────────────────────────────────────────────────────────
    describe("_registerDeployedFOB (F-012)", function()

        it("publishes OnFOBDeployed with the FOB payload and crate count", function()
            local fired = capture("OnFOBDeployed", function()
                fm:_registerDeployedFOB(scene({ sceneObj("fobA"), sceneObj("fobB") }))
            end)
            assert.equals(1, #fired)
            assert.equals("fob_001",        fired[1].fob.fobId)
            assert.equals("Deployed FOB #1", fired[1].fob.name)
            assert.equals(2,                fired[1].totalCratesUsed)
            assert.equals(10,               fired[1].position.x)
            assert.is_not_nil(fired[1].logisticZone)
        end)

        it("registers the FOB and its reverse object lookup", function()
            fm:_registerDeployedFOB(scene({ sceneObj("fobA"), sceneObj("fobB") }))
            assert.is_not_nil(fm._fobs["fob_001"])
            assert.equals("fob_001", fm._objectToFOB["fobA"])
            assert.equals("fob_001", fm._objectToFOB["fobB"])
        end)

    end)

    -- ── F-013 : integrity / destroy ───────────────────────────────────────────
    describe("onDead integrity + _destroyFOB (F-013)", function()

        it("destroys the FOB and cleans up when integrity drops below threshold", function()
            local o1, o2 = sceneObj("deadA"), sceneObj("deadB")
            fm:_registerDeployedFOB(scene({ o1, o2 }))

            -- Both scene objects die → integrity 0/2 = 0 < (1 - threshold).
            o1._alive, o2._alive = false, false

            local fired = capture("OnFOBDestroyed", function()
                fm:onDead({ initiator = o1 })
            end)

            assert.equals(1, #fired)
            assert.equals("fob_001", fired[1].fob.fobId)
            assert.equals(0,         fired[1].destruction.integrityPercent)
            assert.is_not_nil(fired[1].durationAlive)

            assert.is_nil(fm._fobs["fob_001"])          -- unregistered
            assert.is_nil(fm._objectToFOB["deadA"])      -- reverse lookup cleaned
            assert.is_nil(fm._objectToFOB["deadB"])
        end)

        it("keeps the FOB alive when integrity is at/above threshold", function()
            local o1, o2 = sceneObj("halfA"), sceneObj("halfB")
            fm:_registerDeployedFOB(scene({ o1, o2 }))

            -- One object dies → integrity 1/2 = 0.5, NOT below (1 - 0.5) = 0.5.
            o1._alive = false

            local fired = capture("OnFOBDestroyed", function()
                fm:onDead({ initiator = o1 })
            end)

            assert.equals(0, #fired)                     -- no destruction event
            assert.is_not_nil(fm._fobs["fob_001"])        -- still registered
        end)

    end)

    -- ── FIX-FOB-TROOP-PICKUP : troop pickup zone ─────────────────────────────
    describe("troop pickup zone (FIX-FOB-TROOP-PICKUP)", function()

        before_each(function()
            CTLDZoneManager.getInstance()._troopZones = {}
        end)

        it("registers a pickup-capable troop zone at the FOB centroid when troopPickupAtFOB is true", function()
            fm:_registerDeployedFOB(scene({ sceneObj("fobA"), sceneObj("fobB") }))
            local zone = CTLDZoneManager.getInstance():getTroopZoneAtPoint(FOB_CENTROID, coalition.side.BLUE)
            assert.is_not_nil(zone)
            assert.is_true(zone:hasPickup())
        end)

        it("registers no troop zone when troopPickupAtFOB is false", function()
            local borrowed = ctldTestSettings.borrow({ troopPickupAtFOB = false })
            fm:_registerDeployedFOB(scene({ sceneObj("fobA"), sceneObj("fobB") }))
            local zone = CTLDZoneManager.getInstance():getTroopZoneAtPoint(FOB_CENTROID, coalition.side.BLUE)
            assert.is_nil(zone)
            borrowed:restore()
        end)

        it("removes the troop zone when the FOB is destroyed (no ghost zone)", function()
            local o1, o2 = sceneObj("deadTroopA"), sceneObj("deadTroopB")
            fm:_registerDeployedFOB(scene({ o1, o2 }))
            assert.is_not_nil(CTLDZoneManager.getInstance():getTroopZoneAtPoint(FOB_CENTROID, coalition.side.BLUE))

            o1._alive, o2._alive = false, false
            fm:onDead({ initiator = o1 })

            local zone = CTLDZoneManager.getInstance():getTroopZoneAtPoint(FOB_CENTROID, coalition.side.BLUE)
            assert.is_nil(zone)
        end)

        it("leaves isInFOBTroopZone behaving exactly as before, for both settings", function()
            fm:_registerDeployedFOB(scene({ sceneObj("fobC"), sceneObj("fobD") }))
            assert.is_true(fm:isInFOBTroopZone(FOB_CENTROID, coalition.side.BLUE))

            resetFOBManager()
            CTLDZoneManager.getInstance()._troopZones = {}
            local borrowed = ctldTestSettings.borrow({ troopPickupAtFOB = false })
            fm:_registerDeployedFOB(scene({ sceneObj("fobE"), sceneObj("fobF") }))
            assert.is_false(fm:isInFOBTroopZone(FOB_CENTROID, coalition.side.BLUE))
            borrowed:restore()
        end)

    end)

end)

-- ============================================================
-- F-099 : CTLDVehicleSpawner pack
-- ============================================================
describe("CTLDVehicleSpawner pack (F-099)", function()

    local vs
    local origUnitByName, origAddStatic, origGetByName, origSchedule
    local scheduled

    local PACKABLE_TYPE = "M1043 HMMWV Armament"

    local function transport()
        return {
            _point = { x = 0, y = 5, z = 0 },
            isExist      = function() return true end,
            getName      = function() return "Heli1" end,
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return country.id.USA end,
            getTypeName  = function() return "UH-1H" end,
            getPoint     = function(s) return s._point end,
            getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
            getDesc      = function() return { box = { min = { x = -5, y = -2, z = -5 },
                                                       max = { x = 5,  y = 3,  z = 5 } } } end,
            -- north-facing (heading 0)
            getPosition  = function(s) return { x = { x = 1, y = 0, z = 0 },
                                                 y = { x = 0, y = 1, z = 0 }, p = s._point } end,
        }
    end

    before_each(function()
        vs = CTLDVehicleSpawner.getInstance()
        vs._vehicles = {}

        origUnitByName = Unit.getByName
        origAddStatic  = coalition.addStaticObject
        origGetByName  = StaticObject.getByName
        origSchedule   = timer.scheduleFunction

        -- Capture deferred functions instead of running them synchronously.
        scheduled = {}
        timer.scheduleFunction = function(fn) scheduled[#scheduled + 1] = fn; return #scheduled end

        -- Track spawned statics so StaticObject.getByName can hand back a live handle.
        local spawned = {}
        coalition.addStaticObject = function(_cId, data)
            spawned[data.name] = true
            return { getName = function() return data.name end }
        end
        StaticObject.getByName = function(name)
            return spawned[name] and { _name = name } or nil
        end
        vs._spawnedStatics = spawned   -- exposed for assertions
    end)

    after_each(function()
        Unit.getByName            = origUnitByName
        coalition.addStaticObject = origAddStatic
        StaticObject.getByName    = origGetByName
        timer.scheduleFunction    = origSchedule
    end)

    -- ── findPackableVehicles ───────────────────────────────────────────────────
    describe("findPackableVehicles", function()

        local function registerWaiting(unitName)
            vs._vehicles["veh_1"] = CTLDVehicle:new({
                id          = "veh_1",
                vehicleType = PACKABLE_TYPE,
                spawnData   = { unitName = unitName },
            })
        end

        it("returns a WAITING CTLD vehicle in range with its descriptor", function()
            registerWaiting("HumveeMG1")
            Unit.getByName = function(name)
                if name == "HumveeMG1" then
                    return {
                        isExist     = function() return true end,
                        getName     = function() return "HumveeMG1" end,
                        getTypeName = function() return PACKABLE_TYPE end,
                        getPoint    = function() return { x = 10, y = 0, z = 10 } end,
                    }
                end
                return nil
            end

            local packable = vs:findPackableVehicles(transport())
            assert.equals(1, #packable)
            assert.equals("HumveeMG1", packable[1].unitName)
            assert.is_not_nil(packable[1].descriptor)
            assert.equals(PACKABLE_TYPE, packable[1].descriptor.unit)
        end)

        it("ignores a vehicle outside the pack search radius", function()
            registerWaiting("FarHumvee")
            Unit.getByName = function(name)
                if name == "FarHumvee" then
                    return {
                        isExist     = function() return true end,
                        getName     = function() return "FarHumvee" end,
                        getTypeName = function() return PACKABLE_TYPE end,
                        getPoint    = function() return { x = 5000, y = 0, z = 5000 } end,
                    }
                end
                return nil
            end

            assert.equals(0, #vs:findPackableVehicles(transport()))
        end)

    end)

    -- ── packVehicle ────────────────────────────────────────────────────────────
    describe("packVehicle", function()

        local function packableVehicle(destroyedRef)
            return {
                isExist     = function() return not destroyedRef.done end,
                getName     = function() return "HumveeMG1" end,
                getTypeName = function() return PACKABLE_TYPE end,
                getPoint    = function() return { x = 3, y = 0, z = 3 } end,
                getGroup    = function() return nil end,   -- skip JTAC deregister
                destroy     = function() destroyedRef.done = true end,
            }
        end

        it("destroys the vehicle and publishes OnVehiclePacked with the crate count", function()
            local t   = transport()
            local ref = { done = false }
            local veh = packableVehicle(ref)
            Unit.getByName = function(name)
                if name == "Heli1"     then return t   end
                if name == "HumveeMG1" then return veh end
                return nil
            end

            local descriptor = CTLDCrateManager.getInstance():findDescriptorByUnitType(PACKABLE_TYPE)
            assert.is_not_nil(descriptor)
            local expected = descriptor.cratesRequired or 1

            local packed, spawnedCrates
            capture("OnCrateSpawned", function()
                spawnedCrates = 0
                local ed = EventDispatcher.getInstance()
                local cb = function() spawnedCrates = spawnedCrates + 1 end
                ed:subscribe("OnCrateSpawned", cb)
                packed = capture("OnVehiclePacked", function()
                    vs:packVehicle("Heli1", "HumveeMG1", { unitName = "Heli1", groupId = 1,
                                                            coalition = coalition.side.BLUE })
                end)
                ed:unsubscribe("OnCrateSpawned", cb)
            end)

            assert.is_true(ref.done)                        -- vehicle unit destroyed
            assert.equals(1, #packed)
            assert.equals(PACKABLE_TYPE, packed[1].vehicleType)
            assert.equals(expected, packed[1].cratesSpawned)
            assert.equals(expected, spawnedCrates)          -- one OnCrateSpawned per crate

            -- one DCS static per crate
            local n = 0
            for _ in pairs(vs._spawnedStatics) do n = n + 1 end
            assert.equals(expected, n)
        end)

        it("defers a Pack-menu refresh for the transport unit", function()
            local t   = transport()
            local ref = { done = false }
            local veh = packableVehicle(ref)
            Unit.getByName = function(name)
                if name == "Heli1"     then return t   end
                if name == "HumveeMG1" then return veh end
                return nil
            end

            vs:packVehicle("Heli1", "HumveeMG1", { unitName = "Heli1", groupId = 1,
                                                   coalition = coalition.side.BLUE })

            -- Spy refreshForUnit, then run every deferred function captured above.
            local pm       = CTLDPlayerManager.getInstance()
            local refreshed = {}
            pm.refreshForUnit = function(_self, n) refreshed[#refreshed + 1] = n end
            for _, fn in ipairs(scheduled) do pcall(fn) end
            pm.refreshForUnit = nil   -- drop the instance shadow, class method resurfaces

            assert.is_true(#scheduled >= 1)
            assert.equals("Heli1", refreshed[1])
        end)

        it("guards against packing a vehicle that no longer exists", function()
            local t = transport()
            Unit.getByName = function(name)
                if name == "Heli1" then return t end
                if name == "Ghost" then
                    return {
                        isExist     = function() return false end,
                        getName     = function() return "Ghost" end,
                        getTypeName = function() return PACKABLE_TYPE end,
                        getPoint    = function() return { x = 0, y = 0, z = 0 } end,
                        destroy     = function() end,
                    }
                end
                return nil
            end

            local packed = capture("OnVehiclePacked", function()
                vs:packVehicle("Heli1", "Ghost", { unitName = "Heli1", groupId = 1,
                                                   coalition = coalition.side.BLUE })
            end)
            assert.equals(0, #packed)   -- no packing happened
        end)

    end)

end)
