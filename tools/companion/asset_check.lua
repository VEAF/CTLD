---@diagnostic disable
-- tools/companion/asset_check.lua
-- Dev-time asset validator (the CTLD_plugins-style companion). Built into
-- dist/CTLD_asset_check.lua by tools/companion/build_companion.ps1 (prepends the datamine stock-type
-- set as `_CTLD_STOCK_TYPES`). A mission maker loads the built file from a MISSION START trigger,
-- AFTER CTLD, DURING DEVELOPMENT: it cross-checks every configured DCS type against
-- `datamine ∪ declared mod types` and WARNs on unknowns. No instantiation, no events. Remove it for
-- production.
-- ====================================================================================================

--- Pure check: configured types that are neither stock nor a declared extra (mod).
-- @param stock   table  { [typeName] = true } stock DCS types (the datamine set)
-- @param result  table  CTLDTypeCollector.collect() → { types = {name={sources}}, extras = {name} }
-- @return table  sorted array of { type = string, sources = {string,...} }
function _CTLD_assetCheck(stock, result)
    stock = stock or {}
    local types  = (result and result.types)  or {}
    local extras = (result and result.extras) or {}
    local unknown = {}
    for t, e in pairs(types) do
        if not stock[t] and not extras[t] then
            unknown[#unknown + 1] = { type = t, sources = (e and e.sources) or {} }
        end
    end
    table.sort(unknown, function(a, b) return a.type < b.type end)
    return unknown
end

-- Runtime entry point (skipped when this file is loaded by the busted spec, which only needs the
-- pure function above — guarded by the CTLD-present check).
do
    if not (ctld and ctld.utils and type(CTLDTypeCollector) == "table") then
        if trigger and trigger.action and trigger.action.outText then
            trigger.action.outText("[CTLD asset-check] load this AFTER CTLD.lua", 15)
        end
        return
    end

    local unknown = _CTLD_assetCheck(_CTLD_STOCK_TYPES, CTLDTypeCollector.collect())
    if #unknown == 0 then
        local msg = "[CTLD asset-check] OK — every configured DCS type is stock or a declared mod."
        ctld.utils.log("INFO", msg)
        trigger.action.outText(msg, 15)
    else
        local lines = { string.format(
            "[CTLD asset-check] %d configured type(s) unknown — typo, or undeclared mod "
            .. "(add to config `modTypes` / a scene's `modTypes`):", #unknown) }
        for _, u in ipairs(unknown) do
            lines[#lines + 1] = string.format("  - %s  [%s]", u.type, table.concat(u.sources, ", "))
        end
        local msg = table.concat(lines, "\n")
        ctld.utils.log("WARN", msg)
        trigger.action.outText(msg, 30)
    end
end
