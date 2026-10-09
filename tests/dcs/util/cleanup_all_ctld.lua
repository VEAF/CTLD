---@diagnostic disable
-- cleanup_all_ctld.lua v2
-- Brute-force removal of ALL CTLD DCS menu entries for all player groups.
-- Works even with multiple CTLD instances (double-inject scenario).

local removed = 0

-- Step 1: Remove via CTLDMenuManager memory model (handles known instances)
local function cleanMenuManager(mm)
    if not mm or not mm.menus then return end
    -- teardownGroup removes every live entry of the group (each freed id parked, ADR 0027).
    for groupId in pairs(mm.menus) do
        if pcall(mm.teardownGroup, mm, groupId) then removed = removed + 1 end
    end
    mm.menus = {}
end

if ctld and ctld.MenuManager then
    cleanMenuManager(ctld.MenuManager:getInstance())
end

-- Step 3: Nil ALL CTLD singletons to prevent timer callbacks from rebuilding menus
local singletons = {
    "CTLDCoreManager", "CTLDPlayerManager", "CTLDCrateManager",
    "CTLDTroopManager", "CTLDJTACManager", "CTLDVehicleSpawner",
    "CTLDSceneManager", "CTLDFOBManager", "CTLDBeaconManager",
    "CTLDMenuManager",
}
for _, name in ipairs(singletons) do
    local cls = _G[name]
    if cls then cls._instance = nil end
end

trigger.action.outText("[CTLD-CLEAN2] Removed " .. removed .. " group menus. Restart mission to load fixed CTLD.", 10)
return true
