---@diagnostic disable
-- tests/unit/config_spec.lua
-- busted specs for CTLDConfig: singleton, load idempotency, getSetting defaults, gs(), to_type(), parseYAML()
-- Reference: live_tests/unit/U-084 through U-089
-- ============================================================

describe("CTLDConfig", function()

    local cfg

    before_each(function()
        CTLDConfig._instance = nil
        ctld.yamlConfigDatas = nil
        ctld.configUser      = nil
        cfg = CTLDConfig.get()
        cfg:load()
    end)

    -- ── Singleton ────────────────────────────────────────────
    describe("get()", function()

        it("returns a non-nil instance", function()
            assert.is_not_nil(cfg)
        end)

        it("returns the same reference on multiple calls", function()
            local b = CTLDConfig.get()
            assert.equals(cfg, b)
        end)

        it("instance has a settings table", function()
            assert.equals("table", type(cfg.settings))
        end)

        it("isLoaded is true after init", function()
            assert.is_true(cfg.isLoaded)
        end)

        it("mutation via one reference is visible through another", function()
            local b = CTLDConfig.get()
            local orig = cfg.settings["numberOfTroops"]
            cfg.settings["numberOfTroops"] = 999
            assert.equals(999, b.settings["numberOfTroops"])
            cfg.settings["numberOfTroops"] = orig  -- restore
        end)

    end)

    -- ── load() idempotency ────────────────────────────────────
    describe("load()", function()

        it("second call returns true", function()
            local ok, _ = cfg:load()
            assert.is_true(ok)
        end)

        it("second call returns 'already loaded' message", function()
            local _, msg = cfg:load()
            assert.equals("string", type(msg))
            assert.is_not_nil(msg:find("already"))
        end)

        it("second call does not reset settings to defaults", function()
            local orig = cfg.settings["numberOfTroops"]
            cfg.settings["numberOfTroops"] = 77
            cfg:load()
            assert.equals(77, cfg.settings["numberOfTroops"])
            cfg.settings["numberOfTroops"] = orig  -- restore
        end)

    end)

    -- ── getSetting() default values ───────────────────────────
    describe("getSetting() defaults", function()

        it("addPlayerAircraftByType defaults to true", function()
            assert.is_true(cfg:getSetting("addPlayerAircraftByType"))
        end)

        it("disableAllSmoke defaults to false", function()
            assert.is_false(cfg:getSetting("disableAllSmoke"))
        end)

        it("maximumDistanceLogistic defaults to 200", function()
            assert.equals(200, cfg:getSetting("maximumDistanceLogistic"))
        end)

        it("minimumHoverHeight defaults to 7.5", function()
            assert.equals(7.5, cfg:getSetting("minimumHoverHeight"))
        end)

        it("hoverTime defaults to 10", function()
            assert.equals(10, cfg:getSetting("hoverTime"))
        end)

        it("numberOfTroops defaults to 10", function()
            assert.equals(10, cfg:getSetting("numberOfTroops"))
        end)

        it("maxExtractDistance defaults to 125", function()
            assert.equals(125, cfg:getSetting("maxExtractDistance"))
        end)

        it("JTAC_maxDistance defaults to 10000", function()
            assert.equals(10000, cfg:getSetting("JTAC_maxDistance"))
        end)

    end)

    -- ── ctld.gs() shortcut ────────────────────────────────────
    describe("ctld.gs()", function()

        it("returns same value as getSetting for numberOfTroops", function()
            assert.equals(cfg:getSetting("numberOfTroops"), ctld.gs("numberOfTroops"))
        end)

        it("returns same value as getSetting for maximumDistanceLogistic", function()
            assert.equals(cfg:getSetting("maximumDistanceLogistic"), ctld.gs("maximumDistanceLogistic"))
        end)

        it("returns same value as getSetting for buildTimeFOB", function()
            assert.equals(cfg:getSetting("buildTimeFOB"), ctld.gs("buildTimeFOB"))
        end)

        it("returns nil for unknown key", function()
            assert.is_nil(ctld.gs("__nonexistent_key_xyz__"))
        end)

    end)

    -- ── CTLDConfig.to_type() ──────────────────────────────────
    describe("to_type()", function()

        it("converts 'true' string to boolean true", function()
            assert.is_true(CTLDConfig.to_type("true"))
        end)

        it("converts 'false' string to boolean false", function()
            assert.is_false(CTLDConfig.to_type("false"))
        end)

        it("converts integer string to number", function()
            assert.equals(42, CTLDConfig.to_type("42"))
        end)

        it("converts float string to number", function()
            assert.equals(3.14, CTLDConfig.to_type("3.14"))
        end)

        it("converts '0' to number 0", function()
            assert.equals(0, CTLDConfig.to_type("0"))
        end)

        it("strips single quotes from string", function()
            assert.equals("hello", CTLDConfig.to_type("'hello'"))
        end)

        it("strips double quotes from string", function()
            assert.equals("world", CTLDConfig.to_type('"world"'))
        end)

        it("preserves unquoted string as-is", function()
            assert.equals("beacon.ogg", CTLDConfig.to_type("beacon.ogg"))
        end)

    end)

    -- ── CTLDConfig.parseYAML() ────────────────────────────────
    describe("parseYAML()", function()

        it("parses a simple string value", function()
            local t = CTLDConfig.parseYAML("myKey: hello")
            assert.equals("hello", t["myKey"])
        end)

        it("coerces integer value to number", function()
            local t = CTLDConfig.parseYAML("count: 42")
            assert.equals(42, t["count"])
        end)

        it("coerces boolean value", function()
            local t = CTLDConfig.parseYAML("flag: true")
            assert.is_true(t["flag"])
        end)

        it("coerces float value", function()
            local t = CTLDConfig.parseYAML("ratio: 0.5")
            assert.equals(0.5, t["ratio"])
        end)

        it("preserves dotted key as-is", function()
            local t = CTLDConfig.parseYAML("ctld.numberOfTroops: 25")
            assert.equals(25, t["ctld.numberOfTroops"])
        end)

        it("parses multiple lines", function()
            local t = CTLDConfig.parseYAML("ctld.buildTimeFOB: 60\nctld.cratesRequiredForFOB: 5")
            assert.equals(60, t["ctld.buildTimeFOB"])
            assert.equals(5,  t["ctld.cratesRequiredForFOB"])
        end)

        it("returns an empty table for empty input", function()
            local t = CTLDConfig.parseYAML("")
            assert.equals("table", type(t))
        end)

        -- ── Hardened constructs (FEAT-CONFIG-YAML-COMPLETE ticket 02) ──

        it("parses a sequence of scalars", function()
            local t = CTLDConfig.parseYAML("zones:\n- alpha\n- bravo\n- charlie")
            assert.same({ "alpha", "bravo", "charlie" }, t.zones)
        end)

        it("parses a sequence of maps", function()
            local t = CTLDConfig.parseYAML("groups:\n- name: A\n  count: 2\n- name: B\n  count: 3")
            assert.same({ { name = "A", count = 2 }, { name = "B", count = 3 } }, t.groups)
        end)

        it("parses a sequence of sequences (list of lists)", function()
            local t = CTLDConfig.parseYAML("zones:\n- - z1\n  - none\n  - 2\n- - z2\n  - blue\n  - -1")
            assert.same({ { "z1", "none", 2 }, { "z2", "blue", -1 } }, t.zones)
        end)

        it("returns to the parent map after a block sequence at the key's indent", function()
            local t = CTLDConfig.parseYAML("list:\n- a\n- b\nafter: 7")
            assert.same({ "a", "b" }, t.list)
            assert.equals(7, t.after)   -- 'after' must land in the root map, not the list
        end)

        it("coerces an inline empty map {} to an empty table", function()
            local t = CTLDConfig.parseYAML("modTypes: {}")
            assert.same({}, t.modTypes)
        end)

        it("coerces an inline empty list [] to an empty table", function()
            local t = CTLDConfig.parseYAML("items: []")
            assert.same({}, t.items)
        end)

        it("parses deeply nested maps", function()
            local t = CTLDConfig.parseYAML("a:\n  b:\n    c: 42")
            assert.equals(42, t.a.b.c)
        end)

        it("parses a nested map inside a sequence-of-maps item", function()
            local t = CTLDConfig.parseYAML("crates:\n- unit: Drone\n  params:\n    alti: 3000\n    speed: 150")
            assert.same({ { unit = "Drone", params = { alti = 3000, speed = 150 } } }, t.crates)
        end)

        it("preserves quoted scalars containing '#'", function()
            local t = CTLDConfig.parseYAML("pilots:\n- 'MEDEVAC #1'\n- transport1")
            assert.same({ "MEDEVAC #1", "transport1" }, t.pilots)
        end)

        it("keeps unquoted yes/no as strings (not booleans)", function()
            local t = CTLDConfig.parseYAML("flags:\n- - z1\n  - yes\n  - no")
            assert.same({ { "z1", "yes", "no" } }, t.flags)
        end)

    end)

    -- ── FIX-CONFIG-NOT-LOADED-GUARD: getSetting()/gs() before initialize() ────
    -- Shadows the outer before_each's :load() with a fresh, never-loaded instance.
    describe("getSetting() before initialize()", function()

        local fresh

        before_each(function()
            CTLDConfig._instance = nil
            fresh = CTLDConfig.get()   -- isLoaded = false, no :load() call
        end)

        -- Mirrors i18n_spec.lua's own after_each for the identical hazard: without this, a
        -- reordered/added test here leaves CTLDConfig unloaded for every later spec in the
        -- same busted process — an unrelated-looking mass failure elsewhere, not a local one.
        after_each(function()
            ctld.configUser = nil
            CTLDConfig._instance = nil
            CTLDConfig.get():load()
        end)

        it("getSetting raises an error naming ctld.initialize()", function()
            local ok, err = pcall(function() return fresh:getSetting("anyKey") end)
            assert.is_false(ok)
            assert.is_not_nil(tostring(err):find("ctld.initialize()", 1, true))
        end)

        it("ctld.gs raises the same error", function()
            local ok, err = pcall(function() return ctld.gs("anyKey") end)
            assert.is_false(ok)
            assert.is_not_nil(tostring(err):find("ctld.initialize()", 1, true))
        end)

        it("behaves normally again once load() has run", function()
            fresh:load()
            local ok, value = pcall(function() return fresh:getSetting("numberOfTroops") end)
            assert.is_true(ok)
            assert.is_not_nil(value)
        end)

        -- Review finding: load() used to set isLoaded=true BEFORE the malformed-configUser
        -- check that can error() out, so a failed load left isLoaded=true with settings still
        -- empty — getSetting's guard would then skip straight through and return nil silently,
        -- reproducing the exact bug this fix exists to close, via a different trigger.
        it("still refuses (not nil) after a load() that aborted on malformed configUser", function()
            ctld.configUser = "# comment-only snapshot — parses to an empty table"
            local ok1 = pcall(function() fresh:load() end)
            assert.is_false(ok1)   -- load() itself errors on the malformed snapshot

            local ok2, err = pcall(function() return fresh:getSetting("anyKey") end)
            assert.is_false(ok2)
            assert.is_not_nil(tostring(err):find("ctld.initialize()", 1, true))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
-- Round-trip parity (FEAT-CONFIG-YAML-COMPLETE ticket 02): the canonical
-- src/CTLD_config.yaml, parsed by CTLDConfig.parseYAML and its mm_facing/advanced
-- sections merged (the caller's job), must equal the reference engine defaults
-- generated by gen-config. Guards every catalogue edit.
describe("parseYAML round-trip parity", function()

    local function repoRoot()
        local p = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]unit[\\/]")
        return p or ""
    end

    local function readFile(path)
        local fh = assert(io.open(path, "r"))
        local content = fh:read("*a")
        fh:close()
        return content
    end

    -- The reference engine defaults: the JSON oracle emitted by the core (ctld-tools
    -- gen) and committed at tests/ci/data/config_defaults.json. This is an INDEPENDENT
    -- path from the Lua parseYAML under test — Python/ruamel flattens the same YAML —
    -- so the two agreeing proves the Lua parser round-trips. (CTLD-TOOLS-CORE ticket 05
    -- replaced the Python-emitted Lua defaults table with this language-neutral JSON.)
    local dkjson = require("dkjson")
    local function pristineDefaults()
        local decoded, _, err = dkjson.decode(readFile(repoRoot() .. "tests/ci/data/config_defaults.json"))
        assert(decoded, err)
        return decoded
    end

    -- Merge the mm_facing / advanced readability sections plus any top-level keys
    -- (e.g. configVersion) into one flat table (mirrors CTLDConfig:load).
    local function mergeSections(parsed)
        local flat = {}
        for _, section in ipairs({ "mm_facing", "advanced" }) do
            for k, v in pairs(parsed[section] or {}) do
                flat[k] = v
            end
        end
        for k, v in pairs(parsed) do
            if k ~= "mm_facing" and k ~= "advanced" then
                flat[k] = v
            end
        end
        return flat
    end

    it("parsed CTLD_config.yaml equals the pristine engine defaults", function()
        local yaml = readFile(repoRoot() .. "src/CTLD_config.yaml")
        local flat = mergeSections(CTLDConfig.parseYAML(yaml))
        assert.same(pristineDefaults(), flat)
    end)

    -- Ticket 03: the build embeds the verbatim YAML as the ctld.configDefault string.
    it("ctld.configDefault is a string that round-trips to the pristine defaults", function()
        assert.equals("string", type(ctld.configDefault))
        local flat = mergeSections(CTLDConfig.parseYAML(ctld.configDefault))
        assert.same(pristineDefaults(), flat)
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- localiseI18n (FEAT-CONFIG-YAML-COMPLETE ticket 04): the loader applies ctld.tr()
-- to every desc/name string at any depth, mirroring gen-config's _I18N_FIELDS, so
-- runtime labels are translated (the parsed YAML holds literal keys).
describe("CTLDConfig.localiseI18n()", function()

    it("applies ctld.tr to desc/name strings at any depth, leaving other fields", function()
        local origTr = ctld.tr
        ctld.tr = function(s) return "TR:" .. s end
        local t = {
            name = "Group",
            weight = 100,
            parts = { { desc = "Launcher", amount = 2 } },
            nested = { deep = { name = "X" } },
        }
        CTLDConfig.localiseI18n(t)
        ctld.tr = origTr

        assert.equals("TR:Group", t.name)             -- top-level name
        assert.equals(100, t.weight)                  -- non-i18n scalar untouched
        assert.equals("TR:Launcher", t.parts[1].desc) -- desc inside a list of maps
        assert.equals(2, t.parts[1].amount)
        assert.equals("TR:X", t.nested.deep.name)     -- recursive descent
    end)

end)
