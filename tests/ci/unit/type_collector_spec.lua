---@diagnostic disable
-- tests/ci/unit/type_collector_spec.lua
-- CTLDTypeCollector — shared configured-type collector (ASSET-VALIDATION-REVAMP ticket 01).
-- ============================================================

describe("CTLDTypeCollector.typesOfDescriptor", function()

    it("STATIC → desc.type", function()
        local t = CTLDTypeCollector.typesOfDescriptor({ groupType = "STATIC", type = "FARP Tent" })
        assert.same({ "FARP Tent" }, t)
    end)

    it("GROUND → unitType(coalitionId) for both coalitions, deduplicated", function()
        local desc = { groupType = "GROUND", units = {
            { unitType = function(cid) return cid == 1 and "M-113" or "BTR-80" end },
            { unitType = function(_) return "Soldier M4" end },
        } }
        local t = CTLDTypeCollector.typesOfDescriptor(desc)
        table.sort(t)
        assert.same({ "BTR-80", "M-113", "Soldier M4" }, t)
    end)

    it("GROUND → static unit.type fallback when there is no unitType function", function()
        local desc = { groupType = "GROUND", units = { { type = "Hummer" }, { type = "Hummer" } } }
        assert.same({ "Hummer" }, CTLDTypeCollector.typesOfDescriptor(desc))
    end)

    it("non-table or empty descriptor → empty list", function()
        assert.same({}, CTLDTypeCollector.typesOfDescriptor(nil))
        assert.same({}, CTLDTypeCollector.typesOfDescriptor({ groupType = "STATIC" }))
    end)

end)

describe("CTLDTypeCollector.collect", function()

    it("returns a types table keyed by type name with sources", function()
        local result = CTLDTypeCollector.collect()
        assert.is_table(result.types)
        assert.is_table(result.extras)
        local n = 0
        for _, e in pairs(result.types) do
            n = n + 1
            assert.is_table(e.sources)
        end
        assert.is_true(n > 0, "collector found no configured types — is config loaded?")
    end)

    it("surfaces a registered scene's modTypes in extras", function()
        CTLDSceneManager.getInstance():registerSceneModel({
            name = "TC_ModScene",
            modTypes = { "TC_Some_Mod_Type" },
            steps = {{ delayAfterPreviousStep = 0, func = function() end }},
        })
        assert.is_true(CTLDTypeCollector.collect().extras["TC_Some_Mod_Type"] == true)
    end)

    it("folds the config modTypes whitelist into extras", function()
        CTLDConfig.get().settings["modTypes"] = { "TC_Cfg_Mod_Type" }
        assert.is_true(CTLDTypeCollector.collect().extras["TC_Cfg_Mod_Type"] == true)
        CTLDConfig.get().settings["modTypes"] = nil
    end)

end)
