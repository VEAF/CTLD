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

end)

-- ─────────────────────────────────────────────────────────────
-- Round-trip parity (FEAT-CONFIG-YAML-COMPLETE ticket 02): the canonical
-- src/CTLD_config.yaml, parsed by CTLDConfig.parseYAML and its mm_facing/advanced
-- sections merged (the caller's job), must equal the reference engine defaults
-- (ctld.__configDefaults, generated by gen-config). Guards every catalogue edit.
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

    it("parsed CTLD_config.yaml equals ctld.__configDefaults", function()
        local yaml = readFile(repoRoot() .. "src/CTLD_config.yaml")
        local parsed = CTLDConfig.parseYAML(yaml)

        -- Merge the readability sections into one flat table (loader's job).
        local flat = {}
        for _, section in ipairs({ "mm_facing", "advanced" }) do
            for k, v in pairs(parsed[section] or {}) do
                flat[k] = v
            end
        end

        assert.same(ctld.__configDefaults, flat)
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- ctld.userSetup dispatch (FEAT-USERCONFIG-API): callbacks run in order, nil-safe,
-- mutations land in the live config, one failing callback does not abort the rest.
describe("ctld.userSetup dispatch", function()

    before_each(function()
        CTLDConfig._instance = nil
        ctld.yamlConfigDatas = nil
        ctld.userSetup = nil
        CTLDConfig.get():load()
    end)

    after_each(function()
        ctld.userSetup = nil
    end)

    it("runs callbacks in registration order", function()
        local order = {}
        ctld.userSetup = {
            function() table.insert(order, "a") end,
            function() table.insert(order, "b") end,
        }
        ctld.runUserSetup()
        assert.same({ "a", "b" }, order)
    end)

    it("does not error when ctld.userSetup is nil", function()
        ctld.userSetup = nil
        assert.has_no_error(function() ctld.runUserSetup() end)
    end)

    it("makes callback mutations visible in the live config", function()
        ctld.userSetup = { function() ctld.addTo("transportPilotNames", "FromCallback") end }
        ctld.runUserSetup()
        local names = CTLDConfig.get().settings["transportPilotNames"]
        assert.equals("FromCallback", names[#names])
    end)

    it("isolates a failing callback and still runs the others", function()
        local ran = false
        local warn = spy.on(ctld, "logWarning")
        ctld.userSetup = {
            function() error("boom") end,
            function() ran = true end,
        }
        ctld.runUserSetup()
        assert.is_true(ran)
        assert.spy(warn).was_called()
        ctld.logWarning:revert()
    end)

end)
