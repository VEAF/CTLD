---@diagnostic disable
-- @tier: auto-slow
-- =============================================================================
-- tests/dcs/noPlayer/scenario_fatcow_stranded.lua
-- FIX-FAT-COW-STRANDED live check, ticket 04 (a), (c) and (d). Nobody flies.
--
-- Re-injection step machine: inject again until PASS / FAIL (each answer says what it waits for).
--   1  an AI Apache flight `Stranded` is spawned airborne near a BLUE logistic zone and requests an AI cow
--   2  the cow exists: it is given the F10 order "Take off" (orbit where it stands); a sampler then records
--      its position and speed every 5 s for 120 s
--   3  (a) verdict by measurement: circle (speed, bounded distance from the orbit point) or hover
--   4  (c) a CH-47 with 400 kg of fuel is spawned airborne, registered as the cow of a second Apache flight
--      `Stranded2`: the 10 s loop must send it home and tell the flight, within 40 s
--   5  clean up (groups destroyed, cows forgotten)
-- (d) is read in dcs.log: lines "CTLDFatCowManager: cow '...' order ..." and "... phase ... -> ...".
--
-- @scenario  FATCOW-STRANDED
-- @version   1.0 — 2026-11-24
-- =============================================================================

local TAG = "[FATCOW-STRANDED]"
local function done(v) _SCN_FATCOW_STRANDED_RESULT = TAG .. " " .. v; return _SCN_FATCOW_STRANDED_RESULT end

if not (CTLDFatCowManager and ctld and ctld.utils) then return done("ABORT: CTLD not initialized") end
local mgr = CTLDFatCowManager.getInstance()
local S = _SCN_FATCOW_STRANDED or { step = 1, notes = {}, msgs = {}, samples = {} }
_SCN_FATCOW_STRANDED = S
local now = timer.getTime()

local function note(s) S.notes[#S.notes + 1] = s end
local function alive(name) local u = Unit.getByName(name); return u and u:isExist() and u or nil end
local function dist2(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end

if not S.hooked then
    S.hooked = true
    local orig = trigger.action.outTextForGroup
    trigger.action.outTextForGroup = function(gid, text, d, c)
        if type(text) == "string" and text:find("Fat Cow", 1, true) then S.msgs[#S.msgs + 1] = gid .. ": " .. text end
        return orig(gid, text, d, c)
    end
    S.origOut = orig
end

local function apache(name, x, z)
    return {
        name = name, task = "CAS",
        route = { points = { { type = "Turning Point", action = "Turning Point", x = x, y = z + 50000,
            alt = 150, alt_type = "RADIO", speed = 40, task = { id = "ComboTask", params = { tasks = {} } } } } },
        units = { { name = name .. "-1", type = "AH-64D_BLK_II", skill = "High", x = x, y = z,
            alt = 150, alt_type = "RADIO", speed = 40, heading = 0,
            payload = { fuel = 1000, flare = 0, chaff = 0, gun = 100, pylons = {} } } },
    }
end

local function cleanup()
    for _, g in ipairs({ "Stranded", "Stranded2", "Bingo Cow" }) do
        local grp = Group.getByName(g)
        if grp and grp:isExist() then grp:destroy() end
    end
    for _, c in ipairs({ S.cow, S.bingo }) do if c and mgr:getCow(c) then mgr:_cowGone(c) end end
    if S.origOut then trigger.action.outTextForGroup = S.origOut end
    S.hooked = false
end

if S.step == 1 then
    local zone = mgr:nearestHomeZone({ x = 0, y = 0, z = 0 }, coalition.side.BLUE)
    if not zone then return done("ABORT: no BLUE logistic zone in the mission") end
    local c = zone:getCenter()
    S.zone = c
    coalition.addGroup(country.id.USA, Group.Category.HELICOPTER, apache("Stranded", c.x + 4000, c.z))
    S.t1, S.step = now, 2
    return done("RUNNING: step=2 flight Stranded spawned, inject again in 3 s")
end

if S.step == 2 then
    if now - S.t1 < 3 then return done("RUNNING: step=2 waiting a frame") end
    if not alive("Stranded-1") then return done("FAIL: Stranded not spawned") end
    if not S.requested then
        S.requested = true
        mgr:requestAICow("Stranded-1", 1)
        S.t1 = now
        return done("RUNNING: step=2 cow requested, inject again in 4 s")
    end
    local cow = mgr:aiCowOfFlight("Stranded")
    if not cow then
        if now - S.t1 > 20 then return done("FAIL: no cow after 20 s") end
        return done("RUNNING: step=2 waiting for the cow")
    end
    local u = alive(cow.unitName)
    if not u then return done("FAIL: the cow unit is not there") end
    S.cow = cow.unitName
    local p = u:getPoint()
    S.orbit = { x = p.x, z = p.z }
    mgr:orderTakeOff("Stranded-1")
    note(string.format("Take off given at (%.0f, %.0f), phase %s", p.x, p.z, tostring(cow.ai.phase)))
    S.t2 = now
    local function sample()
        local c = alive(S.cow)
        if c then
            local v, q = c:getVelocity(), c:getPoint()
            S.samples[#S.samples + 1] = { t = timer.getTime() - S.t2, d = dist2(q, S.orbit),
                speed = math.sqrt(v.x ^ 2 + v.z ^ 2), alt = q.y, fuel = c:getFuel() }
        end
        if timer.getTime() - S.t2 < 120 then return timer.getTime() + 5 end
    end
    timer.scheduleFunction(sample, nil, timer.getTime() + 5)
    S.step = 3
    return done("RUNNING: step=3 sampling the orbit for 120 s")
end

if S.step == 3 then
    if now - S.t2 < 125 then return done(string.format("RUNNING: step=3 sampling (%.0f s of 120)", now - S.t2)) end
    local n, sumV, maxV, minV, maxD = #S.samples, 0, 0, 1e9, 0
    local cow = mgr:getCow(S.cow)
    for _, s in ipairs(S.samples) do
        sumV = sumV + s.speed
        if s.speed > maxV then maxV = s.speed end
        if s.speed < minV then minV = s.speed end
        if s.d > maxD then maxD = s.d end
    end
    if n == 0 then return done("FAIL: no sample, the cow vanished | " .. table.concat(S.notes, "; ")) end
    local last = S.samples[n]
    S.measuredA = string.format("(a) %d samples over 120 s: speed mean %.1f m/s (min %.1f, max %.1f), max %.0f m from the orbit point, last %.0f m at %.0f m, fuel %.2f, phase %s => %s",
        n, sumV / n, minV, maxV, maxD, last.d, last.alt, last.fuel or -1, cow and tostring(cow.ai.phase) or "?",
        (sumV / n < 3 and maxD < 100) and "HOVER" or "MOVES (circle or drift: see the samples)")
    note(S.measuredA)
    local pts = {}
    for _, s in ipairs(S.samples) do pts[#pts + 1] = string.format("%.0fs:%.0fm/%.1fm/s", s.t, s.d, s.speed) end
    note("samples " .. table.concat(pts, " "))
    -- (c) bingo
    local cx, cz = S.zone.x, S.zone.z
    coalition.addGroup(country.id.USA, Group.Category.HELICOPTER, apache("Stranded2", cx + 8000, cz))
    local alt = land.getHeight({ x = cx, y = cz }) + 150
    coalition.addGroup(country.id.USA, Group.Category.HELICOPTER, {
        name = "Bingo Cow", task = "Transport",
        route = { points = { { type = "Turning Point", action = "Turning Point", x = cx + 8000, y = cz,
            alt = alt, alt_type = "BARO", speed = 40, task = { id = "ComboTask", params = { tasks = {} } } } } },
        units = { { name = "Bingo Cow-1", type = ctld.gs("fatCowAIType"), skill = "High", x = cx + 8000, y = cz,
            alt = alt, alt_type = "BARO", speed = 40, heading = 0,
            payload = { fuel = 400, flare = 0, chaff = 0, gun = 100, pylons = {} } } },
    })
    S.t4, S.step = now, 4
    return done("RUNNING: step=4 low-fuel cow and its flight spawned, inject again in 3 s")
end

if S.step == 4 then
    if now - S.t4 < 3 then return done("RUNNING: step=4 waiting a frame") end
    if not S.registered then
        local u = alive("Bingo Cow-1")
        if not (u and alive("Stranded2-1")) then return done("FAIL: bingo cow or its flight not spawned | " .. table.concat(S.notes, "; ")) end
        local cow = mgr:addAICow("Bingo Cow", "Stranded2", S.zone, 1)
        if not cow then return done("FAIL: addAICow refused the bingo cow") end
        S.bingo, S.registered, S.t5 = cow.unitName, true, now
        S.fuel0 = u:getFuel()
        note(string.format("bingo cow registered, fuel %.2f, in air %s, phase %s", S.fuel0, tostring(ctld.utils.inAir(u)), tostring(cow.ai.phase)))
        return done("RUNNING: step=4 waiting for the 10 s loop to send it home")
    end
    local cow = mgr:getCow(S.bingo)
    if cow and cow.ai.phase == CTLDFatCowManager.PHASE_RETURNING then
        local said = false
        for _, m in ipairs(S.msgs) do if m:find("low on fuel", 1, true) then said = true end end
        note(string.format("sent home %.0f s after registration, message read: %s", now - S.t5, tostring(said)))
        S.verdictC = said
        S.step = 5
    elseif now - S.t5 > 40 then
        return done(string.format("FAIL: (c) the low-fuel cow is still %s after 40 s | %s",
            cow and tostring(cow.ai.phase) or "gone", table.concat(S.notes, "; ")))
    else
        return done(string.format("RUNNING: step=4 (%.0f s) phase %s", now - S.t5, cow and tostring(cow.ai.phase) or "gone"))
    end
end

if S.step == 5 then
    local msgs = table.concat(S.msgs, " || ")
    cleanup()
    local v = S.verdictC and "PASS" or "FAIL: the flight did not read the low-fuel message"
    return done(v .. " | " .. table.concat(S.notes, "; ") .. " | messages: " .. msgs)
end

return done("ABORT: unknown step")
