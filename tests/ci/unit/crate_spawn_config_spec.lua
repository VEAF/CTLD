---@diagnostic disable
-- tests/ci/unit/crate_spawn_config_spec.lua
-- FEAT-NATIVE-CRATE-SPAWN-NEAR ticket 01 -- where an aircraft type's crates spawn is declared in
-- capabilitiesByType (crateSpawnSector + crateSpawnDistance), the size of a crate in its model entry
-- (spawnableCratesModels.<key>.size) and the gap between neighbours in crateSpawnGap (ADR 0024).
-- A type that declares nothing, or something unusable, has no plan: it keeps today's spawn rule.
-- ============================================================

describe("crate spawn plan declared in capabilitiesByType", function()

    local origGs

    before_each(function() origGs = ctld.gs end)
    after_each(function() ctld.gs = origGs end)

    local function withCaps(caps)
        ctld.gs = function(k)
            if k == "capabilitiesByType" then return caps end
            return origGs(k)
        end
    end

    local function plan(typeName)
        return CTLDCrateManager.getInstance():getCrateSpawnPlan(typeName)
    end

    describe("default configuration", function()

        local EXPECTED = {
            ["UH-1H"]     = { sector = "side", distance = 3.0 },
            ["Mi-8MT"]    = { sector = "side", distance = 4.0 },
            ["CH-47Fbl1"] = { sector = "side", distance = 3.7 },
            ["Mi-24P"]    = { sector = "side", distance = 5.1 },
            ["C-130J-30"] = { sector = "rear", distance = 11.3 },
        }

        it("gives each native-cargo type its sector and distance", function()
            for typeName, want in pairs(EXPECTED) do
                local p = plan(typeName)
                assert.is_not_nil(p, typeName)
                assert.equals(want.sector, p.sector, typeName)
                assert.equals(want.distance, p.distance, typeName)
            end
        end)

        it("gives no other type a plan", function()
            for typeName in pairs(ctld.gs("capabilitiesByType") or {}) do
                if not EXPECTED[typeName] then
                    assert.is_nil(plan(typeName), typeName .. " must keep today's spawn rule")
                end
            end
        end)

        it("gives a type absent from the table no plan", function()
            assert.is_nil(plan("SomeModdedHeli"))
        end)

    end)

    describe("a declaration that cannot be used is no plan", function()

        it("needs both the sector and the distance", function()
            withCaps({ A = { crateSpawnSector = "side" }, B = { crateSpawnDistance = 3 } })
            assert.is_nil(plan("A"))
            assert.is_nil(plan("B"))
        end)

        it("ignores an unknown sector", function()
            withCaps({ A = { crateSpawnSector = "top", crateSpawnDistance = 3 } })
            assert.is_nil(plan("A"))
        end)

        it("ignores a zero or negative distance (zero is what the editor writes for an empty number)", function()
            withCaps({ A = { crateSpawnSector = "side", crateSpawnDistance = 0 },
                       B = { crateSpawnSector = "side", crateSpawnDistance = -2 } })
            assert.is_nil(plan("A"))
            assert.is_nil(plan("B"))
        end)

        it("accepts the three sectors", function()
            withCaps({ F = { crateSpawnSector = "front", crateSpawnDistance = 2 },
                       R = { crateSpawnSector = "rear",  crateSpawnDistance = 2 },
                       S = { crateSpawnSector = "side",  crateSpawnDistance = 2 } })
            assert.equals("front", plan("F").sector)
            assert.equals("rear",  plan("R").sector)
            assert.equals("side",  plan("S").sector)
        end)

    end)

end)

describe("crate size and gap", function()

    local origGs

    before_each(function() origGs = ctld.gs end)
    after_each(function() ctld.gs = origGs end)

    it("reads the size of the crate model from its entry (ammo_cargo is 1.31 m)", function()
        local cm = CTLDCrateManager.getInstance()
        assert.equals(1.31, cm:getCrateSize("dynamic"))
        assert.equals(1.31, cm:getCrateSize("load"))
    end)

    -- FIX-REVIEW-HYGIENE-B ticket 03 (issue #255): no size is invented for a model that declares none
    -- (sling, container_cargo, is not measured); the row layout refuses it and the radial rule applies.
    it("gives no size for a model that declares none, or an unknown model", function()
        local cm = CTLDCrateManager.getInstance()
        assert.is_nil(cm:getCrateSize("sling"))
        assert.is_nil(cm:getCrateSize("no_such_model"))
    end)

    it("takes a size declared by the mission maker", function()
        ctld.gs = function(k)
            if k == "spawnableCratesModels" then
                return { dynamic = { type = "ammo_cargo", size = 2.4 } }
            end
            return origGs(k)
        end
        assert.equals(2.4, CTLDCrateManager.getInstance():getCrateSize("dynamic"))
    end)

    it("has a default gap of 0.5 m between neighbouring crates", function()
        assert.equals(0.5, ctld.gs("crateSpawnGap"))
    end)

end)
