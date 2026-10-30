---@diagnostic disable
-- @tier: auto-slow
-- =============================================================================
-- tests/dcs/pilotPassive/scenario_fatcow_takeover.lua
-- FEAT-FAT-COW-TAKEOVER live check (ticket 02), on Test_FatCow_Takeover.miz: the AI flight `Hawk` and
-- its mission-placed cow `Fat Cow Hawk` play the lost flight; an AI Apache spawned here (`Viper`) takes
-- the cow over. Nobody flies: a player parked in any slot (Gunfighter) only receives the messages.
--
-- Re-injection step machine: inject again until PASS / FAIL. Each injection advances when its
-- condition holds, else answers RUNNING with what it waits for.
--   1  the cow has opened its FARP at Hawk's second stop (> 2.5 km from its home, unlike the first)
--      → Hawk is removed and the flight check run, as a shot-down flight would trigger it
--   2  the cow is still there 5 s later (the 2026-10-29 bug: despawned 0.98 s after the re-task),
--      then lifts off within 120 s (DCS behaviour the unit specs cannot show)
--   3  Viper spawned 3 km from the cow; next injection: Viper takes the cow over
--   4  the cow closes on Viper within 120 s; Release the Fat Cow, then Viper takes it back, then RTB
--   5  the cow lands at home and despawns within 10 min
--
-- @scenario  FATCOW-TAKEOVER
-- @version   1.0 — 2026-10-30
-- =============================================================================

local TAG = "[FATCOW-TAKEOVER]"
local function done(v) _SCN_FATCOW_TAKEOVER_RESULT = TAG .. " " .. v; return _SCN_FATCOW_TAKEOVER_RESULT end

if not (CTLDFatCowManager and ctld and ctld.utils) then return done("ABORT: CTLD not initialized") end
local mgr = CTLDFatCowManager.getInstance()
local S = _SCN_FATCOW_TAKEOVER or { step = 1, notes = {}, msgs = {} }
_SCN_FATCOW_TAKEOVER = S
local now = timer.getTime()

local function note(s) S.notes[#S.notes + 1] = s end
local function alive(name) local u = Unit.getByName(name); return u and u:isExist() and u or nil end
local function dist(a, b) return ctld.utils.getDistance("FATCOW-TAKEOVER", a, b) end

-- Messages CTLD sends, kept for the verdict (the original still shows them).
if not S.hooked then
    S.hooked = true
    local orig = trigger.action.outTextForGroup
    trigger.action.outTextForGroup = function(gid, text, d, c)
        if type(text) == "string" and text:find("Fat Cow", 1, true) then S.msgs[#S.msgs + 1] = gid .. ": " .. text end
        return orig(gid, text, d, c)
    end
end

if S.step == 1 then
    local cow = mgr:aiCowOfFlight("Hawk")
    if not cow then return done("ABORT: Hawk has no cow (mission not Test_FatCow_Takeover.miz, or Hawk gone)") end
    local u = alive(cow.unitName)
    -- Seen on 2026-10-30: the cow died landing at Hawk's first stop, and CTLD never heard of it.
    if not u then return done("ABORT: the cow is dead but CTLD still holds it (phase " .. tostring(cow.ai.phase) .. ")") end
    local d = cow.ai.home and dist(u:getPoint(), cow.ai.home) or 0
    if not (cow.state == CTLDFatCow.STATE_DEPLOYED and d > 2500) then
        return done(string.format("RUNNING: step=1 waiting for the cow's FARP at Hawk's 2nd stop (state %s, phase %s, %.0f m from home)",
            cow.state, tostring(cow.ai.phase), d))
    end
    S.cow, S.home, S.t2 = cow.unitName, cow.ai.home, now
    note(string.format("FARP open %.0f m from home", d))
    Group.getByName("Hawk"):destroy()
    mgr:_checkFlightsLater()
    S.step = 2
    return done("RUNNING: step=2 Hawk removed, flight check in 2 s")
end

if S.step == 2 then
    local cow = mgr:getCow(S.cow)
    local u = alive(S.cow)
    if now - S.t2 < 5 then return done("RUNNING: step=2 waiting 5 s") end
    if not (cow and u) then return done("FAIL: the cow vanished after its flight was lost (the 2026-10-29 bug) | " .. table.concat(S.notes, "; ")) end
    if not S.stayed then
        S.stayed = true
        note("still there 5 s after the re-task, phase " .. tostring(cow.ai.phase))
    end
    if not u:inAir() then
        if now - S.t2 > 120 then
            return done("FAIL: the cow stays on the ground 120 s after being sent home | " .. table.concat(S.notes, "; "))
        end
        return done(string.format("RUNNING: step=2 waiting for take-off (%.0f s)", now - S.t2))
    end
    note(string.format("lifted off %.0f s after the re-task", now - S.t2))
    local p = u:getPoint()
    local data = {
        name = "Viper", task = "CAS",
        route = { points = { { type = "Turning Point", action = "Turning Point", x = p.x + 3000, y = p.z,
            alt = 150, alt_type = "RADIO", speed = 40, task = { id = "ComboTask", params = { tasks = {} } } } } },
        units = { { name = "Viper-1", type = "AH-64D_BLK_II", skill = "High", x = p.x + 3000, y = p.z,
            alt = 150, alt_type = "RADIO", speed = 40, heading = 0, payload = { fuel = 1000, flare = 0, chaff = 0, gun = 100, pylons = {} } } },
    }
    coalition.addGroup(u:getCountry(), Group.Category.HELICOPTER, data)
    S.step, S.t3 = 3, now
    return done("RUNNING: step=3 Viper spawned 3 km east of the cow")
end

if S.step == 3 then
    if now - S.t3 < 2 then return done("RUNNING: step=3 waiting a frame for Viper") end
    local v = alive("Viper-1")
    if not v then return done("FAIL: Viper not spawned | " .. table.concat(S.notes, "; ")) end
    local listed = mgr:_takeableCows(v:getCoalition(), v:getPoint())
    if not (listed[1] and listed[1].cow.unitName == S.cow) then return done("FAIL: the cow is not listed for take-over") end
    mgr:takeOverAICow("Viper-1", S.cow)
    local cow = mgr:getCow(S.cow)
    if mgr:aiCowOfFlight("Viper") ~= cow then return done("FAIL: take-over did not attach the cow to Viper") end
    S.d4, S.t4, S.step = dist(alive(S.cow):getPoint(), v:getPoint()), now, 4
    note(string.format("taken over by Viper at %.0f m", S.d4))
    return done("RUNNING: step=4 the cow should close on Viper")
end

if S.step == 4 then
    local u, v = alive(S.cow), alive("Viper-1")
    if not (u and v) then return done("FAIL: cow or Viper gone | " .. table.concat(S.notes, "; ")) end
    local d = dist(u:getPoint(), v:getPoint())
    if d > 800 and d > S.d4 * 0.6 then
        if now - S.t4 > 120 then return done(string.format("FAIL: the cow does not follow Viper (%.0f m, was %.0f) | %s", d, S.d4, table.concat(S.notes, "; "))) end
        return done(string.format("RUNNING: step=4 cow %.0f m from Viper (was %.0f, %.0f s)", d, S.d4, now - S.t4))
    end
    note(string.format("closed on Viper to %.0f m in %.0f s", d, now - S.t4))
    mgr:freeAICow("Viper-1")
    local cow = mgr:getCow(S.cow)
    if not (cow.ai.released and mgr:aiCowOfFlight("Viper") == nil) then return done("FAIL: Release the Fat Cow did not release it") end
    note("released, phase " .. tostring(cow.ai.phase))
    mgr:takeOverAICow("Viper-1", S.cow)
    if mgr:aiCowOfFlight("Viper") ~= cow then return done("FAIL: Viper could not take the released cow back") end
    mgr:releaseAICow("Viper-1")
    if cow.ai.phase ~= CTLDFatCowManager.PHASE_RETURNING then return done("FAIL: RTB did not send it home") end
    note("taken back, then RTB")
    S.step, S.t5 = 5, now
    return done("RUNNING: step=5 the cow flies home")
end

if S.step == 5 then
    local u = alive(S.cow)
    if u then
        S.lastD = dist(u:getPoint(), S.home)
        if now - S.t5 > 600 then return done(string.format("FAIL: not home after 10 min (%.0f m away) | %s", S.lastD, table.concat(S.notes, "; "))) end
        return done(string.format("RUNNING: step=5 %.0f m from home, %s (%.0f s)", S.lastD, u:inAir() and "flying" or "on the ground", now - S.t5))
    end
    if mgr:getCow(S.cow) then return done("FAIL: the unit is gone but CTLD still holds the cow") end
    -- Gone between two polls: a crash on the way would look the same, so it must have been seen near home.
    if not S.lastD or S.lastD > 4000 then
        return done(string.format("FAIL: gone %s m from home, not seen landing there | %s", tostring(S.lastD), table.concat(S.notes, "; ")))
    end
    note(string.format("despawned at home %.0f s after RTB", now - S.t5))
    S.step = 6
end

return done("PASS | " .. table.concat(S.notes, "; ") .. " | messages: " .. table.concat(S.msgs, " || "))
