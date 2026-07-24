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

end)
