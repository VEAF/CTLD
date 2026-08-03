---@diagnostic disable
-- tests/ci/functional/troop_fastrope_spec.lua
-- UX-FASTROPE-INFLIGHT
--   F-150 : _safeToFastRope — conditions AGL / vitesse
--   F-151 : disembark() — messages d'erreur distincts (altitude / vitesse)
--   F-152 : refreshMenuSection en vol — visibilité de "Disembark Troops"
-- ============================================================

-- ── Shared helpers ─────────────────────────────────────────────────────────────

local function makeUnit(name, ptY, speed, groundH)
    groundH = groundH or 0
    speed   = speed   or 0
    ptY     = ptY     or 5
    return {
        _name    = name or "UH-1H-1",
        getName      = function(self) return self._name end,
        getCoalition = function(self) return coalition.side.BLUE end,
        getCountry   = function(self) return 2 end,
        getTypeName  = function(self) return "UH-1H" end,
        getPoint     = function(self) return { x=0, y=ptY, z=0 } end,
        getPosition  = function(self)
            return { x={x=1,y=0,z=0}, p={x=0,y=ptY,z=0} }
        end,
        -- speed in m/s, all on x component for simplicity
        getVelocity  = function(self) return { x=speed, y=0, z=0 } end,
        getGroup     = function(self) return { getID = function() return 9901 end } end,
        isExist      = function(self) return true end,
        _groundH     = groundH,
    }
end

local function makeTroopGroup(name)
    return CTLDTroopGroup:new({
        templateKey  = name or "Alpha Squad",
        templateName = name or "Alpha Squad",
        unitTotal    = 4,
        weight       = 520,
        coalitionId  = coalition.side.BLUE,
        countryId    = 2,
    })
end

local function makePlayerObj(unitName)
    return {
        unitName    = unitName or "UH-1H-1",
        groupId     = 9901,
        typeName    = "UH-1H",
        isTransport = true,
        coalition   = coalition.side.BLUE,
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
describe("F-150 — _safeToFastRope conditions", function()

    local tm
    local _origGs
    local _origLandHeight

    before_each(function()
        CTLDTroopManager._instance = nil
        CTLDConfig.get().settings["loadableGroups"] = {}

        _origGs = ctld.gs
        ctld.gs = function(k)
            if k == "enableFastRopeInsertion" then return true end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=10 } }
            end
            return _origGs(k)
        end

        -- Ground at y=0 for all tests
        _origLandHeight = land.getHeight
        land.getHeight = function(_) return 0 end

        tm = CTLDTroopManager.getInstance()
    end)

    after_each(function()
        ctld.gs      = _origGs
        land.getHeight = _origLandHeight
    end)

    it("returns true when AGL <= max and speed < 2.2 m/s", function()
        -- y=5 (5m AGL), speed=0 — well within limits
        local u = makeUnit("u", 5, 0, 0)
        assert.is_true(tm:_safeToFastRope(u))
    end)

    it("returns false when AGL exceeds fastRopeMaximumHeight + 3m buffer", function()
        -- y=25 → 25m AGL, max=18.28+3=21.28 → too high
        local u = makeUnit("u", 25, 0, 0)
        assert.is_false(tm:_safeToFastRope(u))
    end)

    it("returns false when speed >= 2.2 m/s", function()
        -- y=5 (ok altitude), speed=3 m/s (too fast)
        local u = makeUnit("u", 5, 3, 0)
        assert.is_false(tm:_safeToFastRope(u))
    end)

    it("returns false when both altitude and speed exceed limits", function()
        local u = makeUnit("u", 25, 3, 0)
        assert.is_false(tm:_safeToFastRope(u))
    end)

    it("returns false when enableFastRopeInsertion is false", function()
        ctld.gs = function(k)
            if k == "enableFastRopeInsertion" then return false end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=10 } }
            end
            return _origGs(k)
        end
        local u = makeUnit("u", 5, 0, 0)
        assert.is_false(tm:_safeToFastRope(u))
    end)

end)

-- ─────────────────────────────────────────────────────────────────────────────
describe("F-151 — disembark() fast-rope error messages", function()

    local tm
    local _origGs
    local _origLandHeight
    local _origSpawn
    local messages

    before_each(function()
        CTLDTroopManager._instance  = nil
        CTLDPlayerManager._instance = nil
        ctld.MenuManager._instance  = nil
        EventDispatcher._instance   = nil
        CTLDZoneManager._instance   = nil
        CTLDJTACManager._instance   = nil
        CTLDVehicleSpawner._instance= nil
        _cmInstance                 = nil

        _origGs = ctld.gs
        ctld.gs = function(k)
            if k == "enableFastRopeInsertion" then return true end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=10 } }
            end
            if k == "numberOfTroops"        then return 10 end
            if k == "nbLimitSpawnedTroops"  then return { 0, 0 } end
            if k == "maxTransportWeight"    then return 0 end
            if k == "spawnDistanceInCircle" then return 10 end
            if k == "maxExtractDistance"    then return 125 end
            return _origGs(k)
        end

        _origLandHeight = land.getHeight
        land.getHeight = function(_) return 0 end

        -- Capture all outTextForGroup calls
        messages = {}
        local _origOut = trigger.action.outTextForGroup
        trigger.action.outTextForGroup = function(gid, msg, dur)
            messages[#messages + 1] = msg
        end

        -- Stub spawn (not needed for blocked cases, but guard for success case)
        _origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function(...)
            return { getName=function() return "Grp" end,
                     getUnits=function() return {} end,
                     isExist=function() return true end,
                     getController=function()
                         return { setOption=function() end, setTask=function() end }
                     end }
        end

        -- Force in-air for all these tests
        tm = CTLDTroopManager.getInstance()
        tm._isInAir = function(self, _) return true end

        local zm = CTLDZoneManager.getInstance()
        zm.isUnitInZone    = function(self, _, _) return nil end
        zm.getWaypointZoneAt = function(self, _, _) return nil end
    end)

    after_each(function()
        ctld.gs              = _origGs
        land.getHeight       = _origLandHeight
        CTLDObjectRegistry.spawnObject = _origSpawn
        -- Restore outTextForGroup (was set per-test; restore from orig captured in before_each)
        -- (busted tears down after each test, stubs are reset with the singletons)
    end)

    it("too high only: message mentions altitude, not speed", function()
        -- y=25m (above 18.28+3=21.28 limit), speed=0 (ok)
        local u = makeUnit("UH-1H-1", 25, 0, 0)
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha") }
        tm:disembark(u)

        local hasAlt   = false
        local hasSpeed = false
        for _, m in ipairs(messages) do
            if m:find("Descend", 1, true) or m:find("haut", 1, true) then
                hasAlt = true
            end
            if m:find("Slow down", 1, true) or m:find("rapide", 1, true) then
                hasSpeed = true
            end
        end
        assert.is_true(hasAlt,    "expected an altitude message")
        assert.is_false(hasSpeed, "expected NO speed message")
    end)

    it("too fast only: message mentions speed, not altitude", function()
        -- y=5m (ok), speed=3 m/s (too fast)
        local u = makeUnit("UH-1H-1", 5, 3, 0)
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha") }
        tm:disembark(u)

        local hasAlt   = false
        local hasSpeed = false
        for _, m in ipairs(messages) do
            if m:find("Descend", 1, true) or m:find("haut", 1, true) then
                hasAlt = true
            end
            if m:find("Slow down", 1, true) or m:find("rapide", 1, true) then
                hasSpeed = true
            end
        end
        assert.is_false(hasAlt,  "expected NO altitude message")
        assert.is_true(hasSpeed, "expected a speed message")
    end)

    it("both too high and too fast: both messages sent", function()
        local u = makeUnit("UH-1H-1", 25, 3, 0)
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha") }
        tm:disembark(u)

        local hasAlt   = false
        local hasSpeed = false
        for _, m in ipairs(messages) do
            if m:find("Descend", 1, true) or m:find("haut", 1, true) then
                hasAlt = true
            end
            if m:find("Slow down", 1, true) or m:find("rapide", 1, true) then
                hasSpeed = true
            end
        end
        assert.is_true(hasAlt,   "expected an altitude message")
        assert.is_true(hasSpeed, "expected a speed message")
    end)

    it("conditions met: no blocking message, returns true", function()
        -- y=5m (ok), speed=0 (ok)
        local u = makeUnit("UH-1H-1", 5, 0, 0)
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha") }
        local r = tm:disembark(u)

        assert.is_true(r)
        -- No blocking messages
        for _, m in ipairs(messages) do
            assert.is_falsy(m:find("Descend", 1, true),   "unexpected altitude block message")
            assert.is_falsy(m:find("Slow down", 1, true), "unexpected speed block message")
        end
    end)

end)

-- ─────────────────────────────────────────────────────────────────────────────
describe("F-152 — refreshMenuSection: Disembark Troops visibility in flight", function()

    local tm
    local playerObj
    local _origGs
    local _origLandHeight
    local _origGetByName

    before_each(function()
        CTLDTroopManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        ctld.MenuManager._instance   = nil
        EventDispatcher._instance    = nil
        CTLDZoneManager._instance    = nil
        CTLDJTACManager._instance    = nil
        CTLDVehicleSpawner._instance = nil
        _cmInstance                  = nil

        _origGs = ctld.gs
        ctld.gs = function(k)
            if k == "enableFastRopeInsertion" then return true end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=10,
                                       canParachuteDrop=false } }
            end
            if k == "numberOfTroops"        then return 10 end
            if k == "nbLimitSpawnedTroops"  then return { 0, 0 } end
            if k == "maxTransportWeight"    then return 0 end
            if k == "spawnDistanceInCircle" then return 10 end
            if k == "maxExtractDistance"    then return 125 end
            return _origGs(k)
        end

        _origLandHeight = land.getHeight
        land.getHeight = function(_) return 0 end

        playerObj = makePlayerObj("UH-1H-1")

        tm = CTLDTroopManager.getInstance()
        -- Force in-air
        tm._isInAir = function(self, _) return true end

        local zm = CTLDZoneManager.getInstance()
        zm.getTroopZonesForCoalition = function(self, _) return {} end
        zm.isUnitInZone              = function(self, _, _) return nil end
        zm.getWaypointZoneAt         = function(self, _, _) return nil end
        tm._findAllNearbyDropped     = function(self, _, _) return {} end

        _origGetByName = Unit.getByName
        Unit.getByName = function(name)
            if name == "UH-1H-1" then
                return makeUnit("UH-1H-1", 5, 0, 0)
            end
            return _origGetByName and _origGetByName(name) or nil
        end

        local pm = CTLDPlayerManager.getInstance()
        pm:buildMenu(playerObj)
    end)

    after_each(function()
        ctld.gs        = _origGs
        land.getHeight = _origLandHeight
        Unit.getByName = _origGetByName
    end)

    local function getMenu()
        return ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
    end

    -- ── F-152a : en vol, troupes + fast-rope activé → entrée présente ──────────
    it("in flight with troops and enableFastRopeInsertion=true: Disembark entry present", function()
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad") }
        tm:refreshMenuSection(playerObj, true)
        local node = getMenu():_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                          ctld.tr("Disembark Troops") })
        assert.is_not_nil(node)
    end)

    -- ── F-152b : en vol, fast-rope désactivé → entrée absente ──────────────────
    it("in flight with enableFastRopeInsertion=false: Disembark entry absent", function()
        ctld.gs = function(k)
            if k == "enableFastRopeInsertion" then return false end
            if k == "fastRopeMaximumHeight"   then return 18.28 end
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=10,
                                       canParachuteDrop=false } }
            end
            if k == "numberOfTroops"        then return 10 end
            if k == "nbLimitSpawnedTroops"  then return { 0, 0 } end
            if k == "maxTransportWeight"    then return 0 end
            if k == "spawnDistanceInCircle" then return 10 end
            if k == "maxExtractDistance"    then return 125 end
            return _origGs(k)
        end
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad") }
        tm:refreshMenuSection(playerObj, true)
        local node = getMenu():_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                          ctld.tr("Disembark Troops") })
        assert.is_nil(node)
    end)

    -- ── F-152c : en vol, sans troupes → entrée absente ─────────────────────────
    it("in flight without troops: Disembark entry absent", function()
        -- No inTransit
        tm:refreshMenuSection(playerObj, true)
        local node = getMenu():_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                          ctld.tr("Disembark Troops") })
        assert.is_nil(node)
    end)

    -- ── F-152d : multi-groupe en vol → sous-menu Disembark ────────────────────
    it("in flight with two groups: Disembark Troops submenu with Disembark All", function()
        tm._inTransit["UH-1H-1"] = {
            makeTroopGroup("Alpha Squad"),
            makeTroopGroup("Bravo Squad"),
        }
        tm:refreshMenuSection(playerObj, true)
        local node = getMenu():_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                          ctld.tr("Disembark Troops"),
                                          ctld.tr("Disembark All") })
        assert.is_not_nil(node)
    end)

    -- ── F-152e : au sol (comportement inchangé) ────────────────────────────────
    it("on ground with troops: Disembark entry still present (ground path unchanged)", function()
        -- Override _isInAir to false for this test
        tm._isInAir = function(self, _) return false end
        tm._inTransit["UH-1H-1"] = { makeTroopGroup("Alpha Squad") }
        tm:refreshMenuSection(playerObj, false)
        local node = getMenu():_getNode({ ctld.tr("CTLD"), ctld.tr("Troop Commands"),
                                          ctld.tr("Disembark Troops") })
        assert.is_not_nil(node)
    end)

end)
