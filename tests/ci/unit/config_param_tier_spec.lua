---@diagnostic disable
-- tests/ci/unit/config_param_tier_spec.lua
-- FEAT-CONFIG-PARAM-SEMANTICS ticket 02 — ADR 0011 Addendum 1.
--
-- The config holds two tiers. A **parameter** (default value is a scalar) must always resolve:
-- omitting it is an incomplete document, not a removal, and the engine falls back to
-- configDefault and reports it. A **list** (default value is a table) keeps ADR 0011 point 1:
-- omitting it is an intentional removal and it stays absent.
-- ============================================================

describe("CTLDConfig parameter/list tiers (ADR 0011 addendum 1)", function()

    local DEFAULT = ctld.configDefault

    -- Drop every line declaring `key` at any indent — simulates a hand-edited snapshot.
    local function without(yaml, key)
        local out = {}
        for line in yaml:gmatch("[^\r\n]+") do
            if not line:match("^%s*" .. key .. "%s*:") then out[#out + 1] = line end
        end
        return table.concat(out, "\n")
    end

    local function loadUser(yaml)
        CTLDConfig._instance = nil
        ctld.configUser = yaml
        local cfg = CTLDConfig.get()
        cfg:load()
        return cfg
    end

    after_each(function()
        -- ctld.configUser is a global: restore the default config for every other spec.
        ctld.configUser = nil
        CTLDConfig._instance = nil
        CTLDConfig.get():load()
    end)

    describe("a missing parameter resolves from the default", function()

        it("resolves slingCutDestroyHeight (was an arithmetic error: agl > nil)", function()
            local cfg = loadUser(without(DEFAULT, "slingCutDestroyHeight"))
            assert.equals(40, cfg:getSetting("slingCutDestroyHeight"))
        end)

        it("resolves both JTAC intervals (was an arithmetic error: t + nil)", function()
            local cfg = loadUser(without(without(DEFAULT, "JTAC_searchIntervalSeconds"),
                                         "JTAC_laseIntervalSeconds"))
            assert.equals(10, cfg:getSetting("JTAC_searchIntervalSeconds"))
            assert.equals(15, cfg:getSetting("JTAC_laseIntervalSeconds"))
        end)

        it("resolves a boolean parameter, not just numbers", function()
            local cfg = loadUser(without(DEFAULT, "slingLoad"))
            assert.equals(false, cfg:getSetting("slingLoad"))
        end)

        it("reports exactly the omitted parameter", function()
            local cfg = loadUser(without(DEFAULT, "slingCutDestroyHeight"))
            assert.same({ "slingCutDestroyHeight" }, cfg:getDefaultedParameters())
        end)

        it("reports several omissions sorted, once each", function()
            local cfg = loadUser(without(without(DEFAULT, "slingLoad"), "hoverTime"))
            assert.same({ "hoverTime", "slingLoad" }, cfg:getDefaultedParameters())
        end)
    end)

    describe("a missing list stays an intentional removal", function()

        it("leaves aiZones absent rather than restoring the default", function()
            local cfg = loadUser(without(DEFAULT, "aiZones"))
            assert.is_nil(cfg:getSetting("aiZones"))
        end)

        it("does not report a removed list as a defaulted parameter", function()
            local cfg = loadUser(without(DEFAULT, "aiZones"))
            assert.same({}, cfg:getDefaultedParameters())
        end)
    end)

    describe("a complete config reports nothing", function()

        it("reports nothing when the snapshot is complete", function()
            local cfg = loadUser(DEFAULT)
            assert.same({}, cfg:getDefaultedParameters())
        end)

        it("reports nothing, and never falls back, when no user config is supplied", function()
            CTLDConfig._instance = nil
            ctld.configUser = nil
            local cfg = CTLDConfig.get()
            cfg:load()
            assert.same({}, cfg:getDefaultedParameters())
            assert.is_nil(cfg:getSetting("noSuchKeyAtAll"))
        end)
    end)
end)
