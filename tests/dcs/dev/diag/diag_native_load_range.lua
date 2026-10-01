---@diagnostic disable
-- diag_native_load_range.lua
-- FEAT-NATIVE-CRATE-SPAWN-NEAR ticket 04 -- for each player aircraft, list the cargo objects DCS offers
-- for native loading (`unit:getNearestCargosForAircraft()`) with their distance from the aircraft centre
-- and their local position (x ahead, z to the right), plus what is already on board. Asserts nothing: it
-- lets a tester note the largest distance at which the DCS cargo UI still loads a crate.
-- Inject (HTTP path of the integration runner) as often as needed; the result is returned and logged
-- with the [NLR] tag. Lua 5.1.
-- =============================================================================

if not ctld or not ctld.utils then
    return "[NLR] ABORT: CTLD not initialized"
end

local out = {}
local function add(s) out[#out + 1] = s end

for unitName in pairs(CTLDPlayerManager.getInstance()._players) do
    local u = Unit.getByName(unitName)
    if u and u:isExist() then
        local p   = u:getPoint()
        local pos = u:getPosition()
        local hdg = math.atan2(pos.x.z, pos.x.x)
        add(string.format("%s (%s) at (%.0f, %.0f)", unitName, tostring(u:getTypeName()), p.x, p.z))
        local ok, near = pcall(function() return u:getNearestCargosForAircraft() end)
        if ok and type(near) == "table" then
            for _, c in ipairs(near) do
                local cp = c:getPoint()
                local dx, dz = cp.x - p.x, cp.z - p.z
                local ahead = dx * math.cos(hdg) + dz * math.sin(hdg)
                local right = -dx * math.sin(hdg) + dz * math.cos(hdg)
                add(string.format("   %-28s dist %5.2f m   local ahead %6.2f right %6.2f", c:getName(),
                    math.sqrt(dx * dx + dz * dz), ahead, right))
            end
            if #near == 0 then add("   no cargo offered") end
        else
            add("   getNearestCargosForAircraft unavailable: " .. tostring(near))
        end
        local okB, board = pcall(function() return u:getCargosOnBoard() end)
        add("   on board: " .. (okB and #board or "unreadable"))
    end
end
local msg = (#out == 0) and "[NLR] no player aircraft" or ("[NLR]\n" .. table.concat(out, "\n"))
env.info(msg)
return msg
