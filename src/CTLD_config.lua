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
    -- DEFAULT CONFIGURATION — generated from ctld-config.yaml by ctld-tools
    -- into ctld.__configDefaults (see CTLD_config_defaults.lua, merged before
    -- this file). Edit the YAML, never this block.
    -- ****************************************************************
    for k, v in pairs(ctld.__configDefaults or {}) do
        self.settings[k] = v
    end


    -- ************** AA SYSTEM ASSEMBLY TEMPLATES **********************
    -- Single source of truth for deployable AA systems: parts, assembly rules, AND menu crates.
    -- At init, CTLDCrateAssemblyManager.injectAACrates() reads this table and populates the
    -- spawnableCrates sections automatically — no manual duplication needed.
    --
    -- Field reference:
    --   name           string   display name of the system (used in messages and event data)
    --   count          number   number of unique part types required for a complete system
    --   side           number   coalition owning this system (1=RED, 2=BLUE)
    --   sectionName    string   spawnableCrates section where crate entries will be injected
    --   allCratesLabel string   i18n key for the auto-generated "All crates" mixedSet entry
    --                           (optional — omit to suppress the mixedSet)
    --   parts          array:
    --     DCSTypename  string   DCS type name of the ground unit spawned at assembly
    --     desc         string   i18n key — used for crate menu label AND "Missing X" messages
    --     weight       number   crate weight (kg). Dual role: DCS slingload mass AND unique
    --                           lookup key. MUST be globally unique across all spawnableCrates.
    --                           Omit for NoCrate parts that have no standalone crate at all.
    --     launcher     bool     true = this part triggers rearm detection
    --     amount       number   units spawned per template (default 1; launchers use aaLaunchers)
    --     NoCrate      bool     true = part always present at assembly, not counted in mixedSet.
    --                           Can still carry a weight (spawnable as a standalone crate).
    --     cratesRequired number number of crates of this type needed to unlock the part (default 1)
    --   repair         table:
    --     desc         string   i18n key for repair crate menu label
    --     weight       number   unique crate weight for the repair crate (side = tmpl.side)
    --
    CTLDCrateAssemblyManager.TEMPLATES = {
        {
            name           = "HAWK AA System",
            count          = 5,
            side           = 2,
            sectionName    = "SAM mid range",
            allCratesLabel = "HAWK - All crates",
            parts = {
                { DCSTypename = "Hawk ln",   desc = "HAWK Launcher",     launcher = true, weight = 1004.01 },
                { DCSTypename = "Hawk sr",   desc = "HAWK Search Radar", amount = 2,      weight = 1004.02 },
                { DCSTypename = "Hawk tr",   desc = "HAWK Track Radar",  amount = 2,      weight = 1004.03 },
                { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",          NoCrate = true,  weight = 1004.04 },
                { DCSTypename = "Hawk cwar", desc = "HAWK CWAR",         amount = 2, NoCrate = true, weight = 1004.05 },
            },
            repair = { desc = "HAWK Repair", weight = 1004.06 },
        },
        {
            name           = "NASAMS AA System",
            count          = 3,
            side           = 2,
            sectionName    = "SAM mid range",
            allCratesLabel = "NASAMS - All crates",
            parts = {
                { DCSTypename = "NASAMS_LN_C",          desc = "NASAMS Launcher 120C",     launcher = true, weight = 1004.11 },
                { DCSTypename = "NASAMS_Radar_MPQ64F1", desc = "NASAMS Search/Track Radar",                 weight = 1004.12 },
                { DCSTypename = "NASAMS_Command_Post",  desc = "NASAMS Command Post",                       weight = 1004.13 },
            },
            repair = { desc = "NASAMS Repair", weight = 1004.14 },
        },
        {
            name           = "BUK AA System",
            count          = 3,
            side           = 1,
            sectionName    = "SAM mid range",
            allCratesLabel = "BUK - All crates",
            parts = {
                { DCSTypename = "SA-11 Buk LN 9A310M1", desc = "BUK Launcher",     launcher = true, weight = 1004.31 },
                { DCSTypename = "SA-11 Buk SR 9S18M1",  desc = "BUK Search Radar",                  weight = 1004.32 },
                { DCSTypename = "SA-11 Buk CC 9S470M1", desc = "BUK CC Radar",                      weight = 1004.33 },
            },
            repair = { desc = "BUK Repair", weight = 1004.34 },
        },
        {
            name           = "KUB AA System",
            count          = 2,
            side           = 1,
            sectionName    = "SAM mid range",
            allCratesLabel = "KUB - All crates",
            parts = {
                { DCSTypename = "Kub 2P25 ln",  desc = "KUB Launcher", launcher = true, weight = 1004.21 },
                { DCSTypename = "Kub 1S91 str", desc = "KUB Radar",                     weight = 1004.22 },
            },
            repair = { desc = "KUB Repair", weight = 1004.23 },
        },
        {
            name           = "Patriot AA System",
            count          = 4,
            side           = 2,
            sectionName    = "SAM long range",
            allCratesLabel = "Patriot - All crates",
            parts = {
                { DCSTypename = "Patriot ln",  desc = "Patriot Launcher",        launcher = true, amount = 8, weight = 1005.01 },
                { DCSTypename = "Patriot str", desc = "Patriot Radar",           amount = 2,                  weight = 1005.02 },
                { DCSTypename = "Patriot ECS", desc = "Patriot ECS",                                          weight = 1005.03 },
                { DCSTypename = "Patriot AMG", desc = "Patriot AMG (optional)",  NoCrate = true,              weight = 1005.06 },
            },
            repair = { desc = "Patriot Repair", weight = 1005.07 },
        },
        {
            name           = "S-300 AA System",
            count          = 6,
            side           = 1,
            sectionName    = "SAM long range",
            allCratesLabel = "S-300 - All crates",
            parts = {
                { DCSTypename = "S-300PS 5P85C ln",  desc = "S-300 Grumble TEL C",         launcher = true, amount = 1, weight = 1005.11 },
                { DCSTypename = "S-300PS 5P85D ln",  desc = "S-300 Grumble TEL D",         NoCrate = true,  amount = 2 },   -- no standalone crate
                { DCSTypename = "S-300PS 40B6M tr",  desc = "S-300 Grumble Flap Lid-A TR",                             weight = 1005.12 },
                { DCSTypename = "S-300PS 40B6MD sr", desc = "S-300 Grumble Clam Shell SR",                             weight = 1005.13 },
                { DCSTypename = "S-300PS 64H6E sr",  desc = "S-300 Grumble Big Bird SR",                               weight = 1005.14 },
                { DCSTypename = "S-300PS 54K6 cp",   desc = "S-300 Grumble C2",                                        weight = 1005.15 },
            },
            repair = { desc = "S-300 Repair", weight = 1005.16 },
        },
    }

    -- ******************************************************************
    -- ****************** END OF CONFIGURATION AREA *********************
    -- ******************************************************************

    -- overwrite defaults settings from CTLD_userConfig.lua --------------------------------------------
    if ctld.yamlConfigDatas then
        local userConfigTable = CTLDConfig.parseYAML(ctld.yamlConfigDatas) -- get user config coming from CTLD_userConfig.lua execution in ME

        local report = "REPORT - CTLD user config loaded :"
        for k, v in pairs(userConfigTable) do
            local tableName, fieldName = k:match("([^%.]+)%.(.+)") -- extract key after "ctld."
            if tableName == "ctld" then                            -- load general settings
                self.settings[fieldName] =
                    v                                              -- fix: use variable fieldName, not literal "fieldName"
                report = report .. "\nctld." .. fieldName .. " = " .. tostring(v)
            end
        end
        return true, report
    else
        if self.settings["debug"] then
            ctld.utils.log("WARN", "CTLDConfig: No YAML config data found in ctld.yamlConfigDatas")
        end
    end

    -- Temporary: Loading old ctld settings variables for backward compatibility
    if ctld ~= nil then
        for k, v in pairs(CTLDConfig.getAllSettings()) do
            if self.settings[k] ~= nil then
                ctld[k] = v -- set old ctld variables
            end
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
