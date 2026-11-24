---@diagnostic disable
-- @tier: ia (menu)
-- =============================================================================
-- tests/dcs/pilotPassive/scenario_fatcow_player_leave.lua
-- FIX-FAT-COW-STRANDED live check, ticket 04 (b): does a client group still answer getUnit(1) 2 s, 5 s, 10 s
-- after its player leaves the slot, and does the cow then go home?
--
-- Zip sits in a BLUE helicopter slot (any, in the air or on the ground). Inject once: the flight requests a cow
-- and a handler waits for the player leaving. Zip then leaves the slot (ESC > "Change slot" or "Exit to spectators").
-- The handler samples the group every 0.5 s for 30 s from that instant. Inject again to read the verdict.
--
-- @scenario  FATCOW-PLAYER-LEAVE
-- @version   1.0 — 2026-11-24
-- =============================================================================

local TAG = "[FATCOW-PLAYER-LEAVE]"
local function done(v) _SCN_FATCOW_PLAYER_LEAVE_RESULT = TAG .. " " .. v; return _SCN_FATCOW_PLAYER_LEAVE_RESULT end

if not (CTLDFatCowManager and ctld and ctld.utils) then return done("ABORT: CTLD not initialized") end
local mgr = CTLDFatCowManager.getInstance()
local S = _SCN_FATCOW_PLAYER_LEAVE

if not S then
    local player
    for _, u in ipairs(coalition.getPlayers(coalition.side.BLUE) or {}) do
        if u:isExist() and u:getDesc().category == Unit.Category.HELICOPTER then player = u break end
    end
    if not player then return done("ABORT: no BLUE helicopter player (sit in a helicopter slot)") end
    S = { unit = player:getName(), flight = player:getGroup():getName(), samples = {}, state = "armed" }
    _SCN_FATCOW_PLAYER_LEAVE = S
    mgr:requestAICow(S.unit, 1)
    S.handler = { onEvent = function(_, e)
        if e.id ~= world.event.S_EVENT_PLAYER_LEAVE_UNIT or S.t0 then return end
        S.t0 = timer.getTime()
        S.state = "sampling"
        local function sample0()
            local t = timer.getTime() - S.t0
            local g = Group.getByName(S.flight)
            local gx = g and g:isExist()
            local cow = mgr:aiCowOfFlight(S.flight)
            local named
            for _, c in pairs(mgr._cows) do if c.ai and c.ai.flightGroup == S.flight then named = c end end
            S.samples[#S.samples + 1] = { t = t, group = gx and true or false,
                unit1 = (gx and g:getUnit(1)) and true or false,
                phase = named and named.ai.phase or "-", registered = cow ~= nil }
            if t < 30 then return timer.getTime() + 0.5 end
            S.state = "done"
        end
        local function sample()
            local ok, nxt = pcall(sample0)
            if not ok then S.err = tostring(nxt); S.state = "done"; return nil end
            return nxt
        end
        timer.scheduleFunction(sample, nil, timer.getTime() + 0.1)
    end }
    world.addEventHandler(S.handler)
    return done("STARTED: cow requested for flight '" .. S.flight .. "'. Zip: leave the slot now (wait for the cow message first).")
end

if S.state == "armed" then return done("RUNNING: waiting for the player to leave the slot") end
if S.state == "sampling" then return done(string.format("RUNNING: sampling (%.0f s of 30)", timer.getTime() - S.t0)) end

-- done: the readings nearest to 2, 5 and 10 s, and when each thing changed
local function at(t)
    local best
    for _, s in ipairs(S.samples) do if not best or math.abs(s.t - t) < math.abs(best.t - t) then best = s end end
    return best and string.format("t=%.1fs group=%s getUnit(1)=%s cow=%s registered=%s", best.t, tostring(best.group),
        tostring(best.unit1), best.phase, tostring(best.registered)) or "no sample"
end
local firstGone, firstHome
for _, s in ipairs(S.samples) do
    if not s.unit1 and not firstGone then firstGone = s.t end
    if s.phase == CTLDFatCowManager.PHASE_RETURNING and not firstHome then firstHome = s.t end
end
world.removeEventHandler(S.handler)
local verdict = string.format("MEASURED | 2 s: %s | 5 s: %s | 10 s: %s | getUnit(1) first nil at %s s | cow first RETURNING at %s s",
    at(2), at(5), at(10), firstGone and string.format("%.1f", firstGone) or "never (30 s)",
    firstHome and string.format("%.1f", firstHome) or "never (30 s)")
if S.err then verdict = verdict .. " | sampler error: " .. S.err end
_SCN_FATCOW_PLAYER_LEAVE = nil
return done(verdict)
