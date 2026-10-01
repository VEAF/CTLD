---@diagnostic disable
-- tests/ci/functional/zone_event_payloads_spec.lua
-- FIX-ZONE-REGISTRY-KEY ticket 02 -- every zone event payload identifies a zone by its registry key,
-- in troop and logistic entries alike (ADR 0023). `name` is the key; `fullName`, the troop `zoneName`
-- and the `unitName` of the added/removed lists are gone; no short-name field replaces them.
-- The auto-discovered zones below have a short name (alpha, log1) that differs from their key, so a
-- payload that still carried the short name would fail.
-- ============================================================

describe("Zone event payloads identify zones by registry key", function()

    local TRZ_KEY = "TRZ_alpha_B_999_nil_0"
    local LGZ_KEY = "LGZ_log1_B"

    local savedMission, savedGetZone, origSchedule, smokeRefresh, zm

    before_each(function()
        ctld.startupReport._entries = {}
        CTLDZoneManager._instance = nil
        EventDispatcher._instance = nil
        savedMission = env.mission
        savedGetZone = trigger.misc.getZone
        origSchedule = timer.scheduleFunction
        trigger.misc.getZone = function(_)
            return { point = { x = 100, y = 0, z = 200 }, radius = 300 }
        end
        env.mission = { triggers = { zones = { { name = TRZ_KEY }, { name = LGZ_KEY } } } }

        smokeRefresh = nil
        timer.scheduleFunction = function(fn, _, t)
            if t == ctld.gs("smokeRefreshInterval") then smokeRefresh = smokeRefresh or fn end
            return 0
        end
        zm = CTLDZoneManager.getInstance()
        timer.scheduleFunction = origSchedule
    end)

    after_each(function()
        timer.scheduleFunction = origSchedule
        env.mission            = savedMission
        trigger.misc.getZone   = savedGetZone
        CTLDZoneManager._instance = nil
        EventDispatcher._instance = nil
        ctld.startupReport._entries = {}
    end)

    local function capture(eventName, fn)
        local ed    = EventDispatcher.getInstance()
        local fired = {}
        local cb    = function(p) fired[#fired + 1] = p end
        ed:subscribe(eventName, cb)
        local ok, err = pcall(fn)
        ed:unsubscribe(eventName, cb)
        assert(ok, err)
        return fired
    end

    local function findByName(list, name)
        for _, entry in ipairs(list) do
            if entry.name == name then return entry end
        end
        return nil
    end

    describe("OnZoneSmokeRefreshed", function()

        it("troop and logistic entries carry the registry key as name", function()
            assert.is_not_nil(smokeRefresh, "smoke refresh was not scheduled")
            zm:getTroopZone(TRZ_KEY).smoke = 0   -- a smoking troop zone (none is by default)

            local fired = capture("OnZoneSmokeRefreshed", function() smokeRefresh() end)

            assert.equals(1, #fired)
            local troop = findByName(fired[1].troopZones, TRZ_KEY)
            local logistic = findByName(fired[1].logisticZones, LGZ_KEY)
            assert.is_not_nil(troop, "no troop entry keyed by the registry key")
            assert.is_not_nil(logistic, "no logistic entry keyed by the registry key")
        end)

        it("drops fullName and the troop zoneName", function()
            zm:getTroopZone(TRZ_KEY).smoke = 0

            local fired = capture("OnZoneSmokeRefreshed", function() smokeRefresh() end)

            local troop = findByName(fired[1].troopZones, TRZ_KEY)
            assert.is_nil(troop.fullName)
            assert.is_nil(troop.zoneName)
        end)

    end)

    describe("OnTroopZoneUpdated", function()

        it("zones entries carry the registry key as name", function()
            local fired = capture("OnTroopZoneUpdated", function()
                zm:createExtractZone("scripted_ext", 1001, -1)
            end)
            assert.equals(1, #fired)
            assert.is_not_nil(findByName(fired[1].zones, TRZ_KEY))
            assert.is_not_nil(findByName(fired[1].zones, "scripted_ext"))
        end)

        it("unitsAdded and unitsRemoved entries carry name, not zoneName", function()
            local added = capture("OnTroopZoneUpdated", function()
                zm:createExtractZone("scripted_ext", 1001, -1)
            end)
            assert.equals("scripted_ext", added[1].unitsAdded[1].name)
            assert.is_nil(added[1].unitsAdded[1].zoneName)

            local removed = capture("OnTroopZoneUpdated", function()
                zm:removeExtractZone("scripted_ext", 1001)
            end)
            assert.equals("scripted_ext", removed[1].unitsRemoved[1].name)
            assert.is_nil(removed[1].unitsRemoved[1].zoneName)
        end)

    end)

    describe("OnLogisticZoneUpdated", function()

        it("zones entries carry the registry key as name", function()
            local fired = capture("OnLogisticZoneUpdated", function()
                zm:registerFOBAsLogistic("Deployed FOB #1", { x = 10, y = 0, z = 10 }, 150, coalition.side.BLUE)
            end)
            assert.equals(1, #fired)
            assert.is_not_nil(findByName(fired[1].zones, LGZ_KEY))
            assert.is_not_nil(findByName(fired[1].zones, "Deployed FOB #1"))
        end)

        it("unitsAdded and unitsRemoved entries carry name, not unitName", function()
            local added = capture("OnLogisticZoneUpdated", function()
                zm:registerFOBAsLogistic("Deployed FOB #1", { x = 10, y = 0, z = 10 }, 150, coalition.side.BLUE)
            end)
            assert.equals("Deployed FOB #1", added[1].unitsAdded[1].name)
            assert.is_nil(added[1].unitsAdded[1].unitName)

            local removed = capture("OnLogisticZoneUpdated", function()
                zm:unregisterLogistic("Deployed FOB #1")
            end)
            assert.equals("Deployed FOB #1", removed[1].unitsRemoved[1].name)
            assert.is_nil(removed[1].unitsRemoved[1].unitName)
        end)

    end)

end)
