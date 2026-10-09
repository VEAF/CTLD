---@diagnostic disable
-- CTLD_menu.lua
-- Menu model and DCS F10 menu manager.
--
-- ARCHITECTURE — two layers:
--
--   ctld.Menu         : Logical tree model for one group's menu.
--                       Callers work exclusively with this model.
--                       The tree is unlimited in memory; pagination is transparent.
--
--   ctld.MenuManager  : Singleton. Owns all ctld.Menu instances (one per groupId).
--                       Handles DCS rendering: refresh() applies the difference between the
--                       memory model and what is live (see RENDERING BY DIFFERENCE).
--
-- ORDER CONVENTION:
--   Every node carries an optional `order` field (number).
--   Siblings are sorted by `order` (ascending) before DCS rendering, regardless of
--   insertion order or manager initialization order.
--   Recommended spacing: 10, 20, 30 … to leave room for future entries.
--   Nodes without an explicit `order` value are appended last (math.huge).
--
--   WHY: each manager calls addSubMenu() independently. Without explicit order,
--   the visual position of a submenu would depend on the manager init sequence —
--   fragile and hard to control. Explicit order makes positions declarative and stable.
--
-- ENABLED CONVENTION:
--   Every node carries an `enabled` field (boolean, default true).
--   Disabled nodes are invisible in DCS but remain in the memory tree.
--   This PRESERVES their ORDER position: re-enabling a node brings it back
--   to the exact same F-key slot it would have occupied if always enabled.
--   Use setBranchEnabled() + refresh() to toggle features at runtime
--   (e.g. a mission trigger unlocks FOB building mid-mission).
--
-- PAGINATION:
--   DCS F10 menus: F1-F10 under programmer control, F11 = Previous Page (DCS),
--   F12 = Quit (DCS). Effective programmer slots per level: 10.
--   Rule applied by _renderPage() to every submenu (the root level is not paginated):
--     - If visible children count <= 10 : render all on one page (no pagination).
--     - If visible children count  > 10 : render 9 in F1-F9,
--                                         F10 = "→ Next Page" submenu (DCS-only, not in memory),
--                                         recurse with remaining items inside that submenu.
--     The last page always receives <= 10 items and needs no "→ Next Page".
--   The "→ Next Page" node NEVER exists in the memory model — it is generated
--   at render time only.
--
-- DYNAMIC REFRESH PATTERN (proximity-based lists):
--   local menu = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
--   menu:clearBranch({"CTLD Commands", "Pack Vehicles"})  -- empty children, keep container
--   for _, v in ipairs(nearbyVehicles) do
--       menu:addCommand({"CTLD Commands", "Pack Vehicles"}, v.name, packFn, { unitName = v.name })
--   end
--   menu:refresh()   -- only the entries that changed are recreated in DCS

ctld = ctld or {}

-- =============================================================================
-- ctld.MenuManager — Singleton: owns all group menus, drives DCS rendering
-- =============================================================================

ctld.MenuManager = ctld.MenuManager or {}
ctld.MenuManager._instance = nil

function ctld.MenuManager:getInstance()
    if not self._instance then
        self._instance = self:_new()
    end
    return self._instance
end

function ctld.MenuManager:_new()
    local obj = {
        menus            = {},
        _pendingRefresh  = {},  -- [groupId] = { timerId } while a debounced refresh is scheduled
    }
    setmetatable(obj, { __index = ctld.MenuManager })
    return obj
end

-- Create a ctld.Menu for groupId. Idempotent: returns existing menu if already created.
function ctld.MenuManager:createMenuForGroup(groupId)
    if not groupId or type(groupId) ~= "number" then
        ctld.logWarning("ctld.MenuManager:createMenuForGroup: invalid groupId %s", tostring(groupId))
        return nil
    end
    if self.menus[groupId] then
        return self.menus[groupId]
    end
    local menu = ctld.Menu:_new(groupId, self)
    self.menus[groupId] = menu
    ctld.logInfo("ctld.MenuManager:createMenuForGroup: created menu for group %d", groupId)
    return menu
end

-- =============================================================================
-- DEBOUNCED REFRESH  (see ADR 0027 — dev/adr/0027-stable-f10-entries.md)
--
-- refresh() schedules one refreshMenuForGroup DEBOUNCE_S later; further requests inside that
-- window coalesce into it. The refresh applies the difference at once: an entry that did not
-- change keeps its DCS id, so a screen left open across it still fires what it shows. ADR 0015's
-- ambient path (wipe now, rebuild 4 s later) is gone: the wipe freed the ids and the rebuild handed
-- them out again, which is the misfire it was meant to prevent.
-- =============================================================================

local DEBOUNCE_S = 0.15   -- seconds — one DCS frame is ~0.02 s; 0.15 s absorbs any burst

function ctld.MenuManager:deferredRefreshForGroup(groupId)
    if not self.menus[groupId] then return end
    if self._pendingRefresh[groupId] then return end   -- already scheduled
    local selfRef = self
    -- The entry doubles as this callback's claim on the group: cancelPending removes the
    -- timer, and the callback refuses to act if the entry it finds is not its own. Either
    -- alone would do in the common case; together they hold even if ctld.scheduler.remove
    -- misses, which matters because DCS reuses a numeric group id for the next occupant and
    -- the refresh would land on him 0.15 s into his flight (#152).
    local entry = {}
    entry.timerId = ctld.scheduler.schedule(function()
        if selfRef._pendingRefresh[groupId] ~= entry then return end   -- cancelled
        selfRef._pendingRefresh[groupId] = nil
        if selfRef.menus[groupId] then
            selfRef:refreshMenuForGroup(groupId)
        end
    end, nil, timer.getTime() + DEBOUNCE_S)
    self._pendingRefresh[groupId] = entry
end

-- Cancel the pending (debounced) refresh scheduled for groupId, if any.
-- Call when a group's menu is torn down (last crew member leaves): DCS can reuse a numeric
-- groupId for an unrelated slot occupant, and a leftover pending entry would otherwise make
-- deferredRefreshForGroup silently coalesce the new occupant's first refresh into a stale
-- timer scheduled for someone who already left.
function ctld.MenuManager:cancelPending(groupId)
    local pending = self._pendingRefresh[groupId]
    if pending then
        -- Tolerate an entry that is not a table: this runs on the player-teardown path, and a
        -- raise here would abort the caller mid-cleanup and leave the player registered.
        if type(pending) == "table" and pending.timerId then
            ctld.scheduler.remove(pending.timerId)
        end
        self._pendingRefresh[groupId] = nil
    end
end

-- =============================================================================
-- RENDERING BY DIFFERENCE  (see ADR 0027 — dev/adr/0027-stable-f10-entries.md)
--
-- DCS tracks each F10 entry by an internal id drawn from ONE pool for the whole server, and gives a
-- removed entry's id to the next entry created, for any group (#257, measured 2026-10-09). A screen
-- left open keeps the ids it was drawn with: a click on it runs whatever holds that id now. Hence:
--   - an entry that did not change is never recreated: refreshMenuForGroup compares the rendered tree
--     with the mirror of what is live (menu._rendered) and creates / removes only the difference;
--   - every removal is followed at once by an inert command for PARKING_GROUP_ID, which takes the
--     freed id: a stale click on a removed entry runs that command, which only logs;
--   - DCS appends a created entry after its siblings, so an insertion recreates the siblings that
--     follow it and the declared `order` holds;
--   - commands are handed one stable dispatcher and their entry's key; the node to run is looked up
--     at click time, so a new callback or argument under an unchanged label needs no recreation.
-- An entry's key is its parent's key + submenu/command + label (+ "#n" for the n-th twin), taken in
-- the RENDERED tree, so "→ Next Page" submenus are diffed like any other entry.
-- Within one level, removals run before creations: DCS addresses an entry by its label path, and a
-- recreated entry must not coexist with its old self under the same path.
-- =============================================================================

local PARKING_GROUP_ID = 999999   -- no player slot holds it; VMCT's veafRadio parks on the same id
local PAGE_SIZE        = 9        -- F1-F9 for content on intermediate pages (see PAGINATION)
local KEY_SEP          = "\n"
local parkSeq          = 0

local function newRendered()
    -- children[parentKey] = live entries in DCS order; byKey[key] = entry.
    -- Entry: { key, type, handle (what DCS returned, the only thing removeItemForGroup honours),
    --         path (its label path, the parent path of its children), node }.
    return { children = {}, byKey = {} }
end

local function appendPath(path, label)
    local p = {}
    for _, seg in ipairs(path) do table.insert(p, seg) end
    table.insert(p, label)
    return p
end

-- Inert target of every parked id: a click from a screen drawn before the removal lands here.
local function parkedClick(arg)
    ctld.logInfo("ctld.MenuManager: F10 click on a removed entry, ignored (%s)", tostring(arg and arg.label))
end

-- The one function handed to DCS for every CTLD command. arg = { groupId, key }.
-- Runs the node rendered under that key at the last refresh — what the player saw.
function ctld.MenuManager._dispatch(arg)
    local mgr   = ctld.MenuManager:getInstance()
    local menu  = arg and mgr.menus[arg.groupId]
    local entry = menu and menu._rendered.byKey[arg.key]
    local node  = entry and entry.node
    if not node or not node.functionToCall then
        ctld.logInfo("ctld.MenuManager: F10 click on an entry no longer rendered for group %s, ignored",
            tostring(arg and arg.groupId))
        return
    end
    local fn    = node.functionToCall
    local fnArg = type(node.anyArgument) == "table" and node.anyArgument or {}
    -- The pcall keeps a bad command from crashing the whole menu.
    ctld.utils.protectedCall("ctld.MenuManager: callback '" .. tostring(node.name) .. "'", function()
        fn(fnArg)
    end)
end

-- Consume the id a removal just freed with an inert command no player can see.
function ctld.MenuManager:_park()
    parkSeq = parkSeq + 1
    local label = "CTLD parked " .. parkSeq
    missionCommands.addCommandForGroup(PARKING_GROUP_ID, label, nil, parkedClick, { label = label })
end

-- Remove one live entry, a submenu's children first; park every freed id.
function ctld.MenuManager:_removeEntry(groupId, menu, entry)
    if entry.type == "submenu" then
        local kids = menu._rendered.children[entry.key] or {}
        for i = #kids, 1, -1 do self:_removeEntry(groupId, menu, kids[i]) end
        menu._rendered.children[entry.key] = nil
    end
    missionCommands.removeItemForGroup(groupId, entry.handle)
    self:_park()
    menu._rendered.byKey[entry.key] = nil
    self._removedCount = (self._removedCount or 0) + 1
end

function ctld.MenuManager:_createEntry(groupId, menu, parentPath, wanted)
    local dcsPath = #parentPath > 0 and parentPath or nil
    local handle
    if wanted.type == "submenu" then
        handle = missionCommands.addSubMenuForGroup(groupId, wanted.label, dcsPath)
    else
        handle = missionCommands.addCommandForGroup(groupId, wanted.label, dcsPath, ctld.MenuManager._dispatch,
            { groupId = groupId, key = wanted.key })
    end
    local path  = appendPath(parentPath, wanted.label)
    local entry = { key = wanted.key, type = wanted.type, handle = handle or path, path = path }
    menu._rendered.byKey[wanted.key] = entry
    self._createdCount = (self._createdCount or 0) + 1
    return entry
end

-- Rendered tree of one level: enabled filter, `order` sort, and pagination when `paged`.
-- Each entry: { key, type, label, node, children (submenus) }.
function ctld.MenuManager:_renderLevel(parentKey, children, paged)
    local visible = {}
    for _, child in ipairs(ctld.MenuManager:_sortByOrder(children)) do
        if child.enabled ~= false then table.insert(visible, child) end
    end
    return self:_renderPage(parentKey, visible, 1, paged)
end

-- PAGINATION RULE (see file header): <= 10 items left → all on this page; more → 9 items, then
-- F10 = "→ Next Page" (DCS-only, never in the memory model) holding the rest.
function ctld.MenuManager:_renderPage(parentKey, visible, first, paged)
    local out, seen = {}, {}
    local function push(type, label, node)
        local base = parentKey .. KEY_SEP .. type .. ":" .. label
        seen[base] = (seen[base] or 0) + 1
        local entry = { key = seen[base] > 1 and (base .. "#" .. seen[base]) or base,
                        type = type, label = label, node = node }
        table.insert(out, entry)
        return entry
    end
    local last  = #visible
    local split = paged and (last - first + 1) > 10
    if split then last = first + PAGE_SIZE - 1 end
    for i = first, last do
        local node  = visible[i]
        local entry = push(node.type, node.name, node)
        if node.type == "submenu" then
            entry.children = self:_renderLevel(entry.key, node.children, true)
        end
    end
    if split then
        local nextPage = push("submenu", ctld.tr("→ Next Page"), nil)
        nextPage.children = self:_renderPage(nextPage.key, visible, last + 1, true)
    end
    return out
end

-- Bring one live level to `wanted`. The live entries kept are the longest run that already sits in
-- the wanted order (DCS can only append); every other live entry is removed, then the missing ones
-- are created in order. Submenus kept are diffed recursively.
function ctld.MenuManager:_applyLevel(groupId, menu, parentKey, parentPath, wanted)
    local live     = menu._rendered.children[parentKey] or {}
    local isWanted = {}
    for _, w in ipairs(wanted) do isWanted[w.key] = true end

    local kept, k = {}, 0
    for _, entry in ipairs(live) do
        if isWanted[entry.key] then
            if wanted[k + 1].key ~= entry.key then break end
            k = k + 1
            kept[entry.key] = entry
        end
    end

    for _, entry in ipairs(live) do
        if not kept[entry.key] then self:_removeEntry(groupId, menu, entry) end
    end

    local now = {}
    for _, w in ipairs(wanted) do
        local entry = kept[w.key] or self:_createEntry(groupId, menu, parentPath, w)
        entry.node = w.node
        table.insert(now, entry)
        if w.type == "submenu" then
            self:_applyLevel(groupId, menu, w.key, entry.path, w.children)
        end
    end
    menu._rendered.children[parentKey] = now
end

-- Remove every live CTLD entry of the group, each id parked. Returns the count of top-level entries.
-- Never removes the group's whole menu (nil path would also destroy standard DCS entries such as
-- Ground Crew / ATC) — only the entries CTLD itself added.
function ctld.MenuManager:_removeAll(groupId)
    local menu = self.menus[groupId]
    if not menu then return 0 end
    local top = menu._rendered.children[""] or {}
    for i = #top, 1, -1 do self:_removeEntry(groupId, menu, top[i]) end
    menu._rendered = newRendered()
    return #top
end

-- Last crew member gone: remove and park every live entry, drop the menu and its mirror, cancel any
-- pending refresh. DCS reuses a numeric groupId for the next occupant of a slot (#152), who must
-- start from an empty mirror and no leftover timer.
function ctld.MenuManager:teardownGroup(groupId)
    if self.menus[groupId] then
        self:_removeAll(groupId)
        self.menus[groupId] = nil
    end
    self:cancelPending(groupId)
end

-- Bring the group's live DCS menu to the memory model, by difference (see RENDERING BY DIFFERENCE).
-- Children are rendered in ORDER-field order (see ORDER CONVENTION above); the root level is not
-- paginated, every submenu is.
-- Direct callers (buildMenu on player enter) bypass the debounce intentionally.
function ctld.MenuManager:refreshMenuForGroup(groupId)
    if not self.menus[groupId] then
        ctld.logWarning("ctld.MenuManager:refreshMenuForGroup: no menu for group %s", tostring(groupId))
        return { success = false, message = "Menu not found for group " .. tostring(groupId), refreshedCount = 0 }
    end
    local menu = self.menus[groupId]

    self._createdCount, self._removedCount = 0, 0
    local wanted = self:_renderLevel("", menu.children, false)
    self:_applyLevel(groupId, menu, "", {}, wanted)

    if self._createdCount > 0 or self._removedCount > 0 then
        ctld.logInfo("ctld.MenuManager:refreshMenuForGroup: group %d, %d entr(ies) created, %d removed",
            groupId, self._createdCount, self._removedCount)
    end
    local count = #wanted
    return { success = true, message = "Menu refreshed: " .. count .. " items", refreshedCount = count }
end

-- Return a copy of `children` sorted by `order` ascending.
-- Nodes without an explicit order are placed last (order = math.huge).
-- Nodes sharing the same order value preserve their insertion order (stable sort).
-- table.sort is not stable, so ties are broken on the insertion index: the rendered order must be
-- the same on every refresh, or the difference would recreate entries that did not change.
function ctld.MenuManager:_sortByOrder(children)
    if not children then return {} end
    local sorted, index = {}, {}
    for i, child in ipairs(children) do
        table.insert(sorted, child)
        index[child] = i
    end
    table.sort(sorted, function(a, b)
        local oa = a.order or math.huge
        local ob = b.order or math.huge
        if oa ~= ob then return oa < ob end
        return index[a] < index[b]
    end)
    return sorted
end

-- Retrieve group name by iterating all coalitions.
-- Note: Group.getByID() does not exist in the DCS SSE API (only Group.getByName() is documented).
-- Coalition iteration is the only reliable way to resolve groupId → name.
function ctld.MenuManager:_getGroupName(groupId)
    for _, coalId in ipairs({ 0, 1, 2 }) do
        for _, gp in pairs(coalition.getGroups(coalId) or {}) do
            if gp:getID() == groupId then return gp:getName() end
        end
    end
    return "Unknown"
end

-- Lookup helpers
function ctld.MenuManager:getMenuByGroupId(groupId)   return self.menus[groupId] or nil end
function ctld.MenuManager:getMenuByGroupName(groupName)
    for _, menu in pairs(self.menus) do
        if menu.groupName == groupName then return menu end
    end
    return nil
end
function ctld.MenuManager:getMenuByUnitName(unitName)
    local unit = Unit.getByName(unitName)
    if unit then
        local group = unit:getGroup()
        if group then return self:getMenuByGroupId(group:getID()) end
    end
    return nil
end
function ctld.MenuManager:getMenuByUnitId(unitId)
    local unit = Unit.getByID(unitId)
    if unit then
        local group = unit:getGroup()
        if group then return self:getMenuByGroupId(group:getID()) end
    end
    return nil
end

-- =============================================================================
-- ctld.Menu — Logical tree model for one group's F10 menu
-- =============================================================================

ctld.Menu = {}

function ctld.Menu:_new(groupId, manager)
    local obj = {
        groupId        = groupId,
        groupName      = manager:_getGroupName(groupId),
        children       = {},   -- root-level nodes (ordered by `order` field at render time)
        _lookup        = {},   -- path string → node (for fast access)
        _rendered      = newRendered(),   -- mirror of the entries live in DCS (RENDERING BY DIFFERENCE)
        manager        = manager,
        nextItemId     = 1,
    }
    setmetatable(obj, { __index = ctld.Menu })
    return obj
end

-- Add a submenu node at pathTable / menuName.
--
-- opts (optional table):
--   order   : number  — position among siblings in the DCS menu (ascending).
--             See ORDER CONVENTION at file top. Recommended: multiples of 10.
--             Without this field the node is appended after all ordered siblings.
--   enabled : boolean — initial DCS visibility (default true).
--             false = node reserved in memory but invisible in DCS until
--             setBranchEnabled(path, true) + refresh() is called.
--
-- Idempotent: if the submenu already exists at that path, returns it unchanged.
function ctld.Menu:addSubMenu(pathTable, menuName, opts)
    pathTable = pathTable or {}
    opts      = opts or {}

    if not menuName or type(menuName) ~= "string" then
        ctld.logWarning("ctld.Menu:addSubMenu: invalid menu name")
        return { success = false, message = "Invalid menu name", subMenuId = nil }
    end

    local parent = self:_findOrCreateNode(pathTable)
    if not parent then
        return { success = false, message = "Path not found: " .. self:_pathToString(pathTable), subMenuId = nil }
    end
    if parent.type == "command" then
        return { success = false, message = "Cannot add submenu under a command node", subMenuId = nil }
    end

    -- Idempotent check: if already exists, update mutable props (order, enabled) if provided.
    for _, child in ipairs(parent.children or {}) do
        if child.name == menuName and child.type == "submenu" then
            if opts.order   ~= nil then child.order   = opts.order end
            if opts.enabled ~= nil then child.enabled = opts.enabled end
            return { success = true, message = "Submenu already exists", subMenuId = child.id }
        end
    end

    local subMenuId = "sub_" .. self.nextItemId
    self.nextItemId = self.nextItemId + 1

    local newNode = {
        id       = subMenuId,
        name     = menuName,
        type     = "submenu",
        children = {},
        -- ORDER: controls position among siblings during DCS render.
        -- Lower values appear higher in the menu (smaller F-key number).
        -- Gaps of 10 allow future insertions without renumbering existing entries.
        order   = opts.order,
        -- ENABLED: false keeps the node in memory (ORDER slot reserved) but
        -- hides it from DCS. Toggle with setBranchEnabled() + refresh().
        enabled = (opts.enabled ~= false),
    }

    if not parent.children then parent.children = {} end
    table.insert(parent.children, newNode)
    self._lookup[self:_buildPathString(pathTable, menuName)] = newNode

    return { success = true, message = "Submenu added", subMenuId = subMenuId }
end

-- Add a command leaf at pathTable / commandName.
-- anyArgument must be a table (or nil → defaults to {}).
function ctld.Menu:addCommand(pathTable, commandName, functionToCall, anyArgument, opts)
    pathTable = pathTable or {}

    if not commandName or type(commandName) ~= "string" then
        ctld.logWarning("ctld.Menu:addCommand: invalid command name")
        return { success = false, message = "Invalid command name", commandId = nil }
    end
    if not functionToCall or type(functionToCall) ~= "function" then
        ctld.logWarning("ctld.Menu:addCommand: invalid function for '%s'", tostring(commandName))
        return { success = false, message = "Invalid function reference", commandId = nil }
    end
    if anyArgument ~= nil and type(anyArgument) ~= "table" then
        ctld.logWarning("ctld.Menu:addCommand: anyArgument must be a table for '%s'", tostring(commandName))
        return { success = false, message = "anyArgument must be a table", commandId = nil }
    end

    local parent = self:_findOrCreateNode(pathTable)
    if not parent then
        return { success = false, message = "Path not found: " .. self:_pathToString(pathTable), commandId = nil }
    end
    if parent.type == "command" then
        return { success = false, message = "Cannot add command under a command node", commandId = nil }
    end

    local commandId = "cmd_" .. self.nextItemId
    self.nextItemId = self.nextItemId + 1

    local newNode = {
        id             = commandId,
        name           = commandName,
        type           = "command",
        functionToCall = functionToCall,
        anyArgument    = anyArgument or {},
        enabled        = true,
        order          = opts and opts.order or nil,
    }

    if not parent.children then parent.children = {} end
    table.insert(parent.children, newNode)
    self._lookup[self:_buildPathString(pathTable, commandName)] = newNode

    return { success = true, message = "Command added", commandId = commandId }
end

-- Empty all children of the node at pathTable WITHOUT removing the node itself.
--
-- Use for dynamic content that must be refreshed (nearby crates, vehicles, etc.):
-- the submenu CONTAINER stays at its ORDER position in its parent, so the
-- F-key slot does not shift when content changes.
--
-- Pattern:
--   menu:clearBranch({"CTLD Commands", "Pack Vehicles"})
--   for _, v in ipairs(nearbyVehicles) do
--       menu:addCommand({"CTLD Commands", "Pack Vehicles"}, v.name, fn, args)
--   end
--   menu:refresh()
function ctld.Menu:clearBranch(pathTable)
    pathTable = pathTable or {}
    local node = self:_getNode(pathTable)
    if not node then
        ctld.logWarning("ctld.Menu:clearBranch: path not found: %s", self:_pathToString(pathTable))
        return { success = false, message = "Path not found" }
    end
    if node.type == "command" then
        return { success = false, message = "Cannot clear a command node" }
    end
    -- Remove child entries from the lookup index.
    self:_cleanupLookup(self:_buildPathString(pathTable, ""))
    -- Wipe children; the node itself remains at its position in its parent's children list.
    node.children = {}
    return { success = true, message = "Branch cleared" }
end

-- Enable or disable the node at pathTable (and its subtree visibility in DCS).
-- The node stays in the memory tree — its ORDER position is preserved.
-- Call refresh() after to apply the change to the live DCS menu.
--
-- Typical use: a mission trigger unlocks a feature mid-mission.
--   menu:setBranchEnabled({"CTLD Commands", "FOB"}, true)
--   menu:refresh()
function ctld.Menu:setBranchEnabled(pathTable, enabled)
    local node = self:_getNode(pathTable)
    if not node then
        ctld.logWarning("ctld.Menu:setBranchEnabled: path not found: %s", self:_pathToString(pathTable))
        return { success = false, message = "Path not found" }
    end
    node.enabled = enabled
    return { success = true }
end

-- Permanently remove the node at pathTable and all its descendants.
-- Frees the ORDER slot in the parent — sibling ORDER values are unaffected but
-- the freed slot will not be visible after the next refresh().
--
-- Prefer clearBranch() for dynamic content and setBranchEnabled() for conditional menus.
-- This method is reserved for truly permanent removals.
function ctld.Menu:removeMenuBranch(pathTable)
    if not pathTable or #pathTable == 0 then
        return { success = false, message = "Cannot remove root menu", removedCount = 0 }
    end

    local parentPath = {}
    for i = 1, #pathTable - 1 do table.insert(parentPath, pathTable[i]) end
    local itemName = pathTable[#pathTable]

    local parent = self:_getNode(parentPath)
    if not parent or not parent.children then
        return { success = false, message = "Path not found: " .. self:_pathToString(pathTable), removedCount = 0 }
    end

    local childIndex = nil
    for i, child in ipairs(parent.children) do
        if child.name == itemName then childIndex = i; break end
    end
    if not childIndex then
        return { success = false, message = "Item not found: " .. itemName, removedCount = 0 }
    end

    local count = self:_countNodeItems(parent.children[childIndex])
    table.remove(parent.children, childIndex)
    self:_cleanupLookup(self:_buildPathString(pathTable, ""))
    return { success = true, message = "Removed branch with " .. count .. " items", removedCount = count }
end

-- Bring the live DCS menu to the memory model, DEBOUNCE_S later (see DEBOUNCED REFRESH).
function ctld.Menu:refresh()
    return self.manager:deferredRefreshForGroup(self.groupId)
end

-- =============================================================================
-- Private helpers
-- =============================================================================

-- Return the node at exactly pathTable, or nil if any segment is missing.
-- Does NOT auto-create nodes.
function ctld.Menu:_getNode(pathTable)
    if not pathTable or #pathTable == 0 then return self end
    local current = self
    for _, segment in ipairs(pathTable) do
        if not current.children then return nil end
        local found = nil
        for _, child in ipairs(current.children) do
            if child.name == segment then found = child; break end
        end
        if not found then return nil end
        current = found
    end
    return current
end

-- Navigate to the node at pathTable, auto-creating missing submenu nodes.
-- Used by addSubMenu / addCommand to ensure intermediate nodes exist.
function ctld.Menu:_findOrCreateNode(pathTable)
    if not pathTable or #pathTable == 0 then return self end
    local current = self
    for _, segment in ipairs(pathTable) do
        if not current.children then current.children = {} end
        local found = nil
        for _, child in ipairs(current.children) do
            if child.name == segment then found = child; break end
        end
        if not found then
            found = { name = segment, type = "submenu", children = {}, enabled = true }
            table.insert(current.children, found)
        end
        current = found
    end
    return current
end

function ctld.Menu:_pathToString(pathTable)
    if not pathTable or #pathTable == 0 then return "/" end
    return table.concat(pathTable, ".")
end

function ctld.Menu:_buildPathString(pathTable, itemName)
    local parts = {}
    for _, p in ipairs(pathTable) do table.insert(parts, p) end
    if itemName and itemName ~= "" then table.insert(parts, itemName) end
    return table.concat(parts, ".")
end

function ctld.Menu:_countNodeItems(node)
    if not node then return 0 end
    local count = 1
    if node.children then
        for _, child in ipairs(node.children) do
            count = count + self:_countNodeItems(child)
        end
    end
    return count
end

function ctld.Menu:_cleanupLookup(pathPrefix)
    for key in pairs(self._lookup) do
        if key:find(pathPrefix, 1, true) == 1 then self._lookup[key] = nil end
    end
end
