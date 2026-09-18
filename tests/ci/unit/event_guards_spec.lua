---@diagnostic disable
-- tests/ci/unit/event_guards_spec.lua
-- busted specs for handlers receiving a DCS object the engine has already released.
--
-- DCS hands `event.initiator` to a handler after releasing the underlying unit: the table
-- is non-nil but its method table is gone, so `unit:getName()` raises
-- "attempt to call method 'getName' (a nil value)". Observed in a live multiplayer session
-- (2026-09-17) on S_EVENT_PLAYER_LEAVE_UNIT, 1 ms after DCS logged `release unit`.
--
-- The seven cases below are enumerated from CTLDDCSEventBridge's registration list, not
-- sampled: they are every handler that reads a method off `event.initiator` without a
-- pcall or an `obj.method and` check.
-- ============================================================

describe("event handlers tolerate a released initiator", function()

    -- A released DCS object: present, but carrying no methods at all.
    local function releasedObject()
        return {}
    end

    -- An object whose method table is there but raises, the other shape DCS produces.
    local function raisingObject()
        local o = {}
        function o:getName()       return "ghost_unit" end
        function o:isExist()       error("object no longer exists") end
        function o:getPlayerName() error("object no longer exists") end
        function o:getGroup()      error("object no longer exists") end
        function o:getCoalition()  error("object no longer exists") end
        function o:getTypeName()   error("object no longer exists") end
        return o
    end

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        CTLDZoneManager._instance    = nil
        CTLDFOBManager._instance     = nil
    end)

    after_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        CTLDZoneManager._instance    = nil
        CTLDFOBManager._instance     = nil
    end)

    -- ── CTLDPlayerManager ────────────────────────────────────

    it("CTLDPlayerManager:onPlayerLeaveUnit does not raise", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onPlayerLeaveUnit({ initiator = releasedObject() })
        end)
    end)

    -- The other shape, and the one the first fix missed: an object that still answers
    -- getName() and raises on every other method. Measured on 2026-09-17: with only the
    -- name guarded, onPlayerEnterUnit and onAILand still raised here.
    it("CTLDPlayerManager:onPlayerLeaveUnit does not raise on a raising initiator", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onPlayerLeaveUnit({ initiator = raisingObject() })
        end)
    end)

    it("CTLDPlayerManager:onPlayerEnterUnit does not raise on a raising initiator", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onPlayerEnterUnit({ initiator = raisingObject() })
        end)
    end)

    it("CTLDPlayerManager:onLand does not raise on a raising initiator", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onLand({ initiator = raisingObject() })
        end)
    end)

    it("CTLDPlayerManager:onTakeoff does not raise on a raising initiator", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onTakeoff({ initiator = raisingObject() })
        end)
    end)

    it("CTLDZoneManager:onDead does not raise on a raising initiator", function()
        local zm = CTLDZoneManager.getInstance()
        assert.has_no_error(function()
            zm:onDead({ initiator = raisingObject() })
        end)
    end)

    it("CTLDFOBManager:onDead does not raise on a raising initiator", function()
        local fm = CTLDFOBManager.getInstance()
        assert.has_no_error(function()
            fm:onDead({ initiator = raisingObject() })
        end)
    end)

    it("CTLDCoreManager:onAILand does not raise on a raising initiator", function()
        -- _aiPilotNames must contain the name, or the handler returns before the reads
        -- this case is about.
        local receiver = { _aiPilotNames = { ghost_unit = true }, _aiTransportVehicle = {} }
        assert.has_no_error(function()
            CTLDCoreManager.onAILand(receiver, { initiator = raisingObject() })
        end)
    end)

    it("CTLDPlayerManager:onPlayerEnterUnit does not raise", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onPlayerEnterUnit({ initiator = releasedObject() })
        end)
    end)

    it("CTLDPlayerManager:onLand does not raise", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onLand({ initiator = releasedObject() })
        end)
    end)

    it("CTLDPlayerManager:onTakeoff does not raise", function()
        local mgr = CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            mgr:onTakeoff({ initiator = releasedObject() })
        end)
    end)

    -- ── CTLDZoneManager ──────────────────────────────────────

    it("CTLDZoneManager:onDead does not raise", function()
        local zm = CTLDZoneManager.getInstance()
        assert.has_no_error(function()
            zm:onDead({ initiator = releasedObject() })
        end)
    end)

    -- ── CTLDFOBManager ───────────────────────────────────────

    it("CTLDFOBManager:onDead does not raise", function()
        local fm = CTLDFOBManager.getInstance()
        assert.has_no_error(function()
            fm:onDead({ initiator = releasedObject() })
        end)
    end)

    -- ── CTLDCoreManager ──────────────────────────────────────
    -- Called against a minimal receiver rather than the singleton: CTLDCoreManager:init()
    -- runs the mission-maker crate/JTAC/vehicle scans, none of which this guard concerns.

    it("CTLDCoreManager:onAILand does not raise", function()
        local receiver = { _aiPilotNames = {}, _aiTransportVehicle = {} }
        assert.has_no_error(function()
            CTLDCoreManager.onAILand(receiver, { initiator = releasedObject() })
        end)
    end)

    -- ── Negative controls ────────────────────────────────────
    -- A guard that swallows everything would pass all of the above. These prove the
    -- handlers still act on a healthy object.

    it("onPlayerLeaveUnit still forgets a tracked player on a healthy event", function()
        local mgr = CTLDPlayerManager.getInstance()
        mgr._players["healthy_unit"] = CTLDPlayer:new({
            unitName = "healthy_unit",
            groupId  = 9100,
            typeName = "UH-1H",
        })

        local unit = { _name = "healthy_unit" }
        function unit:getName() return self._name end

        mgr:onPlayerLeaveUnit({ initiator = unit })

        assert.is_nil(mgr:getPlayer("healthy_unit"))
    end)

    it("onPlayerLeaveUnit leaves an untracked healthy unit alone", function()
        local mgr = CTLDPlayerManager.getInstance()
        mgr._players["other_unit"] = CTLDPlayer:new({
            unitName = "other_unit",
            groupId  = 9101,
            typeName = "UH-1H",
        })

        local unit = { _name = "unknown_unit" }
        function unit:getName() return self._name end

        mgr:onPlayerLeaveUnit({ initiator = unit })

        assert.is_not_nil(mgr:getPlayer("other_unit"))
    end)

end)

describe("ctld.utils.safeObjectName", function()

    it("returns nil for a nil object", function()
        assert.is_nil(ctld.utils.safeObjectName(nil))
    end)

    it("returns nil for an object with no methods (released by DCS)", function()
        assert.is_nil(ctld.utils.safeObjectName({}))
    end)

    it("returns nil when getName raises", function()
        local o = {}
        function o:getName() error("object no longer exists") end
        assert.is_nil(ctld.utils.safeObjectName(o))
    end)

    it("returns nil when getName returns nil", function()
        local o = {}
        function o:getName() return nil end
        assert.is_nil(ctld.utils.safeObjectName(o))
    end)

    it("returns nil when getName returns an empty string", function()
        local o = {}
        function o:getName() return "" end
        assert.is_nil(ctld.utils.safeObjectName(o))
    end)

    it("returns nil when getName returns a non-string", function()
        local o = {}
        function o:getName() return 42 end
        assert.is_nil(ctld.utils.safeObjectName(o))
    end)

    it("returns the name for a healthy object", function()
        local o = { _name = "Pilot #001" }
        function o:getName() return self._name end
        assert.equals("Pilot #001", ctld.utils.safeObjectName(o))
    end)

end)
