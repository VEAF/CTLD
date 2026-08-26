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

    -- ─────────────────────────────────────────────────────────────
    -- FEAT-BEACON-REQUESTED-FREQS — opts.frequencies: a caller asks for a briefed frequency
    -- instead of taking whatever the pool drew. Refusals are total: no beacon, no consumed
    -- frequency, and a reason string the caller can read.
    -- ─────────────────────────────────────────────────────────────
    describe("requested frequencies (opts.frequencies)", function()

        -- Frequencies the pools actually hold: 250 kHz (10 kHz step, not an NDB), 251 MHz
        -- (0.5 MHz step) and 40.5 MHz ((100*4 + 10*0 + 5) * 100 kHz).
        local WANT = { vhfKHz = 250, uhfMHz = 251, fmMHz = 40.5 }

        local function inPool(pool, hz)
            return mgr:_poolIndexOf(pool, hz) ~= nil
        end

        local function poolSizes()
            return #mgr._freeVHF, #mgr._freeUHF, #mgr._freeFM
        end

        it("still draws all three bands at random when nothing is requested", function()
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { name = "Default" })

            assert.is_not_nil(b)
            for _, pair in ipairs({ { mgr._freeVHF, mgr._usedVHF, b.vhf },
                                    { mgr._freeUHF, mgr._usedUHF, b.uhf },
                                    { mgr._freeFM,  mgr._usedFM,  b.fm  } }) do
                assert.is_false(inPool(pair[1], pair[3]))   -- taken out of the free pool
                assert.is_true(inPool(pair[2], pair[3]))    -- and recorded as used
            end
        end)

        it("treats an empty request table as no request at all", function()
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = {} })

            assert.is_not_nil(b)
            assert.is_not_nil(b.vhf)
            assert.is_not_nil(b.uhf)
            assert.is_not_nil(b.fm)
        end)

        it("grants all three bands, in the unit each key names", function()
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { name = "FARP Alpha NDB", frequencies = WANT })

            assert.is_not_nil(b)
            assert.equals(250000,    b.vhf)   -- 250 kHz
            assert.equals(251000000, b.uhf)   -- 251 MHz
            assert.equals(40500000,  b.fm)    -- 40.5 MHz
            assert.equals("250.00 kHz - 251.00 / 40.50 MHz", b:freqText())
        end)

        -- FIX-BEACON-FM-POOL-GAP: 38.00 MHz used to fall in one of the pool's four gaps
        -- (s only ran 0..5); the pool is now continuous over the full 30.0-75.9 MHz range.
        it("grants a frequency that used to fall in the FM pool's now-closed gap", function()
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { fmMHz = 38 } })

            assert.is_not_nil(b)
            assert.equals(38000000, b.fm)
        end)

        it("moves a granted frequency out of the free pool and into the used one", function()
            local freeVHF = #mgr._freeVHF
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { vhfKHz = 250 } })

            assert.equals(250000, b.vhf)
            assert.equals(freeVHF - 1, #mgr._freeVHF)
            assert.is_false(inPool(mgr._freeVHF, 250000))
            assert.is_true(inPool(mgr._usedVHF,  250000))
        end)

        it("leaves the bands it was not asked about random", function()
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { fmMHz = 40.5 } })

            assert.equals(40500000, b.fm)
            assert.is_not_nil(b.vhf)
            assert.is_not_nil(b.uhf)
            assert.is_true(inPool(mgr._usedVHF, b.vhf))
            assert.is_true(inPool(mgr._usedUHF, b.uhf))
        end)

        it("matches a fractional request exactly, despite binary floating point", function()
            -- 45.2 has no exact double representation; the pool holds 45200000 Hz exactly.
            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { fmMHz = 45.2, uhfMHz = 350.5 } })

            assert.is_not_nil(b)
            assert.equals(45200000,  b.fm)
            assert.equals(350500000, b.uhf)
        end)

        it("frees a granted frequency on removal, so it can be asked for again", function()
            local first = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { name = "First", frequencies = { vhfKHz = 250 } })
            assert.is_true(mgr:removeBeacon("First"))

            local second = mgr:createAtPoint({ x = 1, y = 0, z = 1 }, coalition.side.BLUE, country.id.USA,
                { name = "Second", frequencies = { vhfKHz = 250 } })

            assert.equals(250000, first.vhf)
            assert.is_not_nil(second)
            assert.equals(250000, second.vhf)
        end)

        -- ── Refusals ─────────────────────────────────────────────
        -- All four refuse the whole call and return a reason. Falling back to a random pick
        -- was rejected: a beacon answering on a frequency other than the briefed one is
        -- invisible to the mission maker and inaudible to the pilot who tuned the briefed one.

        it("refuses a frequency already used by a live beacon", function()
            mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { name = "Holder", frequencies = { vhfKHz = 250 } })

            local b, reason = mgr:createAtPoint({ x = 1, y = 0, z = 1 }, coalition.side.BLUE, country.id.USA,
                { name = "Latecomer", frequencies = { vhfKHz = 250 } })

            assert.is_nil(b)
            assert.is_not_nil(reason:find("already used", 1, true))
        end)

        it("refuses a frequency outside the band — which is what a unit mistake looks like", function()
            local cases = {
                { vhfKHz = 250000 },      -- Hz where kHz was asked for
                { vhfKHz = 0.25 },        -- MHz where kHz was asked for
                { uhfMHz = 251000000 },   -- Hz where MHz was asked for
                { fmMHz  = 45200 },       -- kHz where MHz was asked for
                { uhfMHz = 420 },         -- above the UHF pool
                { fmMHz  = 29 },          -- below the FM pool
            }
            for _, request in ipairs(cases) do
                local b, reason = mgr:createAtPoint({ x = 0, y = 0, z = 0 },
                    coalition.side.BLUE, country.id.USA, { frequencies = request })
                assert.is_nil(b)
                assert.is_not_nil(reason:find("outside the", 1, true))
            end
        end)

        it("refuses a frequency the pool does not offer — off its step, or a map NDB", function()
            local cases = {
                { vhfKHz = 205 },      -- VHF steps by 10 kHz below 850
                { vhfKHz = 440 },      -- on the step, but a real-world NDB (_ndbSkip)
                { uhfMHz = 251.25 },   -- UHF steps by 0.5 MHz
                { fmMHz  = 38.05 },    -- FM steps by 0.1 MHz (the t digit), 38.05 is off-grid
            }
            for _, request in ipairs(cases) do
                local b, reason = mgr:createAtPoint({ x = 0, y = 0, z = 0 },
                    coalition.side.BLUE, country.id.USA, { frequencies = request })
                assert.is_nil(b)
                assert.is_not_nil(reason:find("is not a", 1, true))
            end
        end)

        it("refuses an unknown key rather than quietly returning a random frequency", function()
            local b, reason = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { vhf = 250 } })   -- missing the unit: vhfKHz

            assert.is_nil(b)
            assert.is_not_nil(reason:find("unknown frequency request key", 1, true))
        end)

        it("refuses a non-number value and a non-table request", function()
            local b1, reason1 = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { vhfKHz = "250" } })
            assert.is_nil(b1)
            assert.is_not_nil(reason1:find("must be a number", 1, true))

            local b2, reason2 = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = 250 })
            assert.is_nil(b2)
            assert.is_not_nil(reason2:find("must be a table", 1, true))
        end)

        it("costs nothing when refused — no beacon, no spawn, no frequency consumed", function()
            local vhf, uhf, fm = poolSizes()
            local countBefore  = mgr._beaconCount
            local spawnsBefore = spawnCount

            local b = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { vhfKHz = 250, uhfMHz = 251, fmMHz = 38.05 } })   -- FM is off-grid

            assert.is_nil(b)
            local vhfAfter, uhfAfter, fmAfter = poolSizes()
            assert.equals(vhf, vhfAfter)          -- the granted VHF was never taken
            assert.equals(uhf, uhfAfter)
            assert.equals(fm,  fmAfter)
            assert.equals(countBefore,  mgr._beaconCount)
            assert.equals(spawnsBefore, spawnCount)
            assert.equals(0, (function() local n = 0 for _ in pairs(mgr._beacons) do n = n + 1 end return n end)())
        end)

        it("gives the frequencies back when the spawn fails, so the same request can be retried", function()
            local realSpawn = mgr._spawnBeaconUnit
            mgr._spawnBeaconUnit = function() return nil end

            local b, reason = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { vhfKHz = 250 } })
            assert.is_nil(b)
            assert.is_not_nil(reason:find("spawn failed", 1, true))

            mgr._spawnBeaconUnit = realSpawn
            local retry = mgr:createAtPoint({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, country.id.USA,
                { frequencies = { vhfKHz = 250 } })

            assert.is_not_nil(retry)
            assert.equals(250000, retry.vhf)
        end)

        it("declares band ranges that still match the pools _buildFreqPools builds", function()
            -- The only duplicated knowledge this feature introduces: _bands states each band's
            -- range so a refusal can name it, and _buildFreqPools builds the entries. This
            -- fails if either side moves without the other.
            local pools = { vhf = mgr._freeVHF, uhf = mgr._freeUHF, fm = mgr._freeFM }
            for _, band in ipairs(CTLDBeaconManager._bands) do
                local pool = pools[band.key]
                local lo, hi = math.huge, -math.huge
                for _, hz in ipairs(pool) do
                    if hz < lo then lo = hz end
                    if hz > hi then hi = hz end
                end
                assert.equals(math.floor(band.min * band.perUnit + 0.5), lo)
                assert.equals(math.floor(band.max * band.perUnit + 0.5), hi)
            end
        end)

    end)

end)
