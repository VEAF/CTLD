---@diagnostic disable
-- @tier: ia  (never resolves programmatically -- requires F10 visual confirmation)
-- F-47 : Enable FOB mid-mission + clearBranch Pack Vehicles + 11 items + pagination réelle
-- REQUIRES: F-45 executed first
trigger.action.outText("F-47: Enable FOB + clearBranch + 11 items + pagination", 10)

local players = coalition.getPlayers(coalition.side.BLUE) or {}
local unit = players[1]
if not unit then
    trigger.action.outText("F-47 SKIP: no BLUE player found", 10)
    _SCN_F47_RESULT = "[F-47] ABORT: no BLUE player found"
    return _SCN_F47_RESULT
end
local groupId = unit:getGroup():getID()
local menu    = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
if not menu then
    trigger.action.outText("F-47 SKIP: no menu found — run F-45 first", 10)
    _SCN_F47_RESULT = "[F-47] ABORT: no menu found — run F-45 first"
    return _SCN_F47_RESULT
end

_SCN_F47_RESULT = "[F-47] STARTED"
timer.scheduleFunction(function()
    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")
    local packSub   = ctld.tr("Pack Equipt")
    local fobSub    = ctld.tr("FOBs List")

    menu:setBranchEnabled({root, fobSub}, true)
    menu:addSubMenu({root, cratesSub}, packSub, { order = 25 })
    menu:setBranchEnabled({root, cratesSub, packSub}, true)
    menu:clearBranch({root, cratesSub, packSub})
    for i = 1, 11 do
        menu:addCommand({root, cratesSub, packSub}, "Vehicle_"..i,
            function(arg) end, { id=i })
    end
    menu:refresh()
    trigger.action.outText(
        "F-47 VISUAL CHECK:\n  FOBs List now visible.\n  Crate Commands > Pack Equipt: 9 items + Next Page (11 total).", 30)
    env.info("[F-47] Menu updated. Awaiting visual confirmation.")
end, {}, timer.getTime() + 3)

return _SCN_F47_RESULT
