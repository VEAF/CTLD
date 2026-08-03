---@diagnostic disable
-- tests/ci/helpers/settings.lua
-- Borrow a setting for the duration of one spec, and give it back.
--
-- FIX-SPEC-ISOLATION. `CTLDConfig.get().settings` is the live table the engine reads, shared by
-- every spec in the process. A spec that writes into it and walks away changes what the specs
-- *after* it see — and which specs those are is not knowable: busted takes the order the filesystem
-- gives (a directory hash on Linux), and it is not stable between runs.
--
-- Measured before this helper existed: running `tests/ci/unit/` in reverse filename order failed
-- **29 tests**, all of them reading `capabilitiesByType` after `troop_manager_spec` had set it to
-- nil. The forward run was green, which is why CI caught it and the local runner did not.
--
-- Usage — capture in `before_each`, release in `after_each`:
--
--     local settings = dofile("tests/ci/helpers/settings.lua")   -- or require via the init helper
--
--     local borrowed
--     before_each(function()
--         borrowed = settings.borrow({ loadableGroups = {}, capabilitiesByType = nil })
--     end)
--     after_each(function() borrowed:restore() end)
--
-- `restore()` puts back exactly what was there when `borrow()` ran — not the catalogue default,
-- because a spec may legitimately run inside another fixture's values. Absent stays absent: a key
-- that was nil is deleted again rather than written as nil, which for a list the engine walks with
-- `ipairs` is not the same thing.

local M = {}

local NIL = {}   -- sentinel: "this key was absent", distinct from "this key held nil"

--- Set `values` on the live settings table and return a handle that restores the previous state.
-- @param values table  { [settingName] = newValue }; use `M.ABSENT` to delete a key
-- @return table  handle with a `restore()` method
function M.borrow(values)
    local settings = CTLDConfig.get().settings
    local saved = {}
    for key in pairs(values) do
        local current = settings[key]
        saved[key] = (current == nil) and NIL or current
    end
    -- A second pass to write: `values` may carry a key whose new value is M.ABSENT, and reading
    -- every old value first keeps the two phases independent of table iteration order.
    for key, value in pairs(values) do
        settings[key] = (value == M.ABSENT) and nil or value
    end
    return {
        restore = function()
            for key, old in pairs(saved) do
                settings[key] = (old == NIL) and nil or old
            end
        end,
    }
end

--- Marker for "delete this key" — `borrow{ capabilitiesByType = settings.ABSENT }`.
-- A plain `nil` in a table literal is indistinguishable from an absent field, so callers that need
-- to *remove* a setting have to say so explicitly.
M.ABSENT = setmetatable({}, { __tostring = function() return "<absent>" end })

return M
