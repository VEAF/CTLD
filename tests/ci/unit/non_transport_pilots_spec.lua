---@diagnostic disable
-- tests/ci/unit/non_transport_pilots_spec.lua
-- busted specs for FEAT-NON-TRANSPORT-PILOTS.
--
-- With addPlayerAircraftByType = false, onPlayerEnterUnit used to return *before registering
-- the player* for any unit name absent from transportPilotNames. A setting meant to restrict
-- transport menus to a named list therefore cut every function that has nothing to do with
-- transport — recon above all, which any pilot is supposed to be able to use (#150).
--
-- The whitelist now decides isTransport instead of registration.
-- ============================================================

describe("transportPilotNames decides isTransport, not registration", function()

    local mgr
    local _changed

    local function setCfg(k, v)
        if _changed[k] == nil then
            _changed[k] = { orig = CTLDConfig.get().settings[k] }
        end
        CTLDConfig.get().settings[k] = v
    end

    -- A player unit of the given name and type.
    local function makeUnit(unitName, typeName)
        local grp = { _id = 9500, _name = "grp_" .. unitName }
        function grp:getID()   return self._id   end
        function grp:getName() return self._name end

        local u = { _name = unitName, _type = typeName }
        function u:getName()       return self._name end
        function u:getTypeName()   return self._type end
        function u:getCoalition()  return coalition.side.BLUE end
        function u:isExist()       return true end
        function u:getPlayerName() return "tester" end
        function u:getGroup()      return grp end
        return u
    end

    local function enter(unitName, typeName)
        mgr:onPlayerEnterUnit({ initiator = makeUnit(unitName, typeName) })
        return mgr:getPlayer(unitName)
    end

    before_each(function()
        _changed = {}
        ctld.MenuManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    after_each(function()
        for k, box in pairs(_changed) do
            CTLDConfig.get().settings[k] = box.orig
        end
        _changed = {}
        ctld.MenuManager._instance = nil
    end)

    describe("addPlayerAircraftByType = false", function()

        before_each(function()
            setCfg("addPlayerAircraftByType", false)
            setCfg("transportPilotNames", { "transport_slot_1" })
        end)

        it("a pilot off the list is registered", function()
            assert.is_not_nil(enter("Viper_1", "F-16C bl.52d"))
        end)

        it("a pilot off the list is not a transport", function()
            local p = enter("Viper_1", "F-16C bl.52d")
            assert.is_false(p.isTransport)
        end)

        it("a pilot off the list cannot carry vehicles", function()
            local p = enter("Viper_1", "F-16C bl.52d")
            assert.is_false(p.canCarryVehicles)
        end)

        -- The case that would silently defeat the whole setting: a transport TYPE whose unit
        -- name is not on the list. _detectCapabilities answers true for it, so without the
        -- override he would recover every transport menu and the whitelist would mean nothing.
        it("a TRANSPORT type off the list is still not a transport", function()
            local p = enter("Huey_99", "UH-1H")
            assert.is_not_nil(p)
            assert.is_false(p.isTransport)
        end)

        it("a transport type off the list cannot carry vehicles either", function()
            local p = enter("Herc_99", "Hercules")
            assert.is_false(p.canCarryVehicles)
        end)

        it("a pilot ON the list keeps the capabilities of his type", function()
            local p = enter("transport_slot_1", "UH-1H")
            assert.is_not_nil(p)
            assert.is_true(p.isTransport)
        end)
    end)

    -- Negative control: the default path must come out untouched. Without it, a fix that
    -- simply forced isTransport = false everywhere would pass every assertion above.
    describe("addPlayerAircraftByType = true (default) is unchanged", function()

        before_each(function()
            setCfg("addPlayerAircraftByType", true)
            setCfg("transportPilotNames", { "transport_slot_1" })
        end)

        it("a transport type not on the list is still a transport", function()
            local p = enter("Huey_99", "UH-1H")
            assert.is_not_nil(p)
            assert.is_true(p.isTransport)
        end)

        it("a fighter is registered and is not a transport", function()
            local p = enter("Viper_1", "F-16C bl.52d")
            assert.is_not_nil(p)
            assert.is_false(p.isTransport)
        end)
    end)

end)

describe("CTLDPlayerManager S_EVENT_BIRTH safety net", function()

    local mgr

    local function makeUnit(unitName, playerName)
        local grp = { _id = 9600, _name = "grp_" .. unitName }
        function grp:getID()   return self._id   end
        function grp:getName() return self._name end

        local u = { _name = unitName, _player = playerName }
        function u:getName()       return self._name end
        function u:getTypeName()   return "UH-1H" end
        function u:getCoalition()  return coalition.side.BLUE end
        function u:isExist()       return true end
        function u:getPlayerName() return self._player end
        function u:getGroup()      return grp end
        return u
    end

    before_each(function()
        ctld.MenuManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    after_each(function()
        ctld.MenuManager._instance = nil
    end)

    it("registers a player CTLD does not know yet", function()
        mgr:onBirth({ initiator = makeUnit("late_joiner", "tester") })
        assert.is_not_nil(mgr:getPlayer("late_joiner"))
    end)

    it("ignores an AI unit", function()
        mgr:onBirth({ initiator = makeUnit("ai_truck", nil) })
        assert.is_nil(mgr:getPlayer("ai_truck"))
    end)

    it("leaves an already-tracked player alone", function()
        mgr:onPlayerEnterUnit({ initiator = makeUnit("known", "tester") })
        local before = mgr:getPlayer("known")
        mgr:onBirth({ initiator = makeUnit("known", "tester") })
        assert.equals(before, mgr:getPlayer("known"))
    end)

    it("does not raise on an initiator with no methods", function()
        assert.has_no_error(function() mgr:onBirth({ initiator = {} }) end)
    end)

    it("does not raise on an initiator whose methods raise", function()
        local o = {}
        function o:getName()       return "ghost" end
        function o:getPlayerName() error("object no longer exists") end
        function o:isExist()       error("object no longer exists") end
        assert.has_no_error(function() mgr:onBirth({ initiator = o }) end)
    end)

    it("is subscribed to S_EVENT_BIRTH on the bridge", function()
        -- Asserting the wiring, not just the handler: a handler nobody calls is the exact
        -- defect CTLDPlayerTracker died of.
        local bridge   = CTLDDCSEventBridge.getInstance()
        local handlers = bridge._handlers[world.event.S_EVENT_BIRTH] or {}
        local found    = false
        for _, entry in ipairs(handlers) do
            if entry.target == mgr and entry.method == "onBirth" then found = true end
        end
        assert.is_true(found)
    end)

end)

describe("onPlayerEnterUnit is idempotent", function()
    -- It is now reachable three ways: the DCS event, the BIRTH net and the 30 s scan. DCS
    -- fires BIRTH and PLAYER_ENTER_UNIT for the same slot entry, so without this the menu is
    -- wiped and rebuilt twice in a row under a player who may already have it open — the
    -- misfire #147 was about.

    local mgr

    local function makeUnit(unitName)
        local grp = { _id = 9700, _name = "grp_" .. unitName }
        function grp:getID()   return self._id   end
        function grp:getName() return self._name end
        local u = { _name = unitName }
        function u:getName()       return self._name end
        function u:getTypeName()   return "UH-1H" end
        function u:getCoalition()  return coalition.side.BLUE end
        function u:isExist()       return true end
        function u:getPlayerName() return "tester" end
        function u:getGroup()      return grp end
        return u
    end

    before_each(function()
        ctld.MenuManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        mgr = CTLDPlayerManager.getInstance()
    end)

    after_each(function() ctld.MenuManager._instance = nil end)

    it("a second ENTER for a tracked player does not rebuild the menu", function()
        local builds = 0
        local orig = CTLDPlayerManager.buildMenu
        CTLDPlayerManager.buildMenu = function(self, p) builds = builds + 1; return orig(self, p) end

        mgr:onPlayerEnterUnit({ initiator = makeUnit("Huey_1") })
        mgr:onPlayerEnterUnit({ initiator = makeUnit("Huey_1") })

        CTLDPlayerManager.buildMenu = orig
        assert.equals(1, builds)
    end)

    it("BIRTH then ENTER for the same slot builds exactly one menu", function()
        local builds = 0
        local orig = CTLDPlayerManager.buildMenu
        CTLDPlayerManager.buildMenu = function(self, p) builds = builds + 1; return orig(self, p) end

        mgr:onBirth({ initiator = makeUnit("Huey_2") })
        mgr:onPlayerEnterUnit({ initiator = makeUnit("Huey_2") })

        CTLDPlayerManager.buildMenu = orig
        assert.equals(1, builds)
    end)
end)

describe("a whitelisted mission end to end", function()
    -- The two halves of the lot meet here: the gate sets isTransport, and the menu is built
    -- from it. Asserting each half separately would not prove they are wired together.

    local mgr, _changed

    local function setCfg(k, v)
        if _changed[k] == nil then _changed[k] = { orig = CTLDConfig.get().settings[k] } end
        CTLDConfig.get().settings[k] = v
    end

    local function makeUnit(unitName, typeName)
        local grp = { _id = 9800, _name = "grp_" .. unitName }
        function grp:getID()   return self._id   end
        function grp:getName() return self._name end
        local u = { _name = unitName, _type = typeName }
        function u:getName()       return self._name end
        function u:getTypeName()   return self._type end
        function u:getCoalition()  return coalition.side.BLUE end
        function u:isExist()       return true end
        function u:getPlayerName() return "tester" end
        function u:getGroup()      return grp end
        function u:getPoint()      return { x = 0, y = 0, z = 0 } end
        return u
    end

    before_each(function()
        _changed = {}
        ctld.MenuManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        CTLDReconManager._instance   = nil
        mgr = CTLDPlayerManager.getInstance()
        CTLDReconManager.getInstance()   -- registers the recon section
        setCfg("addPlayerAircraftByType", false)
        setCfg("transportPilotNames", { "transport_slot_1" })
    end)

    after_each(function()
        for k, box in pairs(_changed) do CTLDConfig.get().settings[k] = box.orig end
        _changed = {}
        ctld.MenuManager._instance = nil
        CTLDReconManager._instance = nil
    end)

    it("a Huey pilot off the list gets RECON and no Check Cargo", function()
        local orig = Unit.getByName
        Unit.getByName = function(n) return makeUnit(n, "UH-1H") end
        mgr:onPlayerEnterUnit({ initiator = makeUnit("Huey_99", "UH-1H") })
        Unit.getByName = orig

        local menu = ctld.MenuManager:getInstance():getMenuByGroupId(9800)
        assert.is_not_nil(menu)
        assert.is_not_nil(menu:_getNode({ ctld.tr("CTLD"), ctld.tr("RECON") }))
        assert.is_nil(menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Check Cargo") }))
    end)
end)

describe("CTLDPlayerTracker is gone", function()
    it("the global no longer exists", function()
        assert.is_nil(rawget(_G, "CTLDPlayerTracker"))
    end)
end)
