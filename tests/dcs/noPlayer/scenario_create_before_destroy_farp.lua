---@diagnostic disable
-- @tier: auto-slow
-- =============================================================================
-- CBD2 — FIX-CREATE-BEFORE-DESTROY (ADR 0028) live check, success path of the two FARP packs.
--
--   A. Pack <FARP scene>   : a Countryside FARP is deployed, then packed through the REAL F10 "Pack Equipt"
--                            callback: the crates exist (with the warehouse snapshot), the scene is gone.
--   B. Pack the Fat Cow FARP: a piloted Fat Cow FARP is opened with 2400 kg of fuel, then packed: the fuel
--                            crate is set down carrying the stock, the cow is forgotten.
--
-- The transport is a MOCK 3 km from the first BLUE player (no crate is created next to a live aircraft).
-- A scene takes ~20-60 s to lay out: the scenario polls. Everything created is cleaned up at the end, except
-- the Invisible FARP airbase of the Fat Cow (the scene leaves it in the world by design).
--
-- Result: _SCN_CBD2_RESULT  ("[CBD2] PASS n/n" | "[CBD2] FAIL ..." | "[CBD2] ABORT ...")
-- =============================================================================

if not ctld or not ctld.utils then
    _SCN_CBD2_RESULT = "[CBD2] ABORT: CTLD not initialized"
    return _SCN_CBD2_RESULT
end
if _SCN_CBD2_RUNNING then return _SCN_CBD2_RESULT or "[CBD2] RUNNING" end
_SCN_CBD2_RUNNING = true
_SCN_CBD2_RESULT  = "[CBD2] STARTED"

do
local TAG      = "[CBD2]"
local MOCK     = "CBD2_mock_transport"
local GROUP_ID = 9999998
local BLUE     = coalition.side.BLUE
local passed, failed, reasons = 0, 0, {}

local function log(fmt, ...) ctld.utils.log("INFO", "%s " .. fmt, TAG, ...) end
local function check(id, ok, msg)
    if ok then passed = passed + 1; log("PASS %s", id)
    else failed = failed + 1; reasons[#reasons + 1] = id .. ": " .. msg; log("FAIL %s — %s", id, msg) end
end

local cm = CTLDCrateManager.getInstance()
local sm = CTLDSceneManager.getInstance()
local fc = CTLDFatCowManager.getInstance()

local player = coalition.getPlayers(BLUE)[1]
if not player then
    _SCN_CBD2_RUNNING = false
    _SCN_CBD2_RESULT  = "[CBD2] ABORT: no BLUE player"
    return _SCN_CBD2_RESULT
end

local pp = player:getPoint()
local S  = { x = pp.x, z = pp.z + 3000 }
S.y = land.getHeight({ x = S.x, y = S.z })
local pt = { x = S.x, y = S.y + 1, z = S.z }

local mock = {
    getName      = function() return MOCK end,
    isExist      = function() return true end,
    getCoalition = function() return BLUE end,
    getCountry   = function() return country.id.USA end,
    getTypeName  = function() return "UH-1H" end,
    getPoint     = function() return pt end,
    getVelocity  = function() return { x = 0, y = 0, z = 0 } end,
    getGroup     = function() return { getID = function() return GROUP_ID end, getName = function() return "CBD2_mock_group" end } end,
    inAir        = function() return false end,
    getDesc      = function() return { box = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } } } end,
    getPosition  = function()
        return { p = pt, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
    end,
}
local origGetByName = Unit.getByName
Unit.getByName = function(n) if n == MOCK then return mock end return origGetByName(n) end

local cfg = CTLDConfig.get()
local savedRepack = cfg.settings["enableFARPRepack"]
cfg.settings["enableFARPRepack"] = true

local function cratesBy(spawner)
    local out = {}
    for _, c in pairs(cm.crates) do if c.spawnedBy == spawner then out[#out + 1] = c end end
    return out
end

local function finish()
    for _, c in pairs(cm.crates) do
        if c.spawnedBy == MOCK then cm:destroyCrate(c.crateName) end
    end
    for _, sc in pairs(sm._active) do
        if sc._params and sc._params.player == MOCK then sm:packScene(sc) end
    end
    cfg.settings["enableFARPRepack"] = savedRepack
    Unit.getByName = origGetByName
    CTLDPlayerManager.getInstance()._players[MOCK] = nil
    _SCN_CBD2_RUNNING = false
    if failed == 0 then
        _SCN_CBD2_RESULT = string.format("%s PASS %d/%d", TAG, passed, passed)
    else
        _SCN_CBD2_RESULT = string.format("%s FAIL %d/%d: %s", TAG, failed, passed + failed, table.concat(reasons, " | "))
    end
    trigger.action.outText(_SCN_CBD2_RESULT, 15)
    log("%s", _SCN_CBD2_RESULT)
end

local function guarded(fn)
    local ok, err = pcall(fn)
    if not ok then
        failed = failed + 1
        reasons[#reasons + 1] = "error: " .. tostring(err)
        log("ERROR in step: %s", tostring(err))
        finish()
    end
end

--- Calls `probe` every 3 s until it returns true, then `onReady`; after `timeout` s calls `onTimeout`.
local function poll(probe, onReady, onTimeout, timeout)
    local deadline = timer.getTime() + timeout
    local function tick()
        guarded(function()
            if probe() then onReady()
            elseif timer.getTime() > deadline then onTimeout()
            else timer.scheduleFunction(tick, nil, timer.getTime() + 3) end
        end)
    end
    timer.scheduleFunction(tick, nil, timer.getTime() + 3)
end

-- ── B. Fat Cow FARP (defined first, run after A) ─────────────────────────────
local function partB()
    pt = { x = S.x + 800, y = land.getHeight({ x = S.x + 800, y = S.z }) + 1, z = S.z }
    local cow = CTLDFatCow:new(MOCK, BLUE, { fuelKg = 2400, items = {} })
    cow.notifyGroupId = GROUP_ID
    cow.pilotedFarp   = fc:_newFarpName()
    fc._cows[cow.pilotedFarp] = cow
    local ok, why = fc:deploy(mock, cow, cow.pilotedFarp)
    check("B.1 Fat Cow FARP deploy started", ok == true, "deploy refused: " .. tostring(why))
    if not ok then fc._cows[cow.pilotedFarp] = nil; return finish() end

    poll(function() return cow.state == CTLDFatCow.STATE_DEPLOYED end, function()
        local farpName = cow.farpName
        local ab = Airbase.getByName(farpName)
        check("B.2 FARP open with the stock", ab ~= nil and ab:getWarehouse() ~= nil
              and ab:getWarehouse():getLiquidAmount(0) >= 2300, "FARP '" .. tostring(farpName) .. "' has no fuel")
        local farpKey = cow.pilotedFarp
        fc:packFarp(MOCK)
        local crates = cratesBy(MOCK)
        check("B.3 a crate is set down", #crates >= 1, #crates .. " crate(s)")
        check("B.4 the crates carry the stock", CTLDFatCow.stockOfCrates(crates).fuelKg >= 2300,
              "fuelKg=" .. tostring(CTLDFatCow.stockOfCrates(crates).fuelKg))
        check("B.5 the cow is forgotten, its name freed", fc._cows[farpKey] == nil, "the FARP is still registered")
        check("B.6 the FARP is emptied", ab:getWarehouse():getLiquidAmount(0) < 100,
              "fuel left " .. tostring(ab:getWarehouse():getLiquidAmount(0)))
        finish()
    end, function()
        check("B.2 FARP open with the stock", false, "the Fat Cow scene did not finish laying out in 120 s")
        fc._cows[cow.pilotedFarp] = nil
        finish()
    end, 120)
end

-- ── A. Pack <FARP scene> through the real menu callback ──────────────────────
for _, sc in pairs(sm._active) do
    if sc._modelName == "Countryside FARP" and sc._params == nil then
        -- leave a pre-existing FARP alone: the test scene is told apart by its params below
    end
end
local scene = sm:playSceneAtPos("Countryside FARP", pt, BLUE, country.id.USA, { player = MOCK })
check("A.0 Countryside FARP scene started", scene ~= nil, "playSceneAtPos returned nil")
if not scene then
    Unit.getByName = origGetByName
    cfg.settings["enableFARPRepack"] = savedRepack
    _SCN_CBD2_RUNNING = false
    _SCN_CBD2_RESULT = "[CBD2] FAIL: the scene did not start"
    return _SCN_CBD2_RESULT
end

poll(function()
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Countryside FARP" and sc._params and sc._params.player == MOCK then return true end
    end
    return false
end, function()
    local active
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Countryside FARP" and sc._params and sc._params.player == MOCK then active = sc end
    end
    local objs = {}
    for _, o in ipairs(active._spawnedObjs) do objs[#objs + 1] = o end
    local model = sm:getModel("Countryside FARP")
    local required = model.crate.cratesRequired or 1

    local playerObj = { unitName = MOCK, groupId = GROUP_ID, groupName = "CBD2_mock_group", coalition = BLUE,
                        typeName = "UH-1H", isTransport = true, canCarryVehicles = false }
    CTLDPlayerManager.getInstance()._players[MOCK] = playerObj
    CTLDPlayerManager.getInstance():buildMenu(playerObj)
    cm:refreshPackEquiptSection(playerObj, false, true)
    local menu = ctld.MenuManager:getInstance():getMenuByGroupId(GROUP_ID)
    local node = menu and menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Crate Commands"), ctld.tr("Pack Equipt"),
                                          ctld.tr("Pack %1", "Countryside FARP") })
    check("A.1 the Pack entry lists the deployed FARP", node ~= nil, "no Pack Equipt entry for the Countryside FARP")
    if not node then return finish() end

    node.functionToCall({ unitName = MOCK, sceneName = active._name })
    local crates = cratesBy(MOCK)
    check("A.2 every crate was created", #crates == required, #crates .. " crates, expected " .. required)
    check("A.3 the scene left the active set", sm._active[active._name] == nil, "scene still active")
    local snap = true
    for _, c in ipairs(crates) do snap = snap and (c.metadata.warehouseSnapshot ~= nil) end
    log("A.3b [INFO] every crate carries a warehouseSnapshot: %s", tostring(snap))
    check("A.4 crates are DCS statics", #crates > 0 and StaticObject.getByName(crates[1].crateName) ~= nil,
          "first crate has no DCS static")

    timer.scheduleFunction(function()
        guarded(function()
            local gone = true
            for _, o in ipairs(objs) do if o.isExist and o:isExist() then gone = false end end
            check("A.5 scene objects destroyed", gone, "a scene object is still in the world")
            for _, c in ipairs(crates) do cm:destroyCrate(c.crateName) end
            partB()
        end)
    end, nil, timer.getTime() + 3)
end, function()
    check("A.1 the scene laid out", false, "the Countryside FARP did not finish in 120 s")
    finish()
end, 120)

return _SCN_CBD2_RESULT
end
