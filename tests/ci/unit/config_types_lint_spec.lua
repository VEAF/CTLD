-- Offline config linter: cross-checks the DCS type names referenced in CTLD
-- configuration against the vendored set of known stock DCS types
-- (tests/data/dcs_types.lua, generated from Quaggles/dcs-lua-datamine).
--
-- Purpose: surface likely typos in mission-maker-facing config (spawnableCrates,
-- AA templates, loadableGroups, static registry) at dev/CI time — without DCS.
--
-- Lenient by design: a configured type absent from the stock set is NOT
-- necessarily wrong (mods add types the stock dump doesn't know). So this spec
-- reports the unknowns for a human to eyeball and asserts only the machinery
-- (data loads, collector finds types). Turning "unknown" into a hard failure
-- (with an allow-list of intentional mod/sentinel types) is a documented
-- follow-up in the DCS-DATAMINE-VENDOR lot.

describe("config type-name linter", function()
    local known

    setup(function()
        known = dofile("tests/data/dcs_types.lua")
    end)

    local function collectConfiguredTypes()
        local types = {}
        local function add(t)
            if type(t) == "string" and t ~= "" then types[t] = true end
        end

        local sc = ctld.gs("spawnableCrates") or {}
        for _, items in pairs(sc) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.unit and not item._repairFor and not item.spawnAs then
                        add(item.unit)
                    end
                end
            end
        end

        local aa = (type(CTLDCrateAssemblyManager) == "table" and CTLDCrateAssemblyManager.TEMPLATES) or {}
        for _, tmpl in ipairs(aa) do
            if type(tmpl) == "table" and type(tmpl.parts) == "table" then
                for _, part in ipairs(tmpl.parts) do
                    if type(part) == "table" then add(part.DCSTypename) end
                end
            end
        end

        local lg = ctld.gs("loadableGroups") or {}
        for _, tmpl in ipairs(lg) do
            if type(tmpl) == "table" and type(tmpl.componentTypes) == "table" then
                for _, coaTable in pairs(tmpl.componentTypes) do
                    if type(coaTable) == "table" then
                        for _, tn in pairs(coaTable) do add(tn) end
                    end
                end
            end
        end

        if type(CTLDObjectRegistry) == "table" and type(CTLDObjectRegistry._db) == "table" then
            for _, desc in pairs(CTLDObjectRegistry._db) do
                if type(desc) == "table" and desc.groupType == "STATIC" and desc.type then
                    add(desc.type)
                end
            end
        end

        return types
    end

    it("loads the vendored DCS type set", function()
        assert.is_table(known)
        local n = 0
        for _ in pairs(known) do n = n + 1 end
        assert.is_true(n > 500, "expected a substantial stock type set, got " .. n)
    end)

    it("collects configured type names and reports any not in the stock DCS set", function()
        local configured = collectConfiguredTypes()

        local total, unknown = 0, {}
        for t in pairs(configured) do
            total = total + 1
            if not known[t] then unknown[#unknown + 1] = t end
        end
        table.sort(unknown)

        assert.is_true(total > 0, "collector found no configured type names — is config loaded?")

        if #unknown > 0 then
            print(string.format(
                "\n[config-lint] %d/%d configured type(s) not in the stock DCS set "
                    .. "(mod types or typos — review):",
                #unknown, total))
            for _, t in ipairs(unknown) do
                print("  - " .. t)
            end
        end
        -- Lenient: unknowns are reported, not failed (mods are legitimate).
        assert.is_true(true)
    end)
end)
