---@diagnostic disable
-- tests/ci/unit/beacon_scripted_api_spec.lua
-- FEAT-VMCT-INTEGRATION ticket 03 — a beacon placed by a script, with no transport and no
-- player: createAtPoint() + removeBeacon(). dropBeacon() keeps the pilot-facing half (the
-- coalition message and the OnBeaconDropped event) and delegates the rest.
-- ============================================================

describe("CTLDBeaconManager scripted beacon API", function()

    local mgr, published, coalitionTexts
    local origPublish, origOutText, origGs, origInAir
    local spawnCount

    -- A manager with real frequency pools but no DCS spawning: _spawnBeaconUnit is what needs
    -- a live mission, everything else under test is CTLD's own logic.
    local function newManager()
        local m = setmetatable({}, CTLDBeaconManager)
        m._beacons     = {}
        m._beaconCount = 0
        m._layerState  = {}
        m._freeVHF, m._usedVHF = {}, {}
        m._freeUHF, m._usedUHF = {}, {}
        m._freeFM,  m._usedFM  = {}, {}
        m:_buildFreqPools()
        m._refreshScheduled = true   -- do not start a real timer loop in a unit test
        function m:_spawnBeaconUnit(point, countryId, displayName)
            spawnCount = spawnCount + 1
            local gname = "CTLDBeacon-test-" .. spawnCount
            return { getName = function() return gname end }
        end
        function m:_addBeaconToLayers() end
        function m:_removeBeaconFromLayers() end
        function m:_destroyBeaconUnits() end
        return m
    end

    local function fakeTransport()
        return {
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return country.id.USA end,
            getPoint     = function() return { x = 100, y = 0, z = 200 } end,
        }
    end

    before_each(function()
        spawnCount, published, coalitionTexts = 0, {}, {}

        local dispatcher = EventDispatcher.getInstance()
        origPublish = dispatcher.publish
        dispatcher.publish = function(self, eventName, payload)
            published[#published + 1] = eventName
            return origPublish(self, eventName, payload)
        end

        origOutText = trigger.action.outTextForCoalition
        trigger.action.outTextForCoalition = function(coa, text, dur)
            coalitionTexts[#coalitionTexts + 1] = text
        end

        origGs  = ctld.gs
        ctld.gs = function(key)
            if key == "enabledRadioBeaconDrop" then return true end
            if key == "deployedBeaconBattery"  then return 30 end
            return origGs and origGs(key)
        end

        origInAir = ctld.utils.inAir
        ctld.utils.inAir = function() return true end   -- no bounding-box offset path

        mgr = newManager()
    end)

    after_each(function()
        EventDispatcher.getInstance().publish  = origPublish
        trigger.action.outTextForCoalition     = origOutText
        ctld.gs                                = origGs
        ctld.utils.inAir                       = origInAir
    end)

    it("returns a beacon carrying three usable, non-colliding frequencies", function()
        local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA)

        assert.is_not_nil(b)
        assert.is_not_nil(b.vhf)
        assert.is_not_nil(b.uhf)
        assert.is_not_nil(b.fm)
        assert.is_true(b.vhf ~= b.uhf and b.uhf ~= b.fm and b.vhf ~= b.fm)
        assert.is_not_nil(b:freqText():find("kHz"))
    end)

    it("gives two successive beacons different frequencies, and frees them on removal", function()
        local first  = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA)
        local second = mgr:createAtPoint({ x = 1, y = 0, z = 1 }, coalition.side.BLUE, country.id.USA)

        assert.is_true(first.vhf ~= second.vhf)
        assert.is_true(first.uhf ~= second.uhf)
        assert.is_true(first.fm  ~= second.fm)

        local freeBefore = #mgr._freeVHF
        assert.is_true(mgr:removeBeacon(first.name))
        assert.equals(freeBefore + 1, #mgr._freeVHF)
        assert.is_nil(mgr._beacons[first.beaconName])
    end)

    it("announces nothing and publishes nothing — it is not a player drop", function()
        mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA)

        assert.equals(0, #coalitionTexts)
        for _, name in ipairs(published) do
            assert.is_true(name ~= "OnBeaconDropped", "createAtPoint must not publish OnBeaconDropped")
        end
    end)

    it("ignores enabledRadioBeaconDrop — that setting gates the pilot's menu action", function()
        local base = ctld.gs
        ctld.gs = function(key)
            if key == "enabledRadioBeaconDrop" then return false end
            return base(key)
        end

        local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA)

        ctld.gs = base
        assert.is_not_nil(b)
    end)

    it("takes a name and a battery life from opts, -1 meaning never expires", function()
        local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
            { name = "FARP Alpha NDB", batteryMinutes = -1 })

        assert.equals("FARP Alpha NDB", b.name)
        assert.equals(-1, b.batteryEndTime)
        assert.is_true(b:isBatteryAlive())
    end)

    it("defaults the battery to the deployedBeaconBattery setting", function()
        local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA)
        -- timer.getTime() stub = 0, so endTime is the raw duration in seconds
        assert.equals(30 * 60, b.batteryEndTime)
    end)

    it("removes a beacon by its internal key as well as by its display name", function()
        local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
            { name = "FOB NDB" })

        assert.is_true(mgr:removeBeacon(b.beaconName))
        assert.equals(0, (function() local n = 0 for _ in pairs(mgr._beacons) do n = n + 1 end return n end)())
        assert.is_false(mgr:removeBeacon("FOB NDB"))   -- already gone
    end)

    it("dropBeacon still announces to the coalition and publishes OnBeaconDropped", function()
        local b = mgr:dropBeacon(fakeTransport(), "Zip", false)

        assert.is_not_nil(b)
        assert.equals(1, #coalitionTexts)
        local sawDropped = false
        for _, name in ipairs(published) do
            if name == "OnBeaconDropped" then sawDropped = true end
        end
        assert.is_true(sawDropped)
    end)

    it("dropBeacon still refuses to place a beacon when the pilot action is disabled", function()
        local base = ctld.gs
        ctld.gs = function(key)
            if key == "enabledRadioBeaconDrop" then return false end
            return base(key)
        end

        local b = mgr:dropBeacon(fakeTransport(), "Zip", false)

        ctld.gs = base
        assert.is_nil(b)
        assert.equals(0, #coalitionTexts)
    end)

    it("createAtZone still announces and publishes — it is the mission maker's own drop", function()
        local origGetZone = trigger.misc.getZone
        trigger.misc.getZone = function(name)
            return { point = { x = 500, y = 0, z = 700 }, radius = 100 }
        end

        local b = mgr:createAtZone("beaconZone", "blue", 45, "Alpha NDB")

        trigger.misc.getZone = origGetZone
        assert.is_not_nil(b)
        assert.equals("Alpha NDB", b.name)
        assert.equals(45 * 60, b.batteryEndTime)
        assert.equals(1, #coalitionTexts)
        local sawDropped = false
        for _, name in ipairs(published) do
            if name == "OnBeaconDropped" then sawDropped = true end
        end
        assert.is_true(sawDropped)
    end)

    it("dropBeacon with isFOB still produces a beacon that never expires", function()
        local b = mgr:dropBeacon(fakeTransport(), "Zip", true)

        assert.equals(-1, b.batteryEndTime)
        assert.is_true(b.isFOB)
    end)

end)
