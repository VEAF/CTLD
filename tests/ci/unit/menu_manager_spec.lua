---@diagnostic disable
-- tests/unit/menu_manager_spec.lua
-- busted specs for ctld.MenuManager singleton, ctld.Menu node operations, and pagination
-- Reference: live_tests/unit/U-057 through U-066
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager singleton", function()
    -- U-057

    before_each(function()
        ctld.MenuManager._instance = nil
    end)

    it("_instance is nil before first call", function()
        assert.is_nil(ctld.MenuManager._instance)
    end)

    it("getInstance() returns a non-nil instance", function()
        assert.is_not_nil(ctld.MenuManager:getInstance())
    end)

    it("getInstance() is idempotent", function()
        local a = ctld.MenuManager:getInstance()
        local b = ctld.MenuManager:getInstance()
        assert.equals(a, b)
    end)

    it("instance has a menus table", function()
        assert.equals("table", type(ctld.MenuManager:getInstance().menus))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager createMenuForGroup", function()
    -- U-058

    local mgr

    before_each(function()
        ctld.MenuManager._instance = nil
        mgr = ctld.MenuManager:getInstance()
    end)

    it("valid numeric groupId returns a menu object", function()
        assert.is_not_nil(mgr:createMenuForGroup(1001))
    end)

    it("returned menu has correct groupId", function()
        local menu = mgr:createMenuForGroup(1001)
        assert.equals(1001, menu.groupId)
    end)

    it("nil groupId returns nil", function()
        assert.is_nil(mgr:createMenuForGroup(nil))
    end)

    it("string groupId returns nil", function()
        assert.is_nil(mgr:createMenuForGroup("Pilot"))
    end)

    it("idempotent: second call returns same object", function()
        local a = mgr:createMenuForGroup(1002)
        local b = mgr:createMenuForGroup(1002)
        assert.equals(a, b)
    end)

    it("menu is stored in manager.menus[groupId]", function()
        local menu = mgr:createMenuForGroup(1003)
        assert.equals(menu, mgr.menus[1003])
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager _sortByOrder", function()
    -- U-059

    it("sorts children ascending by order field", function()
        local children = {
            { name = "C", order = 30 },
            { name = "A", order = 10 },
            { name = "B", order = 20 },
        }
        local sorted = ctld.MenuManager:_sortByOrder(children)
        assert.equals("A", sorted[1].name)
        assert.equals("B", sorted[2].name)
        assert.equals("C", sorted[3].name)
    end)

    it("nodes without order are appended last", function()
        local children = {
            { name = "NoOrder" },
            { name = "First", order = 5 },
        }
        local sorted = ctld.MenuManager:_sortByOrder(children)
        assert.equals("First",   sorted[1].name)
        assert.equals("NoOrder", sorted[2].name)
    end)

    it("empty list returns empty table", function()
        local sorted = ctld.MenuManager:_sortByOrder({})
        assert.equals(0, #sorted)
    end)

    it("nil input returns empty table", function()
        local sorted = ctld.MenuManager:_sortByOrder(nil)
        assert.equals(0, #sorted)
    end)

    it("nodes sharing an order keep their insertion order, however many", function()
        local children = {}
        for i = 1, 40 do table.insert(children, { name = "N" .. i }) end
        local sorted = ctld.MenuManager:_sortByOrder(children)
        for i = 1, 40 do assert.equals("N" .. i, sorted[i].name) end
    end)

    it("does not mutate the original list", function()
        local children = {
            { name = "B", order = 20 },
            { name = "A", order = 10 },
        }
        ctld.MenuManager:_sortByOrder(children)
        -- Original order must be preserved
        assert.equals("B", children[1].name)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu addSubMenu", function()

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2001)
    end)

    -- ── Success and options (U-060) ──────────────────────────
    describe("success and options (U-060)", function()

        it("returns success=true", function()
            assert.is_true(menu:addSubMenu({}, "CTLD Commands").success)
        end)

        it("returns a non-nil subMenuId", function()
            assert.is_not_nil(menu:addSubMenu({}, "CTLD Commands").subMenuId)
        end)

        it("idempotent: second call returns same subMenuId", function()
            local r1 = menu:addSubMenu({}, "CTLD Commands")
            local r2 = menu:addSubMenu({}, "CTLD Commands")
            assert.equals(r1.subMenuId, r2.subMenuId)
        end)

        it("opts.order stored on node", function()
            menu:addSubMenu({}, "Ordered", { order = 10 })
            assert.equals(10, menu:_getNode({"Ordered"}).order)
        end)

        it("opts.enabled=false stored on node", function()
            menu:addSubMenu({}, "Hidden", { enabled = false })
            assert.is_false(menu:_getNode({"Hidden"}).enabled)
        end)

        it("enabled defaults to true when not specified", function()
            menu:addSubMenu({}, "Visible")
            assert.is_true(menu:_getNode({"Visible"}).enabled)
        end)

        it("nested addSubMenu creates child node", function()
            menu:addSubMenu({}, "Parent")
            local r = menu:addSubMenu({"Parent"}, "Child")
            assert.is_true(r.success)
            assert.is_not_nil(menu:_getNode({"Parent", "Child"}))
        end)

    end)

    -- ── Guards (U-061) ────────────────────────────────────────
    describe("guards (U-061)", function()

        it("nil name returns success=false and nil subMenuId", function()
            local r = menu:addSubMenu({}, nil)
            assert.is_false(r.success)
            assert.is_nil(r.subMenuId)
        end)

        it("number name returns success=false", function()
            assert.is_false(menu:addSubMenu({}, 42).success)
        end)

        it("parent=command node returns success=false", function()
            menu:addSubMenu({}, "Parent")
            menu:addCommand({"Parent"}, "Leaf", function() end)
            local r = menu:addSubMenu({"Parent", "Leaf"}, "Child")
            assert.is_false(r.success)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu addCommand", function()
    -- U-062

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2002)
    end)

    it("valid call returns success=true", function()
        assert.is_true(menu:addCommand({}, "Load Troops", function() end, {}).success)
    end)

    it("returns a non-nil commandId", function()
        assert.is_not_nil(menu:addCommand({}, "Load Troops", function() end, {}).commandId)
    end)

    it("nil anyArgument defaults to {} on the node", function()
        menu:addCommand({}, "Load Troops", function() end, nil)
        local node = menu:_getNode({"Load Troops"})
        assert.equals("table", type(node.anyArgument))
    end)

    it("nil commandName returns success=false and nil commandId", function()
        local r = menu:addCommand({}, nil, function() end, {})
        assert.is_false(r.success)
        assert.is_nil(r.commandId)
    end)

    it("non-function functionToCall returns success=false", function()
        assert.is_false(menu:addCommand({}, "Bad", "not_a_fn", {}).success)
    end)

    it("non-table anyArgument returns success=false", function()
        assert.is_false(menu:addCommand({}, "Bad", function() end, "string_arg").success)
    end)

    it("parent=command node returns success=false", function()
        menu:addCommand({}, "Leaf", function() end)
        local r = menu:addCommand({"Leaf"}, "Nested", function() end)
        assert.is_false(r.success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu clearBranch", function()
    -- U-063

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2003)
        menu:addSubMenu({}, "Vehicles")
        menu:addCommand({"Vehicles"}, "UH-60", function() end)
        menu:addCommand({"Vehicles"}, "CH-47", function() end)
    end)

    it("returns success=true", function()
        assert.is_true(menu:clearBranch({"Vehicles"}).success)
    end)

    it("children are emptied after clear", function()
        menu:clearBranch({"Vehicles"})
        assert.equals(0, #menu:_getNode({"Vehicles"}).children)
    end)

    it("container node is preserved after clear", function()
        menu:clearBranch({"Vehicles"})
        assert.is_not_nil(menu:_getNode({"Vehicles"}))
    end)

    it("guard: command node returns success=false", function()
        menu:addCommand({}, "TopCmd", function() end)
        assert.is_false(menu:clearBranch({"TopCmd"}).success)
    end)

    it("guard: unknown path returns success=false", function()
        assert.is_false(menu:clearBranch({"NonExistent"}).success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu setBranchEnabled", function()
    -- U-064

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2004)
        menu:addSubMenu({}, "FOB")
    end)

    it("setBranchEnabled(false) marks node enabled=false", function()
        menu:setBranchEnabled({"FOB"}, false)
        assert.is_false(menu:_getNode({"FOB"}).enabled)
    end)

    it("setBranchEnabled(true) marks node enabled=true after disable", function()
        menu:setBranchEnabled({"FOB"}, false)
        menu:setBranchEnabled({"FOB"}, true)
        assert.is_true(menu:_getNode({"FOB"}).enabled)
    end)

    it("returns success=true for known path", function()
        assert.is_true(menu:setBranchEnabled({"FOB"}, false).success)
    end)

    it("returns success=false for unknown path", function()
        assert.is_false(menu:setBranchEnabled({"Unknown"}, true).success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu removeMenuBranch", function()
    -- U-065

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2005)
        -- Build: Vehicles (1 node) → { UH-60 (1), CH-47 (1) } = 3 total
        menu:addSubMenu({}, "Vehicles")
        menu:addCommand({"Vehicles"}, "UH-60", function() end)
        menu:addCommand({"Vehicles"}, "CH-47", function() end)
    end)

    it("returns success=true", function()
        assert.is_true(menu:removeMenuBranch({"Vehicles"}).success)
    end)

    it("removedCount=3 for 1 submenu + 2 commands", function()
        assert.equals(3, menu:removeMenuBranch({"Vehicles"}).removedCount)
    end)

    it("node is no longer accessible after removal", function()
        menu:removeMenuBranch({"Vehicles"})
        assert.is_nil(menu:_getNode({"Vehicles"}))
    end)

    it("guard: empty pathTable returns success=false with removedCount=0", function()
        local r = menu:removeMenuBranch({})
        assert.is_false(r.success)
        assert.equals(0, r.removedCount)
    end)

    it("guard: nil pathTable returns success=false", function()
        assert.is_false(menu:removeMenuBranch(nil).success)
    end)

    it("guard: unknown path returns success=false", function()
        assert.is_false(menu:removeMenuBranch({"NonExistent"}).success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager refreshMenuForGroup mirror", function()
    -- U-067 — the mirror of live entries replaced _activeHandles (FIX-MENU-STABLE-ENTRIES); the
    -- behaviour across refreshes is pinned in menu_stable_entries_spec.lua.

    local mgr, mc

    before_each(function()
        ctld.MenuManager._instance = nil
        mgr = ctld.MenuManager:getInstance()
        mc  = ctldMissionCommandsDouble.install()
    end)

    after_each(function()
        mc:uninstall()
    end)

    it("first refresh: creates every entry, removes nothing", function()
        local menu = mgr:createMenuForGroup(5001)
        menu:addSubMenu({}, "CTLD", { order = 10 })
        menu:addCommand({ "CTLD" }, "Check Cargo", function() end)
        mgr:refreshMenuForGroup(5001)

        assert.equals(2, mc:callCount("add", 5001))
        assert.equals(0, mc:callCount("remove"))
        assert.same({ "CTLD" }, mc:labels(5001, {}))
    end)

    it("a buildMenu-style reset of the memory model keeps the mirror: the next refresh only diffs", function()
        local menu = mgr:createMenuForGroup(5002)
        menu:addSubMenu({}, "CTLD", { order = 10 })
        mgr:refreshMenuForGroup(5002)
        mc:resetCalls()

        -- Simulate buildMenu reset + section rebuild
        menu.children  = {}
        menu._lookup   = {}
        menu.nextItemId = 1
        menu:addSubMenu({}, "CTLD", { order = 10 })
        mgr:refreshMenuForGroup(5002)

        assert.equals(0, mc:callCount())
    end)

    it("new ctld.Menu has an empty mirror", function()
        local menu = mgr:createMenuForGroup(5004)
        assert.is_nil(next(menu._rendered.children))
        assert.is_nil(next(menu._rendered.byKey))
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- FIX-MENU-STABLE-ENTRIES: every refresh applies the difference DEBOUNCE_S after the first request,
-- never a wipe now and a rebuild later (ADR 0027, which supersedes ADR 0015's ambient delay).
describe("ctld.MenuManager debounced refresh", function()

    local mgr, mc
    local scheduledCalls   -- { fn, id, t } per timer.scheduleFunction call
    local removedIds       -- ids passed to timer.removeFunction
    local nextTimerId

    local DEBOUNCE = 0.15  -- must match DEBOUNCE_S in CTLD_menu.lua

    before_each(function()
        ctld.MenuManager._instance = nil
        mgr            = ctld.MenuManager:getInstance()
        mc             = ctldMissionCommandsDouble.install()
        scheduledCalls = {}
        removedIds     = {}
        nextTimerId    = 0
        timer.scheduleFunction = function(fn, _arg, t)
            nextTimerId = nextTimerId + 1
            table.insert(scheduledCalls, { fn = fn, id = nextTimerId, t = t })
            return nextTimerId
        end
        timer.removeFunction = function(id)
            table.insert(removedIds, id)
        end
        timer.getTime = function() return 0 end
    end)

    after_each(function()
        mc:uninstall()
        timer.scheduleFunction = function(fn, arg, t) return 0 end
        timer.removeFunction = function(id) end
        timer.getTime = function() return 0 end
    end)

    -- Seed a menu with one top-level submenu and render it at once (bypassing the debounce), the
    -- way a real menu looks right after buildMenu/onPlayerEnterUnit.
    local function seedMenu(groupId)
        local menu = mgr:createMenuForGroup(groupId)
        menu:addSubMenu({}, "CTLD", { order = 10 })
        mgr:refreshMenuForGroup(groupId)
        mc:resetCalls()
        return menu
    end

    it("a refresh touches nothing now and applies the difference DEBOUNCE_S later", function()
        local menu = seedMenu(6001)
        menu:addCommand({ "CTLD" }, "New", function() end)

        menu:refresh()

        assert.equals(0, mc:callCount())          -- no wipe, nothing removed now
        assert.equals(1, #scheduledCalls)
        assert.equals(DEBOUNCE, scheduledCalls[1].t)

        scheduledCalls[1].fn()   -- advance the mocked timer

        assert.equals(1, mc:callCount("add", 6001))
        assert.equals(0, mc:callCount("remove"))
    end)

    it("a refresh with nothing changed makes no DCS call", function()
        local menu = seedMenu(6002)
        menu:refresh()
        scheduledCalls[1].fn()
        assert.equals(0, mc:callCount())
    end)

    it("a second refresh inside the window coalesces", function()
        local menu = seedMenu(6015)
        menu:refresh()
        menu:refresh()

        assert.equals(1, #scheduledCalls)
    end)

    it("a refresh for another group is debounced the same way (no bystander delay)", function()
        seedMenu(6006)
        local bystander = seedMenu(6007)
        mgr.menus[6006]:addCommand({ "CTLD" }, "Do Thing", function()
            bystander:refresh()   -- fan-out to a different group mid-callback
        end)
        mgr:refreshMenuForGroup(6006)
        local id = mc:idOf(6006, { "CTLD", "Do Thing" })

        mc:click(id)

        assert.equals(1, #scheduledCalls)
        assert.equals(DEBOUNCE, scheduledCalls[1].t)
    end)

    it("a menu command's own refresh is debounced and applied", function()
        local menu = seedMenu(6009)
        menu:addCommand({ "CTLD" }, "Do Thing", function()
            menu:addCommand({ "CTLD" }, "Done", function() end)
            menu:refresh()   -- refresh triggered synchronously from inside the click
        end)
        mgr:refreshMenuForGroup(6009)
        mc:resetCalls()

        mc:click(mc:idOf(6009, { "CTLD", "Do Thing" }))   -- DCS invokes the click

        assert.equals(1, #scheduledCalls)
        assert.equals(DEBOUNCE, scheduledCalls[1].t)
        scheduledCalls[1].fn()
        assert.same({ "Do Thing", "Done" }, mc:labels(6009, { "CTLD" }))
    end)

    it("a raising command is logged, not propagated", function()
        local menu = seedMenu(6008)
        menu:addCommand({ "CTLD" }, "Boom", function() error("boom") end)
        mgr:refreshMenuForGroup(6008)

        assert.has_no_error(function() mc:click(mc:idOf(6008, { "CTLD", "Boom" })) end)
    end)

    -- FIX-CANCELPENDING-URGENT-TIMER (#152).
    it("cancelPending cancels a pending debounce via timer.removeFunction", function()
        local menu = seedMenu(6011)
        menu:refresh()
        assert.equals(1, #scheduledCalls)
        local timerId = scheduledCalls[1].id

        mgr:cancelPending(6011)

        assert.is_nil(mgr._pendingRefresh[6011])
        assert.equals(1, #removedIds)
        assert.equals(timerId, removedIds[1])
    end)

    it("a cancelled debounce applies nothing if its callback still runs", function()
        -- The reported symptom (#152): a new occupant takes the same numeric group id, already
        -- has a menu, and the previous occupant's debounce fires inside his first 150 ms.
        -- A mocked timer cannot really retract the call, so this asserts the outcome: nothing.
        local menu = seedMenu(6013)
        menu:addCommand({ "CTLD" }, "New", function() end)
        menu:refresh()
        local cb = scheduledCalls[1].fn

        mgr:cancelPending(6013)
        cb()   -- DCS fires it anyway

        assert.equals(0, mc:callCount())
    end)

    it("cancelPending on a group with nothing pending removes nothing", function()
        seedMenu(6014)

        mgr:cancelPending(6014)

        assert.equals(0, #removedIds)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager submenu pagination", function()
    -- U-066 — rendered through refreshMenuForGroup inside a submenu (the root level is not paginated).

    local mgr, mc
    local GID = 5101

    local function render(n, disabled)
        local menu = mgr:createMenuForGroup(GID)
        menu:addSubMenu({}, "L")
        for i = 1, n do
            menu:addCommand({ "L" }, "Item_" .. i, function() end)
        end
        if disabled then menu:setBranchEnabled({ "L", "Item_" .. disabled }, false) end
        mgr:refreshMenuForGroup(GID)
        mc:resetCalls()
        mgr.menus[GID] = nil
    end

    local function count(kind)
        local n = 0
        for _, e in pairs(mc.entries) do
            if e.gid == GID and e.kind == kind then n = n + 1 end
        end
        return n
    end

    before_each(function()
        ctld.MenuManager._instance = nil
        mgr = ctld.MenuManager:getInstance()
        mc  = ctldMissionCommandsDouble.install()
    end)

    after_each(function()
        mc:uninstall()
    end)

    it("10 items → all rendered inline, no NextPage submenu", function()
        render(10)
        assert.equals(10, count("command"))
        assert.equals(1,  count("submenu"))   -- L itself
    end)

    it("11 items → 11 commands rendered, 1 NextPage submenu created", function()
        render(11)
        local next = ctld.tr("→ Next Page")
        assert.equals(11, count("command"))
        assert.equals(2,  count("submenu"))
        assert.equals(next, mc:labels(GID, { "L" })[10])
        assert.same({ "Item_10", "Item_11" }, mc:labels(GID, { "L", next }))
    end)

    it("20 items → 20 commands rendered, 2 NextPage submenus created", function()
        render(20)
        assert.equals(20, count("command"))
        assert.equals(3,  count("submenu"))
    end)

    it("disabled nodes are not rendered", function()
        render(3, 2)
        assert.same({ "Item_1", "Item_3" }, mc:labels(GID, { "L" }))
    end)

    it("empty list → only the submenu itself", function()
        render(0)
        assert.equals(0, count("command"))
        assert.equals(1, count("submenu"))
    end)

end)
