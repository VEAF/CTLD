-- CTLDConfig Singleton Class
-- src version — do not edit source/ original
ctld = ctld or {}

ctld.VERSION = "2.0.0-rc1"

CTLDConfig = {}
CTLDConfig._instance = nil

-- Get the unique instance of the config
function CTLDConfig.get()
    if CTLDConfig._instance == nil then
        CTLDConfig._instance = setmetatable({}, { __index = CTLDConfig })
        CTLDConfig._instance.settings = {}
        CTLDConfig._instance.isLoaded = false
    end
    return CTLDConfig._instance
end

-- Load settings from the text file
function CTLDConfig:load()
    if self.isLoaded then
        return true, "CTLDConfig: Configuration already loaded."
    end
    self.isLoaded                                       = true

    -- ****************************************************************
    -- COMPLETE CONFIGURATION (ADR 0011) — resolve the winning YAML snapshot and
    -- parse it whole. ctld.configUser (a full mission snapshot) wins over
    -- ctld.configDefault (the engine YAML embedded verbatim by the build). NO merge:
    -- a missing element is intentionally absent at runtime.
    -- ****************************************************************
    local usingUser = ctld.configUser ~= nil
    local parsed = CTLDConfig.parseYAML(ctld.configUser or ctld.configDefault or "")

    -- Merge the readability sections (mm_facing / advanced) into one flat map, plus any
    -- top-level keys outside the sections (e.g. configVersion).
    local flat = {}
    for _, section in ipairs({ "mm_facing", "advanced" }) do
        for k, v in pairs(parsed[section] or {}) do
            flat[k] = v
        end
    end
    for k, v in pairs(parsed) do
        if k ~= "mm_facing" and k ~= "advanced" then
            flat[k] = v
        end
    end

    -- A configUser that parses to nothing is malformed. ctld-tools validates the
    -- snapshot before use, so this is a hard error — no silent fallback to defaults.
    if usingUser and next(flat) == nil then
        error("CTLDConfig: ctld.configUser is malformed or empty — aborting load. "
            .. "Validate the snapshot with ctld-tools before use.")
    end

    -- Localise i18n labels: every desc/name string is an i18n key (mirrors the
    -- gen-config _I18N_FIELDS wrapping, so runtime labels match in every language).
    CTLDConfig.localiseI18n(flat)

    for k, v in pairs(flat) do
        self.settings[k] = v
    end

    return true, "CTLDConfig: loaded (" .. (usingUser and "user" or "default") .. " config)."
end

-- Localise i18n labels in place: apply ctld.tr() to every string value stored under
-- a "desc" or "name" key, at any depth. Mirrors ctld-tools gen-config _I18N_FIELDS,
-- so runtime labels match the former generated defaults in every language.
function CTLDConfig.localiseI18n(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            CTLDConfig.localiseI18n(v)
        elseif (k == "desc" or k == "name") and type(v) == "string" and ctld.tr then
            t[k] = ctld.tr(v)
        end
    end
end

-- Retrieve a specific setting
function CTLDConfig:getSetting(key)
    return self.settings[key]
end

-- Retrieve a specific setting
function CTLDConfig.getAllSettings()
    return CTLDConfig._instance.settings
end

-- Retrieve a specific setting
function CTLDConfig:setSetting(key, value)
    self.settings[key] = value
    return self.settings[key]
end

------------------------------------------------------------------
-- yaml parsing utilities
------------------------------------------------------------------
-- Utility: Trims whitespace from both ends of a string
-- @param s: The raw string to trim
function CTLDConfig.trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Utility: Converts string values to their appropriate Lua types
-- @param v: The string value to convert
function CTLDConfig.to_type(v)
    if v == "true" then return true end
    if v == "false" then return false end
    if tonumber(v) then return tonumber(v) end
    return v:gsub("^['\"]", ""):gsub("['\"]$", "")
end

-- Utility: Converts a scalar YAML token to a Lua value.
-- Inline empty collections ("{}" / "[]") become empty tables; everything else
-- goes through to_type (bool / number / quote-stripped string).
-- @param v: The trimmed scalar token
function CTLDConfig.scalar(v)
    if v == "{}" or v == "[]" then return {} end
    return CTLDConfig.to_type(v)
end

-- Main Parser: Converts a block-style YAML string into a Lua table.
-- Supports the constructs the CTLD config catalogue relies on: nested maps,
-- block sequences (indented at their key's column), sequences of maps,
-- sequences of sequences (`- - x`), inline empty `{}`/`[]`, and quoted scalars.
-- Lua 5.1, dependency-free. Keys and structure are preserved verbatim (the
-- mm_facing / advanced section split is merged by the caller, not here).
function CTLDConfig.parseYAML(data)
    local result = {}
    -- Frame = {indent=<column of this container's direct children>, node=<table>, isSeq=<bool>}
    local stack = { { indent = 0, node = result, isSeq = false } }
    -- pending = a map key whose child container is not yet materialised; the next
    -- line decides map vs seq: {frame=<map frame>, key=<str>, col=<key column>}
    local pending = nil

    local function top() return stack[#stack] end

    local function openPending(isSeq, childIndent)
        local node = {}
        pending.frame.node[pending.key] = node
        stack[#stack + 1] = { indent = childIndent, node = node, isSeq = isSeq }
        pending = nil
    end

    for rawline in data:gmatch("[^\r\n]+") do
        local indent = #(rawline:match("^ *"))
        local content = rawline:sub(indent + 1):gsub("%s+$", "")

        if content ~= "" and content:sub(1, 1) ~= "#" then
            -- Peel leading "- " dashes; each one is a sequence level.
            local dashCols = {}
            local col = indent
            while content == "-" or content:sub(1, 2) == "- " do
                dashCols[#dashCols + 1] = col
                if content == "-" then
                    content, col = "", col + 1
                else
                    content, col = content:sub(3), col + 2
                end
            end

            -- STEP A — resolve a pending map key using this line's geometry.
            if pending then
                if #dashCols > 0 and dashCols[1] >= pending.col then
                    openPending(true, dashCols[1])                 -- block sequence
                elseif col > pending.col then
                    openPending(false, col)                        -- nested map
                else
                    pending = nil                                  -- childless key: stays {}
                end
            end

            -- STEP B — pop frames deeper than where this line anchors. A dash seeks
            -- a sequence at its column; a mapping key seeks a map at its column and
            -- must also pop a sibling sequence sharing that indent.
            if #dashCols > 0 then
                local anchor = dashCols[1]
                while #stack > 1 and top().indent > anchor do
                    stack[#stack] = nil
                end
            else
                local anchor = col
                while #stack > 1 and (top().indent > anchor
                    or (top().indent == anchor and top().isSeq)) do
                    stack[#stack] = nil
                end
            end

            -- STEP C — ensure a sequence frame exists for each dash level.
            for di = 1, #dashCols do
                local dcol = dashCols[di]
                if not (top().isSeq and top().indent == dcol) then
                    local seqNode = {}
                    local parent = top()
                    if parent.isSeq then
                        parent.node[#parent.node + 1] = seqNode
                    end
                    stack[#stack + 1] = { indent = dcol, node = seqNode, isSeq = true }
                end
            end

            -- STEP D — handle the remainder at column `col`.
            if content ~= "" then
                local k, v = content:match("^([^:]+):%s*(.*)$")
                if k ~= nil and content:find(":") then
                    k = k:gsub("%s+$", "")
                    if #dashCols > 0 then
                        -- "- key: ..." → a new map item inside the current sequence
                        local mapNode = {}
                        local s = top()
                        s.node[#s.node + 1] = mapNode
                        stack[#stack + 1] = { indent = col, node = mapNode, isSeq = false }
                        if v == "" then
                            pending = { frame = top(), key = k, col = col }
                        else
                            mapNode[k] = CTLDConfig.scalar(v)
                        end
                    else
                        local s = top()
                        if v == "" then
                            s.node[k] = {}
                            pending = { frame = s, key = k, col = indent }
                        else
                            s.node[k] = CTLDConfig.scalar(v)
                        end
                    end
                else
                    -- pure scalar → sequence item
                    local s = top()
                    if s.isSeq then
                        s.node[#s.node + 1] = CTLDConfig.scalar(content)
                    end
                end
            end
        end
    end

    return result
end

local config = CTLDConfig.get() -- get the singleton instance

-- Global shortcut for config access.
-- Usage: ctld.gs("paramName")  instead of  CTLDConfig.get():getSetting("paramName")
-- This is the ONLY authorised form to read config parameters throughout src/.
function ctld.gs(key)
    return CTLDConfig.get():getSetting(key)
end

--[[
------------------------------------------------------------------
-- Example: At start of CTLD initialization : Load ctld user config from CTLD_userConfig.lua
-- and set the ctld settings accordingly
-- ctld.yamlConfigDatas must be loaded beforehand by executing CTLD_userConfig.lua in the mission editor
-- with a trigger at START MISSION in "DO SCRIPT FILE" action
------------------------------------------------------------------

local myConfig = CTLDConfig.get()   -- Get the singleton instance
local success, report = myConfig:load()   -- Load the data from your specific path
if success then
    trigger.action.outText(report, 10)    -- Display the result if loading was successful
end

--At this stage, the ctld configuration settings are loaded with the user's values.


------------------------------------------------------------------
--- How to use the CTLDConfig singleton class in your scripts
--- to get ex "ctld.maximumDistanceLogistic = 200" value
------------------------------------------------------------------
local config = CTLDConfig.get()                                        -- get the singleton instance
local maximumDistanceLogistic = config:getSetting("maximumDistanceLogistic")  -- retrieve specific setting
-- Now you can use maximumDistanceLogistic in your script

-- You can also modify settings:
config:setSetting("maximumDistanceLogistic", 250)

-- To completely reset the singleton (useful for testing):
CTLDConfig.reset()  -- class method (dot notation)
]] --
