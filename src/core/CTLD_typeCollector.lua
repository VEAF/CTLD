---@diagnostic disable
-- CTLD_typeCollector.lua
-- CTLDTypeCollector — single source of truth for "which DCS type names does this mission configure,
-- and which are declared non-stock (mod) types". Consumed at design time by the busted config/scene
-- gates and at dev-time by the optional companion validator (ASSET-VALIDATION-REVAMP). Pure lookup,
-- no spawning.
--
-- Dependencies: ctld.gs, CTLDObjectRegistry, CTLDSceneManager, CTLDCrateAssemblyManager (all read).
-- ====================================================================================================

CTLDTypeCollector = {}

--- DCS type names a single registry descriptor spawns.
--   STATIC : desc.type
--   GROUND : desc.units[i].unitType(coalitionId) for RED/BLUE (a per-coalition function), or a
--            static desc.units[i].type as a fallback.
-- @param desc table  a CTLDObjectRegistry descriptor
-- @return table  array of type-name strings (deduplicated)
function CTLDTypeCollector.typesOfDescriptor(desc)
    local out, seen = {}, {}
    if type(desc) ~= "table" then return out end
    local function push(tn)
        if type(tn) == "string" and tn ~= "" and not seen[tn] then
            seen[tn] = true
            out[#out + 1] = tn
        end
    end
    if desc.groupType == "STATIC" then
        push(desc.type)
    elseif desc.groupType == "GROUND" and type(desc.units) == "table" then
        for _, u in ipairs(desc.units) do
            if type(u) == "table" then
                if type(u.unitType) == "function" then
                    for _, cid in ipairs({ 1, 2 }) do
                        local ok, tn = pcall(u.unitType, cid)
                        if ok then push(tn) end
                    end
                else
                    push(u.type)
                end
            end
        end
    end
    return out
end

--- Collect every configured DCS type name and the declared non-stock (mod) type set.
-- @return table {
--   types  = { [typeName] = { sources = { "Registry[..]", "spawnableCrates[..]", … } } },
--   extras = { [typeName] = true },   -- scene model.modTypes ∪ ctld.gs("modTypes")
-- }
function CTLDTypeCollector.collect()
    local types = {}
    local function add(name, source)
        if type(name) ~= "string" or name == "" then return end
        local e = types[name]
        if not e then e = { sources = {} }; types[name] = e end
        e.sources[#e.sources + 1] = source
    end

    local sm = (type(CTLDSceneManager) == "table") and CTLDSceneManager.getInstance() or nil

    -- 1. Object registry (scene props, crate statics, troop groups…)
    if type(CTLDObjectRegistry) == "table" and type(CTLDObjectRegistry._db) == "table" then
        for regKey, desc in pairs(CTLDObjectRegistry._db) do
            for _, tn in ipairs(CTLDTypeCollector.typesOfDescriptor(desc)) do
                add(tn, "Registry[" .. tostring(regKey) .. "]")
            end
        end
    end

    -- 2. spawnableCrates — skip scene sentinels, repair entries and aircraft.
    local buildable = ctld.gs("spawnableCrates") or {}
    for sectionName, items in pairs(buildable) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if type(item) == "table" and item.unit then
                    local isScene = sm and (sm:getModel(item.unit) ~= nil)
                    if not isScene and not item._repairFor and not item.spawnAs then
                        add(item.unit, "spawnableCrates[" .. tostring(sectionName) .. "]")
                    end
                end
            end
        end
    end

    -- 3. AA system templates (CTLDCrateAssemblyManager.TEMPLATES)
    local aaTmpls = (type(CTLDCrateAssemblyManager) == "table")
        and CTLDCrateAssemblyManager.TEMPLATES or {}
    for _, tmpl in ipairs(aaTmpls) do
        if type(tmpl) == "table" and type(tmpl.parts) == "table" then
            for _, part in ipairs(tmpl.parts) do
                if type(part) == "table" and part.DCSTypename then
                    add(part.DCSTypename, "AASystem[" .. tostring(tmpl.name) .. "]")
                end
            end
        end
    end

    -- 4. loadableGroups[].componentTypes (custom troop roles)
    local loadable = ctld.gs("loadableGroups") or {}
    for _, tmpl in ipairs(loadable) do
        if type(tmpl) == "table" and type(tmpl.componentTypes) == "table" then
            for _, coaTable in pairs(tmpl.componentTypes) do
                if type(coaTable) == "table" then
                    for _, tn in pairs(coaTable) do
                        add(tn, "loadableGroups[" .. tostring(tmpl.name) .. "]")
                    end
                end
            end
        end
    end

    -- Build a set of AA system template names to skip when scanning vehicleStock
    -- (vehicleStock keys can be scene names, AA template names, or real DCS typeNames).
    local aaTemplateNames = {}
    for _, tmpl in ipairs(aaTmpls) do
        if type(tmpl) == "table" and type(tmpl.name) == "string" then
            aaTemplateNames[tmpl.name] = true
        end
    end

    -- 5+7. aiZones[*].vehicleStock (keys) and aiZones[*].vehicleTypes (array) — DCS unit typeNames
    --      vehicleStock: skip scene model names and AA system template names (not DCS unit types).
    local aiZones = ctld.gs("aiZones") or {}
    for _, entry in ipairs(aiZones) do
        if type(entry) == "table" then
            local zoneName = tostring(entry.dcsZoneName or "?")
            if type(entry.vehicleStock) == "table" then
                for tn in pairs(entry.vehicleStock) do
                    if type(tn) == "string" then
                        local isScene = sm and (sm:getModel(tn) ~= nil)
                        if not isScene and not aaTemplateNames[tn] then
                            add(tn, "aiZones[" .. zoneName .. "].vehicleStock")
                        end
                    end
                end
            end
            if type(entry.vehicleTypes) == "table" then
                for _, tn in ipairs(entry.vehicleTypes) do
                    if type(tn) == "string" then
                        add(tn, "aiZones[" .. zoneName .. "].vehicleTypes")
                    end
                end
            end
        end
    end

    -- 6. capabilitiesByType[*].loadableVehiclesRED/BLUE — arrays of DCS unit typeNames
    local capsByType = ctld.gs("capabilitiesByType") or {}
    for transportType, c in pairs(capsByType) do
        if type(c) == "table" then
            local pfx = "capabilitiesByType[" .. tostring(transportType) .. "]"
            for _, tn in ipairs(c.loadableVehiclesRED  or {}) do add(tn, pfx .. ".loadableVehiclesRED")  end
            for _, tn in ipairs(c.loadableVehiclesBLUE or {}) do add(tn, pfx .. ".loadableVehiclesBLUE") end
        end
    end

    -- Declared non-stock types: scene model.modTypes ∪ the mission-maker config whitelist.
    local extras = {}
    if sm and type(sm._models) == "table" then
        for _, model in pairs(sm._models) do
            if type(model.modTypes) == "table" then
                for _, tn in ipairs(model.modTypes) do
                    if type(tn) == "string" then extras[tn] = true end
                end
            end
        end
    end
    local cfgMods = ctld.gs("modTypes") or {}
    if type(cfgMods) == "table" then
        for _, tn in ipairs(cfgMods) do
            if type(tn) == "string" then extras[tn] = true end
        end
    end

    return { types = types, extras = extras }
end
