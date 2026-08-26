---@diagnostic disable
-- tests/ci/unit/scenes_minefields_spec.lua
-- busted specs for the FARP / minefield scene models. Re-integrates coverage that
-- previously lived ONLY in the dead FullGas relics (framework ctld_test, never re-tooled):
--   F-043  FARP Alpha scene structure       (src/scenes/CTLD_farpAlphaScene.lua)
--   F-091  farpScene structure — Part 1 only (src/scenes/CTLD_farpScene.lua)
--   F-083  setLandMine 1x1 → 1 mine          (src/scenes/CTLD_mineFieldScene.lua)
--   F-084  setLandMine 5x15 quinconce → 68   (recomputed from src, see below)
--   F-085  setLandMine 4x3 quinconce → 11
--   F-087  setLandMineAuto parametric + single-mine branch + guards
--
-- Scenes self-register into CTLDSceneManager; the model table is retrieved via
-- getModel(name). The mineField model exposes setLandMine / setLandMineAuto and its
-- own _sets registry as plain table fields, so they can be driven directly here.
--
-- Mine counting: the spawn primitive is CTLDObjectRegistry.spawnObject("Landmine", ...).
-- We stub it to count invocations and return a fake DCS static; setLandMine collects
-- every truthy return into its result array, so #result == number of mines spawned.
--
-- Quinconce mine-count formula (src ~l.210, nbMinesColumns=N >= 2, nbMinesPerColumns=R):
--   odd rows  (r=1,3,...) : N mines
--   even rows (r=2,4,...) : N-1 mines
--   total T(N,R) = R*N - floor(R/2)
--     F-084  N=5, R=15 : 15*5 - floor(15/2) = 75 - 7 = 68
--     F-085  N=4, R=3  :  3*4 - floor(3/2)  = 12 - 1 = 11
-- ============================================================

-- Resolve repo root so we can dofile the scene files. The CI loader (helpers/loader.lua)
-- loads src/ managers but NOT src/scenes/*, so each scene spec loads its own scene files.
local _thisFile = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]unit[\\/]")
if not _thisFile then _thisFile = "" end  -- relative path: cwd is repo root

-- Scene files write i18n into ctld.i18n["fr"/"es"/"ko"], but loader.lua only loads the EN
-- dictionary. Load the non-EN dicts here (idempotent) so the scene dofiles below never index
-- a nil language table, regardless of spec execution order. Same pattern as i18n_spec.lua.
dofile(_thisFile .. "src/CTLD_i18n_fr.lua")
dofile(_thisFile .. "src/CTLD_i18n_es.lua")
dofile(_thisFile .. "src/CTLD_i18n_ko.lua")

describe("FARP / minefield scenes", function()

    local sm

    -- Register the scene models once. registerSceneModel is a no-op if a model of the
    -- same name is already registered (e.g. mineField loaded by another spec), so this is
    -- safe regardless of spec execution order.
    setup(function()
        dofile(_thisFile .. "src/scenes/CTLD_mineFieldScene.lua")
        dofile(_thisFile .. "src/scenes/CTLD_farpAlphaScene.lua")
        dofile(_thisFile .. "src/scenes/CTLD_farpScene.lua")
        dofile(_thisFile .. "src/scenes/CTLD_countrysideFarpScene.lua")
    end)

    before_each(function()
        sm = CTLDSceneManager.getInstance()
    end)

    -- ── F-043 : FARP Alpha scene structure ────────────────────────────────────
    describe("FARP Alpha scene structure (F-043)", function()

        local model
        before_each(function() model = sm:getModel("FARP Alpha") end)

        it("is registered as a built-in scene model", function()
            assert.is_not_nil(model)
            assert.equals("FARP Alpha", model.name)
        end)

        it("has 15 steps (13 spawn + 1 completion func + 1 troop pickup func)", function()
            assert.equals(15, #model.steps)
        end)

        it("step 1 spawns SINGLE_HELIPAD at polar 100/0 with a fuel-warehouse func", function()
            local s = model.steps[1]
            assert.equals("SINGLE_HELIPAD", s.registryKey)
            assert.is_not_nil(s.polar)
            assert.equals(100, s.polar.distance)
            assert.equals(0,   s.polar.angle)
            assert.is_function(s.func)
        end)

        it("step 2 spawns FARP_Tent and carries relativeHeadingInDegrees", function()
            local s = model.steps[2]
            assert.equals("FARP_Tent", s.registryKey)
            assert.is_not_nil(s.relativeHeadingInDegrees)
        end)

        it("step 14 is func-only (completion message, no registryKey)", function()
            local s = model.steps[14]
            assert.is_nil(s.registryKey)
            assert.is_function(s.func)
        end)

        it("step 15 is func-only (troop pickup registration, no registryKey)", function()
            local s = model.steps[15]
            assert.is_nil(s.registryKey)
            assert.is_function(s.func)
        end)

        it("every step carries a delayAfterPreviousStep", function()
            for _, s in ipairs(model.steps) do
                assert.is_not_nil(s.delayAfterPreviousStep)
            end
        end)

        it("exposes its crate descriptor (weight, deploy/i18n keys, 1 crate required)", function()
            assert.is_not_nil(model.crate)
            assert.equals(1001.23,            model.crate.weight)
            assert.equals("FARP Alpha Crate", model.crate.i18nKey)
            assert.equals("Deploy FARP Alpha", model.crate.deployKey)
            assert.equals(1,                  model.crate.cratesRequired)
        end)

    end)

    -- ── F-091 : farpScene structure (Part 1 only — visual spawn is out of busted scope) ──
    describe("farpScene structure (F-091 Part 1)", function()

        local model
        before_each(function() model = sm:getModel("farpScene") end)

        it("is registered after its scene file loads", function()
            assert.is_not_nil(model)
            assert.equals("farpScene", model.name)
        end)

        it("has 7 steps (prescript + 5 objects + 1 troop pickup func)", function()
            assert.equals(7, #model.steps)
        end)

        it("step 1 is the prescript func (no registryKey, delay 0)", function()
            local s = model.steps[1]
            assert.is_nil(s.registryKey)
            assert.is_function(s.func)
            assert.equals(0, s.delayAfterPreviousStep)
        end)

        it("step 2 spawns SINGLE_HELIPAD at the reference point (polar 0/0, delay 0)", function()
            local s = model.steps[2]
            assert.equals("SINGLE_HELIPAD", s.registryKey)
            assert.equals(0, s.polar.distance)
            assert.equals(0, s.polar.angle)
            assert.equals(0, s.delayAfterPreviousStep)
        end)

        it("step 3 spawns FARP_Tent at 30 m / 90° (delay 1 s)", function()
            local s = model.steps[3]
            assert.equals("FARP_Tent", s.registryKey)
            assert.equals(30, s.polar.distance)
            assert.equals(90, s.polar.angle)
            assert.equals(1,  s.delayAfterPreviousStep)
        end)

        it("step 4 spawns FARP_Ammo_Storage at 30 m / 135°", function()
            local s = model.steps[4]
            assert.equals("FARP_Ammo_Storage", s.registryKey)
            assert.equals(30,  s.polar.distance)
            assert.equals(135, s.polar.angle)
        end)

        it("step 5 spawns Windsock at 15 m / 270°", function()
            local s = model.steps[5]
            assert.equals("Windsock", s.registryKey)
            assert.equals(15,  s.polar.distance)
            assert.equals(270, s.polar.angle)
        end)

        it("step 6 spawns Fuel_Truck at 35 m / 225° (delay 1 s)", function()
            local s = model.steps[6]
            assert.equals("Fuel_Truck", s.registryKey)
            assert.equals(35,  s.polar.distance)
            assert.equals(225, s.polar.angle)
            assert.equals(1,   s.delayAfterPreviousStep)
        end)

        it("object steps 2-6 all carry relativeAltitudeInMeters", function()
            for i = 2, 6 do
                assert.is_not_nil(model.steps[i].relativeAltitudeInMeters)
            end
        end)

        it("step 7 is func-only (troop pickup registration, no registryKey)", function()
            local s = model.steps[7]
            assert.is_nil(s.registryKey)
            assert.is_function(s.func)
        end)

    end)

    -- ── Countryside FARP scene structure (FEAT-FARP-TROOP-PICKUP) ─────────────
    describe("Countryside FARP scene structure", function()

        local model
        before_each(function() model = sm:getModel("Countryside FARP") end)

        it("is registered as a built-in scene model", function()
            assert.is_not_nil(model)
            assert.equals("Countryside FARP", model.name)
        end)

        it("has 12 steps (9 spawn + 1 warehouse/message func + 1 troop pickup func)", function()
            assert.equals(12, #model.steps)
        end)

        it("step 1 spawns Invisible_FARP", function()
            assert.equals("Invisible_FARP", model.steps[1].registryKey)
        end)

        it("step 12 is func-only (troop pickup registration, no registryKey)", function()
            local s = model.steps[12]
            assert.is_nil(s.registryKey)
            assert.is_function(s.func)
        end)

    end)

    -- ── FARP troop pickup registration (FEAT-FARP-TROOP-PICKUP) ───────────────
    -- Drives each scene's own final step.func(ctx) directly, then asserts through the
    -- public CTLDZoneManager path — the same discipline FIX-FOB-TROOP-PICKUP established.
    describe("FARP troop pickup registration (FEAT-FARP-TROOP-PICKUP)", function()

        local origGs, origAirbaseGetByName, settings

        local function fakeHelipad(name, point)
            local o = { _exists = true }
            function o:getName()  return name end
            function o:getPoint() return point end
            return o
        end

        local function fakeAirbase(helipad)
            local ab = { _helipad = helipad }
            function ab:getName()  return helipad:getName() end
            function ab:getPoint() return helipad:getPoint() end
            function ab:isExist()  return helipad._exists end
            return ab
        end

        local function ctxFor(spawnedObj, coalitionId)
            return {
                unit  = { getName = function() return "test-unit" end },
                scene = {
                    _spawnedObjs = { spawnedObj },
                    _coalitionId = coalitionId or coalition.side.BLUE,
                    _params      = {},
                },
            }
        end

        before_each(function()
            CTLDZoneManager.getInstance()._troopZones = {}

            origGs   = ctld.gs
            settings = {}
            ctld.gs  = function(key)
                if settings[key] ~= nil then return settings[key] end
                return origGs and origGs(key)
            end

            origAirbaseGetByName = Airbase.getByName
        end)

        after_each(function()
            ctld.gs           = origGs
            Airbase.getByName = origAirbaseGetByName
        end)

        for _, sceneName in ipairs({ "farpScene", "FARP Alpha", "Countryside FARP" }) do
            describe(sceneName, function()

                local function lastStepFunc()
                    local model = sm:getModel(sceneName)
                    return model.steps[#model.steps].func
                end

                it("registers a pickup-capable troop zone when troopPickupAtFARP is true", function()
                    local pad = fakeHelipad(sceneName .. "-1", { x = 10, y = 0, z = 20 })
                    local ab  = fakeAirbase(pad)
                    Airbase.getByName = function(n) return (n == pad:getName()) and ab or nil end

                    lastStepFunc()(ctxFor(pad))

                    local zone = CTLDZoneManager.getInstance():getTroopZoneAtPoint(
                        { x = 10, y = 0, z = 20 }, coalition.side.BLUE)
                    assert.is_not_nil(zone)
                    assert.is_true(zone:hasPickup())
                end)

                it("registers no troop zone when troopPickupAtFARP is false", function()
                    settings.troopPickupAtFARP = false
                    local pad = fakeHelipad(sceneName .. "-2", { x = 10, y = 0, z = 20 })
                    local ab  = fakeAirbase(pad)
                    Airbase.getByName = function(n) return (n == pad:getName()) and ab or nil end

                    lastStepFunc()(ctxFor(pad))

                    local zone = CTLDZoneManager.getInstance():getTroopZoneAtPoint(
                        { x = 10, y = 0, z = 20 }, coalition.side.BLUE)
                    assert.is_nil(zone)
                end)

                it("removes the troop zone once the airbase stops existing (no ghost zone)", function()
                    local pad = fakeHelipad(sceneName .. "-3", { x = 10, y = 0, z = 20 })
                    local ab  = fakeAirbase(pad)
                    Airbase.getByName = function(n) return (n == pad:getName()) and ab or nil end

                    lastStepFunc()(ctxFor(pad))
                    assert.is_not_nil(CTLDZoneManager.getInstance():getTroopZoneAtPoint(
                        { x = 10, y = 0, z = 20 }, coalition.side.BLUE))

                    pad._exists = false
                    CTLDStaticWatcher.getInstance():_tick(0)

                    local zone = CTLDZoneManager.getInstance():getTroopZoneAtPoint(
                        { x = 10, y = 0, z = 20 }, coalition.side.BLUE)
                    assert.is_nil(zone)
                end)

            end)
        end

    end)

    -- ── F-083 / F-084 / F-085 / F-087 : minefield spawning ─────────────────────
    describe("minefield spawning (F-083, F-084, F-085, F-087)", function()

        local scene
        local origSpawnObject
        local spawnCount

        -- A minimal DCS Unit stub. getHeadingInRadians(rawHeading=true) reads
        -- getPosition().x (orientation vec3) → atan2(0,1) = 0 rad heading.
        local function transport()
            return {
                getName     = function() return "heli_test" end,
                isExist     = function() return true end,
                getCoalition= function() return coalition.side.BLUE end,
                getCountry  = function() return country.id.USA end,
                getPosition = function()
                    return {
                        x = { x = 1, y = 0, z = 0 },   -- orientation (heading 0)
                        p = { x = 0, y = 0, z = 0 },   -- position
                    }
                end,
            }
        end

        before_each(function()
            scene = sm:getModel("mineField")
            scene._sets = {}   -- reset deployed-set registry between tests

            -- Stub the spawn primitive: count invocations, return a fake DCS static.
            origSpawnObject = CTLDObjectRegistry.spawnObject
            spawnCount = 0
            CTLDObjectRegistry.spawnObject = function(objectKey)
                spawnCount = spawnCount + 1
                local n = spawnCount
                return {
                    getName = function() return "Mine-" .. n end,
                    isExist = function() return true end,
                    destroy = function() end,
                }
            end
        end)

        after_each(function()
            CTLDObjectRegistry.spawnObject = origSpawnObject
        end)

        -- ── F-083 : 1x1 single mine ────────────────────────────────────────────
        describe("setLandMine 1x1 (F-083)", function()

            it("spawns exactly 1 mine and returns it in a table", function()
                local ok, result = scene.setLandMine(transport(), 20, 1, 1, 6, 12)
                assert.is_true(ok)
                assert.is_not_nil(result)
                assert.equals("table", type(result))
                assert.equals(1, #result)
                assert.equals(1, spawnCount)
            end)

        end)

        -- ── F-084 : 5x15 quinconce → 68 ────────────────────────────────────────
        describe("setLandMine 5x15 quinconce (F-084)", function()

            it("spawns 68 mines (T(5,15) = 15*5 - floor(15/2) = 68)", function()
                local ok, result = scene.setLandMine(transport(), 20, 5, 15, 6, 12)
                assert.is_true(ok)
                assert.equals(68, #result)
                assert.equals(68, spawnCount)
            end)

        end)

        -- ── F-085 : 4x3 quinconce → 11 ─────────────────────────────────────────
        describe("setLandMine 4x3 quinconce (F-085)", function()

            it("spawns 11 mines (T(4,3) = 3*4 - floor(3/2) = 11)", function()
                local ok, result = scene.setLandMine(transport(), 20, 4, 3, 6, 12)
                assert.is_true(ok)
                assert.equals(11, #result)
                assert.equals(11, spawnCount)
            end)

        end)

        -- ── F-087 : setLandMineAuto parametric ─────────────────────────────────
        describe("setLandMineAuto (F-087)", function()

            -- Layout solver picks the (N,R) whose T(N,R) is closest to nbMines while
            -- honouring the width/length aspect ratio. For (width=50, length=80, nbMines=40):
            --   N0 = floor(sqrt(40*50/80) + 0.5) = floor(5.5) = 5
            --   candidates settle on N=4, R=11 → T(4,11) = 11*4 - floor(11/2) = 39 mines.
            it("lays 39 mines for a 50 m x 80 m / 40-mine request", function()
                local ok, result = scene.setLandMineAuto(transport(), 20, 50, 80, 40)
                assert.is_true(ok)
                assert.equals("table", type(result))
                assert.equals(39, #result)
                assert.equals(39, spawnCount)
            end)

            it("routes nbMines=1 to the single-mine branch (exactly 1 mine)", function()
                local ok, result = scene.setLandMineAuto(transport(), 20, 50, 80, 1)
                assert.is_true(ok)
                assert.equals(1, #result)
                assert.equals(1, spawnCount)
            end)

            it("returns false + message for a nil trigger unit (no spawn)", function()
                local ok, msg = scene.setLandMineAuto(nil, 20, 50, 80, 40)
                assert.is_false(ok)
                assert.is_not_nil(msg)
                assert.equals(0, spawnCount)
            end)

            it("returns false + message for nbMines < 1", function()
                local ok, msg = scene.setLandMineAuto(transport(), 20, 50, 80, 0)
                assert.is_false(ok)
                assert.is_not_nil(msg)
                assert.equals(0, spawnCount)
            end)

            it("returns false + message for a non-positive width", function()
                local ok, msg = scene.setLandMineAuto(transport(), 20, 0, 80, 10)
                assert.is_false(ok)
                assert.is_not_nil(msg)
                assert.equals(0, spawnCount)
            end)

            it("returns false + message for a non-positive length", function()
                local ok, msg = scene.setLandMineAuto(transport(), 20, 50, 0, 10)
                assert.is_false(ok)
                assert.is_not_nil(msg)
                assert.equals(0, spawnCount)
            end)

        end)

    end)

end)
