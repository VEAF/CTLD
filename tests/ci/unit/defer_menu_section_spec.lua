---@diagnostic disable
-- tests/ci/unit/defer_menu_section_spec.lua
-- busted specs for CTLDPlayerManager.deferMenuSection load-position independence.
--
-- deferMenuSection must work whether called BEFORE getInstance() (queued and flushed
-- at init) or AFTER (routed straight to registerMenuSection) — so a scene's source is
-- identical whether merged into CTLD.lua or loaded as a plugin after CTLD init.
-- Ticket: .backlog/SCENE-PLUGINS/tickets/01-defermenusection-timing-insensitive.md
-- ============================================================

describe("CTLDPlayerManager.deferMenuSection load-position independence", function()

    local function isRegistered(mgr, key)
        for _, s in ipairs(mgr._menuSections) do
            if s.key == key then return true end
        end
        return false
    end

    before_each(function()
        CTLDPlayerManager._instance      = nil
        CTLDDCSEventBridge._instance     = nil
        CTLDPlayerManager._deferredSections = {}
    end)

    -- ── pre-init path (queue then flush) — must not regress ──────
    describe("called BEFORE getInstance()", function()

        it("section is registered after init flush", function()
            CTLDPlayerManager.deferMenuSection({ key = "pre_init_section" })
            local mgr = CTLDPlayerManager.getInstance()
            assert.is_true(isRegistered(mgr, "pre_init_section"))
        end)

        it("the deferred queue is drained after init", function()
            CTLDPlayerManager.deferMenuSection({ key = "pre_init_section" })
            CTLDPlayerManager.getInstance()
            assert.equals(0, #CTLDPlayerManager._deferredSections)
        end)

    end)

    -- ── post-init path (route directly) — the plugin case ───────
    describe("called AFTER getInstance()", function()

        it("section is registered immediately (no second flush needed)", function()
            local mgr = CTLDPlayerManager.getInstance()
            CTLDPlayerManager.deferMenuSection({ key = "post_init_section" })
            assert.is_true(isRegistered(mgr, "post_init_section"))
        end)

        it("does not leave the section stranded in the deferred queue", function()
            CTLDPlayerManager.getInstance()
            CTLDPlayerManager.deferMenuSection({ key = "post_init_section" })
            assert.equals(0, #CTLDPlayerManager._deferredSections)
        end)

        it("dedups by key (same key twice → one entry)", function()
            local mgr = CTLDPlayerManager.getInstance()
            CTLDPlayerManager.deferMenuSection({ key = "dup_section" })
            CTLDPlayerManager.deferMenuSection({ key = "dup_section" })
            local count = 0
            for _, s in ipairs(mgr._menuSections) do
                if s.key == "dup_section" then count = count + 1 end
            end
            assert.equals(1, count)
        end)

    end)

    -- ── guards ──────────────────────────────────────────────────
    it("ignores nil / keyless sectionDef without throwing (post-init)", function()
        CTLDPlayerManager.getInstance()
        assert.has_no_error(function()
            CTLDPlayerManager.deferMenuSection(nil)
            CTLDPlayerManager.deferMenuSection({})
        end)
    end)

end)
