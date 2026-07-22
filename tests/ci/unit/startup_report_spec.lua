---@diagnostic disable
-- tests/ci/unit/startup_report_spec.lua
-- busted specs for ctld.startupReport (STARTUP-REPORT-UNIFIED ticket 01).
-- Tests assert externally observable behaviour: what appears in DCS.log / on screen.
-- ============================================================

describe("ctld.startupReport", function()

    local origOutText, origEnvInfo
    local outTextCalls, envInfoCalls

    before_each(function()
        -- Reset collector
        ctld.startupReport._entries = {}

        -- Capture trigger.action.outText calls
        outTextCalls = {}
        origOutText = trigger.action.outText
        trigger.action.outText = function(msg, dur)
            outTextCalls[#outTextCalls + 1] = msg
        end

        -- Capture env.info calls
        envInfoCalls = {}
        origEnvInfo = env.info
        env.info = function(msg)
            envInfoCalls[#envInfoCalls + 1] = msg
            return origEnvInfo(msg)
        end
    end)

    after_each(function()
        trigger.action.outText = origOutText
        env.info = origEnvInfo
        ctld.startupReport._entries = {}
    end)

    -- Helper: find a log block containing the CTLD_STARTUP_REPORT banner
    local function startupBlock()
        for _, msg in ipairs(envInfoCalls) do
            if msg:find("CTLD_STARTUP_REPORT", 1, true) then return msg end
        end
        return nil
    end

    -- ── empty collector ───────────────────────────────────────
    it("flush() with empty collector writes [OK] to log and emits no outText", function()
        ctld.startupReport.flush()

        assert.is_not_nil(startupBlock())
        assert.is_true(startupBlock():find("[OK]", 1, true) ~= nil)
        assert.equals(0, #outTextCalls)
    end)

    -- ── NOTICE only ───────────────────────────────────────────
    it("flush() with NOTICE only calls outText once with notice text", function()
        ctld.startupReport.add("NOTICE", "TestManager", "Install mod X")
        ctld.startupReport.flush()

        assert.equals(1, #outTextCalls)
        assert.is_true(outTextCalls[1]:find("Install mod X", 1, true) ~= nil)
        -- log block contains the entry
        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_true(block:find("NOTICE", 1, true) ~= nil)
    end)

    -- ── ERROR only ────────────────────────────────────────────
    it("flush() with ERROR only calls outText once with alarm banner", function()
        ctld.startupReport.add("ERROR", "TestManager", "Bad config value")
        ctld.startupReport.flush()

        assert.equals(1, #outTextCalls)
        assert.is_true(outTextCalls[1]:find("CTLD_STARTUP_REPORT", 1, true) ~= nil)
        -- log block contains the entry
        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_true(block:find("ERROR", 1, true) ~= nil)
    end)

    -- ── ERROR + NOTICE ────────────────────────────────────────
    it("flush() with ERROR + NOTICE shows notice text and alarm banner in one outText", function()
        ctld.startupReport.add("NOTICE", "TestManager", "Install mod X")
        ctld.startupReport.add("ERROR",  "TestManager", "Bad config value")
        ctld.startupReport.flush()

        assert.equals(1, #outTextCalls)
        local screen = outTextCalls[1]
        assert.is_true(screen:find("Install mod X",      1, true) ~= nil)
        assert.is_true(screen:find("CTLD_STARTUP_REPORT", 1, true) ~= nil)
    end)

    -- ── collector resets after flush ──────────────────────────
    it("add() after flush() → second flush() sees only new entries", function()
        ctld.startupReport.add("ERROR", "TestManager", "First error")
        ctld.startupReport.flush()

        -- Reset captures
        outTextCalls = {}
        envInfoCalls = {}

        -- Second flush with a new entry only
        ctld.startupReport.add("NOTICE", "TestManager", "Second notice")
        ctld.startupReport.flush()

        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_nil(block:find("First error", 1, true))
        assert.is_true(block:find("Second notice", 1, true) ~= nil)
        assert.equals(1, #outTextCalls)
    end)

    -- ── INFO severity ─────────────────────────────────────────
    it("flush() with INFO only: entry in log, no outText, no [OK]", function()
        ctld.startupReport.add("INFO", "TestManager", "Diagnostic note")
        ctld.startupReport.flush()

        assert.equals(0, #outTextCalls)
        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_true(block:find("INFO", 1, true) ~= nil)
        assert.is_true(block:find("Diagnostic note", 1, true) ~= nil)
        -- [OK] must NOT appear when entries are present
        assert.is_nil(block:find("[OK]", 1, true))
    end)

    it("flush() with INFO + NOTICE: outText for NOTICE only, INFO in log", function()
        ctld.startupReport.add("INFO",   "TestManager", "Info note")
        ctld.startupReport.add("NOTICE", "TestManager", "Install mod X")
        ctld.startupReport.flush()

        assert.equals(1, #outTextCalls)
        assert.is_true(outTextCalls[1]:find("Install mod X", 1, true) ~= nil)
        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_true(block:find("Info note",    1, true) ~= nil)
        assert.is_true(block:find("Install mod X", 1, true) ~= nil)
    end)

    it("flush() with INFO + ERROR: alarm banner on screen, INFO in log", function()
        ctld.startupReport.add("INFO",  "TestManager", "Info note")
        ctld.startupReport.add("ERROR", "TestManager", "Bad config value")
        ctld.startupReport.flush()

        assert.equals(1, #outTextCalls)
        assert.is_true(outTextCalls[1]:find("CTLD_STARTUP_REPORT", 1, true) ~= nil)
        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_true(block:find("Info note", 1, true) ~= nil)
        assert.is_true(block:find("ERROR",     1, true) ~= nil)
    end)

    -- ── double flush with no new entries ─────────────────────
    it("second flush() with no new entries after first → [OK], no outText", function()
        ctld.startupReport.add("NOTICE", "TestManager", "A notice")
        ctld.startupReport.flush()

        outTextCalls = {}
        envInfoCalls = {}

        ctld.startupReport.flush()

        local block = startupBlock()
        assert.is_not_nil(block)
        assert.is_true(block:find("[OK]", 1, true) ~= nil)
        assert.equals(0, #outTextCalls)
    end)

end)
