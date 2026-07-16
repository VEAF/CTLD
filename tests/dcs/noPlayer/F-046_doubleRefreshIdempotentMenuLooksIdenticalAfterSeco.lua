---@diagnostic disable
-- @tier: human (menu)  (never resolves programmatically -- requires F10 visual confirmation)
-- F-46 : Double refresh() idempotent — menu looks identical after second refresh
-- REQUIRES: F-45 executed first (menu already built)
trigger.action.outText("F-46: Double refresh() idempotent", 10)

local players = coalition.getPlayers(coalition.side.BLUE) or {}
local unit = players[1]
if not unit then
    trigger.action.outText("F-46 SKIP: no BLUE player found", 10)
    env.info("[F-46] SKIP: no BLUE player")
    _SCN_F46_RESULT = "[F-46] ABORT: no BLUE player found"
    return _SCN_F46_RESULT
end
local groupId = unit:getGroup():getID()
local menu    = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
if not menu then
    trigger.action.outText("F-46 SKIP: no menu found — run F-45 first", 10)
    env.info("[F-46] SKIP: no menu found")
    _SCN_F46_RESULT = "[F-46] ABORT: no menu found — run F-45 first"
    return _SCN_F46_RESULT
end

_SCN_F46_RESULT = "[F-46] STARTED"
menu:refresh()
trigger.action.outText("F-46 VISUAL CHECK:\nSecond refresh() done.\nMenu must look identical to F-45.", 20)
env.info("[F-46] Second refresh complete. Awaiting visual confirmation.")
return _SCN_F46_RESULT
