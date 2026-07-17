---@diagnostic disable
-- tests/ci/unit/companion_asset_check_spec.lua
-- Pure-logic tests for the dev-time asset-check companion (_CTLD_assetCheck).
-- ASSET-VALIDATION-REVAMP ticket 03.
-- ============================================================

local ROOT = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]unit[\\/]") or ""

describe("_CTLD_assetCheck", function()

    setup(function()
        -- Defines _CTLD_assetCheck; the file's runtime block runs harmlessly against the loaded
        -- CTLD stubs (no _CTLD_STOCK_TYPES here, so it just WARNs to the stubbed outText).
        dofile(ROOT .. "tools/companion/asset_check.lua")
    end)

    local function names(unknown)
        local out = {}
        for _, u in ipairs(unknown) do out[#out + 1] = u.type end
        return out
    end

    it("flags a configured type that is neither stock nor a declared extra", function()
        local result = { types = { Known = { sources = {} }, Bogus = { sources = { "spawnableCrates[x]" } } },
                         extras = {} }
        local unknown = _CTLD_assetCheck({ Known = true }, result)
        assert.same({ "Bogus" }, names(unknown))
    end)

    it("does not flag a stock type", function()
        local result = { types = { Stock = { sources = {} } }, extras = {} }
        assert.equals(0, #_CTLD_assetCheck({ Stock = true }, result))
    end)

    it("does not flag a declared extra (mod) type", function()
        local result = { types = { Mod = { sources = {} } }, extras = { Mod = true } }
        assert.equals(0, #_CTLD_assetCheck({}, result))
    end)

    it("carries the source list for each unknown", function()
        local result = { types = { Bad = { sources = { "AASystem[HAWK]" } } }, extras = {} }
        local unknown = _CTLD_assetCheck({}, result)
        assert.same({ "AASystem[HAWK]" }, unknown[1].sources)
    end)

    it("is defensive about nil inputs", function()
        assert.equals(0, #_CTLD_assetCheck(nil, nil))
    end)

    it("returns unknowns sorted by type name", function()
        local result = { types = { Zulu = { sources = {} }, Alpha = { sources = {} } }, extras = {} }
        assert.same({ "Alpha", "Zulu" }, names(_CTLD_assetCheck({}, result)))
    end)

end)
