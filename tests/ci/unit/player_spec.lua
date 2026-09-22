---@diagnostic disable
-- tests/unit/player_spec.lua
-- busted specs for CTLDPlayer entity and CTLDPlayerManager singleton
-- Reference: live_tests/unit/U-026 through U-029
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayer entity construct + cargo helpers", function()
    -- U-026

    local playerObj

    before_each(function()
        playerObj = CTLDPlayer:new({
            unitName         = "test_unit",
            groupId          = 42,
            groupName        = "test_group",
            coalition        = coalition.side.BLUE,
            typeName         = "UH-1H",
            isTransport      = true,
            canCarryVehicles = false,
        })
    end)

    -- ── Constructor fields ────────────────────────────────────
    describe("constructor", function()

        it("new() returns non-nil", function()
            assert.is_not_nil(playerObj)
        end)

        it("unitName preserved", function()
            assert.equals("test_unit", playerObj.unitName)
        end)

        it("groupId preserved", function()
            assert.equals(42, playerObj.groupId)
        end)

        it("groupName preserved", function()
            assert.equals("test_group", playerObj.groupName)
        end)

        it("coalition preserved", function()
            assert.equals(coalition.side.BLUE, playerObj.coalition)
        end)

        it("typeName preserved", function()
            assert.equals("UH-1H", playerObj.typeName)
        end)

        it("isTransport preserved", function()
            assert.is_true(playerObj.isTransport)
        end)

        it("canCarryVehicles preserved", function()
            assert.is_false(playerObj.canCarryVehicles)
        end)

        it("loadedTroops empty at init", function()
            assert.equals(0, #playerObj.loadedTroops)
        end)

        it("loadedCrates empty at init", function()
            assert.equals(0, #playerObj.loadedCrates)
        end)

        it("loadedVehicles empty at init", function()
            assert.equals(0, #playerObj.loadedVehicles)
        end)

    end)

    -- ── addLoadedVehicle / removeLoadedVehicle ────────────────
    describe("addLoadedVehicle / removeLoadedVehicle", function()

        local veh1, veh2

        before_each(function()
            veh1 = { id = "veh_1" }
            veh2 = { id = "veh_2" }
        end)

        it("loadedVehicles == 1 after adding veh1", function()
            playerObj:addLoadedVehicle(veh1)
            assert.equals(1, #playerObj.loadedVehicles)
        end)

        it("loadedVehicles == 2 after adding veh1 + veh2", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            assert.equals(2, #playerObj.loadedVehicles)
        end)

        it("loadedVehicles == 1 after removing veh1 from {veh1, veh2}", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            playerObj:removeLoadedVehicle(veh1)
            assert.equals(1, #playerObj.loadedVehicles)
        end)

        it("veh2 remains after removing veh1", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            playerObj:removeLoadedVehicle(veh1)
            assert.equals(veh2, playerObj.loadedVehicles[1])
        end)

        it("loadedVehicles == 0 after removing both", function()
            playerObj:addLoadedVehicle(veh1)
            playerObj:addLoadedVehicle(veh2)
            playerObj:removeLoadedVehicle(veh1)
            playerObj:removeLoadedVehicle(veh2)
            assert.equals(0, #playerObj.loadedVehicles)
        end)

        it("removeLoadedVehicle absent object does not throw", function()
            assert.has_no_error(function()
                playerObj:removeLoadedVehicle({ id = "ghost" })
            end)
        end)

        it("loadedVehicles still 0 after remove on empty list", function()
            playerObj:removeLoadedVehicle(veh1)
            assert.equals(0, #playerObj.loadedVehicles)
        end)

    end)

    -- ── addLoadedCrate / removeLoadedCrate ────────────────────
    describe("addLoadedCrate / removeLoadedCrate", function()

        it("loadedCrates == 1 after addLoadedCrate", function()
            playerObj:addLoadedCrate({ id = "crate_A" })
            assert.equals(1, #playerObj.loadedCrates)
        end)

        it("loadedCrates == 0 after add + remove", function()
            local c = { id = "crate_A" }
            playerObj:addLoadedCrate(c)
            playerObj:removeLoadedCrate(c)
            assert.equals(0, #playerObj.loadedCrates)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager singleton + getPlayer nil", function()
    -- U-027

    before_each(function()
        CTLDPlayerManager._instance   = nil
        CTLDDCSEventBridge._instance  = nil
    end)

    it("getInstance() does not throw", function()
        assert.has_no_error(function() CTLDPlayerManager.getInstance() end)
    end)

    it("getInstance() returns non-nil", function()
        assert.is_not_nil(CTLDPlayerManager.getInstance())
    end)

    it("getInstance() is idempotent", function()
        local m1 = CTLDPlayerManager.getInstance()
        local m2 = CTLDPlayerManager.getInstance()
        assert.equals(m1, m2)
    end)

    it("getPlayer('unit_inexistante') == nil", function()
        assert.is_nil(CTLDPlayerManager.getInstance():getPlayer("unit_inexistante"))
    end)

    it("getPlayer('') == nil", function()
        assert.is_nil(CTLDPlayerManager.getInstance():getPlayer(""))
    end)

    it("getPlayer(nil) == nil", function()
        assert.is_nil(CTLDPlayerManager.getInstance():getPlayer(nil))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager _detectCapabilities", function()
    -- U-028

    local mgr

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    local function mockUnit(typeName)
        local u = { _type = typeName }
        function u:getTypeName() return self._type end
        return u
    end

    -- UH-1H: in capabilitiesByType, canTransportWholeVehicle=false (CTLD config)
    it("UH-1H: isTransport == true", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("UH-1H"))
        assert.is_true(isT)
    end)

    it("UH-1H: canCarryVehicles == false (CTLD config)", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("UH-1H"))
        assert.is_false(canV)
    end)

    -- SK-60: in capabilitiesByType, canTransportWholeVehicle=false
    it("SK-60: isTransport == true", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("SK-60"))
        assert.is_true(isT)
    end)

    it("SK-60: canCarryVehicles == false", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("SK-60"))
        assert.is_false(canV)
    end)

    -- Hercules: in capabilitiesByType, canTransportWholeVehicle=true
    it("Hercules: isTransport == true", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("Hercules"))
        assert.is_true(isT)
    end)

    it("Hercules: canCarryVehicles == true", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("Hercules"))
        assert.is_true(canV)
    end)

    -- F-16C_50: not in capabilitiesByType
    it("F-16C_50: isTransport == false", function()
        local isT, _ = mgr:_detectCapabilities(mockUnit("F-16C_50"))
        assert.is_false(isT)
    end)

    it("F-16C_50: canCarryVehicles == false", function()
        local _, canV = mgr:_detectCapabilities(mockUnit("F-16C_50"))
        assert.is_false(canV)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager onPlayerEnterUnit + onPlayerLeaveUnit", function()
    -- U-029

    local mgr

    local mockGroup = {
        _id   = 999,
        _name = "mock_grp_999",
    }
    function mockGroup:getID()   return self._id   end
    function mockGroup:getName() return self._name end

    local mockUnit = {
        _name = "mock_pilot",
        _type = "UH-1H",
        _coa  = coalition.side.BLUE,
    }
    function mockUnit:getName()       return self._name end
    function mockUnit:getTypeName()   return self._type end
    function mockUnit:getCoalition()  return self._coa  end
    function mockUnit:isExist()       return true        end
    function mockUnit:getPlayerName() return "MockPilot" end
    function mockUnit:getGroup()      return mockGroup   end

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    -- ── onPlayerEnterUnit ────────────────────────────────────
    describe("onPlayerEnterUnit()", function()

        before_each(function()
            -- buildMenu may fail silently for fake groupId — pcall to isolate
            pcall(function()
                mgr:onPlayerEnterUnit({ initiator = mockUnit })
            end)
        end)

        it("getPlayer('mock_pilot') is non-nil after enter", function()
            assert.is_not_nil(mgr:getPlayer("mock_pilot"))
        end)

        it("unitName is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals("mock_pilot", p.unitName) end
        end)

        it("typeName is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals("UH-1H", p.typeName) end
        end)

        it("groupId is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals(999, p.groupId) end
        end)

        it("groupName is correct", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals("mock_grp_999", p.groupName) end
        end)

        it("coalition is BLUE", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.equals(coalition.side.BLUE, p.coalition) end
        end)

        it("isTransport == true (UH-1H in capabilitiesByType)", function()
            local p = mgr:getPlayer("mock_pilot")
            if p then assert.is_true(p.isTransport) end
        end)

    end)

    -- ── onPlayerLeaveUnit ────────────────────────────────────
    describe("onPlayerLeaveUnit()", function()

        before_each(function()
            pcall(function()
                mgr:onPlayerEnterUnit({ initiator = mockUnit })
            end)
        end)

        it("does not throw", function()
            assert.has_no_error(function()
                mgr:onPlayerLeaveUnit({ initiator = mockUnit })
            end)
        end)

        it("getPlayer('mock_pilot') == nil after leave", function()
            mgr:onPlayerLeaveUnit({ initiator = mockUnit })
            assert.is_nil(mgr:getPlayer("mock_pilot"))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
-- FIX-MENU-AMBIENT-REFRESH-RACE follow-up: buildMenu must render immediately (urgent), and
-- onPlayerLeaveUnit must not leave a stale pending-refresh entry behind for a reused groupId.
describe("CTLDPlayerManager buildMenu / onPlayerLeaveUnit — ambient/urgent interplay", function()

    local mgr, mmgr
    local addCalls, scheduledCalls, removedIds, nextTimerId

    local mockGroup = { _id = 4242, _name = "mock_grp_4242" }
    function mockGroup:getID()   return self._id   end
    function mockGroup:getName() return self._name end

    local mockUnit = {
        _name = "mock_pilot_4242",
        _type = "UH-1H",
        _coa  = coalition.side.BLUE,
    }
    function mockUnit:getName()       return self._name end
    function mockUnit:getTypeName()   return self._type end
    function mockUnit:getCoalition()  return self._coa  end
    function mockUnit:isExist()       return true        end
    function mockUnit:getPlayerName() return "MockPilot" end
    function mockUnit:getGroup()      return mockGroup   end

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        ctld.MenuManager._instance   = nil
        mgr  = CTLDPlayerManager.getInstance()
        mmgr = ctld.MenuManager:getInstance()

        addCalls       = {}
        scheduledCalls = {}
        removedIds     = {}
        nextTimerId    = 0

        missionCommands.addSubMenuForGroup = function(gid, name, _path)
            table.insert(addCalls, { gid = gid, name = name })
            return "h" .. (#addCalls)
        end
        missionCommands.addCommandForGroup = function(gid, name)
            table.insert(addCalls, { gid = gid, name = name })
        end
        missionCommands.removeItemForGroup = function() end
        timer.scheduleFunction = function(fn, _arg, t)
            nextTimerId = nextTimerId + 1
            table.insert(scheduledCalls, { fn = fn, id = nextTimerId, t = t })
            return nextTimerId
        end
        timer.removeFunction = function(id) table.insert(removedIds, id) end
        timer.getTime = function() return 0 end
    end)

    after_each(function()
        missionCommands.addSubMenuForGroup = function() end
        missionCommands.addCommandForGroup = function() end
        missionCommands.removeItemForGroup = function() end
        timer.scheduleFunction = function(fn, arg, t) return 0 end
        timer.removeFunction = function(id) end
        timer.getTime = function() return 0 end
    end)

    it("a freshly-joined player's menu renders immediately, not after AMBIENT_REBUILD_DELAY_S", function()
        mgr:onPlayerEnterUnit({ initiator = mockUnit })

        -- buildMenu's own trailing refresh must have gone through the urgent (debounced) path:
        -- scheduled at DEBOUNCE_S (0.15), not AMBIENT_REBUILD_DELAY_S (4) — and, since the
        -- flow is urgent, the same debounce timer that's already captured is the one that
        -- actually renders once advanced.
        assert.is_true(#scheduledCalls >= 1)
        assert.equals(0.15, scheduledCalls[#scheduledCalls].t)

        local addBefore = #addCalls
        scheduledCalls[#scheduledCalls].fn()
        assert.is_true(#addCalls > addBefore)   -- the CTLD root menu actually got rendered
    end)

    it("onTakeoff's refresh chain is urgent, not delayed 4s (regression anchor for the runUrgent wrap)", function()
        mgr:onPlayerEnterUnit({ initiator = mockUnit })
        scheduledCalls[#scheduledCalls].fn()   -- settle the initial urgent build first
        local scheduledBefore = #scheduledCalls

        mgr:onTakeoff({ initiator = mockUnit })

        -- At least one new refresh must have been scheduled, and none of the NEW ones may be
        -- the 4s ambient delay — reverting onTakeoff's runUrgent wrap would make this fail.
        assert.is_true(#scheduledCalls > scheduledBefore)
        for i = scheduledBefore + 1, #scheduledCalls do
            assert.not_equal(4, scheduledCalls[i].t)
        end
    end)

    it("onPlayerLeaveUnit cancels any pending refresh for the departing group", function()
        mgr:onPlayerEnterUnit({ initiator = mockUnit })
        -- Advance the urgent debounce so the menu is fully built before it's torn down.
        scheduledCalls[#scheduledCalls].fn()

        -- Simulate an ambient refresh left pending for this group at the moment the player leaves.
        mmgr:deferredRefreshForGroup(mockGroup._id)
        assert.is_not_nil(mmgr._pendingAmbient[mockGroup._id])

        mgr:onPlayerLeaveUnit({ initiator = mockUnit })

        assert.is_nil(mmgr._pendingAmbient[mockGroup._id])
        assert.is_nil(mmgr._pendingRefresh[mockGroup._id])
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager onPlayerLeaveUnit multi-crew group-aware", function()
    -- U-030

    local mgr
    local removeCalls

    -- Build a minimal mock unit for a given unitName and groupId.
    local function makeMockUnit(unitName, groupId)
        local grp = { _id = groupId, _name = "grp_" .. groupId }
        function grp:getID()   return self._id   end
        function grp:getName() return self._name end

        local u = { _name = unitName, _type = "CH-47D", _coa = coalition.side.BLUE }
        function u:getName()       return self._name end
        function u:getTypeName()   return self._type end
        function u:getCoalition()  return self._coa  end
        function u:isExist()       return true        end
        function u:getPlayerName() return self._name end
        function u:getGroup()      return grp         end
        return u
    end

    -- Inject a CTLDPlayer directly into _players, bypassing buildMenu.
    local function injectPlayer(m, unitName, groupId)
        m._players[unitName] = CTLDPlayer:new({
            unitName         = unitName,
            groupId          = groupId,
            groupName        = "grp_" .. groupId,
            coalition        = coalition.side.BLUE,
            typeName         = "CH-47D",
            isTransport      = true,
            canCarryVehicles = true,
        })
    end

    -- Inject a ctld.Menu with a fake _activeHandles entry for groupId.
    local function injectMenu(groupId, handle)
        ctld.MenuManager._instance = nil
        local mm   = ctld.MenuManager:getInstance()
        local menu = mm:createMenuForGroup(groupId)
        menu._activeHandles = { handle }
        return mm
    end

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
        removeCalls = {}
        missionCommands.removeItemForGroup = function(gid, h)
            table.insert(removeCalls, { gid = gid, handle = h })
        end
    end)

    after_each(function()
        missionCommands.removeItemForGroup = function() end
        ctld.MenuManager._instance = nil
    end)

    it("last player leaves: removeItemForGroup called with active handle", function()
        local gid = 7001
        injectPlayer(mgr, "pilot_A", gid)
        injectMenu(gid, "handle_A")

        local unitA = makeMockUnit("pilot_A", gid)
        mgr:onPlayerLeaveUnit({ initiator = unitA })

        assert.equals(1, #removeCalls)
        assert.equals("handle_A", removeCalls[1].handle)
    end)

    it("last player leaves: mmgr.menus[groupId] set to nil", function()
        local gid = 7002
        injectPlayer(mgr, "pilot_A", gid)
        local mm = injectMenu(gid, "handle_A")

        local unitA = makeMockUnit("pilot_A", gid)
        mgr:onPlayerLeaveUnit({ initiator = unitA })

        assert.is_nil(mm.menus[gid])
    end)

    it("non-last player leaves: removeItemForGroup NOT called", function()
        local gid = 7003
        injectPlayer(mgr, "pilot_A",   gid)
        injectPlayer(mgr, "copilot_B", gid)
        injectMenu(gid, "handle_AB")

        local unitA = makeMockUnit("pilot_A", gid)
        mgr:onPlayerLeaveUnit({ initiator = unitA })

        assert.equals(0, #removeCalls)
    end)

    it("non-last player leaves: mmgr.menus[groupId] preserved", function()
        local gid = 7004
        injectPlayer(mgr, "pilot_A",   gid)
        injectPlayer(mgr, "copilot_B", gid)
        local mm = injectMenu(gid, "handle_AB")

        local unitA = makeMockUnit("pilot_A", gid)
        mgr:onPlayerLeaveUnit({ initiator = unitA })

        assert.is_not_nil(mm.menus[gid])
    end)

    it("non-last leave: departing player removed from _players", function()
        local gid = 7005
        injectPlayer(mgr, "pilot_A",   gid)
        injectPlayer(mgr, "copilot_B", gid)
        injectMenu(gid, "handle_AB")

        local unitA = makeMockUnit("pilot_A", gid)
        mgr:onPlayerLeaveUnit({ initiator = unitA })

        assert.is_nil(mgr:getPlayer("pilot_A"))
        assert.is_not_nil(mgr:getPlayer("copilot_B"))
    end)

    it("after non-last leave, last player leaves: full cleanup fires", function()
        local gid = 7006
        injectPlayer(mgr, "pilot_A",   gid)
        injectPlayer(mgr, "copilot_B", gid)
        local mm = injectMenu(gid, "handle_AB")

        mgr:onPlayerLeaveUnit({ initiator = makeMockUnit("pilot_A",   gid) })
        mgr:onPlayerLeaveUnit({ initiator = makeMockUnit("copilot_B", gid) })

        assert.equals(1, #removeCalls)
        assert.equals("handle_AB", removeCalls[1].handle)
        assert.is_nil(mm.menus[gid])
        assert.is_nil(mgr:getPlayer("pilot_A"))
        assert.is_nil(mgr:getPlayer("copilot_B"))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager _scanExistingPlayers evicts departed players", function()
    -- FIX-PLAYER-EVENT-GUARDS ticket 02.
    --
    -- When DCS delivers S_EVENT_PLAYER_LEAVE_UNIT with an already-released initiator, the
    -- handler cannot read the unit name and the player is never forgotten: the F10 menu is
    -- never torn down and cancelPending (the #147 fix against a recycled groupId) never runs.
    -- The 30 s sweep is the backstop that closes that hole.

    local mgr
    local removeCalls
    local savedGetByName

    local function injectPlayer(m, unitName, groupId)
        m._players[unitName] = CTLDPlayer:new({
            unitName         = unitName,
            groupId          = groupId,
            groupName        = "grp_" .. groupId,
            coalition        = coalition.side.BLUE,
            typeName         = "CH-47D",
            isTransport      = true,
            canCarryVehicles = true,
        })
    end

    local function injectMenu(groupId, handle)
        ctld.MenuManager._instance = nil
        local mm   = ctld.MenuManager:getInstance()
        local menu = mm:createMenuForGroup(groupId)
        menu._activeHandles = { handle }
        return mm
    end

    -- Unit.getByName answers from this table: name -> { exists, player }.
    local function slotsAre(slots)
        Unit.getByName = function(name)
            local s = slots[name]
            if not s then return nil end
            local u = { _name = name }
            function u:getName()       return self._name end
            function u:isExist()       return s.exists   end
            function u:getPlayerName() return s.player    end
            return u
        end
    end

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
        removeCalls = {}
        missionCommands.removeItemForGroup = function(gid, h)
            table.insert(removeCalls, { gid = gid, handle = h })
        end
        savedGetByName = Unit.getByName
    end)

    after_each(function()
        missionCommands.removeItemForGroup = function() end
        ctld.MenuManager._instance = nil
        Unit.getByName = savedGetByName
    end)

    it("evicts a player whose unit no longer exists", function()
        injectPlayer(mgr, "pilot_A", 8001)
        slotsAre({})   -- Unit.getByName returns nil

        mgr:_scanExistingPlayers()

        assert.is_nil(mgr:getPlayer("pilot_A"))
    end)

    it("evicts a player whose unit exists but is dead", function()
        injectPlayer(mgr, "pilot_A", 8002)
        slotsAre({ pilot_A = { exists = false, player = "Someone" } })

        mgr:_scanExistingPlayers()

        assert.is_nil(mgr:getPlayer("pilot_A"))
    end)

    it("evicts a player whose slot no longer carries a player name", function()
        injectPlayer(mgr, "pilot_A", 8003)
        slotsAre({ pilot_A = { exists = true, player = nil } })

        mgr:_scanExistingPlayers()

        assert.is_nil(mgr:getPlayer("pilot_A"))
    end)

    it("does NOT evict a player still flying", function()
        injectPlayer(mgr, "pilot_A", 8004)
        slotsAre({ pilot_A = { exists = true, player = "Zip" } })

        mgr:_scanExistingPlayers()

        assert.is_not_nil(mgr:getPlayer("pilot_A"))
    end)

    it("tears the group menu down when evicting the last player", function()
        injectPlayer(mgr, "pilot_A", 8005)
        local mm = injectMenu(8005, "handle_A")
        slotsAre({})

        mgr:_scanExistingPlayers()

        assert.equals(1, #removeCalls)
        assert.equals("handle_A", removeCalls[1].handle)
        assert.is_nil(mm.menus[8005])
    end)

    it("cancels a pending rebuild when evicting the last player", function()
        injectPlayer(mgr, "pilot_A", 8006)
        local mm = injectMenu(8006, "handle_A")
        -- Same shape the manager itself stores (FIX-CANCELPENDING-URGENT-TIMER): a bare
        -- `true` was a shortcut mirroring the old implementation, and it stopped being
        -- what cancelPending reads.
        mm._pendingRefresh[8006] = { timerId = 4242 }
        slotsAre({})

        mgr:_scanExistingPlayers()

        assert.is_nil(mm._pendingRefresh[8006])
    end)

    it("multi-crew: evicting both crew members tears the menu down exactly once", function()
        injectPlayer(mgr, "pilot_A",   8007)
        injectPlayer(mgr, "copilot_B", 8007)
        local mm = injectMenu(8007, "handle_AB")
        slotsAre({})

        mgr:_scanExistingPlayers()

        assert.is_nil(mgr:getPlayer("pilot_A"))
        assert.is_nil(mgr:getPlayer("copilot_B"))
        assert.equals(1, #removeCalls)
        assert.is_nil(mm.menus[8007])
    end)

    it("multi-crew: one crew member left flying keeps the menu", function()
        injectPlayer(mgr, "pilot_A",   8008)
        injectPlayer(mgr, "copilot_B", 8008)
        local mm = injectMenu(8008, "handle_AB")
        slotsAre({ copilot_B = { exists = true, player = "Zip" } })

        mgr:_scanExistingPlayers()

        assert.is_nil(mgr:getPlayer("pilot_A"))
        assert.is_not_nil(mgr:getPlayer("copilot_B"))
        assert.equals(0, #removeCalls)
        assert.is_not_nil(mm.menus[8008])
    end)

    it("closes the loop: a released-initiator leave is repaired by the next sweep", function()
        injectPlayer(mgr, "pilot_A", 8009)
        local mm = injectMenu(8009, "handle_A")

        -- The event as DCS delivered it on 2026-09-17: initiator present, methods gone.
        mgr:onPlayerLeaveUnit({ initiator = {} })
        assert.is_not_nil(mgr:getPlayer("pilot_A"))   -- nothing the handler can do

        slotsAre({})
        mgr:_scanExistingPlayers()

        assert.is_nil(mgr:getPlayer("pilot_A"))
        assert.equals(1, #removeCalls)
        assert.is_nil(mm.menus[8009])
    end)

    it("survives Unit.getByName raising, and still reschedules itself", function()
        injectPlayer(mgr, "pilot_A", 8010)
        Unit.getByName = function() error("DCS is busy releasing this unit") end

        local scheduled = 0
        local savedSchedule = timer.scheduleFunction
        timer.scheduleFunction = function(fn, arg, t)
            scheduled = scheduled + 1
            return 0
        end

        local ok = pcall(function() mgr:_scanExistingPlayers() end)

        timer.scheduleFunction = savedSchedule

        assert.is_true(ok)
        assert.equals(1, scheduled)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDPlayerManager _scanExistingPlayers outlives its own failures", function()
    -- The sweep is the backstop for damaged PLAYER_LEAVE_UNIT events. A pass that raises
    -- must not take the 30 s reschedule with it: a sweep that silently stops is
    -- indistinguishable from a sweep that finds nothing.

    local mgr
    local savedGetPlayers

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
        savedGetPlayers = coalition.getPlayers
    end)

    after_each(function()
        coalition.getPlayers = savedGetPlayers
        ctld.MenuManager._instance = nil
    end)

    it("a unit being released during the add pass does not cancel the eviction pass", function()
        -- Sourcery's finding on PR #151: one bad unit in coalition.getPlayers() used to abort
        -- the whole pass, so the reverse eviction never ran that sweep and stale entries
        -- survived. Per-unit protection, not per-pass.
        local mgr2 = CTLDPlayerManager.getInstance()
        mgr2._players["stale_pilot"] = CTLDPlayer:new({
            unitName = "stale_pilot",
            groupId  = 8200,
            typeName = "UH-1H",
        })

        local rotting = {}
        function rotting:isExist() error("object no longer exists") end
        coalition.getPlayers = function(side)
            if side == coalition.side.RED then return { rotting } end
            return {}
        end

        local savedGetByName = Unit.getByName
        Unit.getByName = function() return nil end   -- the tracked slot is gone

        mgr2:_scanExistingPlayers()

        Unit.getByName = savedGetByName

        assert.is_nil(mgr2:getPlayer("stale_pilot"))
    end)

    it("reschedules itself even when the add pass raises", function()
        coalition.getPlayers = function() error("DCS is mid-slot-change") end

        local scheduled = 0
        local savedSchedule = timer.scheduleFunction
        timer.scheduleFunction = function() scheduled = scheduled + 1; return 0 end

        local ok = pcall(function() mgr:_scanExistingPlayers() end)

        timer.scheduleFunction = savedSchedule

        assert.is_true(ok)
        assert.equals(1, scheduled)
    end)

end)
