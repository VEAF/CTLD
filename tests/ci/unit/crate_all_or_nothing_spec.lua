---@diagnostic disable
-- FIX-CREATE-BEFORE-DESTROY: CTLDCrateManager:spawnCratesAllOrNothing creates a batch of crates and returns them only when every one
-- was created; a partial batch is removed again so that nothing is left behind (ADR 0028).
-- The aligned creation is a double that makes as many crates as it is told to.
-- ============================================================

describe("CTLDCrateManager:spawnCratesAllOrNothing", function()

    local mgr, origAligned, origDestroy
    local made, destroyed

    local function fakeAligned(howMany)
        return function(_self, descriptors)
            local crates = {}
            for i = 1, math.min(howMany, #descriptors) do
                crates[i] = { crateName = "CTLD_fake_" .. i }
            end
            return #crates, { positions = {} }, crates
        end
    end

    before_each(function()
        mgr = CTLDCrateManager.getInstance()
        origAligned, origDestroy = mgr.spawnCratesAligned, mgr.destroyCrate
        destroyed = {}
        mgr.destroyCrate = function(_self, name) destroyed[#destroyed + 1] = name end
    end)

    after_each(function()
        mgr.spawnCratesAligned, mgr.destroyCrate = origAligned, origDestroy
    end)

    local function run(howMany, required)
        mgr.spawnCratesAligned = fakeAligned(howMany)
        local descriptors = {}
        for i = 1, required do descriptors[i] = { desc = "d" .. i } end
        return mgr:spawnCratesAllOrNothing(descriptors, {}, coalition.side.BLUE, "Heli1", "vehicle_pack")
    end

    it("returns every crate when all were created", function()
        local crates = run(3, 3)
        assert.equals(3, #crates)
        assert.equals(0, #destroyed)
    end)

    it("removes the crates already created and returns nothing when only some were", function()
        local crates, created = run(1, 2)
        assert.is_nil(crates)
        assert.equals(1, created)
        assert.same({ "CTLD_fake_1" }, destroyed)
    end)

    it("returns nothing when none was created, and removes nothing", function()
        local crates, created = run(0, 2)
        assert.is_nil(crates)
        assert.equals(0, created)
        assert.equals(0, #destroyed)
    end)

end)
