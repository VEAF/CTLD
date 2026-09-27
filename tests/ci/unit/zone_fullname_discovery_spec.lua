---@diagnostic disable
-- tests/ci/unit/zone_fullname_discovery_spec.lua
-- FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY -- TRZ_/LGZ_/WPZ_ register under their full DCS name,
-- not the parsed short field (parsed.zoneName/parsed.name), matching EXZ_'s existing convention.
-- No prior art: zone_manager_spec.lua only exercises parseTRZ/_parseLGZ/_parseWPZ in isolation;
-- nothing before this file ran a real discovery pass and asserted the registration key.
-- ============================================================

describe("Auto-discovered zones register under their full DCS name", function()

    local savedMission, savedGetZone

    before_each(function()
        ctld.startupReport._entries = {}
        CTLDZoneManager._instance = nil
        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        trigger.misc.getZone = function(_)
            return { point = { x = 100, y = 0, z = 200 }, radius = 300 }
        end
    end)

    after_each(function()
        ctld.startupReport._entries = {}
        CTLDZoneManager._instance = nil
        env.mission           = savedMission
        trigger.misc.getZone   = savedGetZone
    end)

    describe("_discoverTRZ", function()

        it("registers under the full DCS name, not the parsed short zoneName", function()
            env.mission = { triggers = { zones = { { name = "TRZ_dropzone1_B_0_nil_0" } } } }
            local zm = CTLDZoneManager.getInstance()

            assert.is_not_nil(zm._troopZones["TRZ_dropzone1_B_0_nil_0"])
            assert.is_nil(zm._troopZones["dropzone1"])
        end)

        it("two TRZ_ zones sharing the same parsed short name both register", function()
            env.mission = { triggers = { zones = {
                { name = "TRZ_dropzone1_B_0_nil_0" },
                { name = "TRZ_dropzone1_R_10_nil_0" },
            } } }
            local zm = CTLDZoneManager.getInstance()

            assert.is_not_nil(zm._troopZones["TRZ_dropzone1_B_0_nil_0"])
            assert.is_not_nil(zm._troopZones["TRZ_dropzone1_R_10_nil_0"])
            assert.are_not.equals(
                zm._troopZones["TRZ_dropzone1_B_0_nil_0"],
                zm._troopZones["TRZ_dropzone1_R_10_nil_0"])
        end)

    end)

    describe("_discoverLGZ", function()

        it("registers under the full DCS name, not the parsed short name", function()
            env.mission = { triggers = { zones = { { name = "LGZ_supply_B" } } } }
            local zm = CTLDZoneManager.getInstance()

            assert.is_not_nil(zm._logisticZones["LGZ_supply_B"])
            assert.is_nil(zm._logisticZones["supply"])
        end)

    end)

    describe("_discoverWPZ", function()

        it("registers under the full DCS name, not the parsed short zoneName", function()
            env.mission = { triggers = { zones = { { name = "WPZ_march_B" } } } }
            local zm = CTLDZoneManager.getInstance()

            assert.is_not_nil(zm._troopZones["WPZ_march_B"])
            assert.is_nil(zm._troopZones["march"])
        end)

    end)

    describe("aiZones no longer collides with a TRZ_'s parsed short name", function()

        it("an aiZones entry named after a TRZ_'s short field registers independently", function()
            env.mission = { triggers = { zones = { { name = "TRZ_dropzone1_B_0_nil_0" } } } }
            local origGs = ctld.gs
            ctld.gs = function(k)
                if k == "aiZones" then
                    return { { dcsZoneName = "dropzone1", isPickup = true, cargoType = "T",
                               troopStock = { All = -1 } } }
                end
                return origGs(k)
            end

            local zm = CTLDZoneManager.getInstance()

            local trzCollision = false
            for _, e in ipairs(ctld.startupReport._entries) do
                if e.severity == "ERROR" and e.source == "ZoneManager"
                        and tostring(e.message):find("already taken") then
                    trzCollision = true
                end
            end
            assert.is_false(trzCollision)

            ctld.gs = origGs
        end)

    end)

end)
