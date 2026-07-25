---@diagnostic disable
-- tests/ci/unit/config_externalised_spec.lua
-- FEAT-CONFIG-YAML-COMPLETE ticket 01: knobs externalised from hardcoded src/ literals
-- into CTLD_config.yaml. Each must load with its former default (behaviour parity).
-- ============================================================

describe("CTLDConfig externalised knobs (ticket 01)", function()

    local cfg

    before_each(function()
        CTLDConfig._instance = nil
        ctld.yamlConfigDatas = nil
        cfg = CTLDConfig.get()
        cfg:load()
    end)

    -- ── Slice 1: AA distances + beacon removal radius ──
    it("aaRearmDistance defaults to 300 (was CTLD_aasystem _REARM_DIST)", function()
        assert.equals(300, ctld.gs("aaRearmDistance"))
    end)

    it("aaAssemblyDistance defaults to 500 (was CTLD_aasystem _ASSEMBLY_DIST)", function()
        assert.equals(500, ctld.gs("aaAssemblyDistance"))
    end)

    it("beaconRemovalRadius defaults to 500 (was CTLD_beacon BEACON_REMOVAL_RADIUS)", function()
        assert.equals(500, ctld.gs("beaconRemovalRadius"))
    end)

    -- ── Slice 2: crate/fob radii, sling cut, jtac laser codes, weights, zone radius ──
    it("loadCrateSearchRadius defaults to 50 (was CTLD_crate literal)", function()
        assert.equals(50, ctld.gs("loadCrateSearchRadius"))
    end)

    it("unpackSearchRadius defaults to 300 (was CTLD_crate literal)", function()
        assert.equals(300, ctld.gs("unpackSearchRadius"))
    end)

    it("fobCrateCollectionRadius defaults to 750 (was CTLD_fob literal)", function()
        assert.equals(750, ctld.gs("fobCrateCollectionRadius"))
    end)

    it("slingCutDestroyHeight defaults to 40 (was CTLD_crate literal 40.0)", function()
        assert.equals(40, ctld.gs("slingCutDestroyHeight"))
    end)

    it("jtacLaserCodeMin defaults to 1111 (was CTLD_jtac LASER_CODE_MIN)", function()
        assert.equals(1111, ctld.gs("jtacLaserCodeMin"))
    end)

    it("jtacLaserCodeMax defaults to 1688 (was CTLD_jtac LASER_CODE_MAX)", function()
        assert.equals(1688, ctld.gs("jtacLaserCodeMax"))
    end)

    it("defaultVehicleWeight defaults to 2500 (was CTLD_vehicle/player literal)", function()
        assert.equals(2500, ctld.gs("defaultVehicleWeight"))
    end)

    it("fieldExtractTroopWeight defaults to 130 (was CTLD_troop literal)", function()
        assert.equals(130, ctld.gs("fieldExtractTroopWeight"))
    end)

    it("defaultZoneRadius defaults to 500 (was CTLD_zone literal)", function()
        assert.equals(500, ctld.gs("defaultZoneRadius"))
    end)

end)
