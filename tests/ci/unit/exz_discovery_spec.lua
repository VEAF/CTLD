---@diagnostic disable
-- tests/ci/unit/exz_discovery_spec.lua
-- FEAT-EXZ-AUTODISCOVERY ticket 02 -- EXZ_<name>_<flag>_<smoke> naming-convention
-- auto-discovery, converging on the same creation path as the scripted
-- ctld.createExtractZone() API. See ADR 0016 and dev/roadmap.md.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDZoneManager._parseEXZ", function()

    local zm

    before_each(function()
        zm = setmetatable({}, CTLDZoneManager)
    end)

    describe("valid formats", function()

        it("parses a flag and a smoke value", function()
            local r, e = zm:_parseEXZ("EXZ_frontline_flag42_2")
            assert.is_not_nil(r)
            assert.equals("flag42", r.flag)
            assert.equals(2, r.smoke)
        end)

        it("honours the reserved word 'nil' for flag", function()
            local r = zm:_parseEXZ("EXZ_lz1_nil_2")
            assert.is_not_nil(r)
            assert.is_nil(r.flag)
            assert.equals(2, r.smoke)
        end)

        it("honours the reserved word 'nil' for smoke", function()
            local r = zm:_parseEXZ("EXZ_lz1_flag1_nil")
            assert.is_not_nil(r)
            assert.equals("flag1", r.flag)
            assert.is_nil(r.smoke)
        end)

        it("honours 'nil' for both flag and smoke", function()
            local r = zm:_parseEXZ("EXZ_lz1_nil_nil")
            assert.is_not_nil(r)
            assert.is_nil(r.flag)
            assert.is_nil(r.smoke)
        end)

        it("tolerates a free-text name segment containing underscores", function()
            local r, e = zm:_parseEXZ("EXZ_front_line_alpha_flag1_0")
            assert.is_not_nil(r)
            assert.equals("flag1", r.flag)
            assert.equals(0, r.smoke)
        end)

        it("accepts smoke value 0 (green)", function()
            assert.equals(0, zm:_parseEXZ("EXZ_lz1_nil_0").smoke)
        end)

        it("accepts smoke value 4 (blue)", function()
            assert.equals(4, zm:_parseEXZ("EXZ_lz1_nil_4").smoke)
        end)

    end)

    describe("invalid formats", function()

        it("rejects the wrong prefix", function()
            assert.is_nil(zm:_parseEXZ("TRZ_lz1_nil_0"))
        end)

        it("rejects a missing smoke field", function()
            local r, e = zm:_parseEXZ("EXZ_lz1_flag1")
            assert.is_nil(r)
            assert.is_not_nil(e)
        end)

        it("rejects bare 'EXZ'", function()
            assert.is_nil(zm:_parseEXZ("EXZ"))
        end)

        it("rejects an out-of-range smoke value", function()
            local r, e = zm:_parseEXZ("EXZ_lz1_nil_5")
            assert.is_nil(r)
            assert.is_not_nil(e)
        end)

        it("rejects a non-numeric, non-'nil' smoke value", function()
            assert.is_nil(zm:_parseEXZ("EXZ_lz1_nil_abc"))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDZoneManager._discoverEXZ", function()

    local savedMission, savedGetZone

    before_each(function()
        ctld.startupReport._entries = {}
        CTLDZoneManager._instance = nil
        savedMission  = env.mission
        savedGetZone  = trigger.misc.getZone
        trigger.misc.getZone = function(name)
            return { point = { x = 100, y = 0, z = 200 }, radius = 300 }
        end
    end)

    after_each(function()
        ctld.startupReport._entries = {}
        CTLDZoneManager._instance = nil
        env.mission          = savedMission
        trigger.misc.getZone = savedGetZone
    end)

    it("registers a well-formed EXZ_ zone under its full DCS name", function()
        env.mission = { triggers = { zones = { { name = "EXZ_frontline_flag42_2" } } } }
        local zm = CTLDZoneManager.getInstance()
        local zone = zm._troopZones["EXZ_frontline_flag42_2"]
        assert.is_not_nil(zone)
        assert.equals("flag42", zone.objectiveFlag)
        assert.equals(2, zone.smoke)
        assert.equals(0, zone.coalition)
    end)

    it("honours 'nil' flag and smoke end to end", function()
        env.mission = { triggers = { zones = { { name = "EXZ_lz1_nil_nil" } } } }
        local zm = CTLDZoneManager.getInstance()
        local zone = zm._troopZones["EXZ_lz1_nil_nil"]
        assert.is_not_nil(zone)
        assert.equals("nil", zone.objectiveFlag) -- tostring(nil), same as the scripted API
        assert.equals(-1, zone.smoke)
    end)

    it("reports a malformed EXZ_ name and does not register it", function()
        env.mission = { triggers = { zones = { { name = "EXZ_lz1_flag1" } } } } -- missing smoke
        local zm = CTLDZoneManager.getInstance()
        assert.is_nil(zm._troopZones["EXZ_lz1_flag1"])
        local found = false
        for _, e in ipairs(ctld.startupReport._entries) do
            if e.severity == "ERROR" and e.source == "ZoneManager" then found = true end
        end
        assert.is_true(found)
    end)

    it("produces the same zone shape as the scripted createExtractZone API", function()
        env.mission = { triggers = { zones = { { name = "EXZ_frontline_flag1_1" } } } }
        local zm = CTLDZoneManager.getInstance()
        local discovered = zm._troopZones["EXZ_frontline_flag1_1"]

        local zm2 = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)
        zm2:createExtractZone("some_other_zone", "flag1", 1)
        local scripted = zm2._troopZones["some_other_zone"]

        assert.equals(discovered.objectiveFlag, scripted.objectiveFlag)
        assert.equals(discovered.smoke, scripted.smoke)
        assert.equals(discovered.coalition, scripted.coalition)
    end)

    it("does not overwrite a zone already registered under that exact full name", function()
        env.mission = { triggers = { zones = { { name = "EXZ_lz1_nil_nil" } } } }
        local zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)
        local sentinel = CTLDTroopZone:new({
            dcsName = "EXZ_lz1_nil_nil", zoneName = "EXZ_lz1_nil_nil",
            coalition = coalition.side.BLUE, center = { x = 0, y = 0, z = 0 }, radius = 10,
        })
        zm._troopZones["EXZ_lz1_nil_nil"] = sentinel

        zm:_discoverEXZ()

        assert.equals(sentinel, zm._troopZones["EXZ_lz1_nil_nil"])
    end)

end)
