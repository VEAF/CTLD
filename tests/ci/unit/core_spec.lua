---@diagnostic disable
-- tests/unit/core_spec.lua
-- busted specs for CTLDDCSEventBridge (singleton, register, route) and
-- Reference: live_tests/unit/U-005 through U-007
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDDCSEventBridge", function()
    -- U-005

    before_each(function()
        CTLDDCSEventBridge._instance = nil
    end)

    -- ── Singleton ────────────────────────────────────────────
    describe("singleton", function()

        it("getInstance() returns a non-nil instance", function()
            assert.is_not_nil(CTLDDCSEventBridge.getInstance())
        end)

        it("getInstance() is idempotent", function()
            local a = CTLDDCSEventBridge.getInstance()
            local b = CTLDDCSEventBridge.getInstance()
            assert.equals(a, b)
        end)

        it("_handlers is a table", function()
            assert.equals("table", type(CTLDDCSEventBridge.getInstance()._handlers))
        end)

    end)

    -- ── register ─────────────────────────────────────────────
    describe("register()", function()

        local bridge, fakeEventId

        before_each(function()
            bridge      = CTLDDCSEventBridge.getInstance()
            fakeEventId = 9999
        end)

        it("creates a handler list for the event id", function()
            local mgr = { onFake = function() end }
            bridge:register(mgr, fakeEventId, "onFake")
            assert.is_not_nil(bridge._handlers[fakeEventId])
        end)

        it("exactly 1 handler registered after one register()", function()
            local mgr = { onFake = function() end }
            bridge:register(mgr, fakeEventId, "onFake")
            assert.equals(1, #bridge._handlers[fakeEventId])
        end)

    end)

    -- ── onEvent routing ──────────────────────────────────────
    describe("onEvent()", function()

        local bridge, fakeEventId, received

        before_each(function()
            bridge      = CTLDDCSEventBridge.getInstance()
            fakeEventId = 9999
            received    = nil
            local mgr = {
                onFake = function(self, event) received = event end,
            }
            bridge:register(mgr, fakeEventId, "onFake")
        end)

        it("dispatches event to registered handler", function()
            bridge:onEvent({ id = fakeEventId })
            assert.is_not_nil(received)
        end)

        it("event.id is passed to handler", function()
            bridge:onEvent({ id = fakeEventId, initiator = nil })
            assert.equals(fakeEventId, received.id)
        end)

        it("unknown event id does not throw", function()
            assert.has_no_error(function()
                bridge:onEvent({ id = 88888 })
            end)
        end)

        it("crashing handler is isolated (no propagation)", function()
            local crashMgr = {
                onCrash = function(self, e) error("handler crash") end,
            }
            bridge:register(crashMgr, fakeEventId, "onCrash")
            assert.has_no_error(function()
                bridge:onEvent({ id = fakeEventId })
            end)
        end)

    end)

end)

