---@diagnostic disable
-- tests/dcs/util/shutdown_ctld.lua
-- Cancels every timer CTLD has scheduled (ctld.scheduler.cancelAll), so a previous instance leaves
-- nothing running. Reloading the mission (Shift+R) is the supported way to start CTLD afresh; this
-- script is for stopping a live instance cleanly. Injecting CTLD.lua over a live mission is NOT
-- supported (see the integration-testing skill).
--
-- Returns a one-line report.
if not ctld or not ctld.scheduler then
    return "shutdown_ctld: CTLD scheduler not loaded - nothing to cancel"
end
ctld.scheduler.cancelAll()
return "shutdown_ctld: all CTLD timers cancelled"
