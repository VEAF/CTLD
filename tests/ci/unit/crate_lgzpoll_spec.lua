---@diagnostic disable
-- tests/ci/unit/crate_lgzpoll_spec.lua
-- busted specs for CTLDCrateManager LGZ ground-position poll guard.
--
-- The poll runs every 10 s and calls refreshRequestEquipmentSection for each
-- ground player whose logistic zone set has changed.  The guard condition must
-- treat _isFlying = nil (never flown = spawned on ground) identically to
-- _isFlying = false (has landed).
--
-- Regression test for FIX-LGZ-POLL-NIL-ISFLYING (ticket 02).
-- ============================================================

describe("CTLDCrateManager LGZ ground-position poll guard", function()

    local lgzPoll            -- captured _lgzGroundPoll function
    local origSchedule       -- saved timer.scheduleFunction
    local origCmInstance     -- saved CTLDCrateManager._instance (restored in after_each)
    local origPmInstance     -- saved CTLDPlayerManager._instance

    -- Minimal unit stub: on the ground, not moving.
    local groundUnit = {
        isExist     = function() return true end,
        inAir       = function() return false end,
        getPoint    = function() return { x = 0, y = 0, z = 0 } end,
        getVelocity = function() return { x = 0, y = 0, z = 0 } end,
    }

    before_each(function()
        -- Save existing singletons so after_each can restore them.
        origCmInstance = CTLDCrateManager._instance
        origPmInstance = CTLDPlayerManager._instance

        -- Override timer.scheduleFunction to capture the LGZ poll.
        -- The hover-status poller is scheduled at getTime()+1 = 1.
        -- The LGZ ground poll is scheduled at getTime()+10 = 10.
        -- (timer.getTime() returns 0 in the stub.)
        lgzPoll     = nil
        origSchedule = timer.scheduleFunction
        timer.scheduleFunction = function(fn, arg, t)
            if t == 10 then lgzPoll = fn end
            return 0
        end

        -- Reset CrateManager so it re-initializes and triggers our override.
        CTLDCrateManager._instance = nil
        CTLDCrateManager.getInstance()

        -- Restore timer stub.
        timer.scheduleFunction = origSchedule

        -- Clear _players so each test starts from a clean state.
        CTLDPlayerManager.getInstance()._players = {}
    end)

    after_each(function()
        -- Restore singletons to avoid cross-test contamination.
        CTLDCrateManager._instance = origCmInstance
        CTLDPlayerManager._instance = origPmInstance
    end)

    -- ── Helpers ──────────────────────────────────────────────────────────────

    -- Build a minimal playerObj with the given _isFlying state.
    local function makePlayer(isFlying)
        return {
            unitName    = "test_unit",
            coalition   = coalition.side.BLUE,
            isTransport = false,  -- skip refreshRequestEquipmentSection body
            groupId     = 99,
            _isFlying   = isFlying,
            _lgzKey     = nil,
        }
    end

    -- Stub Zone manager to return one zone named "log1".
    local function stubOneZone()
        local origFn = CTLDZoneManager.getInstance().getLogisticZonesAtPoint
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint =
            function() return {{ name = "log1" }} end
        return origFn
    end

    -- ── Precondition: poll was actually captured ──────────────────────────────
    it("_lgzGroundPoll is scheduled during CTLDCrateManager init", function()
        assert.is_not_nil(lgzPoll)
    end)

    -- ── nil case: player spawned on ground, never took off ────────────────────
    it("processes a player with _isFlying=nil (spawned on ground, never flown)", function()
        local p = makePlayer(nil)
        CTLDPlayerManager.getInstance()._players["test_unit"] = p

        local origGetByName = Unit.getByName
        Unit.getByName = function(n) if n == "test_unit" then return groundUnit end end
        local origZones = stubOneZone()

        lgzPoll(nil, 0)

        Unit.getByName = origGetByName
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = origZones

        -- _lgzKey was nil; poll should have set it to "log1"
        assert.equals("log1", p._lgzKey)
    end)

    -- ── false case: player has landed (existing behaviour must not regress) ───
    it("processes a player with _isFlying=false (has landed)", function()
        local p = makePlayer(false)
        CTLDPlayerManager.getInstance()._players["test_unit"] = p

        local origGetByName = Unit.getByName
        Unit.getByName = function(n) if n == "test_unit" then return groundUnit end end
        local origZones = stubOneZone()

        lgzPoll(nil, 0)

        Unit.getByName = origGetByName
        CTLDZoneManager.getInstance().getLogisticZonesAtPoint = origZones

        assert.equals("log1", p._lgzKey)
    end)

    -- ── true case: player is in-flight, must be skipped ───────────────────────
    it("skips a player with _isFlying=true (in flight)", function()
        local p = makePlayer(true)
        CTLDPlayerManager.getInstance()._players["test_unit"] = p

        -- No unit or zone stubs needed: the guard must bail before Unit.getByName.
        lgzPoll(nil, 0)

        -- _lgzKey must remain nil
        assert.is_nil(p._lgzKey)
    end)

end)
