---@diagnostic disable
-- tests/ci/unit/jtac_drone_globals_spec.lua
-- FEAT-JTAC-DRONE-GLOBALS — drone orbit geometry comes from settings, not from a per-crate block.
--
-- The four globals were rebased onto the values the two shipped drones used, so retiring
-- `specificParams` changes only what was chosen and announced (spawn altitude 4000 → 3000 m, spawn
-- speed 54 → 41.7 m/s, both now matching the orbit).
-- ============================================================

describe("JTAC drone orbit settings", function()

    describe("the four globals carry the values they replaced", function()

        it("altitude is 3000, the value the drones used per-crate", function()
            assert.equals(3000, ctld.gs("JTAC_droneAltitude"))
        end)

        it("search radius is 2000 and lasing radius is 1000 — a distinction one key could not hold", function()
            assert.equals(2000, ctld.gs("JTAC_droneRadiusNoLase"))
            assert.equals(1000, ctld.gs("JTAC_droneRadiusOnLase"))
            assert.is_true(ctld.gs("JTAC_droneRadiusNoLase") > ctld.gs("JTAC_droneRadiusOnLase"))
        end)

        it("speed is 150 km/h", function()
            assert.equals(150, ctld.gs("JTAC_droneSpeed"))
        end)

        it("the single-radius setting is retired", function()
            assert.is_nil(ctld.gs("JTAC_droneRadius"))
        end)
    end)

    describe("spawn and orbit agree", function()

        it("buildGroupUnitDef spawns a drone at the orbit altitude and speed", function()
            local desc = { unit = "MQ-9 Reaper", spawnAs = "AIRPLANE", isJTAC = true }
            local def  = ctld.utils.buildGroupUnitDef(desc, { x = 0, y = 0, z = 0 }, "G1", 1, 2)
            local unit = def.units[1]
            assert.equals(ctld.gs("JTAC_droneAltitude"), unit.alt)
            -- The unitDef speed is m/s; the setting is km/h.
            assert.is_true(math.abs(unit.speed - ctld.gs("JTAC_droneSpeed") / 3.6) < 0.01)
        end)

        it("a ground crate is unaffected by the drone settings", function()
            local def = ctld.utils.buildGroupUnitDef({ unit = "Hummer" }, { x = 0, y = 0, z = 0 }, "G2", 3, 4)
            assert.is_nil(def.units[1].alt)
            assert.is_nil(def.route)
        end)
    end)

    describe("a config still carrying specificParams is reported, not silently ignored", function()

        local origAdd, entries

        before_each(function()
            entries  = {}
            origAdd  = ctld.startupReport.add
            ctld.startupReport.add = function(severity, source, message)
                entries[#entries + 1] = { severity = severity, source = source, message = message }
            end
        end)

        after_each(function()
            ctld.startupReport.add = origAdd
        end)

        local function processWith(crates)
            local cm = CTLDCrateManager.getInstance()
            local orig = CTLDConfig.get().settings.spawnableCrates
            CTLDConfig.get().settings.spawnableCrates = crates
            cm:_processSpawnableCrates()
            CTLDConfig.get().settings.spawnableCrates = orig
        end

        it("emits one NOTICE naming every stale crate, not one message per crate", function()
            processWith({
                Drone = {
                    { unit = "MQ-9 Reaper",    desc = "MQ-9",  weight = 9001.01,
                      isJTAC = true, specificParams = { alti = 3000 } },
                    { unit = "RQ-1A Predator", desc = "RQ-1A", weight = 9001.02,
                      isJTAC = true, specificParams = { speed = 150 } },
                },
            })
            local notices = {}
            for _, e in ipairs(entries) do
                if e.severity == "NOTICE" and e.message:find("specificParams", 1, true) then
                    notices[#notices + 1] = e
                end
            end
            assert.equals(1, #notices)
            assert.is_truthy(notices[1].message:find("MQ-9", 1, true))
            assert.is_truthy(notices[1].message:find("RQ-1A", 1, true))
        end)

        it("says nothing for a clean catalogue", function()
            processWith({
                Support = { { unit = "Hummer", desc = "Hummer", weight = 9002.01 } },
            })
            for _, e in ipairs(entries) do
                assert.is_nil(e.message:find("specificParams", 1, true))
            end
        end)
    end)
end)
