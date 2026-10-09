---@diagnostic disable
-- tests/ci/helpers/mission_commands_double.lua
-- A missionCommands double that hands out entry ids the way DCS was measured to (#257, 2026-10-09):
--   - every entry gets an internal id; an untouched entry keeps its id whatever happens around it;
--   - one id pool for the whole server (global and every group menu share it);
--   - a removed entry's id goes to the next entry created, last freed first reused.
-- A spec captures an id with idOf() before a refresh, then click()s it after: the click runs whatever
-- entry holds that id now, which is what a player gets from an F10 screen left open across a change.
--
-- Usage:
--   local mc = ctldMissionCommandsDouble.install()
--   ...
--   mc:uninstall()   -- in after_each: puts the previous missionCommands functions back
-- ============================================================

local Double = {}
Double.__index = Double

local function pathKey(gid, path)
    return tostring(gid) .. "\n" .. table.concat(path, "\n")
end

local function copyPath(path, name)
    local p = {}
    for _, seg in ipairs(path or {}) do table.insert(p, seg) end
    if name then table.insert(p, name) end
    return p
end

local function isPrefix(prefix, path)
    if #prefix >= #path then return false end
    for i = 1, #prefix do
        if prefix[i] ~= path[i] then return false end
    end
    return true
end

function Double:_allocate()
    if #self.free > 0 then
        return table.remove(self.free)   -- last freed, first reused
    end
    self.nextId = self.nextId + 1
    return self.nextId
end

function Double:_add(kind, gid, name, parentPath, fn, arg)
    local id = self:_allocate()
    self.seq = self.seq + 1
    local entry = {
        id = id, kind = kind, gid = gid, name = name,
        path = copyPath(parentPath, name), fn = fn, arg = arg, seq = self.seq,
    }
    self.entries[id] = entry
    table.insert(self.calls, { op = "add", kind = kind, gid = gid, name = name, id = id })
    return copyPath(entry.path)   -- DCS returns the item's path, which is its handle
end

-- The live entry at gid + path; with twins, the oldest one.
function Double:_find(gid, path)
    local key, best = pathKey(gid, path), nil
    for _, e in pairs(self.entries) do
        if pathKey(e.gid, e.path) == key and (not best or e.seq < best.seq) then best = e end
    end
    return best
end

function Double:_free(entry)
    self.entries[entry.id] = nil
    table.insert(self.free, entry.id)
end

function Double:_remove(gid, path)
    table.insert(self.calls, { op = "remove", gid = gid, name = path and path[#path] })
    local entry = path and self:_find(gid, path)
    if not entry then return end
    -- A submenu goes with its descendants: free them first, deepest first, then the submenu.
    local descendants = {}
    for _, e in pairs(self.entries) do
        if e.gid == gid and isPrefix(entry.path, e.path) then table.insert(descendants, e) end
    end
    table.sort(descendants, function(a, b)
        if #a.path ~= #b.path then return #a.path > #b.path end
        return a.seq < b.seq
    end)
    for _, e in ipairs(descendants) do self:_free(e) end
    self:_free(entry)
end

-- Id of the live entry at gid + full path (labels from the root), or nil.
function Double:idOf(gid, path)
    local e = self:_find(gid, path)
    return e and e.id
end

-- The live entry holding `id` now, or nil.
function Double:entry(id)
    return self.entries[id]
end

-- Click the F10 entry that held `id` when the screen was drawn: runs whatever command holds the id
-- now. Returns that entry (nil when the id is free).
function Double:click(id)
    local e = self.entries[id]
    if e and e.kind == "command" and e.fn then e.fn(e.arg) end
    return e
end

-- Labels of the live children of gid + parentPath, in DCS display order (creation order).
function Double:labels(gid, parentPath)
    parentPath = parentPath or {}
    local kids = {}
    for _, e in pairs(self.entries) do
        if e.gid == gid and #e.path == #parentPath + 1 and (#parentPath == 0 or isPrefix(parentPath, e.path)) then
            table.insert(kids, e)
        end
    end
    table.sort(kids, function(a, b) return a.seq < b.seq end)
    local out = {}
    for _, e in ipairs(kids) do table.insert(out, e.name) end
    return out
end

-- Number of live entries for gid.
function Double:count(gid)
    local n = 0
    for _, e in pairs(self.entries) do
        if e.gid == gid then n = n + 1 end
    end
    return n
end

-- Calls recorded since the last resetCalls(), optionally filtered on op ("add" / "remove") and gid.
function Double:callCount(op, gid)
    local n = 0
    for _, c in ipairs(self.calls) do
        if (not op or c.op == op) and (gid == nil or c.gid == gid) then n = n + 1 end
    end
    return n
end

function Double:resetCalls()
    self.calls = {}
end

function Double:uninstall()
    for k, v in pairs(self.saved) do missionCommands[k] = v end
end

local M = {}

function M.install()
    local d = setmetatable({ entries = {}, free = {}, nextId = 0, seq = 0, calls = {}, saved = {} }, Double)
    for _, k in ipairs({ "addSubMenuForGroup", "addCommandForGroup", "removeItemForGroup" }) do
        d.saved[k] = missionCommands[k]
    end
    missionCommands.addSubMenuForGroup = function(gid, name, path)
        return d:_add("submenu", gid, name, path)
    end
    missionCommands.addCommandForGroup = function(gid, name, path, fn, arg)
        return d:_add("command", gid, name, path, fn, arg)
    end
    missionCommands.removeItemForGroup = function(gid, path)
        d:_remove(gid, path)
    end
    return d
end

return M
