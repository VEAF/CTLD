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

    -- ── ADR 0011 Addendum 3: a list newer than the snapshot was never removed by its author ──
    describe("a missing list newer than the snapshot's version takes its default", function()

        local SINCE = { fatCowCrates = "2.3.0", fatCowLoadouts = "2.3.0" }
        local savedSince

        before_each(function()
            savedSince = ctld.configListSince
            ctld.configListSince = SINCE
        end)
        after_each(function()
            ctld.configListSince = savedSince
        end)

        -- Drop `key` and its block (the `- ` items at its indent, and anything deeper).
        local function withoutList(yaml, key)
            local out, indent = {}, nil
            for line in yaml:gmatch("[^\r\n]+") do
                local lead = #line:match("^(%s*)")
                if indent and (lead > indent or (lead == indent and line:match("^%s*%- "))) then
                    -- inside the dropped block
                else
                    indent = nil
                    if line:match("^%s*" .. key .. "%s*:") then indent = lead else out[#out + 1] = line end
                end
            end
            return table.concat(out, "\n")
        end

        local function atVersion(yaml, version)
            return (yaml:gsub('configVersion: "[^"]*"', 'configVersion: "' .. version .. '"', 1))
        end

        it("a 2.2.0 snapshot without fatCowCrates gets the catalogue's crates", function()
            local cfg = loadUser(atVersion(withoutList(DEFAULT, "fatCowCrates"), "2.2.0"))
            local crates = cfg:getSetting("fatCowCrates")
            assert.is_table(crates)
            assert.is_true(#crates > 0)
            assert.equals(2400, crates[1].fuelKg)
        end)

        it("reports the list among the settings taken from the default", function()
            local cfg = loadUser(atVersion(withoutList(withoutList(DEFAULT, "fatCowCrates"), "fatCowLoadouts"), "2.2.0"))
            assert.same({ "fatCowCrates", "fatCowLoadouts" }, cfg:getDefaultedParameters())
        end)

        it("a snapshot with no configVersion predates the list too", function()
            local yaml = withoutList(DEFAULT, "fatCowCrates"):gsub('configVersion: "[^"]*"\n?', "", 1)
            local cfg = loadUser(yaml)
            assert.is_table(cfg:getSetting("fatCowCrates"))
        end)

        it("a 2.3.0 snapshot without fatCowCrates removed it: it stays absent", function()
            local cfg = loadUser(withoutList(DEFAULT, "fatCowCrates"))
            assert.is_nil(cfg:getSetting("fatCowCrates"))
            assert.same({}, cfg:getDefaultedParameters())
        end)

        it("a list kept by the snapshot is the snapshot's, even when older", function()
            local yaml = atVersion(DEFAULT, "2.2.0"):gsub("desc: Fat Cow fuel tank %(800 gal%)", "desc: My tank", 1)
            local cfg = loadUser(yaml)
            assert.equals("My tank", cfg:getSetting("fatCowCrates")[1].desc)
        end)

        it("a list the table does not name stays a removal at any version", function()
            local cfg = loadUser(atVersion(without(DEFAULT, "aiZones"), "2.0.0"))
            assert.is_nil(cfg:getSetting("aiZones"))
        end)
    end)

    -- ── Ticket 03: a parameter must have exactly one default, in the catalogue ──
    describe("no parameter carries a duplicate default in code", function()

        -- Repo root, resolved the way tests/ci/helpers/loader.lua does it.
        local ROOT = debug.getinfo(1, "S").source
                        :match("^@(.+)tests[\\/]ci[\\/]unit[\\/]") or ""

        local function isScalarLiteral(lit)
            return tonumber(lit) ~= nil or lit == "true" or lit == "false"
                or lit:match('^"[^"]*"$') ~= nil
        end

        it("no ctld.gs() call is followed by a scalar literal fallback", function()
            local list = io.open(ROOT .. "tools/build/listToMerge.txt", "r")
            assert.is_not_nil(list, "listToMerge.txt not found")
            local offenders = {}
            for entry in list:lines() do
                local rel = entry:match("^%s*([%w_/%.%-]+%.lua)%s*$")
                local f = rel and io.open(ROOT .. "src/" .. rel, "r")
                if f then
                    local n = 0
                    for line in f:lines() do
                        n = n + 1
                        for key, lit in line:gmatch('ctld%.gs%("([%w_]+)"%)%s+or%s+([^%s,)}]+)') do
                            if isScalarLiteral(lit) then
                                offenders[#offenders + 1] =
                                    string.format("src/%s:%d  %s or %s", rel, n, key, lit)
                            end
                        end
                    end
                    f:close()
                end
            end
            list:close()
            -- A scalar default belongs in src/CTLD_config.yaml and nowhere else: the engine
            -- resolves a missing parameter from there (ADR 0011 Addendum 1), so an `or <literal>`
            -- is a second, silently divergent default. Two had already drifted.
            assert.same({}, offenders)
        end)

        it("collection guards are untouched — a missing list still means empty", function()
            local kept = 0
            local list = assert(io.open(ROOT .. "tools/build/listToMerge.txt", "r"))
            for entry in list:lines() do
                local rel = entry:match("^%s*([%w_/%.%-]+%.lua)%s*$")
                local f = rel and io.open(ROOT .. "src/" .. rel, "r")
                if f then
                    for line in f:lines() do
                        for _ in line:gmatch('ctld%.gs%("[%w_]+"%)%s+or%s+{') do
                            kept = kept + 1
                        end
                    end
                    f:close()
                end
            end
            list:close()
            assert.is_true(kept > 0)
        end)
    end)

    describe("the start-up notice names both versions (FEAT-CTLD-TOOLS-CONFIG-COMPLETION)", function()

        local function withVersion(yaml, version)
            return (yaml:gsub('configVersion:%s*"[^"]*"', 'configVersion: "' .. version .. '"'))
        end

        it("gives the config version, the catalogue version and the absent settings", function()
            local cfg = loadUser(withVersion(without(DEFAULT, "slingCutDestroyHeight"), "1.9.0"))
            local notice = cfg:getDefaultedNotice()
            assert.is_truthy(notice:find("1.9.0", 1, true))
            assert.is_truthy(notice:find("slingCutDestroyHeight", 1, true))
            local catalogue = DEFAULT:match('configVersion:%s*"([^"]*)"')
            assert.is_truthy(notice:find(catalogue, 1, true))
        end)

        it("says the version is unknown when the snapshot carries none", function()
            local noVersion = without(without(DEFAULT, "slingCutDestroyHeight"), "configVersion")
            local notice = loadUser(noVersion):getDefaultedNotice()
            assert.is_truthy(notice:find("?", 1, true))
        end)

        it("has no notice when the snapshot is complete", function()
            assert.is_nil(loadUser(DEFAULT):getDefaultedNotice())
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
