---@diagnostic disable
-- cleanup_ctld_menus.lua
-- Wipe all CTLD F10 menus for all live player groups before a CTLD reinject.
-- Iterates all coalitions, finds groups with a live player, removes their CTLD menu handle.

local removed = 0

-- Try to remove via CTLDMenuManager if the old instance is alive.
if ctld and ctld.MenuManager then
    local mm = ctld.MenuManager:getInstance()
    if mm and mm.menus then
        -- teardownGroup removes every live entry of the group (each freed id parked, ADR 0027).
        for groupId in pairs(mm.menus) do
            if pcall(mm.teardownGroup, mm, groupId) then removed = removed + 1 end
        end
        mm.menus = {}
    end
end

-- Also nuke CTLDPlayerManager players so the new instance starts fresh.
if CTLDPlayerManager and CTLDPlayerManager._instance then
    CTLDPlayerManager._instance._players = {}
end

-- Nuke all CTLD singletons so the next CTLD.lua injection creates fresh instances.
if CTLDCoreManager    then CTLDCoreManager._instance    = nil end
if CTLDPlayerManager  then CTLDPlayerManager._instance  = nil end
if CTLDCrateManager   then CTLDCrateManager._instance   = nil end
if CTLDTroopManager   then CTLDTroopManager._instance   = nil end
if CTLDJTACManager    then CTLDJTACManager._instance    = nil end
if CTLDVehicleSpawner then CTLDVehicleSpawner._instance = nil end
if CTLDSceneManager   then CTLDSceneManager._instance   = nil end
if CTLDFOBManager     then CTLDFOBManager._instance     = nil end
if CTLDBeaconManager  then CTLDBeaconManager._instance  = nil end

trigger.action.outText("[CTLD-CLEAN] Menus wiped (" .. removed .. " group menus removed). Inject CTLD.lua now.", 8)
return true
