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

    -- Configured type names come from the shared CTLDTypeCollector (single source of truth; it also
    -- covers GROUND descriptor unit types via unitType(coalitionId), which the old inline collector
    -- missed).

    it("loads the vendored DCS type set", function()
        assert.is_table(known)
        local n = 0
        for _ in pairs(known) do n = n + 1 end
        assert.is_true(n > 500, "expected a substantial stock type set, got " .. n)
    end)

    it("collects configured type names and reports any not in the stock DCS set", function()
        local result = CTLDTypeCollector.collect()

        local total, unknown = 0, {}
        for t in pairs(result.types) do
            total = total + 1
            -- Declared mod types (scene modTypes ∪ config modTypes) are intentional — not reported.
            if not known[t] and not result.extras[t] then unknown[#unknown + 1] = t end
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
