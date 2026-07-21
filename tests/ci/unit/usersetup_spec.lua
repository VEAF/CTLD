---@diagnostic disable
-- tests/ci/unit/usersetup_spec.lua
-- busted specs for the CTLD_userSetup MM helper API (FEAT-USERCONFIG-API):
--   ctld.addCrate / removeCrate / patchCrate / addTroopGroup / removeTroopGroup / addTo / logDefaults
-- Tests assert observable state of the live config after each helper, not internals.
-- ============================================================

describe("CTLD_userSetup helpers", function()

    local cfg

    before_each(function()
        CTLDConfig._instance = nil
        ctld.yamlConfigDatas = nil
        cfg = CTLDConfig.get()
        cfg:load()
    end)

    -- helper: count entries in a spawnableCrates section
    local function sectionCount(section)
        local s = cfg.settings["spawnableCrates"][section]
        return s and #s or 0
    end

    -- helper: find a crate entry by weight across all sections
    local function findCrate(weight)
        for _, entries in pairs(cfg.settings["spawnableCrates"]) do
            for _, e in ipairs(entries) do
                if e.weight == weight then return e end
            end
        end
        return nil
    end

    -- ── addCrate ──────────────────────────────────────────────
    describe("ctld.addCrate", function()

        it("appends an entry to an existing section", function()
            local before = sectionCount("Support")
            ctld.addCrate("Support", { weight = 9999.01, desc = "Test Unit", unit = "Ural-375", side = 2 })
            assert.equals(before + 1, sectionCount("Support"))
            assert.is_not_nil(findCrate(9999.01))
        end)

        it("creates the section when absent", function()
            assert.is_nil(cfg.settings["spawnableCrates"]["My Custom Section"])
            ctld.addCrate("My Custom Section", { weight = 9999.02, desc = "Custom", unit = "Ural-375" })
            assert.equals(1, sectionCount("My Custom Section"))
        end)

        it("appends after pre-existing entries (post-injectAACrates order)", function()
            ctld.addCrate("Support", { weight = 9999.03, desc = "Last", unit = "Ural-375" })
            local s = cfg.settings["spawnableCrates"]["Support"]
            assert.equals(9999.03, s[#s].weight)
        end)

        it("rejects a duplicate weight and logs a warning", function()
            local warn = spy.on(ctld, "logWarning")
            ctld.addCrate("Support", { weight = 9999.04, desc = "First", unit = "Ural-375" })
            local afterFirst = sectionCount("Support")
            ctld.addCrate("Combat Vehicles", { weight = 9999.04, desc = "Dup", unit = "Ural-375" })
            assert.equals(afterFirst, sectionCount("Support"))
            assert.spy(warn).was_called()
            ctld.logWarning:revert()
        end)
    end)

    -- ── removeCrate ───────────────────────────────────────────
    describe("ctld.removeCrate", function()

        it("removes an entry by weight", function()
            ctld.addCrate("Support", { weight = 9999.05, desc = "ToRemove", unit = "Ural-375" })
            assert.is_not_nil(findCrate(9999.05))
            ctld.removeCrate(9999.05)
            assert.is_nil(findCrate(9999.05))
        end)

        it("finds the entry across sections", function()
            ctld.addCrate("My Section A", { weight = 9999.06, desc = "A", unit = "Ural-375" })
            ctld.removeCrate(9999.06)
            assert.is_nil(findCrate(9999.06))
        end)

        it("logs a warning on an unknown weight", function()
            local warn = spy.on(ctld, "logWarning")
            ctld.removeCrate(123456.99)
            assert.spy(warn).was_called()
            ctld.logWarning:revert()
        end)
    end)

    -- ── patchCrate ────────────────────────────────────────────
    describe("ctld.patchCrate", function()

        it("patches a top-level field, leaving others intact", function()
            ctld.addCrate("Support", { weight = 9999.07, desc = "Patch", unit = "Ural-375", cratesRequired = 2 })
            ctld.patchCrate(9999.07, { cratesRequired = 5 })
            local e = findCrate(9999.07)
            assert.equals(5, e.cratesRequired)
            assert.equals("Ural-375", e.unit)
        end)

        it("deep-merges one level into a table field", function()
            ctld.addCrate("Support", {
                weight = 9999.08, desc = "Drone", unit = "MQ-9 Reaper",
                specificParams = { alti = 100, speed = 50 },
            })
            ctld.patchCrate(9999.08, { specificParams = { alti = 5000 } })
            local e = findCrate(9999.08)
            assert.equals(5000, e.specificParams.alti)
            assert.equals(50, e.specificParams.speed)
        end)

        it("logs a warning on an unknown weight", function()
            local warn = spy.on(ctld, "logWarning")
            ctld.patchCrate(123456.99, { cratesRequired = 1 })
            assert.spy(warn).was_called()
            ctld.logWarning:revert()
        end)
    end)

    -- ── addTroopGroup / removeTroopGroup ──────────────────────
    describe("ctld.addTroopGroup / removeTroopGroup", function()

        it("adds a troop group to loadableGroups", function()
            local before = #cfg.settings["loadableGroups"]
            ctld.addTroopGroup({ name = "Test Squad", inf = 3 })
            assert.equals(before + 1, #cfg.settings["loadableGroups"])
        end)

        it("removes a troop group by name", function()
            ctld.addTroopGroup({ name = "Removable Squad", inf = 2 })
            ctld.removeTroopGroup("Removable Squad")
            for _, g in ipairs(cfg.settings["loadableGroups"]) do
                assert.not_equals("Removable Squad", g.name)
            end
        end)

        it("logs a warning removing an unknown name", function()
            local warn = spy.on(ctld, "logWarning")
            ctld.removeTroopGroup("No Such Group 42")
            assert.spy(warn).was_called()
            ctld.logWarning:revert()
        end)
    end)

    -- ── patchTroopGroup ───────────────────────────────────────
    describe("ctld.patchTroopGroup", function()

        local function findGroup(name)
            for _, g in ipairs(cfg.settings["loadableGroups"]) do
                if g.name == name then return g end
            end
            return nil
        end

        it("patches a top-level field, leaving others intact", function()
            ctld.addTroopGroup({ name = "Patchable Squad", inf = 3, mg = 1 })
            ctld.patchTroopGroup("Patchable Squad", { inf = 6 })
            local g = findGroup("Patchable Squad")
            assert.equals(6, g.inf)
            assert.equals(1, g.mg)
        end)

        it("deep-merges one level into a table field", function()
            ctld.addTroopGroup({ name = "Nested Squad", inf = 2, aa = { count = 1, type = "Igla" } })
            ctld.patchTroopGroup("Nested Squad", { aa = { count = 3 } })
            local g = findGroup("Nested Squad")
            assert.equals(3, g.aa.count)
            assert.equals("Igla", g.aa.type)
        end)

        it("logs a warning patching an unknown name", function()
            local warn = spy.on(ctld, "logWarning")
            ctld.patchTroopGroup("No Such Group 42", { inf = 1 })
            assert.spy(warn).was_called()
            ctld.logWarning:revert()
        end)
    end)

    -- ── addTo ─────────────────────────────────────────────────
    describe("ctld.addTo", function()

        it("appends to a named array setting", function()
            local before = #cfg.settings["transportPilotNames"]
            ctld.addTo("transportPilotNames", "TestPilot #1")
            assert.equals(before + 1, #cfg.settings["transportPilotNames"])
            assert.equals("TestPilot #1", cfg.settings["transportPilotNames"][#cfg.settings["transportPilotNames"]])
        end)

        it("logs a warning on an unknown setting", function()
            local warn = spy.on(ctld, "logWarning")
            ctld.addTo("noSuchArraySetting", "x")
            assert.spy(warn).was_called()
            ctld.logWarning:revert()
        end)
    end)

    -- ── logDefaults ───────────────────────────────────────────
    describe("ctld.logDefaults", function()

        it("logs a serialised representation of a known setting", function()
            local captured = ""
            local logSpy = spy.on(ctld.utils, "log")
            ctld.logDefaults("spawnableCrates")
            assert.spy(logSpy).was_called()
            ctld.utils.log:revert()
        end)
    end)
end)
