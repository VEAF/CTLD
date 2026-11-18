---@diagnostic disable
-- @tier: auto-check
-- =============================================================================
-- DGO — FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS (issue #309, ADR 0029) live check: a dropped group acts on its own.
--
--   A. Enemy in range      : troops dropped by a (mock) transport are ordered to the nearest enemy, and really walk to it.
--   B. No enemy in range   : they are ordered to a random point within maximumMoveDistance of the drop point.
--   C. Both distances at 0 : no order, and the group stays where it was dropped.
--   D. Scripted spawn      : ctld.spawnGroupAtPoint's last argument is the search distance (5000 reaches the enemy
--                            although maximumSearchDistance is 0; 50 does not reach it, so the group walks at random).
--
-- The transport is a MOCK 3 km from the first BLUE player, so nothing is ever dropped next to a live aircraft.
-- The settings are overridden for the duration of the scenario only; everything created is cleaned up at the end.
--
-- Result: _SCN_DGO_RESULT  ("[DGO] PASS n/n" | "[DGO] FAIL ..." | "[DGO] ABORT ...")
-- =============================================================================

if not ctld or not ctld.utils then
    _SCN_DGO_RESULT = "[DGO] ABORT: CTLD not initialized"
    return _SCN_DGO_RESULT
end
if _SCN_DGO_RUNNING then return _SCN_DGO_RESULT or "[DGO] RUNNING" end
_SCN_DGO_RUNNING = true
_SCN_DGO_RESULT  = "[DGO] STARTED"

do
local TAG       = "[DGO]"
local MOCK      = "DGO_mock_transport"
local GROUP_ID  = 9999998
local BLUE      = coalition.side.BLUE
local RED       = coalition.side.RED
local ENEMY_DIST = 700      -- the enemy sits this far (x) from the drop point
local WALK_WAIT  = 16       -- seconds the dropped group is given to walk
local passed, failed, reasons = 0, 0, {}

local function log(fmt, ...) ctld.utils.log("INFO", "%s " .. fmt, TAG, ...) end
local function check(id, ok, msg)
    if ok then passed = passed + 1; log("PASS %s", id)
    else failed = failed + 1; reasons[#reasons + 1] = id .. ": " .. msg; log("FAIL %s — %s", id, msg) end
end

local tm = CTLDTroopManager.getInstance()

local player = coalition.getPlayers(BLUE)[1]
if not player then
    _SCN_DGO_RUNNING = false
    _SCN_DGO_RESULT  = "[DGO] ABORT: no BLUE player"
    return _SCN_DGO_RESULT
end

-- Site: 3 km from the player.
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
    getPlayerName = function() return nil end,
    getGroup     = function() return { getID = function() return GROUP_ID end, getName = function() return "DGO_mock_group" end } end,
    inAir        = function() return false end,
    getDesc      = function() return { box = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } } } end,
    getPosition  = function()
        return { p = pt, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
    end,
}
local origGetByName = Unit.getByName
Unit.getByName = function(n) if n == MOCK then return mock end return origGetByName(n) end

-- The mock is not a DCS unit: the cargo-weight update (a DCS call by unit name) is skipped for the scenario.
local origWeight = ctld.utils.updateTransportWeight
ctld.utils.updateTransportWeight = function() end

-- The two settings under test, overridden for the scenario only.
local origGs    = ctld.gs
local overrides = {}
ctld.gs = function(k)
    if overrides[k] ~= nil then return overrides[k] end
    return origGs(k)
end

-- Record every route the troop manager schedules (the decision), then let it through.
local routes = {}
local origSchedule = CTLDTroopManager._scheduleRoute
CTLDTroopManager._scheduleRoute = function(self, grpName, fromPt, destPt)
    routes[#routes + 1] = { grp = grpName, from = fromPt, dest = destPt }
    return origSchedule(self, grpName, fromPt, destPt)
end

-- ── helpers ──────────────────────────────────────────────────────────────────
local created = {}     -- enemy groups this scenario made
local dropped = {}     -- dropped groups this scenario made

local function dist2d(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end

local function spawnEnemy(x, z)
    local gname = "DGO_enemy_" .. (#created + 1)
    coalition.addGroup(country.id.RUSSIA, Group.Category.GROUND, {
        name = gname, task = "Ground Nothing", visible = false, hidden = false,
        units = { { type = "Infantry AK", name = gname .. "_u1", x = x, y = z, heading = 0, skill = "Average", playerCanDrive = false } },
    })
    created[#created + 1] = gname
    return gname
end

local function leaderPoint(gname)
    local g = Group.getByName(gname)
    local u = g and g:getUnit(1)
    return u and u:getPoint() or nil
end

local function lastDropped()
    local list = tm._droppedGroups[BLUE]
    return list[#list]
end

-- Run one drop: clear the route log, call fn, and return the dropped group name and the routes it scheduled.
local function drop(fn)
    routes = {}
    local before = #tm._droppedGroups[BLUE]
    fn()
    local gname = lastDropped()
    if #tm._droppedGroups[BLUE] > before then dropped[#dropped + 1] = gname else gname = nil end
    return gname, routes
end

local function pilotDrop()
    tm:preLoadTransport(MOCK, 4, true)
    tm:disembark(mock)
end

local function finish()
    for _, n in ipairs(dropped) do
        local g = Group.getByName(n)
        if g then g:destroy() end
    end
    for _, n in ipairs(created) do
        local g = Group.getByName(n)
        if g then g:destroy() end
    end
    tm._inTransit[MOCK] = nil
    CTLDTroopManager._scheduleRoute = origSchedule
    ctld.gs = origGs
    ctld.utils.updateTransportWeight = origWeight
    Unit.getByName = origGetByName
    _SCN_DGO_RUNNING = false
    if failed == 0 then
        _SCN_DGO_RESULT = string.format("%s PASS %d/%d", TAG, passed, passed)
    else
        _SCN_DGO_RESULT = string.format("%s FAIL %d/%d: %s", TAG, failed, passed + failed, table.concat(reasons, " | "))
    end
    trigger.action.outText(_SCN_DGO_RESULT, 15)
    log("%s", _SCN_DGO_RESULT)
end

local function step(fn, delay)
    timer.scheduleFunction(function()
        local ok, err = pcall(fn)
        if not ok then
            failed = failed + 1
            reasons[#reasons + 1] = "error: " .. tostring(err)
            log("ERROR in step: %s", tostring(err))
            finish()
        end
    end, nil, timer.getTime() + (delay or 2))
end

-- ── A. enemy in range ────────────────────────────────────────────────────────
overrides.maximumSearchDistance = 4000
overrides.maximumMoveDistance   = 2000
local enemyA = spawnEnemy(S.x + ENEMY_DIST, S.z)
local enemyAPt = { x = S.x + ENEMY_DIST, z = S.z }
check("A.0 enemy spawned", leaderPoint(enemyA) ~= nil, "the enemy group was not created")

local gA, rA = drop(pilotDrop)
check("A.1 troops dropped", gA ~= nil, "no group was dropped")
check("A.2 exactly one order", #rA == 1, #rA .. " order(s)")
check("A.3 the order goes to the enemy", rA[1] ~= nil and dist2d(rA[1].dest, enemyAPt) < 30,
      "destination " .. (rA[1] and string.format("%.0f,%.0f", rA[1].dest.x, rA[1].dest.z) or "none"))
local startA = gA and leaderPoint(gA)

step(function()
    local nowA = gA and leaderPoint(gA)
    check("A.4 the group walks toward the enemy", startA ~= nil and nowA ~= nil
          and dist2d(nowA, enemyAPt) < dist2d(startA, enemyAPt) - 8,
          "distance to the enemy " .. (startA and string.format("%.0f", dist2d(startA, enemyAPt)) or "?") .. " -> "
          .. (nowA and string.format("%.0f", dist2d(nowA, enemyAPt)) or "?"))
    if gA then local g = Group.getByName(gA); if g then g:destroy() end end

    -- ── B. no enemy in range: random walk within maximumMoveDistance ────────
    overrides.maximumSearchDistance = 100          -- the enemy is 700 m away: out of range
    overrides.maximumMoveDistance   = 150
    local gB, rB = drop(pilotDrop)
    check("B.1 troops dropped", gB ~= nil, "no group was dropped")
    check("B.2 exactly one order", #rB == 1, #rB .. " order(s)")
    check("B.3 destination within maximumMoveDistance of the drop point",
          rB[1] ~= nil and math.abs(rB[1].dest.x - rB[1].from.x) <= 150 and math.abs(rB[1].dest.z - rB[1].from.z) <= 150,
          "destination " .. (rB[1] and string.format("%.0f,%.0f from %.0f,%.0f", rB[1].dest.x, rB[1].dest.z, rB[1].from.x, rB[1].from.z) or "none"))
    check("B.4 not the enemy", rB[1] ~= nil and dist2d(rB[1].dest, enemyAPt) > 100, "the order goes to the enemy")
    local startB = gB and leaderPoint(gB)
    local destB  = rB[1] and rB[1].dest

    step(function()
        local nowB = gB and leaderPoint(gB)
        if startB and nowB and destB and dist2d(startB, destB) > 40 then
            check("B.5 the group walks toward its destination", dist2d(nowB, destB) < dist2d(startB, destB) - 8,
                  "distance " .. string.format("%.0f -> %.0f", dist2d(startB, destB), dist2d(nowB, destB)))
        else
            log("B.5 skipped (destination too close to the drop point to measure a walk)")
        end
        if gB then local g = Group.getByName(gB); if g then g:destroy() end end

        -- ── C. both distances at 0: no order ────────────────────────────────
        overrides.maximumSearchDistance = 0
        overrides.maximumMoveDistance   = 0
        local gC, rC = drop(pilotDrop)
        check("C.1 troops dropped", gC ~= nil, "no group was dropped")
        check("C.2 no order", #rC == 0, #rC .. " order(s)")
        local startC = gC and leaderPoint(gC)

        step(function()
            local nowC = gC and leaderPoint(gC)
            check("C.3 the group stays where it was dropped", startC ~= nil and nowC ~= nil and dist2d(startC, nowC) < 4,
                  "moved " .. ((startC and nowC) and string.format("%.1f", dist2d(startC, nowC)) or "?") .. " m")
            if gC then local g = Group.getByName(gC); if g then g:destroy() end end

            -- ── D. scripted spawn: the last argument is the search distance ────
            overrides.maximumSearchDistance = 0        -- the setting alone would look for nobody
            overrides.maximumMoveDistance   = 150
            local gD1, rD1 = drop(function() ctld.spawnGroupAtPoint("blue", 4, pt, 5000) end)
            check("D.1 spawned", gD1 ~= nil, "no group was spawned")
            check("D.2 its own search distance reaches the enemy", rD1[1] ~= nil and dist2d(rD1[1].dest, enemyAPt) < 30,
                  "destination " .. (rD1[1] and string.format("%.0f,%.0f", rD1[1].dest.x, rD1[1].dest.z) or "none"))
            if gD1 then local g = Group.getByName(gD1); if g then g:destroy() end end

            overrides.maximumSearchDistance = 4000     -- the setting alone would reach the enemy
            local gD2, rD2 = drop(function() ctld.spawnGroupAtPoint("blue", 4, pt, 50) end)
            check("D.3 spawned", gD2 ~= nil, "no group was spawned")
            check("D.4 a short search distance does not reach it: random walk",
                  rD2[1] ~= nil and dist2d(rD2[1].dest, enemyAPt) > 100
                  and math.abs(rD2[1].dest.x - pt.x) <= 150 and math.abs(rD2[1].dest.z - pt.z) <= 150,
                  "destination " .. (rD2[1] and string.format("%.0f,%.0f", rD2[1].dest.x, rD2[1].dest.z) or "none"))
            finish()
        end, WALK_WAIT)
    end, WALK_WAIT)
end, WALK_WAIT)

return _SCN_DGO_RESULT
end
