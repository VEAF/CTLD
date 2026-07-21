-- ============================================================
-- CTLD_userSetup.lua
-- Mission Maker configuration helper API (FEAT-USERCONFIG-API).
--
-- Surgical add/remove/patch operations on the live config, meant to be called
-- from `ctld.userSetup` callbacks. The bootstrap runs those callbacks after
-- CTLDConfig:load() and injectAACrates(), so AA entries are already present and
-- the whole default catalogue is patchable.
--
--   ctld.userSetup = ctld.userSetup or {}
--   table.insert(ctld.userSetup, function(cfg)
--       ctld.addCrate("Support", { weight = 2000.01, desc = "My Unit", unit = "Ural-375", side = 1 })
--       ctld.patchCrate(1001.01, { cratesRequired = 3 })
--   end)
--
-- Merged after CTLD_config.lua. Defines functions only — the ctld.utils.* calls
-- resolve at callback time (runtime), so load order beyond `ctld` is irrelevant.
-- ============================================================

ctld = ctld or {}

-- Live settings table of the config singleton.
local function _settings()
    return CTLDConfig.get().settings
end

-- Locate a crate entry by weight across all spawnableCrates sections.
-- Returns entry, sectionTable, index (or nil).
local function _findCrate(weight)
    local crates = _settings()["spawnableCrates"]
    if type(crates) ~= "table" then return nil end
    for _, entries in pairs(crates) do
        for i, e in ipairs(entries) do
            if e.weight == weight then return e, entries, i end
        end
    end
    return nil
end

--- Add a crate entry to a spawnableCrates section (section created if absent).
-- A duplicate weight is fatal (irrecoverable F10-menu corruption): the entry is
-- rejected with a visible warning, but the mission is NOT aborted.
---@param section string
---@param entry table
---@return boolean added
function ctld.addCrate(section, entry)
    local crates = _settings()["spawnableCrates"]
    if type(crates) ~= "table" then
        ctld.logWarning("ctld.addCrate: spawnableCrates unavailable — entry rejected")
        return false
    end
    if entry and entry.weight and _findCrate(entry.weight) then
        local msg = string.format(
            "CTLD userConfig: duplicate crate weight %s — entry rejected", tostring(entry.weight))
        ctld.logWarning("ctld.addCrate: %s", msg)
        if trigger and trigger.action and trigger.action.outText then
            trigger.action.outText(msg, 30)
        end
        return false
    end
    crates[section] = crates[section] or {}
    table.insert(crates[section], entry)
    return true
end

--- Remove a crate entry by weight (searched across all sections).
---@param weight number
---@return boolean removed
function ctld.removeCrate(weight)
    local _, entries, idx = _findCrate(weight)
    if not entries then
        ctld.logWarning("ctld.removeCrate: no crate with weight %s — nothing removed", tostring(weight))
        return false
    end
    table.remove(entries, idx)
    return true
end

--- Patch a crate entry found by weight. Shallow merge at the top level, plus a
-- one-level deep merge for table-valued fields (e.g. specificParams), so a single
-- nested field can be changed without rewriting the whole sub-table.
---@param weight number
---@param patch table
---@return boolean patched
function ctld.patchCrate(weight, patch)
    local entry = _findCrate(weight)
    if not entry then
        ctld.logWarning("ctld.patchCrate: no crate with weight %s — nothing patched", tostring(weight))
        return false
    end
    for k, v in pairs(patch or {}) do
        if type(v) == "table" and type(entry[k]) == "table" then
            for kk, vv in pairs(v) do
                entry[k][kk] = vv
            end
        else
            entry[k] = v
        end
    end
    return true
end

--- Add an infantry group template to loadableGroups.
---@param entry table
---@return boolean added
function ctld.addTroopGroup(entry)
    local groups = _settings()["loadableGroups"]
    if type(groups) ~= "table" then
        ctld.logWarning("ctld.addTroopGroup: loadableGroups unavailable — entry rejected")
        return false
    end
    table.insert(groups, entry)
    return true
end

--- Remove an infantry group template by name.
---@param name string
---@return boolean removed
function ctld.removeTroopGroup(name)
    local groups = _settings()["loadableGroups"]
    if type(groups) == "table" then
        for i, g in ipairs(groups) do
            if g.name == name then
                table.remove(groups, i)
                return true
            end
        end
    end
    ctld.logWarning("ctld.removeTroopGroup: no group named '%s' — nothing removed", tostring(name))
    return false
end

--- Patch an infantry group template found by name. Shallow merge at the top level,
-- plus a one-level deep merge for table-valued fields — mirrors patchCrate, so a
-- single field can be changed without rewriting the whole group.
---@param name string
---@param patch table
---@return boolean patched
function ctld.patchTroopGroup(name, patch)
    local groups = _settings()["loadableGroups"]
    if type(groups) == "table" then
        for _, g in ipairs(groups) do
            if g.name == name then
                for k, v in pairs(patch or {}) do
                    if type(v) == "table" and type(g[k]) == "table" then
                        for kk, vv in pairs(v) do
                            g[k][kk] = vv
                        end
                    else
                        g[k] = v
                    end
                end
                return true
            end
        end
    end
    ctld.logWarning("ctld.patchTroopGroup: no group named '%s' — nothing patched", tostring(name))
    return false
end

--- Append an entry to an array-type setting (transportPilotNames, troopZones,
-- wpZones, extractableGroups, logisticUnits, ...).
---@param settingName string
---@param entry any
---@return boolean added
function ctld.addTo(settingName, entry)
    local value = _settings()[settingName]
    if type(value) ~= "table" then
        ctld.logWarning("ctld.addTo: setting '%s' is not an array — nothing added", tostring(settingName))
        return false
    end
    table.insert(value, entry)
    return true
end

--- Serialise a config setting to CTLD.log in copy-pasteable Lua form, so the MM
-- can inspect the real defaults at runtime. Intended to be called from a ME
-- DO SCRIPT trigger a few seconds after mission start.
---@param settingName string
function ctld.logDefaults(settingName)
    local value = ctld.gs(settingName)
    if value == nil then
        ctld.logWarning("ctld.logDefaults: unknown setting '%s'", tostring(settingName))
        return
    end
    local out
    if type(value) == "table" then
        out = ctld.utils.tableShowScript("ctld.logDefaults", value, settingName)
    else
        out = settingName .. " = " .. ctld.utils.basicSerialize("ctld.logDefaults", value)
    end
    ctld.utils.log("INFO", "ctld.logDefaults(%s):\n%s", tostring(settingName), out)
end

--- Run every registered ctld.userSetup callback, in registration order, against the
-- live config singleton. Each callback is guarded so a failure in one is reported
-- and neither aborts the other callbacks nor the mission (FEAT-USERCONFIG-API US 11).
-- Called by ctld.initialize() after injectAACrates and before the managers boot.
function ctld.runUserSetup()
    local callbacks = ctld.userSetup or {}
    local cfg = CTLDConfig.get()
    for i, cb in ipairs(callbacks) do
        if type(cb) == "function" then
            local ok, err = pcall(cb, cfg)
            if not ok then
                ctld.logWarning("ctld.userSetup callback #%d failed: %s", i, tostring(err))
            end
        else
            ctld.logWarning("ctld.userSetup entry #%d is not a function — skipped", i)
        end
    end
end
