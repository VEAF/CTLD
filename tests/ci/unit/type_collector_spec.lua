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
        -- Borrow rather than set-then-nil: the catalogue ships `modTypes: []`, so writing nil at the
        -- end deletes a key that was there. Harmless today — nothing downstream distinguishes an
        -- empty list from an absent one — but it is the same leak as the others, spelled quietly
        -- (FIX-SPEC-ISOLATION).
        local borrowed = ctldTestSettings.borrow({ modTypes = { "TC_Cfg_Mod_Type" } })
        assert.is_true(CTLDTypeCollector.collect().extras["TC_Cfg_Mod_Type"] == true)
        borrowed:restore()
    end)

    it("collects DCS typeNames from aiZones vehicleStock", function()
        local prev = CTLDConfig.get().settings["aiZones"]
        CTLDConfig.get().settings["aiZones"] = {
            { dcsZoneName = "TC_Zone", coalition = "BLUE", isPickup = true, cargoType = "V",
              vehicleStock = { ["TC_HMMWV_Probe"] = 1 } },
        }
        local result = CTLDTypeCollector.collect()
        assert.is_not_nil(result.types["TC_HMMWV_Probe"],
            "vehicleStock typeName not collected from aiZones")
        CTLDConfig.get().settings["aiZones"] = prev
    end)

    it("collects DCS typeNames from capabilitiesByType loadableVehiclesRED/BLUE", function()
        local prev = CTLDConfig.get().settings["capabilitiesByType"]
        CTLDConfig.get().settings["capabilitiesByType"] = {
            ["TC_Transport"] = {
                loadableVehiclesRED  = { "TC_Vehicle_RED" },
                loadableVehiclesBLUE = { "TC_Vehicle_BLUE" },
            },
        }
        local result = CTLDTypeCollector.collect()
        assert.is_not_nil(result.types["TC_Vehicle_RED"],
            "loadableVehiclesRED typeName not collected")
        assert.is_not_nil(result.types["TC_Vehicle_BLUE"],
            "loadableVehiclesBLUE typeName not collected")
        CTLDConfig.get().settings["capabilitiesByType"] = prev
    end)

    it("collects DCS typeNames from aiZones vehicleTypes", function()
        local prev = CTLDConfig.get().settings["aiZones"]
        CTLDConfig.get().settings["aiZones"] = {
            { dcsZoneName = "TC_Zone2", coalition = "BLUE", isPickup = true, cargoType = "V",
              vehicleTypes = { "TC_VehicleType_Probe" } },
        }
        local result = CTLDTypeCollector.collect()
        assert.is_not_nil(result.types["TC_VehicleType_Probe"],
            "vehicleTypes typeName not collected from aiZones")
        CTLDConfig.get().settings["aiZones"] = prev
    end)

end)
