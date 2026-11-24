---@diagnostic disable
-- tests/ci/unit/fatcow_ai_spec.lua
-- FEAT-FAT-COW ticket 04: an AI cow comes from the nearest friendly logistic zone and follows a flight.
-- A player flight commands it from F10 (Land here, Take off, Hold here, Join us); an AI flight's cow
-- lands and takes off with the leader. It deploys after the delay, goes home when released.
-- ============================================================

local HELLFIRE = "weapons.missiles.AGM_114K"
local RADAR    = "weapons.missiles.AGM_114"

describe("AI Fat Cow", function()
    local mgr, sm, w, groups, units, scheduled, messages, added, inZone, saved, players, rebuilt

    local function newUnit(name, groupName, x, z)
        local u = {
            airborne = false, _name = name, _group = groupName, _p = { x = x or 0, y = 20, z = z or 0 },
        }
        function u:getName() return self._name end
        function u:isExist() return true end
        function u:getCoalition() return coalition.side.BLUE end
        function u:getCountry() return 2 end
        function u:getPoint() return self._p end
        function u:getPosition() return { x = { x = 1, y = 0, z = 0 }, p = self._p } end
        function u:inAir() return self.airborne end
        function u:getDesc() return { category = self.category or Unit.Category.HELICOPTER } end
        function u:getGroup() return groups[self._group] end
        units[name] = u
        return u
    end

    local function newGroup(name, id, unitName)
        local g = { _name = name, _id = id, tasks = {}, destroyed = false, activated = false }
        function g:getName() return self._name end
        function g:getID() return self._id end
        function g:isExist() return not self.destroyed end
        function g:getUnit() return units[unitName] end
        function g:getUnits()
            local out = {}
            for _, u in pairs(units) do if u._group == name then out[#out + 1] = u end end
            return out
        end
        function g:getController()
            local grp = self
            return { setTask = function(_, t) grp.tasks[#grp.tasks + 1] = t end }
        end
        function g:activate() self.activated = true end
        function g:destroy() self.destroyed = true end
        groups[name] = g
        return g
    end

    local function lastTask(groupName)
        local t = groups[groupName].tasks
        return t[#t]
    end

    local function runScheduled()
        local list = scheduled
        scheduled = {}
        for _, fn in ipairs(list) do fn() end
    end

    before_each(function()
        CTLDFatCowManager._instance = nil
        mgr = CTLDFatCowManager.getInstance()
        mgr._started = true
        sm  = CTLDSceneManager.getInstance()
        groups, units, scheduled, messages, added, inZone = {}, {}, {}, {}, {}, true
        w = { liquids = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }, items = {} }
        function w:getLiquidAmount(t) return self.liquids[t] end
        function w:setLiquidAmount(t, v) self.liquids[t] = v end
        function w:getItemCount(n) return self.items[n] or 0 end
        function w:setItem(n, v) self.items[n] = v end
        local zm = CTLDZoneManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        players, rebuilt = {}, {}
        saved = {
            players = pm._players, buildMenu = pm.buildMenu,
            unitGet = Unit.getByName, groupGet = Group.getByName, addGroup = coalition.addGroup,
            schedule = ctld.scheduler.schedule, remove = ctld.scheduler.remove,
            inAir = ctld.utils.inAir, gid = ctld.utils.getGroupId, outGroup = trigger.action.outTextForGroup,
            play = sm.playScene, pack = sm.packScene, airbase = Airbase.getByName,
            zone = zm.getLogisticZonesForCoalition, gs = ctld.gs, cargo = trigger.action.setUnitInternalCargo,
        }
        pm._players  = players
        pm.buildMenu = function(_, p) rebuilt[#rebuilt + 1] = p.groupName end
        Unit.getByName  = function(n) return units[n] end
        Group.getByName = function(n) return groups[n] end
        coalition.addGroup = function(_, _, data)
            added[#added + 1] = data
            newUnit(data.units[1].name, data.name, data.units[1].x, data.units[1].y)
            return newGroup(data.name, 100 + #added, data.units[1].name)
        end
        ctld.scheduler.schedule = function(fn) scheduled[#scheduled + 1] = fn; return #scheduled end
        ctld.scheduler.remove   = function(id) scheduled[id] = function() end end
        ctld.utils.inAir = function(u) return u.airborne end
        ctld.utils.getGroupId = function(u) return u:getGroup():getID() end
        trigger.action.outTextForGroup = function(gid, text) messages[#messages + 1] = { gid = gid, text = text } end
        trigger.action.setUnitInternalCargo = function() end
        zm.getLogisticZonesForCoalition = function()
            if not inZone then return {} end
            return { { name = "Akrotiri", getCenter = function() return { x = 5000, y = 10, z = 2000 } end } }
        end
        sm.playScene = function(_, u, model, params)
            local scene = { _name = "Fat Cow FARP#1", _params = params }
            mgr:onSceneLaidOut(scene)
            return scene
        end
        sm.packScene = function() return {} end
        Airbase.getByName = function(n) if n == "CTLD_FatCow_FARP_1" then return { getWarehouse = function() return w end } end end
        local settings = { fatCowAIType = "CH-47Fbl1", fatCowDeployDelay = 60, fatCowAICows = {},
                           fatCowTypes = { "CH-47Fbl1" },
                           fatCowLoadouts = {
                               { desc = "Six", fuelKg = 7200, items = { { item = HELLFIRE, count = 6 } } },
                               { desc = "Radar", fuelKg = 4800, items = { { item = RADAR, count = 20 } } },
                           } }
        ctld.gs = function(k) if settings[k] ~= nil then return settings[k] end return saved.gs(k) end
        mgr._settings = settings
    end)

    after_each(function()
        local zm = CTLDZoneManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        pm._players, pm.buildMenu = saved.players, saved.buildMenu
        Unit.getByName, Group.getByName, coalition.addGroup = saved.unitGet, saved.groupGet, saved.addGroup
        ctld.scheduler.schedule, ctld.scheduler.remove = saved.schedule, saved.remove
        ctld.utils.inAir, ctld.utils.getGroupId = saved.inAir, saved.gid
        trigger.action.outTextForGroup, trigger.action.setUnitInternalCargo = saved.outGroup, saved.cargo
        sm.playScene, sm.packScene, Airbase.getByName = saved.play, saved.pack, saved.airbase
        zm.getLogisticZonesForCoalition, ctld.gs = saved.zone, saved.gs
        CTLDFatCowManager._instance = nil
    end)

    -- An Apache flight "Gunfighter" (group id 7) whose leader requests a cow, and the cow ready.
    local function flightWithCow(player)
        newGroup("Gunfighter", 7, "Gunfighter-1")
        local leader = newUnit("Gunfighter-1", "Gunfighter", 1000, 2000)
        if player then function leader:getPlayerName() return "Zip" end end
        mgr:requestAICow("Gunfighter-1", 1)
        runScheduled()
        local cow = mgr:aiCowOfFlight("Gunfighter")
        return leader, cow
    end

    it("comes airborne from the nearest friendly logistic zone, with fuel, and follows the flight", function()
        local leader, cow = flightWithCow()
        leader.airborne = true
        assert.equals(1, #added)
        assert.equals("CH-47Fbl1", added[1].units[1].type)
        assert.equals("Turning Point", added[1].route.points[1].type)
        assert.equals(5000, added[1].units[1].x)
        assert.equals(2444, added[1].units[1].payload.fuel)   -- 80 % of the CH-47F's internal fuel
        assert.is_not_nil(cow)
        assert.equals(7200, cow.stock.fuelKg)
        assert.equals(6, cow.stock.items[HELLFIRE])
        local t = lastTask(cow.ai.groupName)
        assert.equals("Follow", t.id)
        assert.equals(7, t.params.groupId)
    end)

    it("carries the loadout the flight picked", function()
        newGroup("Gunfighter", 7, "Gunfighter-1")
        newUnit("Gunfighter-1", "Gunfighter")
        mgr:requestAICow("Gunfighter-1", 2)
        runScheduled()
        local cow = mgr:aiCowOfFlight("Gunfighter")
        assert.equals(4800, cow.stock.fuelKg)
        assert.equals(20, cow.stock.items[RADAR])
        assert.is_nil(cow.stock.items[HELLFIRE])
        mgr:requestAICow("Gunfighter-1", 9)                -- no such loadout: nothing comes
        assert.equals(1, #added)
    end)

    it("can be requested in the air, but not without a friendly logistic zone, nor twice", function()
        newGroup("Gunfighter", 7, "Gunfighter-1")
        local leader = newUnit("Gunfighter-1", "Gunfighter")
        leader.airborne = true
        inZone = false
        mgr:requestAICow("Gunfighter-1", 1)
        assert.equals(0, #added)
        inZone = true
        mgr:requestAICow("Gunfighter-1", 1)
        runScheduled()
        mgr:requestAICow("Gunfighter-1", 1)
        assert.equals(1, #added)
        assert.is_not_nil(messages[2].text:find("Akrotiri", 1, true))
    end)

    it("does nothing on its own for a player flight: the leader landing or taking off moves it not", function()
        local leader, cow = flightWithCow(true)
        units[cow.unitName].airborne = true
        mgr:onLand({ initiator = leader })
        assert.equals("Follow", lastTask(cow.ai.groupName).id)
        mgr:orderLandHere("Gunfighter-1")
        assert.equals("Mission", lastTask(cow.ai.groupName).id)
        units[cow.unitName].airborne = false
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        leader.airborne = true
        mgr:onTakeoff({ initiator = leader })              -- hopping onto the FARP
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
    end)

    it("obeys Take off, Hold here and Join us, packing its FARP first", function()
        local leader, cow = flightWithCow(true)
        units[cow.unitName].airborne = true
        mgr:orderLandHere("Gunfighter-1")
        units[cow.unitName].airborne = false
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        w.liquids[0] = 5000
        mgr:orderTakeOff("Gunfighter-1")
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        assert.equals(5000, cow.stock.fuelKg)
        assert.equals("Orbit", lastTask(cow.ai.groupName).id)
        mgr:orderHoldHere("Gunfighter-1")
        local orbit = lastTask(cow.ai.groupName)
        assert.equals("Orbit", orbit.id)
        assert.equals(leader._p.x, orbit.params.point.x)
        mgr:orderJoin("Gunfighter-1")
        assert.equals("Follow", lastTask(cow.ai.groupName).id)
    end)

    it("reports its stock before it has landed", function()
        local _, cow = flightWithCow(true)
        mgr:reportFlightCowStatus("Gunfighter-1")
        local text = messages[#messages].text
        assert.is_not_nil(text:find("7200 kg", 1, true))
        assert.is_not_nil(text:find("laser Hellfire x6", 1, true))
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
    end)

    it("lands next to the leader with a Land task, and deploys only after the delay", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        local t = lastTask(cow.ai.groupName)
        assert.equals("Mission", t.id)
        assert.equals("Land", t.params.route.points[1].task.params.tasks[1].id)
        mgr:onLand({ initiator = units[cow.unitName] })
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        runScheduled()
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        assert.equals(7200, w.liquids[0])
        assert.equals(7, messages[#messages].gid)
    end)

    it("packs and follows again when the leader takes off", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        w.liquids[0] = 6000
        leader.airborne = true
        mgr:onTakeoff({ initiator = leader })
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        assert.equals(6000, cow.stock.fuelKg)
        assert.equals("Follow", lastTask(cow.ai.groupName).id)
    end)

    it("ignores a wingman: only the leader moves the cow or closes its FARP", function()
        local leader, cow = flightWithCow()
        local wingman = newUnit("Gunfighter-2", "Gunfighter", 1000, 2050)
        mgr:onLand({ initiator = wingman })
        assert.equals("Follow", lastTask(cow.ai.groupName).id)
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        wingman.airborne = true
        mgr:onTakeoff({ initiator = wingman })
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
    end)

    it("does not deploy when the leader took off before the delay ran out", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        mgr:onTakeoff({ initiator = leader })
        runScheduled()
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        assert.equals("Follow", lastTask(cow.ai.groupName).id)
    end)

    -- FIX-FAT-COW-DEPLOY-REFUSALS (issue #296): the deployment that follows the delay can be refused, and the flight
    -- and the log are told why.
    describe("when the deployment that follows the delay is refused", function()
        local logs, savedLog
        local EMPTY   = "The Fat Cow is empty: send it home with RTB."
        local COULD_NOT = "The Fat Cow FARP could not be deployed."

        before_each(function()
            logs, savedLog = {}, ctld.utils.log
            ctld.utils.log = function(level, fmt, ...)
                local ok, text = pcall(string.format, fmt, ...)
                logs[#logs + 1] = { level = level, text = ok and text or fmt }
            end
        end)
        after_each(function() ctld.utils.log = savedLog end)

        local function logged(level, needle)
            local n = 0
            for _, l in ipairs(logs) do
                if l.level == level and l.text:find(needle, 1, true) then n = n + 1 end
            end
            return n
        end

        local function said(text)
            local n = 0
            for _, m in ipairs(messages) do if m.text == text then n = n + 1 end end
            return n
        end

        -- The cow has landed next to the leader and its delay is running; `refuse` spoils what the timer will do.
        local function landedThenRun(refuse)
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            mgr:onLand({ initiator = units[cow.unitName] })
            if refuse then refuse(cow) end
            messages, logs = {}, {}
            runScheduled()
            return cow
        end

        it("tells the flight that an empty cow has nothing to deploy, and logs why", function()
            local cow = landedThenRun(function(c) c.stock.fuelKg, c.stock.items = 0, {} end)
            assert.equals(1, said(EMPTY))
            assert.equals(7, messages[#messages].gid)                        -- the flight it serves
            assert.equals(1, logged("WARN", "did not deploy after the delay: empty"))
            assert.is_not_nil(logs[1].text:find(cow.unitName, 1, true))
            assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        end)

        it("tells the flight, and logs the reason, when the cow is in the air", function()
            landedThenRun(function(c) units[c.unitName].airborne = true end)
            assert.equals(1, said(COULD_NOT))
            assert.equals(1, logged("WARN", "did not deploy after the delay: airborne"))
        end)

        it("tells the flight, and logs the reason, when the scene did not start", function()
            sm.playScene = function() return nil end
            landedThenRun()
            assert.equals(1, said(COULD_NOT))
            assert.equals(1, logged("WARN", "did not deploy after the delay: scene"))
        end)

        it("tells the flight, and logs the reason, when the cow is no longer registered", function()
            landedThenRun(function(c) mgr._cows[c.unitName] = nil end)
            assert.equals(1, said(COULD_NOT))
            assert.equals(1, logged("WARN", "did not deploy after the delay: unknown"))
        end)

        it("only logs, at information level, when the FARP is already open", function()
            local cow = landedThenRun(function(c) c.state = CTLDFatCow.STATE_DEPLOYED end)
            assert.equals(0, #messages)
            assert.equals(1, logged("INFO", "already deployed when its delay ran out"))
            assert.equals(0, logged("WARN", "did not deploy"))
            assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        end)

        it("says nothing more than the scene did when the FARP could not be added (once)", function()
            Airbase.getByName = function() return nil end                  -- no warehouse: the scene fails
            landedThenRun()
            assert.equals(1, said(COULD_NOT))
            assert.equals(0, said(EMPTY))
            assert.equals(0, logged("WARN", "did not deploy after the delay"))
        end)

        it("sends nothing once the flight is gone, and still logs it", function()
            landedThenRun(function(c)
                c.stock.fuelKg, c.stock.items = 0, {}
                groups["Gunfighter"].destroyed = true
            end)
            assert.equals(0, said(EMPTY))
            assert.equals(0, #messages)
            assert.equals(1, logged("WARN", "did not deploy after the delay: empty"))
        end)

        it("leaves the nominal path alone: a cow with stock deploys, with no refusal", function()
            local cow = landedThenRun()
            assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
            assert.equals(0, said(EMPTY))
            assert.equals(0, said(COULD_NOT))
            assert.equals(0, logged("WARN", "did not deploy"))
            assert.equals(0, logged("INFO", "already deployed"))
        end)
    end)

    it("goes home when emptied, and despawns once landed there", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        w.liquids[0], w.items[HELLFIRE] = 0, 0
        mgr:onTakeoff({ initiator = leader })
        assert.equals(CTLDFatCowManager.PHASE_RETURNING, cow.ai.phase)
        assert.equals("Mission", lastTask(cow.ai.groupName).id)
        assert.is_nil(mgr:aiCowOfFlight("Gunfighter"))
        mgr:onLand({ initiator = units[cow.unitName] })
        assert.is_true(groups[cow.ai.groupName].destroyed)
        assert.is_nil(mgr:getCow(cow.unitName))
    end)

    it("goes home, packed, when released", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        mgr:releaseAICow("Gunfighter-1")
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        assert.equals(CTLDFatCowManager.PHASE_RETURNING, cow.ai.phase)
    end)

    it("goes home, packed, when its flight is gone", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        groups["Gunfighter"].destroyed = true
        mgr:onDead({ initiator = leader })
        runScheduled()
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        assert.equals(CTLDFatCowManager.PHASE_RETURNING, cow.ai.phase)
        assert.is_nil(mgr:aiCowOfFlight("Gunfighter"))
    end)

    it("waits for a late-activated escort to be activated", function()
        mgr._settings.fatCowAICows = { { group = "Cow Group", escort = "Gunfighter" } }
        newGroup("Cow Group", 50, "Cow-1")
        newUnit("Cow-1", "Cow Group")
        newGroup("Gunfighter", 7, "Gunfighter-1")
        local leader = newUnit("Gunfighter-1", "Gunfighter")
        leader.active = false
        function leader:isActive() return self.active end
        mgr:_activateMissionCows()
        assert.is_false(groups["Cow Group"].activated)
        leader.active = true
        mgr:onBirth({ initiator = leader })
        assert.is_true(groups["Cow Group"].activated)
    end)

    it("activates a mission-placed cow once its escorted flight is in the world", function()
        mgr._settings.fatCowAICows = { { group = "Cow Group", escort = "Gunfighter" } }
        newGroup("Cow Group", 50, "Cow-1")
        newUnit("Cow-1", "Cow Group")
        mgr:_activateMissionCows()
        assert.is_false(groups["Cow Group"].activated)   -- the flight is not there yet
        newGroup("Gunfighter", 7, "Gunfighter-1")
        newUnit("Gunfighter-1", "Gunfighter")
        mgr:onBirth({ initiator = units["Gunfighter-1"] })
        runScheduled()
        assert.is_true(groups["Cow Group"].activated)
        local cow = mgr:aiCowOfFlight("Gunfighter")
        assert.is_not_nil(cow)
        assert.equals(7200, cow.stock.fuelKg)            -- loadout 1 when the entry names none
        assert.equals("Follow", lastTask("Cow Group").id)
    end)

    it("does not activate a mission-placed cow whose loadout does not exist", function()
        mgr._settings.fatCowAICows = { { group = "Cow Group", escort = "Gunfighter", loadout = 7 } }
        newGroup("Cow Group", 50, "Cow-1")
        newUnit("Cow-1", "Cow Group")
        newGroup("Gunfighter", 7, "Gunfighter-1")
        newUnit("Gunfighter-1", "Gunfighter")
        mgr:_activateMissionCows()
        assert.is_false(groups["Cow Group"].activated)
    end)

    it("hands the FARP of a cow gone home to the next one", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        local farp = cow.farpName
        mgr:releaseAICow("Gunfighter-1")
        mgr:onLand({ initiator = units[cow.unitName] })     -- home: despawned
        assert.equals(farp, mgr:_farpNameFor("someone else"))
    end)

    it("gives a mission-placed cow the loadout its entry names", function()
        mgr._settings.fatCowAICows = { { group = "Cow Group", escort = "Gunfighter", loadout = 2 } }
        newGroup("Cow Group", 50, "Cow-1")
        newUnit("Cow-1", "Cow Group")
        newGroup("Gunfighter", 7, "Gunfighter-1")
        newUnit("Gunfighter-1", "Gunfighter")
        mgr:_activateMissionCows()
        runScheduled()
        assert.equals(20, mgr:aiCowOfFlight("Gunfighter").stock.items[RADAR])
    end)

    -- ── FEAT-FAT-COW-TAKEOVER: a cow going home can be taken over ─────────────────────────────────

    -- A tracked player, as CTLDPlayerManager holds it.
    local function player(unitName, groupName, groupId, coalitionId, typeName, isTransport)
        players[unitName] = { unitName = unitName, groupName = groupName, groupId = groupId,
                              coalition = coalitionId or coalition.side.BLUE, typeName = typeName or "AH-64D_BLK_II",
                              isTransport = isTransport or false }
        return players[unitName]
    end

    -- A player flight `name` (group id `id`) with its unit at x, z: a helicopter unless `category` says otherwise.
    local function playerFlight(name, id, x, z, category)
        newGroup(name, id, name .. "-1")
        local u = newUnit(name .. "-1", name, x, z)
        u.category = category
        return player(name .. "-1", name, id), u
    end

    -- Gunfighter's cow, landed and deployed at x (55 km from home by default), then Gunfighter shot down.
    local function orphanCow(x)
        local leader, cow = flightWithCow()
        units[cow.unitName]._p = { x = x or 60000, y = 20, z = 2000 }
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        groups["Gunfighter"].destroyed = true
        mgr:onDead({ initiator = leader })
        runScheduled()
        return cow
    end

    -- The AI Fat Cow menu `p` sees: the set of its labels (submenus included), and the take-over
    -- commands in order.
    local function aiMenuOf(p)
        local set, takeOver = {}, {}
        local menu = {
            addSubMenu = function(_, _, label) set[label] = true end,
            addCommand = function(_, path, label, _, arg, opts)
                set[label] = true
                if path[3] == "Take over a Fat Cow" then
                    takeOver[opts.order] = { label = label, cow = arg.cow }
                end
            end,
        }
        mgr:_buildAIMenu(p, menu, { "CTLD", "Fat Cow" })
        return set, takeOver
    end

    -- Every label of the whole Fat Cow menu section `p` sees.
    local function sectionOf(p)
        local set = {}
        local menu = {
            addSubMenu = function(_, _, label) set[label] = true end,
            addCommand = function(_, _, label) set[label] = true end,
        }
        mgr:buildMenuSection(p, menu)
        return set
    end

    -- FIX-FAT-COW-HELICOPTERS-ONLY: Zip, in an A-10 on an Open Training (2026-11-01), could request a cow.
    it("gives an aeroplane no Fat Cow menu, and a helicopter the AI one", function()
        local hog = playerFlight("Hog", 13, 8000, 2000, Unit.Category.AIRPLANE)
        assert.same({}, sectionOf(hog))
        local apache = playerFlight("Apache", 14, 8000, 2000)
        assert.is_true(sectionOf(apache)["Request a Fat Cow"])
    end)

    it("sends no cow to an aeroplane, whatever menu it clicked", function()
        playerFlight("Hog", 13, 8000, 2000, Unit.Category.AIRPLANE)
        mgr:requestAICow("Hog-1", 1)
        runScheduled()
        assert.is_nil(mgr:aiCowOfFlight("Hog"))
    end)

    it("is not despawned by a landing away from home (Marteau du Golan, 2026-10-29)", function()
        local cow = orphanCow()
        assert.equals(CTLDFatCowManager.PHASE_RETURNING, cow.ai.phase)
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)
        mgr:onLand({ initiator = units[cow.unitName] })     -- DCS fires it on the re-task, on the spot
        assert.is_false(groups[cow.ai.groupName].destroyed)
        assert.equals(cow, mgr:getCow(cow.unitName))
        units[cow.unitName]._p = { x = 5100, y = 20, z = 2000 }   -- home
        mgr:onLand({ initiator = units[cow.unitName] })
        assert.is_true(groups[cow.ai.groupName].destroyed)
        assert.is_nil(mgr:getCow(cow.unitName))
    end)

    it("is not despawned by a landing away from home after RTB either", function()
        local leader, cow = flightWithCow()
        units[cow.unitName]._p = { x = 60000, y = 20, z = 2000 }
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        mgr:releaseAICow("Gunfighter-1")
        mgr:onLand({ initiator = units[cow.unitName] })
        assert.is_false(groups[cow.ai.groupName].destroyed)
    end)

    it("tells the helicopter flights that could take it over that it is going home, and no one else", function()
        playerFlight("Viper", 8, 8000, 2000)
        player("Viper-2", "Viper", 8)                                       -- same flight: told once
        playerFlight("Red", 9, 8000, 2000)
        players["Red-1"].coalition = coalition.side.RED                      -- other coalition
        playerFlight("Chinook", 10, 8000, 2000)
        players["Chinook-1"].typeName, players["Chinook-1"].isTransport = "CH-47Fbl1", true   -- a cow pilot
        playerFlight("Hornet", 12, 8000, 2000, Unit.Category.AIRPLANE)      -- not a helicopter
        playerFlight("Hammer", 11, 9000, 2000)
        mgr:requestAICow("Hammer-1", 2)                                      -- a flight with a cow already
        runScheduled()
        messages = {}
        orphanCow()
        local to = {}
        for _, m in ipairs(messages) do to[m.gid] = (to[m.gid] or 0) + 1 end
        assert.equals(1, to[8])
        assert.is_nil(to[9])
        assert.is_nil(to[10])
        assert.is_nil(to[11])
        assert.is_nil(to[12])
        local text
        for _, m in ipairs(messages) do if m.gid == 8 then text = m.text end end
        assert.is_not_nil(text:find("Akrotiri", 1, true))
        assert.is_not_nil(text:find("52.0 km", 1, true))                    -- from Viper-1, at x 8000
        assert.is_not_nil(text:find("Take over a Fat Cow", 1, true))
    end)

    it("lists the cows going home to a helicopter flight without a cow, in the order of their numbers, with no distance", function()
        local p = playerFlight("Viper", 8, 8000, 2000)
        local hornet = playerFlight("Hornet", 12, 8000, 2000, Unit.Category.AIRPLANE)
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        local far  = orphanCow(60000)                                        -- 52 km from Viper-1: cow 1
        local near = orphanCow(20000)                                        -- 12 km: cow 2
        local set, takeOver = aiMenuOf(p)
        assert.is_true(set["Take over a Fat Cow"])
        assert.equals(far.unitName, takeOver[far.ai.number].cow)             -- the order is the number, not the distance
        assert.equals("Fat Cow #1 — going home to Akrotiri", takeOver[1].label)
        assert.equals(near.unitName, takeOver[near.ai.number].cow)
        assert.equals("Fat Cow #2 — going home to Akrotiri", takeOver[2].label)
        assert.is_nil(aiMenuOf(hornet)["Take over a Fat Cow"])
        local viperRebuilt = false
        for _, g in ipairs(rebuilt) do if g == "Viper" then viperRebuilt = true end end
        assert.is_true(viperRebuilt)                                        -- its menu was rebuilt
    end)

    it("offers a cow released with RTB, or empty, until it has landed at home", function()
        local p = playerFlight("Viper", 8, 8000, 2000)
        local leader, cow = flightWithCow()
        units[cow.unitName]._p = { x = 20000, y = 20, z = 2000 }
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        w.liquids[0], w.items[HELLFIRE] = 0, 0                               -- emptied
        mgr:releaseAICow("Gunfighter-1")
        local _, takeOver = aiMenuOf(p)
        assert.equals(cow.unitName, takeOver[cow.ai.number].cow)
        units[cow.unitName]._p = { x = 5000, y = 20, z = 2000 }
        rebuilt = {}
        mgr:onLand({ initiator = units[cow.unitName] })                     -- home
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[1])
    end)

    it("leaves the menus once the cow is dead", function()
        local p = playerFlight("Viper", 8, 8000, 2000)
        local cow = orphanCow()
        rebuilt = {}
        mgr:onDead({ initiator = units[cow.unitName] })
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[1])
    end)

    -- FIX-FAT-COW-TAKEOVER-LABELS (issue #298): the list has no distance, so nothing rebuilds it on a timer.
    it("does not rebuild the take-over menus on a timer", function()
        local registered = {}
        local savedRegister = ctld.scheduler.register
        ctld.scheduler.register = function(name) registered[#registered + 1] = name end
        mgr._started = false
        local ok, err = pcall(function() mgr:start() end)
        ctld.scheduler.register = savedRegister
        assert.is_true(ok, tostring(err))
        local resync = false
        for _, name in ipairs(registered) do
            assert.is_not.equals("fatCow_takeOverMenus", name)
            if name == "fatCow_resync" then resync = true end
        end
        assert.is_true(resync)                                               -- the control: the other timer is still there
    end)

    it("joins the flight that takes it over, which then commands it as its own", function()
        local p = playerFlight("Viper", 8, 8000, 2000)
        local cow = orphanCow()
        messages, rebuilt = {}, {}
        mgr:takeOverAICow("Viper-1", cow.unitName)
        assert.equals(cow, mgr:aiCowOfFlight("Viper"))
        assert.equals(CTLDFatCowManager.PHASE_FOLLOWING, cow.ai.phase)
        local t = lastTask(cow.ai.groupName)
        assert.equals("Follow", t.id)
        assert.equals(8, t.params.groupId)
        assert.equals(8, messages[1].gid)
        assert.is_not_nil(messages[1].text:find("52.0 km", 1, true))
        assert.is_not_nil(messages[1].text:find("7200 kg", 1, true))
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[1])
        mgr:orderHoldHere("Viper-1")
        assert.equals("Orbit", lastTask(cow.ai.groupName).id)
    end)

    it("refuses a take-over to a flight with a cow, or of a cow no longer going home", function()
        playerFlight("Viper", 8, 8000, 2000)
        local cow = orphanCow()
        playerFlight("Hammer", 11, 9000, 2000)
        mgr:takeOverAICow("Hammer-1", cow.unitName)                          -- Hammer takes it first
        mgr:takeOverAICow("Viper-1", cow.unitName)
        assert.is_not_nil(messages[#messages].text:find("no longer available", 1, true))
        assert.equals(cow, mgr:aiCowOfFlight("Hammer"))
        mgr:requestAICow("Viper-1", 2)
        runScheduled()
        mgr:takeOverAICow("Viper-1", cow.unitName)
        assert.is_not_nil(messages[#messages].text:find("already has a Fat Cow", 1, true))
    end)

    it("is released where it stands, FARP open, for another flight to take over", function()
        local p = playerFlight("Viper", 8, 8000, 2000)
        assert.is_true(aiMenuOf(p)["Release the Fat Cow"])
        local leader, cow = flightWithCow()
        units[cow.unitName]._p = { x = 20000, y = 20, z = 2000 }           -- 12 km from Viper-1
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        local tasks = #groups[cow.ai.groupName].tasks
        messages = {}
        mgr:freeAICow("Gunfighter-1")
        assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)                 -- still serving
        assert.equals(tasks, #groups[cow.ai.groupName].tasks)               -- not re-tasked
        assert.is_nil(mgr:aiCowOfFlight("Gunfighter"))
        local to = {}
        for _, m in ipairs(messages) do to[m.gid] = m.text end
        assert.is_not_nil(to[7]:find("released", 1, true))
        assert.is_not_nil(to[8]:find("was released", 1, true))
        assert.is_not_nil(to[8]:find("12.0 km", 1, true))
        local _, takeOver = aiMenuOf(p)
        assert.equals("Fat Cow #" .. cow.ai.number .. " — waiting", takeOver[cow.ai.number].label)
        mgr:takeOverAICow("Viper-1", cow.unitName)
        assert.equals(CTLDFatCow.STATE_STOWED, cow.state)                   -- packed before it moves
        local t = lastTask(cow.ai.groupName)
        assert.equals("Follow", t.id)
        assert.equals(8, t.params.groupId)
        assert.is_nil(cow.ai.released)
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
    end)

    -- ── FIX-FAT-COW-TAKEOVER-LABELS (issue #298): every AI cow has a number, and the messages name it ──

    describe("numbering the cows", function()
        local function groupNumber(cow) return tonumber(cow.ai.groupName:match("#(%d+)$")) end

        -- Two mission-placed cows "Cow A" and "Cow B" (escorting Gunfighter and Hammer), in the world.
        local function missionCows()
            mgr._settings.fatCowAICows = {
                { group = "Cow A", escort = "Gunfighter" },
                { group = "Cow B", escort = "Hammer" },
            }
            newGroup("Cow A", 50, "CowA-1"); newUnit("CowA-1", "Cow A")
            newGroup("Cow B", 51, "CowB-1"); newUnit("CowB-1", "Cow B")
            newGroup("Gunfighter", 7, "Gunfighter-1"); newUnit("Gunfighter-1", "Gunfighter")
            newGroup("Hammer", 11, "Hammer-1"); newUnit("Hammer-1", "Hammer")
            mgr:_activateMissionCows()
            runScheduled()
        end

        it("gives a requested cow the number of its group name, and keeps it", function()
            local leader, cow = flightWithCow()
            assert.equals(1, cow.ai.number)
            assert.equals("Fat Cow Gunfighter #1", cow.ai.groupName)
            assert.equals(groupNumber(cow), cow.ai.number)
            units[cow.unitName]._p = { x = 60000, y = 20, z = 2000 }
            mgr:onLand({ initiator = leader })
            mgr:onLand({ initiator = units[cow.unitName] })
            runScheduled()
            groups["Gunfighter"].destroyed = true
            mgr:onDead({ initiator = leader })
            runScheduled()
            assert.equals(1, cow.ai.number)                                 -- lost its flight: still cow 1
        end)

        it("numbers each requested cow once", function()
            local _, first = flightWithCow()
            newGroup("Hammer", 11, "Hammer-1")
            newUnit("Hammer-1", "Hammer", 9000, 2000)
            mgr:requestAICow("Hammer-1", 1)
            runScheduled()
            local second = mgr:aiCowOfFlight("Hammer")
            assert.equals(1, first.ai.number)
            assert.equals(2, second.ai.number)
            assert.equals(2, groupNumber(second))
        end)

        it("numbers the mission-placed cows from the same counter, in the order of fatCowAICows", function()
            missionCows()
            local a, b = mgr:aiCowOfFlight("Gunfighter"), mgr:aiCowOfFlight("Hammer")
            assert.equals(1, a.ai.number)
            assert.equals(2, b.ai.number)
            newGroup("Viper", 8, "Viper-1")
            newUnit("Viper-1", "Viper", 8000, 2000)
            mgr:requestAICow("Viper-1", 1)
            runScheduled()
            assert.equals(3, mgr:aiCowOfFlight("Viper").ai.number)          -- no number used twice
        end)

        it("leaves the group name a mission maker gave a placed cow alone", function()
            missionCows()
            assert.equals("Cow A", mgr:aiCowOfFlight("Gunfighter").ai.groupName)
            assert.equals("Cow B", mgr:aiCowOfFlight("Hammer").ai.groupName)
        end)
    end)

    describe("announcing a free cow by its number", function()
        local function toViper()
            local text
            for _, m in ipairs(messages) do if m.gid == 8 then text = m.text end end
            return text
        end

        it("names the cow that lost its flight and is going home to a base, with its distance and stock", function()
            playerFlight("Viper", 8, 8000, 2000)
            local cow = orphanCow()
            local text = toViper()
            assert.is_not_nil(text:find("Fat Cow #" .. cow.ai.number .. " lost its flight and is going home to Akrotiri: 52.0 km", 1, true))
            assert.is_not_nil(text:find("7200 kg", 1, true))
        end)

        it("names the cow that was released, with its distance", function()
            playerFlight("Viper", 8, 8000, 2000)
            local leader, cow = flightWithCow()
            units[cow.unitName]._p = { x = 20000, y = 20, z = 2000 }
            mgr:onLand({ initiator = leader })
            mgr:onLand({ initiator = units[cow.unitName] })
            runScheduled()
            messages = {}
            mgr:freeAICow("Gunfighter-1")
            local text = toViper()
            assert.is_not_nil(text:find("Fat Cow #" .. cow.ai.number .. " was released and waits for a flight: 12.0 km", 1, true))
        end)

        it("names a cow going home with no base known (a mission-placed cow)", function()
            playerFlight("Viper", 8, 8000, 2000)
            mgr._settings.fatCowAICows = { { group = "Cow A", escort = "Gunfighter" } }
            newGroup("Cow A", 50, "CowA-1"); newUnit("CowA-1", "Cow A", 20000, 2000)
            local leader = (function() newGroup("Gunfighter", 7, "Gunfighter-1"); return newUnit("Gunfighter-1", "Gunfighter") end)()
            mgr:_activateMissionCows()
            runScheduled()
            local cow = mgr:aiCowOfFlight("Gunfighter")
            messages = {}
            groups["Gunfighter"].destroyed = true
            mgr:onDead({ initiator = leader })
            runScheduled()
            local text = toViper()
            assert.is_not_nil(text:find("Fat Cow #" .. cow.ai.number .. " lost its flight and is going home: ", 1, true))
        end)
    end)

    -- FIX-FAT-COW-TAKEOVER-LABELS (issue #298): the real F10 rendering against the missionCommands double that recycles
    -- ids as DCS does (ADR 0027). A refresh that changes nothing for the pilot must create and remove nothing, and
    -- an entry clicked from a screen left open must reach the cow it names.
    describe("the Take over a Fat Cow list holds still", function()
        local mc, viper
        local LIST = { "CTLD", "Fat Cow", "Take over a Fat Cow" }
        local VIPER_GID = 8

        before_each(function()
            ctld.MenuManager._instance = nil
            mc = ctldMissionCommandsDouble.install()
            viper = playerFlight("Viper", VIPER_GID, 8000, 2000)
        end)

        after_each(function()
            mc:uninstall()
            ctld.MenuManager._instance = nil
        end)

        -- What buildMenu does for the Fat Cow section, on the real menu, applied the way a refresh applies it.
        local function render()
            local mm   = ctld.MenuManager:getInstance()
            local menu = mm:createMenuForGroup(VIPER_GID)
            menu.children, menu._lookup, menu.nextItemId = {}, {}, 1
            menu:addSubMenu({}, "CTLD", { order = 10 })
            mgr:buildMenuSection(viper, menu)
            mm:refreshMenuForGroup(VIPER_GID)
        end

        local function labels() return mc:labels(VIPER_GID, LIST) end

        local function move(cow, x) units[cow.unitName]._p = { x = x, y = 20, z = 2000 } end

        local function entryOf(cow)
            for _, name in ipairs(labels()) do
                if name:find("#" .. cow.ai.number .. " ", 1, true) then
                    return mc:idOf(VIPER_GID, { LIST[1], LIST[2], LIST[3], name })
                end
            end
        end

        it("creates and removes nothing when a cow has come closer between two refreshes", function()
            local cow = orphanCow(60000)                                     -- 52 km from Viper-1
            render()
            assert.equals(1, #labels())
            mc:resetCalls()
            move(cow, 20000)                                                 -- 12 km
            render()
            assert.equals(0, mc:callCount())
        end)

        it("gives two cows in the same state two distinct labels", function()
            orphanCow(60000)
            orphanCow(60000)                                                 -- the same distance
            render()
            local l = labels()
            assert.equals(2, #l)
            assert.is_not.equals(l[1], l[2])
        end)

        it("keeps the order of the numbers, whatever the distances", function()
            local first  = orphanCow(60000)                                  -- cow 1, the farther
            local second = orphanCow(20000)                                  -- cow 2, the nearer
            render()
            assert.same({ "Fat Cow #1 — going home to Akrotiri", "Fat Cow #2 — going home to Akrotiri" }, labels())
            move(first, 12000); move(second, 70000)                          -- the distances invert
            mc:resetCalls()
            render()
            assert.same({ "Fat Cow #1 — going home to Akrotiri", "Fat Cow #2 — going home to Akrotiri" }, labels())
            assert.equals(0, mc:callCount())
        end)

        it("takes the cow the entry names, after the cows swapped their distance ranks", function()
            local first  = orphanCow(60000)
            local second = orphanCow(20000)
            render()
            local id = entryOf(first)                                        -- the screen the pilot is reading
            move(first, 12000); move(second, 70000)
            render()
            mc:click(id)
            assert.equals(first, mgr:aiCowOfFlight("Viper"))
            assert.is_not.equals(second, mgr:aiCowOfFlight("Viper"))
        end)

        it("names the number and the state of each of the three kinds of cow", function()
            -- 1: lost its flight and goes home to a base
            local lost = orphanCow(60000)
            -- 2: released where it stands
            local leader, released = flightWithCow()
            units[released.unitName]._p = { x = 20000, y = 20, z = 2000 }
            mgr:onLand({ initiator = leader })
            mgr:onLand({ initiator = units[released.unitName] })
            runScheduled()
            mgr:freeAICow("Gunfighter-1")
            -- 3: a mission-placed cow that lost its flight (it has no base to name)
            mgr._settings.fatCowAICows = { { group = "Cow A", escort = "Hammer" } }
            newGroup("Cow A", 50, "CowA-1"); newUnit("CowA-1", "Cow A", 30000, 2000)
            newGroup("Hammer", 11, "Hammer-1")
            local hammer = newUnit("Hammer-1", "Hammer")
            mgr:_activateMissionCows()
            runScheduled()
            groups["Hammer"].destroyed = true
            mgr:onDead({ initiator = hammer })
            runScheduled()
            local placed
            for _, c in pairs(mgr._cows) do if c.ai and c.ai.groupName == "Cow A" then placed = c end end
            render()
            assert.same({
                "Fat Cow #" .. lost.ai.number .. " — going home to Akrotiri",
                "Fat Cow #" .. released.ai.number .. " — waiting",
                "Fat Cow #" .. placed.ai.number .. " — going home",
            }, labels())
        end)
    end)

    -- FIX-FAT-COW-EMPTY-AI-TYPE (issue #297): an empty fatCowAIType removes "Request a Fat Cow" and nothing else.
    describe("with an empty fatCowAIType", function()
        local COMMANDS = { "Land here", "Take off", "Hold here", "Join us", "Fat Cow status", "FARP status", "RTB",
                           "Release the Fat Cow" }

        it("keeps the Fat Cow menu, and removes only Request a Fat Cow", function()
            mgr._settings.fatCowAIType = ""
            local set = aiMenuOf(playerFlight("Viper", 8, 8000, 2000))
            assert.is_true(set["Fat Cow"])
            for _, label in ipairs(COMMANDS) do
                assert.is_true(set[label], label .. " is missing")
            end
            assert.is_nil(set["Request a Fat Cow"])
            assert.is_nil(set["Six"])                                        -- nor the loadouts under it
            assert.is_nil(set["Radar"])
        end)

        it("is unchanged with a type (the control)", function()
            local set = aiMenuOf(playerFlight("Viper", 8, 8000, 2000))
            assert.is_true(set["Request a Fat Cow"])
            assert.is_true(set["Six"])
            for _, label in ipairs(COMMANDS) do
                assert.is_true(set[label], label .. " is missing")
            end
        end)

        it("still offers a cow to take over", function()
            local p = playerFlight("Viper", 8, 8000, 2000)
            orphanCow()                                                      -- a cow going home
            mgr._settings.fatCowAIType = ""
            assert.is_true(aiMenuOf(p)["Take over a Fat Cow"])
        end)

        it("lets the pilot command a cow placed by the mission", function()
            mgr._settings.fatCowAIType = ""
            mgr._settings.fatCowAICows = { { group = "Cow Group", escort = "Gunfighter" } }
            newGroup("Cow Group", 50, "Cow-1")
            newUnit("Cow-1", "Cow Group")
            newGroup("Gunfighter", 7, "Gunfighter-1")
            local leader = newUnit("Gunfighter-1", "Gunfighter")
            function leader:getPlayerName() return "Zip" end
            mgr:_activateMissionCows()
            runScheduled()
            local cow = mgr:aiCowOfFlight("Gunfighter")
            assert.is_not_nil(cow)
            assert.is_true(aiMenuOf(player("Gunfighter-1", "Gunfighter", 7))["Land here"])
            units[cow.unitName].airborne = true
            mgr:orderLandHere("Gunfighter-1")                               -- the click on Land here
            assert.equals("Mission", lastTask(cow.ai.groupName).id)
        end)

        it("answers a flight with no cow that it has none", function()
            mgr._settings.fatCowAIType = ""
            playerFlight("Viper", 8, 8000, 2000)
            mgr:reportFlightCowStatus("Viper-1")
            assert.is_not_nil(messages[#messages].text:find("Your flight has no Fat Cow", 1, true))
            messages = {}
            mgr:orderLandHere("Viper-1")
            assert.is_not_nil(messages[#messages].text:find("Your flight has no Fat Cow", 1, true))
        end)
    end)

    -- FIX-FAT-COW-GROUND-TEST (issue #295): a landed CH-47 can read "in the air" to DCS's raw inAir(). The cow asks the
    -- shared helper, which counts it as on the ground. The mock tells the two apart: its raw inAir() always says
    -- "in the air", while `airborne` (what the helper reads, as in every spec of this file) says it is landed.
    describe("a landed CH-47 whose raw inAir() says it flies", function()
        local function atRest(cow) units[cow.unitName].inAir = function() return true end end

        it("deploys its FARP when the delay expires", function()
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            mgr:onLand({ initiator = units[cow.unitName] })
            atRest(cow)
            runScheduled()
            assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        end)

        it("is told by Land here that it is already on the ground, and is not re-tasked", function()
            local _, cow = flightWithCow(true)
            atRest(cow)
            local tasks = #groups[cow.ai.groupName].tasks
            messages = {}
            mgr:orderLandHere("Gunfighter-1")
            assert.is_not_nil(messages[#messages].text:find("already on the ground", 1, true))
            assert.equals(tasks, #groups[cow.ai.groupName].tasks)
        end)

        it("stays on the ground, its FARP open, when released", function()
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            mgr:onLand({ initiator = units[cow.unitName] })
            runScheduled()
            assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
            atRest(cow)
            local tasks = #groups[cow.ai.groupName].tasks
            mgr:freeAICow("Gunfighter-1")
            assert.equals(tasks, #groups[cow.ai.groupName].tasks)            -- no orbit task: it does not lift off
            assert.equals(CTLDFatCow.STATE_DEPLOYED, cow.state)
        end)

        it("is still refused as airborne by the deployment when it really flies (control)", function()
            local _, cow = flightWithCow()
            units[cow.unitName].airborne = true
            local ok, why = mgr:deploy(units[cow.unitName])
            assert.is_false(ok)
            assert.equals("airborne", why)
        end)

        it("is still sent to land by Land here when it really flies (control)", function()
            local _, cow = flightWithCow(true)
            units[cow.unitName].airborne = true
            mgr:orderLandHere("Gunfighter-1")
            assert.equals("Mission", lastTask(cow.ai.groupName).id)
        end)

        it("still orbits where it stands when released while it really flies (control)", function()
            local _, cow = flightWithCow()
            units[cow.unitName].airborne = true
            mgr:freeAICow("Gunfighter-1")
            assert.equals("Orbit", lastTask(cow.ai.groupName).id)
        end)
    end)

    -- ── FIX-FAT-COW-AI-LANDING ───────────────────────────────────────────────────────────────────

    -- The Land task point the cow was last given, as { x, z }.
    local function landPoint(cow)
        local p = lastTask(cow.ai.groupName).params.route.points[1].task.params.tasks[1].params.point
        return { x = p.x, z = p.y }
    end

    describe("landing next to the leader", function()
        local savedDisposition, asked
        before_each(function()
            savedDisposition, asked = _G.Disposition, nil
        end)
        after_each(function() _G.Disposition = savedDisposition end)

        local function disposition(candidates)
            _G.Disposition = { getSimpleZones = function(p, radius, clearance, attempts)
                asked = { p = p, radius = radius, clearance = clearance, attempts = attempts }
                return candidates
            end }
        end

        it("lands in the nearest clearing around the point 120 m left of the leader", function()
            disposition({
                { x = 1000, y = 0, z = 1950 },     -- 50 m from the leader: too close
                { x = 1000, y = 0, z = 1700 },     -- 180 m from the asked point
                { x = 1100, y = 0, z = 1880 },     -- 100 m: the one
                { x = 1500, y = 0, z = 1880 },     -- 500 m: out of the search radius
            })
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            assert.equals(1000, asked.p.x)
            assert.equals(1880, asked.p.z)
            assert.equals(300, asked.radius)
            assert.equals(100, asked.clearance)                             -- the widest first
            assert.same({ x = 1100, z = 1880 }, landPoint(cow))
        end)

        it("takes the widest clearance that offers a clearing: 100 m, else 50, else 30", function()
            local clearances = {}
            _G.Disposition = { getSimpleZones = function(_, _, clearance)
                clearances[#clearances + 1] = clearance
                if clearance == 50 then return { { x = 1200, y = 1880 } } end   -- 200 m away
                if clearance == 30 then return { { x = 1040, y = 1880 } } end   -- nearer, but closer to scenery
                return {}
            end }
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            assert.same({ 100, 50 }, clearances)
            assert.same({ x = 1200, z = 1880 }, landPoint(cow))
        end)

        it("reads a candidate given as a vec2 (y is the map z)", function()
            disposition({ { x = 1050, y = 1800 } })
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            assert.same({ x = 1050, z = 1800 }, landPoint(cow))
        end)

        it("skips a clearing on water", function()
            disposition({ { x = 1100, y = 0, z = 1880 } })
            local leader, cow = flightWithCow()
            local savedSurface = land.getSurfaceType
            land.getSurfaceType = function() return land.SurfaceType.WATER end
            mgr:onLand({ initiator = leader })
            land.getSurfaceType = savedSurface
            assert.same({ x = 1000, z = 1880 }, landPoint(cow))
        end)

        it("keeps the asked point without the singleton, on an error, or with no clearing", function()
            _G.Disposition = nil
            local leader, cow = flightWithCow()
            mgr:onLand({ initiator = leader })
            assert.same({ x = 1000, z = 1880 }, landPoint(cow))
            _G.Disposition = { getSimpleZones = function() error("signature changed") end }
            mgr:orderLandHere("Gunfighter-1")
            units[cow.unitName].airborne = true
            mgr:orderLandHere("Gunfighter-1")
            assert.same({ x = 1000, z = 1880 }, landPoint(cow))
            disposition({})
            mgr:orderLandHere("Gunfighter-1")
            assert.same({ x = 1000, z = 1880 }, landPoint(cow))
        end)

        it("searches a clearing for Land here too", function()
            disposition({ { x = 1100, y = 0, z = 1880 } })
            local _, cow = flightWithCow(true)
            units[cow.unitName].airborne = true
            mgr:orderLandHere("Gunfighter-1")
            assert.same({ x = 1100, z = 1880 }, landPoint(cow))
        end)

        -- FIX-FAT-COW-CLEARING-LOG (issue #299): the situations in which the search cannot do its job leave a trace.
        describe("logs why it cannot land in a clearing", function()
            local logs, savedLog

            before_each(function()
                logs, savedLog = {}, ctld.utils.log
                ctld.utils.log = function(level, fmt, ...)
                    local ok, text = pcall(string.format, fmt, ...)
                    logs[#logs + 1] = { level = level, text = ok and text or fmt }
                end
            end)
            after_each(function() ctld.utils.log = savedLog end)

            local function lines(level, needle)
                local out = {}
                for _, l in ipairs(logs) do
                    if l.level == level and (not needle or l.text:find(needle, 1, true)) then out[#out + 1] = l.text end
                end
                return out
            end

            -- A player flight's cow, airborne: "Land here" is the landing, as many times as it is called.
            local function cowToLand()
                local _, cow = flightWithCow(true)
                units[cow.unitName].airborne = true
                return cow
            end

            local ASKED = { x = 1000, z = 1880 }

            it("warns once when the singleton is missing", function()
                _G.Disposition = nil
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                local w = lines("WARN", "is not available")
                assert.equals(1, #w)
                assert.is_not_nil(w[1]:find(cow.unitName, 1, true))
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(1, #lines("WARN", "is not available"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("warns once with the error the search raised", function()
                _G.Disposition = { getSimpleZones = function() error("signature changed") end }
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                local w = lines("WARN", "failed")
                assert.equals(1, #w)
                assert.is_not_nil(w[1]:find("signature changed", 1, true))
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(1, #lines("WARN", "failed"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("warns once when the search returns something that is not a table", function()
                _G.Disposition = { getSimpleZones = function() return "oops" end }
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                local w = lines("WARN", "returned")
                assert.equals(1, #w)
                assert.is_not_nil(w[1]:find("a string", 1, true))
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(1, #lines("WARN", "returned"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("says nil when the search returns nothing", function()
                _G.Disposition = { getSimpleZones = function() return nil end }
                cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                local w = lines("WARN", "returned")
                assert.equals(1, #w)
                assert.is_not_nil(w[1]:find("returned nil", 1, true))
            end)

            it("warns when a non-empty list holds no point at all", function()
                disposition({ 5, "x" })
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                local w = lines("WARN", "returned")
                assert.equals(1, #w)
                assert.is_not_nil(w[1]:find("a list whose first entry is a number", 1, true))
                assert.same(ASKED, landPoint(cow))
            end)

            it("counts a candidate without numeric coordinates as no point, and does not raise", function()
                disposition({ { x = "far", y = 1880 } })
                local cow = cowToLand()
                assert.has_no.errors(function() mgr:orderLandHere("Gunfighter-1") end)
                assert.equals(1, #lines("WARN", "returned"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("does not warn when at least one candidate is a point: it picks it", function()
                disposition({ 5, { x = 1100, y = 1880 } })
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(0, #lines("WARN"))
                assert.same({ x = 1100, z = 1880 }, landPoint(cow))
            end)

            it("tells at every landing that there is no clearing, without a warning, for an empty list", function()
                disposition({})
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                mgr:orderLandHere("Gunfighter-1")
                local i = lines("INFO", "no clearing within 300 m")
                assert.equals(2, #i)
                assert.is_not_nil(i[1]:find(cow.unitName, 1, true))
                assert.equals(0, #lines("WARN"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("does the same when every point is rejected (too close to the leader, out of range)", function()
                disposition({ { x = 1000, y = 1950 }, { x = 1500, y = 1880 } })
                local cow = cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(1, #lines("INFO", "no clearing within 300 m"))
                assert.equals(0, #lines("WARN"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("tracks the three causes apart: an error does not silence a later wrong shape", function()
                local cow = cowToLand()
                _G.Disposition = { getSimpleZones = function() error("boom") end }
                mgr:orderLandHere("Gunfighter-1")
                _G.Disposition = { getSimpleZones = function() return "oops" end }
                mgr:orderLandHere("Gunfighter-1")
                _G.Disposition = nil
                mgr:orderLandHere("Gunfighter-1")
                _G.Disposition = { getSimpleZones = function() error("boom again") end }
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(1, #lines("WARN", "failed"))
                assert.equals(1, #lines("WARN", "returned"))
                assert.equals(1, #lines("WARN", "is not available"))
                assert.equals(3, #lines("WARN"))
                assert.same(ASKED, landPoint(cow))
            end)

            it("logs when the flight's own landing takes the fallback, not only on Land here", function()
                _G.Disposition = nil
                local leader = flightWithCow()
                mgr:onLand({ initiator = leader })
                assert.equals(1, #lines("WARN", "is not available"))
            end)

            it("keeps its line for a clearing that was found, and nothing else", function()
                disposition({ { x = 1100, y = 1880 } })
                cowToLand()
                mgr:orderLandHere("Gunfighter-1")
                assert.equals(1, #lines("INFO", "lands in a clearing"))
                assert.equals(0, #lines("INFO", "no clearing"))
                assert.equals(0, #lines("WARN"))
            end)
        end)
    end)

    it("forgets a cow whose unit vanished without an event, and its flight may request another", function()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        units[cow.unitName] = nil                                           -- struck a tree: no DEAD, no CRASH
        mgr:_resyncFarps()
        assert.is_nil(mgr:getCow(cow.unitName))
        assert.is_nil(mgr:aiCowOfFlight("Gunfighter"))
        mgr:requestAICow("Gunfighter-1", 1)
        assert.equals(2, #added)
    end)

    it("orbits where it stands when released in the air", function()
        local _, cow = flightWithCow()
        units[cow.unitName].airborne = true
        units[cow.unitName]._p = { x = 20000, y = 20, z = 2000 }
        mgr:freeAICow("Gunfighter-1")
        local t = lastTask(cow.ai.groupName)
        assert.equals("Orbit", t.id)
        assert.equals(20000, t.params.point.x)
        mgr:freeAICow("Gunfighter-1")
        assert.is_not_nil(messages[#messages].text:find("no Fat Cow", 1, true))
    end)

    -- FIX-FAT-COW-STRANDED 01: a cow that hovered for 5 h left no line in the log (Campagne, 2026-11-22).
    describe("logs every order and phase change of the cow", function()
        local logs, savedLog

        before_each(function()
            logs, savedLog = {}, ctld.utils.log
            ctld.utils.log = function(level, fmt, ...)
                local ok, text = pcall(string.format, fmt, ...)
                logs[#logs + 1] = { level = level, text = ok and text or fmt }
            end
        end)
        after_each(function() ctld.utils.log = savedLog end)

        -- The INFO lines that name `cow` and contain every needle.
        local function lines(cow, ...)
            local needles, out = { ... }, {}
            for _, l in ipairs(logs) do
                local all = l.level == "INFO" and l.text:find(cow.unitName, 1, true) ~= nil
                for _, n in ipairs(needles) do all = all and l.text:find(n, 1, true) ~= nil end
                if all then out[#out + 1] = l.text end
            end
            return out
        end

        it("writes one order line naming the cow and the requester, and one phase line, for Take off", function()
            local _, cow = flightWithCow(true)
            logs = {}
            mgr:orderTakeOff("Gunfighter-1")
            local order = lines(cow, "order", "Take off", "Gunfighter-1")
            assert.equals(1, #order)
            local phase = lines(cow, "phase following -> holding")
            assert.equals(1, #phase)
        end)

        it("logs Hold here, Join us and Land here with the unit that gave them", function()
            local _, cow = flightWithCow(true)
            units[cow.unitName].airborne = true
            logs = {}
            mgr:orderHoldHere("Gunfighter-1")
            assert.equals(1, #lines(cow, "order", "Hold here", "Gunfighter-1"))
            mgr:orderJoin("Gunfighter-1")
            assert.equals(1, #lines(cow, "order", "Join us", "Gunfighter-1"))
            assert.equals(1, #lines(cow, "phase holding -> following"))
            mgr:orderLandHere("Gunfighter-1")
            assert.equals(1, #lines(cow, "order", "Land here", "Gunfighter-1"))
            assert.equals(1, #lines(cow, "phase following -> landing"))
        end)

        it("logs RTB, Release and Take over", function()
            local _, cow = flightWithCow(true)
            units[cow.unitName].airborne = true
            logs = {}
            mgr:freeAICow("Gunfighter-1")
            assert.equals(1, #lines(cow, "order", "Release", "Gunfighter-1"))
            newGroup("Viper", 8, "Viper-1")
            newUnit("Viper-1", "Viper")
            mgr:takeOverAICow("Viper-1", cow.unitName)
            assert.equals(1, #lines(cow, "order", "Take over", "Viper-1"))
            logs = {}
            mgr:releaseAICow("Viper-1")
            assert.equals(1, #lines(cow, "order", "RTB", "Viper-1"))
            assert.equals(1, #lines(cow, "phase following -> returning"))
        end)

        it("logs the landing and the end of the landing as phase changes", function()
            local leader, cow = flightWithCow()
            logs = {}
            mgr:onLand({ initiator = leader })
            assert.equals(1, #lines(cow, "phase following -> landing"))
            mgr:onLand({ initiator = units[cow.unitName] })
            assert.equals(1, #lines(cow, "phase landing -> landed"))
        end)

        it("writes nothing more while nothing changes, loop ticks included", function()
            local _, cow = flightWithCow(true)
            mgr:orderHoldHere("Gunfighter-1")
            logs = {}
            mgr:_resyncFarps()
            mgr:_resyncFarps()
            assert.equals(0, #lines(cow))
        end)

        it("writes no phase line when an order leaves the phase as it was", function()
            local _, cow = flightWithCow(true)
            mgr:orderHoldHere("Gunfighter-1")
            logs = {}
            mgr:orderHoldHere("Gunfighter-1")
            assert.equals(1, #lines(cow, "order", "Hold here"))
            assert.equals(0, #lines(cow, "phase"))
        end)
    end)
end)
