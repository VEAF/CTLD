---@diagnostic disable
-- tests/ci/functional/zone_registry_key_roundtrip_spec.lua
-- FIX-ZONE-REGISTRY-KEY ticket 01 -- a zone is found again by its own registryKey(), whichever way it
-- was registered (ADR 0023). Every path that files a troop or logistic zone is exercised through the
-- real zone manager; a new registration path that files a zone under another key fails here.
-- ============================================================

describe("Zone registry key -- round trip over every registration path", function()

    local savedMission, savedGetZone, origGs, origStatic

    before_each(function()
        ctld.startupReport._entries = {}
        CTLDZoneManager._instance = nil
        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        origGs       = ctld.gs
        origStatic   = StaticObject.getByName
        trigger.misc.getZone = function(_)
            return { point = { x = 100, y = 0, z = 200 }, radius = 300 }
        end
        env.mission = { triggers = { zones = {
            { name = "TRZ_alpha_B_999_nil_0" },
            { name = "WPZ_march_B" },
            { name = "EXZ_rescue_B_nil_0" },
            { name = "LGZ_log1_B" },
        } } }
        StaticObject.getByName = function(n)
            if n == "depot_static" then
                return {
                    getName      = function() return n end,
                    getCoalition = function() return coalition.side.BLUE end,
                    getPoint     = function() return { x = 5, y = 0, z = 5 } end,
                    isExist      = function() return true end,
                }
            end
            return origStatic and origStatic(n) or nil
        end
        ctld.gs = function(k)
            if k == "logisticUnits" then return { "depot_static" } end
            if k == "aiZones" then
                return { { dcsZoneName = "aiz_one", coalition = "BLUE", isDropoff = true } }
            end
            return origGs(k)
        end
    end)

    after_each(function()
        ctld.gs                = origGs
        StaticObject.getByName = origStatic
        env.mission            = savedMission
        trigger.misc.getZone   = savedGetZone
        CTLDZoneManager._instance = nil
        ctld.startupReport._entries = {}
    end)

    local function allZonesRoundTrip(zm)
        local nTroop, nLogistic = 0, 0
        for _, zone in pairs(zm._troopZones) do
            nTroop = nTroop + 1
            assert.equals(zone, zm:getTroopZone(zone:registryKey()),
                "troop zone not found again by its registryKey: " .. tostring(zone.zoneName))
        end
        for _, zone in pairs(zm._logisticZones) do
            nLogistic = nLogistic + 1
            assert.equals(zone, zm:getLogisticZone(zone:registryKey()),
                "logistic zone not found again by its registryKey: " .. tostring(zone.name))
        end
        return nTroop, nLogistic
    end

    it("auto-discovered TRZ_/WPZ_/EXZ_/LGZ_ zones: the key is the full DCS name", function()
        local zm = CTLDZoneManager.getInstance()
        assert.equals("TRZ_alpha_B_999_nil_0", zm:getTroopZone("TRZ_alpha_B_999_nil_0"):registryKey())
        assert.equals("WPZ_march_B",           zm:getTroopZone("WPZ_march_B"):registryKey())
        assert.equals("EXZ_rescue_B_nil_0",    zm:getTroopZone("EXZ_rescue_B_nil_0"):registryKey())
        assert.equals("LGZ_log1_B",            zm:getLogisticZone("LGZ_log1_B"):registryKey())
    end)

    it("logistic unit (logisticUnits config): the key is the unit name", function()
        local zm = CTLDZoneManager.getInstance()
        local z = zm:getLogisticZone("depot_static")
        assert.is_not_nil(z)
        assert.equals("depot_static", z:registryKey())
    end)

    it("AIZ_ config zone: found again by its registryKey", function()
        local zm = CTLDZoneManager.getInstance()
        local z = zm:getTroopZone("aiz_one")
        assert.is_not_nil(z)
        assert.equals(z, zm:getTroopZone(z:registryKey()))
    end)

    it("FOB troop zone and FOB logistic zone: the key is the FOB name", function()
        local zm = CTLDZoneManager.getInstance()
        local p = { x = 10, y = 0, z = 10 }
        assert.is_true(zm:registerFOBAsTroopZone("Deployed FOB #1", p, 150, coalition.side.BLUE))
        assert.is_true(zm:registerFOBAsLogistic("Deployed FOB #1", p, 150, coalition.side.BLUE))
        assert.equals("Deployed FOB #1", zm:getTroopZone("Deployed FOB #1"):registryKey())
        assert.equals("Deployed FOB #1", zm:getLogisticZone("Deployed FOB #1"):registryKey())
    end)

    it("scripted createExtractZone: the key is the name given by the script", function()
        local zm = CTLDZoneManager.getInstance()
        assert.is_true(zm:createExtractZone("scripted_ext", 1001, -1))
        assert.equals("scripted_ext", zm:getTroopZone("scripted_ext"):registryKey())
    end)

    it("every zone registered by any of the paths above is found again by its own registryKey", function()
        local zm = CTLDZoneManager.getInstance()
        local p = { x = 10, y = 0, z = 10 }
        zm:registerFOBAsTroopZone("Deployed FOB #1", p, 150, coalition.side.BLUE)
        zm:registerFOBAsLogistic("Deployed FOB #1", p, 150, coalition.side.BLUE)
        zm:createExtractZone("scripted_ext", 1001, -1)
        local nTroop, nLogistic = allZonesRoundTrip(zm)
        assert.is_true(nTroop >= 6)
        assert.is_true(nLogistic >= 3)
    end)

end)
