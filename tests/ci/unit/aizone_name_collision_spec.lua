---@diagnostic disable
-- tests/ci/unit/aizone_name_collision_spec.lua
-- FIX-AIZONE-NAME-COLLISION ticket 01 — an aiZones entry whose dcsZoneName is already a
-- registered troop zone is skipped. The skip is right (a discovered zone wins); the silence
-- was not. It is reachable by accident because a TRZ registers under its *parsed* name.
-- ============================================================

describe("an aiZones entry whose name is already taken", function()

    local zm, origGs, origGetZone, settings

    local function reports()
        local out = {}
        for _, e in ipairs(ctld.startupReport._entries) do
            if e.source == "ZoneManager" then out[#out + 1] = e end
        end
        return out
    end

    before_each(function()
        zm = setmetatable({ _troopZones = {}, _logisticZones = {} }, CTLDZoneManager)
        origGs      = ctld.gs
        origGetZone = trigger.misc.getZone
        settings = {
            aiZones = {
                { dcsZoneName = "dropzone1", coalition = "BLUE", isPickup = false, isDropoff = true },
            },
        }
        ctld.gs = function(key)
            if settings[key] ~= nil then return settings[key] end
            return origGs and origGs(key)
        end
        trigger.misc.getZone = function(name)
            return { point = { x = 0, y = 0, z = 0 }, radius = 250 }
        end
        ctld.startupReport._entries = {}
    end)

    after_each(function()
        ctld.gs                    = origGs
        trigger.misc.getZone       = origGetZone
        ctld.startupReport._entries = {}
    end)

    it("is reported once, naming the entry and the zone holding the name", function()
        -- what _discoverTRZ would have registered for TRZ_dropzone1_B_0_nil_0
        zm._troopZones["dropzone1"] = CTLDTroopZone:new({
            dcsName = "TRZ_dropzone1_B_0_nil_0", zoneName = "dropzone1",
            coalition = coalition.side.BLUE, center = { x = 0, y = 0, z = 0 }, radius = 250,
        })

        zm:_loadAIZonesFromConfig()

        local r = reports()
        assert.equals(1, #r)
        assert.equals("ERROR", r[1].severity)
        assert.is_not_nil(r[1].message:find("dropzone1", 1, true))
        assert.is_not_nil(r[1].message:find("TRZ_dropzone1_B_0_nil_0", 1, true))
    end)

    it("leaves the discovered zone in place — the report explains the loss, it does not undo it", function()
        local trz = CTLDTroopZone:new({
            dcsName = "TRZ_dropzone1_B_0_nil_0", zoneName = "dropzone1",
            coalition = coalition.side.BLUE, center = { x = 0, y = 0, z = 0 }, radius = 250,
        })
        zm._troopZones["dropzone1"] = trz

        zm:_loadAIZonesFromConfig()

        assert.equals(trz, zm._troopZones["dropzone1"])
        assert.is_false(zm._troopZones["dropzone1"]:hasAIDropoff())
    end)

    it("says nothing when the names differ, and registers both zones", function()
        zm._troopZones["dropmarker1"] = CTLDTroopZone:new({
            dcsName = "TRZ_dropmarker1_B_0_nil_0", zoneName = "dropmarker1",
            coalition = coalition.side.BLUE, center = { x = 0, y = 0, z = 0 }, radius = 250,
        })

        zm:_loadAIZonesFromConfig()

        assert.equals(0, #reports())
        assert.is_not_nil(zm._troopZones["dropmarker1"])
        assert.is_not_nil(zm._troopZones["dropzone1"])
        assert.is_true(zm._troopZones["dropzone1"]:hasAIDropoff())
    end)

    it("says nothing about an entry already rejected by validation", function()
        -- _validateZoneNames already reported it; a second message would be noise.
        zm._aiZoneErrors = { dropzone1 = true }
        zm._troopZones["dropzone1"] = CTLDTroopZone:new({
            dcsName = "TRZ_dropzone1_B_0_nil_0", zoneName = "dropzone1",
            coalition = coalition.side.BLUE, center = { x = 0, y = 0, z = 0 }, radius = 250,
        })

        zm:_loadAIZonesFromConfig()

        assert.equals(0, #reports())
    end)

    it("reports each colliding entry separately", function()
        settings.aiZones = {
            { dcsZoneName = "dropzone1", coalition = "BLUE", isDropoff = true },
            { dcsZoneName = "dropzone2", coalition = "RED",  isDropoff = true },
        }
        for _, n in ipairs({ "dropzone1", "dropzone2" }) do
            zm._troopZones[n] = CTLDTroopZone:new({
                dcsName = "TRZ_" .. n .. "_B_0_nil_0", zoneName = n,
                coalition = coalition.side.BLUE, center = { x = 0, y = 0, z = 0 }, radius = 250,
            })
        end

        zm:_loadAIZonesFromConfig()

        assert.equals(2, #reports())
    end)

end)
