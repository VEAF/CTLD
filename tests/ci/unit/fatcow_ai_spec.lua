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

    -- ── FEAT-FAT-COW-TAKEOVER: a cow that lost its flight ─────────────────────────────────────────

    -- A tracked player, as CTLDPlayerManager holds it.
    local function player(unitName, groupName, groupId, coalitionId, typeName, isTransport)
        players[unitName] = { unitName = unitName, groupName = groupName, groupId = groupId,
                              coalition = coalitionId or coalition.side.BLUE, typeName = typeName or "AH-64D_BLK_II",
                              isTransport = isTransport or false }
        return players[unitName]
    end

    -- Gunfighter's cow, landed and deployed 55 km from home, then Gunfighter shot down.
    local function orphanCow()
        local leader, cow = flightWithCow()
        units[cow.unitName]._p = { x = 60000, y = 20, z = 2000 }
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        groups["Gunfighter"].destroyed = true
        mgr:onDead({ initiator = leader })
        runScheduled()
        return cow
    end

    -- The labels the AI Fat Cow menu shows to `p`, as a set.
    local function aiMenuOf(p)
        local set = {}
        local menu = { addSubMenu = function() end,
                       addCommand = function(_, _, label) set[label] = true end }
        mgr:_buildAIMenu(p, menu, { "CTLD", "Fat Cow" })
        return set
    end

    -- An Apache flight "Viper" (group id 8), with a player, 3 km from home.
    local function viper()
        newGroup("Viper", 8, "Viper-1")
        newUnit("Viper-1", "Viper", 8000, 2000)
        return player("Viper-1", "Viper", 8)
    end

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

    it("tells the flights that could take it over that it is going home, and no one else", function()
        viper()
        player("Viper-2", "Viper", 8)                                       -- same flight: told once
        player("Red-1", "Red", 9, coalition.side.RED)                        -- other coalition
        player("Chinook-1", "Chinook", 10, nil, "CH-47Fbl1", true)          -- a cow pilot
        newGroup("Hammer", 11, "Hammer-1")
        newUnit("Hammer-1", "Hammer", 9000, 2000)
        player("Hammer-1", "Hammer", 11)
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
        local text
        for _, m in ipairs(messages) do if m.gid == 8 then text = m.text end end
        assert.is_not_nil(text:find("Akrotiri", 1, true))
        assert.is_not_nil(text:find("52.0 km", 1, true))                    -- from Viper-1, at x 8000
        assert.is_not_nil(text:find("Take over a Fat Cow", 1, true))
    end)

    it("shows Take over a Fat Cow to a flight without a cow while one waits, and no longer once taken", function()
        local p = viper()
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        local cow = orphanCow()
        assert.is_true(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[#rebuilt])                          -- its menu was rebuilt
        rebuilt = {}
        mgr:takeOverAICow("Viper-1")
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[1])
        assert.is_nil(cow.ai.orphan)
    end)

    it("leaves the menus once the cow it was offered for is home or dead", function()
        local p = viper()
        local cow = orphanCow()
        units[cow.unitName]._p = { x = 5000, y = 20, z = 2000 }
        rebuilt = {}
        mgr:onLand({ initiator = units[cow.unitName] })
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[1])
        groups["Gunfighter"].destroyed = false
        cow = orphanCow()
        rebuilt = {}
        mgr:onDead({ initiator = units[cow.unitName] })
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        assert.equals("Viper", rebuilt[1])
    end)

    it("joins the flight that takes it over, which then commands it as its own", function()
        viper()
        local cow = orphanCow()
        messages = {}
        mgr:takeOverAICow("Viper-1")
        assert.equals(cow, mgr:aiCowOfFlight("Viper"))
        assert.equals(CTLDFatCowManager.PHASE_FOLLOWING, cow.ai.phase)
        local t = lastTask(cow.ai.groupName)
        assert.equals("Follow", t.id)
        assert.equals(8, t.params.groupId)
        assert.equals(8, messages[1].gid)
        assert.is_not_nil(messages[1].text:find("7200 kg", 1, true))
        mgr:orderHoldHere("Viper-1")
        assert.equals("Orbit", lastTask(cow.ai.groupName).id)
        mgr:releaseAICow("Viper-1")
        assert.equals(CTLDFatCowManager.PHASE_RETURNING, cow.ai.phase)
        assert.is_nil(cow.ai.orphan)                                      -- released on purpose: not offered
    end)

    it("refuses a take-over to a flight with a cow, or when none waits", function()
        viper()
        mgr:takeOverAICow("Viper-1")
        assert.is_not_nil(messages[#messages].text:find("No Fat Cow is waiting", 1, true))
        local cow = orphanCow()
        mgr:requestAICow("Viper-1", 2)
        runScheduled()
        mgr:takeOverAICow("Viper-1")
        assert.is_not_nil(messages[#messages].text:find("already has a Fat Cow", 1, true))
        assert.is_true(cow.ai.orphan)
    end)

    it("offers neither a cow released with RTB nor an empty one", function()
        local p = viper()
        local leader, cow = flightWithCow()
        mgr:onLand({ initiator = leader })
        mgr:onLand({ initiator = units[cow.unitName] })
        runScheduled()
        mgr:releaseAICow("Gunfighter-1")
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
        newGroup("Hammer", 11, "Hammer-1")
        local hammer = newUnit("Hammer-1", "Hammer", 9000, 2000)
        mgr:requestAICow("Hammer-1", 1)
        runScheduled()
        local empty = mgr:aiCowOfFlight("Hammer")
        empty.stock = { fuelKg = 0, items = {} }
        groups["Hammer"].destroyed = true
        mgr:onDead({ initiator = hammer })
        runScheduled()
        assert.equals(CTLDFatCowManager.PHASE_RETURNING, empty.ai.phase)
        assert.is_nil(aiMenuOf(p)["Take over a Fat Cow"])
    end)
end)
