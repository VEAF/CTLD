---@diagnostic disable
-- U-53 : Enabled flag — disabled node absent from DCS rebuild
trigger.action.outText("U-53: Enabled flag in rebuild", 10)

local log = function(msg) env.info("[U-53] " .. msg) end
local pass, fail = 0, 0
local failReasons = {}
local function ok(label, cond)
    if cond then pass = pass + 1; log("PASS " .. label)
    else fail = fail + 1; failReasons[#failReasons+1] = label; log("FAIL " .. label) end
end

local _dcs_calls = {}
missionCommands = {
    addSubMenuForGroup  = function(gId, name, path) table.insert(_dcs_calls, {fn="addSubMenu", name=name, path=path}) end,
    addCommandForGroup  = function(gId, name, path) table.insert(_dcs_calls, {fn="addCommand", name=name, path=path}) end,
    removeItemForGroup  = function() end,
}
ctld = ctld or {}; ctld.tr=ctld.tr or function(k)return k end
ctld.logInfo=ctld.logInfo or function()end; ctld.logWarning=ctld.logWarning or function()end; ctld.logError=ctld.logError or function()end
Unit=Unit or {getByName=function()return nil end,getByID=function()return nil end}
coalition=coalition or {getGroups=function()return{}end}
ctld.MenuManager._instance = nil

_SCN_U53_RESULT = "[U-53] STARTED"

local m = ctld.MenuManager:getInstance():createMenuForGroup(8)
m:addSubMenu({}, "CTLD Commands")
m:addSubMenu({"CTLD Commands"}, "Troops",  {order=10})
m:addSubMenu({"CTLD Commands"}, "FOB",     {order=20, enabled=false})
m:addSubMenu({"CTLD Commands"}, "Beacons", {order=30})
m:refresh()

local rendered = {}
for _, c in ipairs(_dcs_calls) do
    if c.fn=="addSubMenu" and c.path and c.path[1]=="CTLD Commands" then
        rendered[c.name] = true
    end
end
ok("T23a: Troops rendered (enabled)",   rendered["Troops"]  == true)
ok("T23b: FOB absent (disabled)",       rendered["FOB"]     == nil)
ok("T23c: Beacons rendered (enabled)",  rendered["Beacons"] == true)

local result = string.format("U-53: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(result, 10)
env.info("[U-53] " .. result)

local total = pass + fail
if fail == 0 then
    _SCN_U53_RESULT = "[U-53] PASS " .. pass .. "/" .. total
else
    _SCN_U53_RESULT = "[U-53] FAIL " .. fail .. "/" .. total .. ": " .. table.concat(failReasons, "; ")
end
return _SCN_U53_RESULT
