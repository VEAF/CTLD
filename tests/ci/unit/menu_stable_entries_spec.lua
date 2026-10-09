---@diagnostic disable
-- tests/ci/unit/menu_stable_entries_spec.lua
-- FIX-MENU-STABLE-ENTRIES (#257): an F10 entry that did not change is never recreated, and every id a
-- removal frees is parked on an inert command, so a click from a screen left open across a refresh
-- fires what the player saw, or nothing.
-- Runs against the missionCommands double that recycles ids as DCS was measured to.
-- ============================================================

local PARKING_GROUP_ID = 999999   -- a group id no player slot holds (shared with VMCT's veafRadio)

describe("ctld.MenuManager stable entries (#257)", function()

    local mgr, mc, fired
    local GID = 7001
    local LIST = { "TEST MENU", "Liste" }

    local function recorder(label)
        return function(arg) table.insert(fired, { label = label, arg = arg }) end
    end

    local function fill(menu, labels)
        menu:clearBranch(LIST)
        for _, l in ipairs(labels) do
            menu:addCommand(LIST, l, recorder(l))
        end
    end

    local function path(label)
        return { LIST[1], LIST[2], label }
    end

    before_each(function()
        ctld.MenuManager._instance = nil
        mgr   = ctld.MenuManager:getInstance()
        mc    = ctldMissionCommandsDouble.install()
        fired = {}
    end)

    after_each(function()
        mc:uninstall()
        ctld.MenuManager._instance = nil
    end)

    local function newMenu()
        local menu = mgr:createMenuForGroup(GID)
        menu:addSubMenu({}, LIST[1], { order = 10 })
        menu:addSubMenu({ LIST[1] }, LIST[2], { order = 10 })
        return menu
    end

    it("an identical refresh keeps every id: a click captured before it fires the same command (test 1)", function()
        local menu = newMenu()
        fill(menu, { "A", "B", "C", "D" })
        mgr:refreshMenuForGroup(GID)
        local idB = mc:idOf(GID, path("B"))

        fill(menu, { "A", "B", "C", "D" })
        mgr:refreshMenuForGroup(GID)
        mc:click(idB)

        assert.equals(1, #fired)
        assert.equals("B", fired[1].label)
    end)

    it("a branch cleared and refilled identically makes no DCS call", function()
        local menu = newMenu()
        fill(menu, { "A", "B", "C", "D" })
        mgr:refreshMenuForGroup(GID)
        mc:resetCalls()

        fill(menu, { "A", "B", "C", "D" })
        mgr:refreshMenuForGroup(GID)

        assert.equals(0, mc:callCount())
    end)

    it("after a removal and a creation, a click on the removed entry fires the parked command (test 9b)", function()
        local menu = newMenu()
        fill(menu, { "A", "B", "C", "D" })
        mgr:refreshMenuForGroup(GID)
        local idA = mc:idOf(GID, path("A"))
        local idB = mc:idOf(GID, path("B"))

        fill(menu, { "B", "C", "D", "E" })
        mgr:refreshMenuForGroup(GID)

        local hit = mc:click(idA)
        assert.equals(0, #fired)
        assert.is_not_nil(hit)
        assert.equals(PARKING_GROUP_ID, hit.gid)
        assert.has_no_error(function() hit.fn(hit.arg) end)   -- inert: only logs

        -- and an untouched entry still fires itself (test 9a)
        mc:click(idB)
        assert.equals(1, #fired)
        assert.equals("B", fired[1].label)
    end)

    it("every removal is followed by one parked command", function()
        local menu = newMenu()
        fill(menu, { "A", "B", "C", "D" })
        mgr:refreshMenuForGroup(GID)
        mc:resetCalls()

        fill(menu, { "B", "D" })
        mgr:refreshMenuForGroup(GID)

        assert.equals(2, mc:callCount("remove", GID))
        assert.equals(2, mc:callCount("add", PARKING_GROUP_ID))
        assert.equals(0, mc:callCount("add", GID))
        assert.same({ "B", "D" }, mc:labels(GID, LIST))
    end)

    it("a changed argument under an unchanged label runs the new argument without recreating the entry", function()
        local menu = newMenu()
        local function fn(arg) table.insert(fired, { label = "A", arg = arg }) end
        menu:addCommand(LIST, "A", fn, { v = 1 })
        mgr:refreshMenuForGroup(GID)
        local idA = mc:idOf(GID, path("A"))
        mc:resetCalls()

        menu:clearBranch(LIST)
        menu:addCommand(LIST, "A", function(arg) table.insert(fired, { label = "A2", arg = arg }) end, { v = 2 })
        mgr:refreshMenuForGroup(GID)
        mc:click(idA)

        assert.equals(0, mc:callCount())
        assert.equals(1, #fired)
        assert.equals("A2", fired[1].label)
        assert.equals(2, fired[1].arg.v)
    end)

    it("an insertion recreates exactly the siblings that follow it, so the declared order holds", function()
        local menu = mgr:createMenuForGroup(GID)
        menu:addCommand({}, "A", recorder("A"), nil, { order = 10 })
        menu:addCommand({}, "B", recorder("B"), nil, { order = 30 })
        menu:addCommand({}, "C", recorder("C"), nil, { order = 40 })
        mgr:refreshMenuForGroup(GID)
        local idA = mc:idOf(GID, { "A" })
        local idB = mc:idOf(GID, { "B" })
        mc:resetCalls()

        menu:addCommand({}, "X", recorder("X"), nil, { order = 20 })
        mgr:refreshMenuForGroup(GID)

        assert.same({ "A", "X", "B", "C" }, mc:labels(GID, {}))
        assert.equals(idA, mc:idOf(GID, { "A" }))      -- A untouched
        assert.equals(2, mc:callCount("remove", GID))   -- B and C
        assert.equals(3, mc:callCount("add", GID))      -- X, B, C
        mc:click(idB)                                   -- B's old id was parked
        assert.equals(0, #fired)
    end)

    it("a re-enabled node returns to its slot", function()
        local menu = mgr:createMenuForGroup(GID)
        menu:addSubMenu({}, "A", { order = 10 })
        menu:addSubMenu({}, "B", { order = 20, enabled = false })
        menu:addSubMenu({}, "C", { order = 30 })
        mgr:refreshMenuForGroup(GID)
        assert.same({ "A", "C" }, mc:labels(GID, {}))

        menu:setBranchEnabled({ "B" }, true)
        mgr:refreshMenuForGroup(GID)

        assert.same({ "A", "B", "C" }, mc:labels(GID, {}))
    end)

    it("a submenu turned command parks every id it freed", function()
        local menu = mgr:createMenuForGroup(GID)
        menu:addCommand({ "S" }, "s1", recorder("s1"))
        menu:addCommand({ "S" }, "s2", recorder("s2"))
        mgr:refreshMenuForGroup(GID)
        local ids = { mc:idOf(GID, { "S", "s1" }), mc:idOf(GID, { "S", "s2" }), mc:idOf(GID, { "S" }) }
        mc:resetCalls()

        menu:removeMenuBranch({ "S" })
        menu:addCommand({}, "S", recorder("S"))
        mgr:refreshMenuForGroup(GID)

        assert.equals(3, mc:callCount("add", PARKING_GROUP_ID))
        for _, id in ipairs(ids) do
            local hit = mc:click(id)
            assert.is_true(hit == nil or hit.gid == PARKING_GROUP_ID)
        end
        assert.equals(0, #fired)
        assert.same({ "S" }, mc:labels(GID, {}))
    end)

    it("an entry crossing a page boundary is recreated on its new page, the others are untouched", function()
        local menu = mgr:createMenuForGroup(GID)
        for i = 1, 10 do
            menu:addCommand({ "L" }, "Item_" .. i, recorder("Item_" .. i), nil, { order = i * 10 })
        end
        mgr:refreshMenuForGroup(GID)
        local id1  = mc:idOf(GID, { "L", "Item_1" })
        local id9  = mc:idOf(GID, { "L", "Item_9" })
        local id10 = mc:idOf(GID, { "L", "Item_10" })
        mc:resetCalls()

        menu:addCommand({ "L" }, "Item_95", recorder("Item_95"), nil, { order = 95 })
        mgr:refreshMenuForGroup(GID)

        local next = ctld.tr("→ Next Page")
        local page1 = mc:labels(GID, { "L" })
        assert.equals(10, #page1)
        assert.equals(next, page1[10])
        assert.same({ "Item_95", "Item_10" }, mc:labels(GID, { "L", next }))
        assert.equals(id1, mc:idOf(GID, { "L", "Item_1" }))   -- page 1 entries untouched
        assert.equals(id9, mc:idOf(GID, { "L", "Item_9" }))
        assert.equals(1, mc:callCount("remove", GID))     -- only Item_10 left page 1
        mc:click(id10)                                    -- its old id is parked
        assert.equals(0, #fired)
        mc:click(id1)
        assert.equals("Item_1", fired[1].label)
    end)

    it("teardown removes every live entry, parks each id and drops the mirror", function()
        local menu = newMenu()
        fill(menu, { "A", "B" })
        mgr:refreshMenuForGroup(GID)
        local live = mc:count(GID)
        local idA = mc:idOf(GID, path("A"))
        mc:resetCalls()

        mgr:teardownGroup(GID)

        assert.equals(0, mc:count(GID))
        assert.equals(live, mc:callCount("add", PARKING_GROUP_ID))
        assert.is_nil(mgr.menus[GID])

        -- the next occupant of the same group id starts from an empty mirror
        local again = newMenu()
        fill(again, { "A" })
        mgr:refreshMenuForGroup(GID)
        assert.same({ "A" }, mc:labels(GID, LIST))
        mc:click(idA)
        assert.equals(0, #fired)
    end)

    it("a dispatch for an entry no longer rendered runs nothing", function()
        local menu = newMenu()
        fill(menu, { "A" })
        mgr:refreshMenuForGroup(GID)
        local entry = mc:entry(mc:idOf(GID, path("A")))
        mgr:teardownGroup(GID)

        assert.has_no_error(function() entry.fn(entry.arg) end)
        assert.equals(0, #fired)
    end)

end)
