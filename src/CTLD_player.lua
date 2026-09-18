---@diagnostic disable
-- ============================================================
-- CTLD_player.lua
-- CTLDPlayer entity + CTLDPlayerManager singleton
--
-- CTLDPlayer       : immutable identity snapshot (unit name, group, coalition,
--                    type, capabilities) plus mutable cargo state
--                    (loaded crates / vehicles / troops).
-- CTLDPlayerManager: lifecycle (enter/leave unit), F10 menu orchestration,
--                    cargo state tracking via EventDispatcher subscriptions.
--
-- DCS events consumed (via CTLDDCSEventBridge):
--   S_EVENT_PLAYER_ENTER_UNIT → onPlayerEnterUnit(event)
--   S_EVENT_PLAYER_LEAVE_UNIT → onPlayerLeaveUnit(event)
--
-- CTLD events consumed (via EventDispatcher):
--   OnVehicleLoaded   { transportUnitObject, ctldVehicleObject } → add to loadedVehicles
--   OnVehicleUnloaded { transportUnitObject, ctldVehicleObject } → remove from loadedVehicles
--   OnCrateLoaded     { carrierUnitName, crate }                → add to loadedCrates
--
-- Events published: none.
--
-- Dependencies: class (lib/class.lua), CTLDUtils (ctld.utils),
--               CTLDConfig (ctld.gs), EventDispatcher, CTLDDCSEventBridge,
--               ctld.MenuManager (CTLD_menu.lua)
-- DCS API: unit:getName, unit:getGroup, unit:getTypeName, unit:getCoalition,
--          unit:getPlayerName, unit:isExist,
--          missionCommands.removeItemForGroup, trigger.action.outTextForGroup
-- ============================================================

ctld = ctld or {}

-- ============================================================
-- CTLDPlayer  (entity)
-- ============================================================

CTLDPlayer = class()

--- Constructor.
-- @param data table  Required fields:
--   unitName, groupId, groupName, coalition, typeName, isTransport, canCarryVehicles
function CTLDPlayer:init(data)
    self.unitName         = data.unitName
    self.groupId          = data.groupId
    self.groupName        = data.groupName
    self.coalition        = data.coalition
    self.typeName         = data.typeName
    self.isTransport      = data.isTransport      or false
    self.canCarryVehicles = data.canCarryVehicles  or false
    self.loadedTroops     = {}
    self.loadedCrates     = {}
    self.loadedVehicles   = {}
end

--- Append a CTLDVehicle to the loaded vehicles list.
-- @param ctldVehicleObject CTLDVehicle
function CTLDPlayer:addLoadedVehicle(ctldVehicleObject)
    table.insert(self.loadedVehicles, ctldVehicleObject)
end

--- Remove a CTLDVehicle from the loaded list (matched by object identity).
-- @param ctldVehicleObject CTLDVehicle
function CTLDPlayer:removeLoadedVehicle(ctldVehicleObject)
    for i, v in ipairs(self.loadedVehicles) do
        if v == ctldVehicleObject then
            table.remove(self.loadedVehicles, i)
            return
        end
    end
end

--- Append a CTLDCrate to the loaded crates list.
-- @param ctldCrateObject CTLDCrate
function CTLDPlayer:addLoadedCrate(ctldCrateObject)
    table.insert(self.loadedCrates, ctldCrateObject)
end

--- Remove a CTLDCrate from the loaded list (matched by object identity).
-- @param ctldCrateObject CTLDCrate
function CTLDPlayer:removeLoadedCrate(ctldCrateObject)
    for i, c in ipairs(self.loadedCrates) do
        if c == ctldCrateObject then
            table.remove(self.loadedCrates, i)
            return
        end
    end
end

-- ============================================================
-- CTLDPlayerManager  (singleton)
-- ============================================================

CTLDPlayerManager = class()
CTLDPlayerManager._instance = nil

-- Pre-init queue for menu sections registered before getInstance() is called
-- (e.g. by scene files loaded before CTLDCoreManager runs).
-- Flushed into _menuSections during init().
CTLDPlayerManager._deferredSections = {}

--- Queue a menu section definition for registration at init time.
-- Load-position-independent: if the manager is already initialised (e.g. a plugin scene loaded
-- from a mission-start trigger after CTLD), route straight to registerMenuSection instead of
-- queuing into the already-drained pre-init queue. Otherwise queue for the init-time flush.
-- Safe to call from module top-level code before CTLDPlayerManager.getInstance().
-- @param sectionDef table  same format as registerMenuSection()
function CTLDPlayerManager.deferMenuSection(sectionDef)
    if not sectionDef or not sectionDef.key then return end
    if CTLDPlayerManager._instance then
        CTLDPlayerManager._instance:registerMenuSection(sectionDef)
    else
        CTLDPlayerManager._deferredSections[#CTLDPlayerManager._deferredSections + 1] = sectionDef
    end
end

--- Return (or create) the singleton instance.
function CTLDPlayerManager.getInstance()
    if not CTLDPlayerManager._instance then
        local o = setmetatable({}, CTLDPlayerManager)
        o:init()
        CTLDPlayerManager._instance = o
    end
    return CTLDPlayerManager._instance
end

function CTLDPlayerManager:init()
    self._players      = {}   -- unitName → CTLDPlayer
    self._menuSections = {}   -- ordered list of { key, manager, method, configKey, order }

    -- Register for DCS player slot events
    local bridge = CTLDDCSEventBridge.getInstance()
    bridge:register(self, world.event.S_EVENT_PLAYER_ENTER_UNIT, "onPlayerEnterUnit")
    bridge:register(self, world.event.S_EVENT_PLAYER_LEAVE_UNIT, "onPlayerLeaveUnit")
    -- Safety net: DCS can fire S_EVENT_BIRTH before world.addEventHandler is registered, and a
    -- missed ENTER leaves a player with no CTLD menu until the 30 s sweep catches up.
    bridge:register(self, world.event.S_EVENT_BIRTH, "onBirth")

    -- Subscribe to CTLD cargo events to maintain per-player cargo state
    local ed = EventDispatcher.getInstance()

    ed:subscribe("OnVehicleLoaded", function(p)
        if not p or not p.transportUnitObject then return end
        local playerObj = self:getPlayer(p.transportUnitObject:getName())
        if not playerObj then return end
        if p.ctldVehicleObject then
            playerObj:addLoadedVehicle(p.ctldVehicleObject)
        end
        self:refreshForUnit(playerObj.unitName)
    end)

    ed:subscribe("OnVehicleUnloaded", function(p)
        if not p or not p.transportUnitObject then return end
        local playerObj = self:getPlayer(p.transportUnitObject:getName())
        if not playerObj then return end
        if p.ctldVehicleObject then
            playerObj:removeLoadedVehicle(p.ctldVehicleObject)
        end
        self:refreshForUnit(playerObj.unitName)
    end)

    ed:subscribe("OnCrateLoaded", function(p)
        if not p or not p.carrierUnitName then return end
        local playerObj = self:getPlayer(p.carrierUnitName)
        if not playerObj then return end
        if p.crate then playerObj:addLoadedCrate(p.crate) end
        self:refreshForUnit(playerObj.unitName)
        -- Crate is now inside the aircraft: remove it from the Unpack menu immediately
        CTLDCrateManager.getInstance():refreshUnpackSectionForUnit(p.carrierUnitName)
    end)

    -- When a FOB is deployed, refresh Request Equipment for all grounded players
    -- who may now be within the new FOB logistic zone.
    ed:subscribe("OnFOBDeployed", function(_p)
        local crateMgr = CTLDCrateManager.getInstance()
        local jtacMgr  = CTLDJTACManager.getInstance()
        for _, playerObj in pairs(self._players) do
            local unit = Unit.getByName(playerObj.unitName)
            if unit and unit:isExist() and not ctld.utils.inAir(unit) then
                crateMgr:refreshRequestEquipmentSection(playerObj)
                jtacMgr:refreshJtacEquipmentSection(playerObj)
            end
        end
    end)

    -- Flush pre-init deferred sections (registered by scene files before getInstance()).
    for _, s in ipairs(CTLDPlayerManager._deferredSections) do
        self:registerMenuSection(s)
    end
    CTLDPlayerManager._deferredSections = {}

    -- Flight-state poller (0.5 s cadence).
    -- S_EVENT_TAKEOFF / S_EVENT_LAND fire with a 3-5 s delay in DCS for helicopters.
    -- This poller detects the inAir() transition immediately and triggers the same
    -- refresh chain, so menus switch within 0.5 s of the actual state change.
    -- onTakeoff / onLand still run when the events fire, but by then _isFlying already
    -- matches the real state and the refresh is a fast no-op.
    -- unitName → { confirmed=bool, pending=bool|nil, ticks=number }
    -- confirmed: last state that triggered a menu refresh (nil = not yet seeded)
    -- pending:   candidate new state (must hold for DEBOUNCE_TICKS consecutive polls)
    -- ticks:     consecutive ticks the pending state has been seen
    self._inAirDebounce = {}
    local POLL_INTERVAL   = 0.5   -- seconds between checks
    local DEBOUNCE_TICKS  = 2     -- require 2 consecutive same-state ticks (~1 s) before acting
    local self_ref = self
    timer.scheduleFunction(function(_, t)
        local inst = self_ref
        if not inst then return nil end
        for unitName, playerObj in pairs(inst._players) do
            local unit = Unit.getByName(unitName)
            if unit and unit:isExist() then
                local nowInAir = ctld.utils.inAir(unit)
                local db = inst._inAirDebounce[unitName]
                if not db then
                    -- First encounter: seed confirmed state, no refresh needed (buildMenu ran already).
                    inst._inAirDebounce[unitName] = { confirmed = nowInAir, pending = nil, ticks = 0 }
                else
                    if nowInAir == db.confirmed then
                        -- State matches confirmed: reset pending
                        db.pending = nil
                        db.ticks   = 0
                    else
                        -- State differs from confirmed: debounce
                        if db.pending == nowInAir then
                            db.ticks = db.ticks + 1
                        else
                            db.pending = nowInAir
                            db.ticks   = 1
                        end
                        if db.ticks >= DEBOUNCE_TICKS then
                            -- Stable new state — commit and refresh menus
                            db.confirmed = nowInAir
                            db.pending   = nil
                            db.ticks     = 0
                            playerObj._isFlying = nowInAir
                            -- runUrgent: same real transition onTakeoff/onLand handle, detected
                            -- here redundantly by polling — see AMBIENT vs URGENT REFRESH in
                            -- CTLD_menu.lua.
                            if nowInAir then
                                ctld.MenuManager:getInstance():runUrgent(playerObj.groupId, function()
                                    CTLDTroopManager.getInstance():refreshMenuSection(playerObj, true)
                                    CTLDCrateManager.getInstance():refreshRequestEquipmentSection(playerObj)
                                    CTLDCrateManager.getInstance():refreshCrateFlightSection(playerObj, true)
                                    CTLDVehicleSpawner.getInstance():refreshLoadSection(playerObj)
                                    CTLDVehicleSpawner.getInstance():refreshUnloadSection(playerObj)
                                    CTLDVehicleSpawner.getInstance():refreshParachuteVehicleSection(playerObj)
                                    CTLDJTACManager.getInstance():refreshJtacEquipmentSection(playerObj)
                                end)
                                ctld.utils.log("INFO", "CTLDPlayerManager: flight-state poller → TAKEOFF unit=%s", unitName)
                            else
                                ctld.MenuManager:getInstance():runUrgent(playerObj.groupId, function()
                                    CTLDTroopManager.getInstance():refreshMenuSection(playerObj, false)
                                    CTLDCrateManager.getInstance():refreshRequestEquipmentSection(playerObj)
                                    CTLDCrateManager.getInstance():refreshLoadCrateSection(playerObj)
                                    CTLDCrateManager.getInstance():refreshUnpackSection(playerObj, true)  -- _noRefresh: refreshCrateFlightSection below calls refresh()
                                    CTLDCrateManager.getInstance():refreshCrateFlightSection(playerObj, false)
                                    CTLDVehicleSpawner.getInstance():refreshLoadSection(playerObj)
                                    CTLDVehicleSpawner.getInstance():refreshUnloadSection(playerObj)
                                    CTLDVehicleSpawner.getInstance():refreshParachuteVehicleSection(playerObj)
                                    CTLDJTACManager.getInstance():refreshJtacEquipmentSection(playerObj)
                                    for _, s in ipairs(inst._menuSections) do
                                        if s.refreshMethod and s.manager and s.manager[s.refreshMethod] then
                                            local _rok, _rerr = pcall(s.manager[s.refreshMethod], s.manager, playerObj)
                                            if not _rok then
                                                ctld.utils.log("WARN",
                                                    "CTLDPlayerManager: refreshSection '%s' failed for '%s': %s",
                                                    tostring(s.refreshMethod), unitName, tostring(_rerr))
                                            end
                                        end
                                    end
                                end)
                                ctld.utils.log("INFO", "CTLDPlayerManager: flight-state poller → LAND unit=%s", unitName)
                            end
                        end
                    end
                end
            end
        end
        return t + POLL_INTERVAL
    end, nil, timer.getTime() + POLL_INTERVAL)

    ctld.utils.log("INFO", "CTLDPlayerManager: init complete")
end

--- Build menus for any players occupying slots not yet tracked, and forget those whose slot
--- is gone. Called once at the end of ctld.initialize() (after all sections are registered),
--- then rescheduled every 30 s **for the whole mission** — not for a bounded warm-up window.
--- It is the safety net both for S_EVENT_PLAYER_ENTER_UNIT missed in multiplayer (a player
--- joining while CTLD is still booting) and for S_EVENT_PLAYER_LEAVE_UNIT arriving with an
--- initiator DCS has already released, which no handler can read a name from.
function CTLDPlayerManager:_scanExistingPlayers()
    -- The sweep is the backstop for events DCS delivers damaged, so it must outlive its own
    -- mistakes: anything raising inside one pass would otherwise take the reschedule with it
    -- and silently end the sweep for the rest of the mission.
    local ok, err = pcall(self._scanPlayersOnce, self)
    if not ok then
        ctld.utils.log("WARN", "CTLDPlayerManager: player scan pass failed: %s", tostring(err))
    end

    -- Schedule repeated scans indefinitely (every 30 s) to recover missed
    -- S_EVENT_PLAYER_ENTER_UNIT events (slot switch without briefing screen,
    -- AI takeover, late joiners in long missions) and to forget departed players.
    local self_ref = self
    timer.scheduleFunction(function()
        self_ref:_scanExistingPlayers()
    end, nil, timer.getTime() + 30)
end

--- One sweep pass: add players CTLD does not know yet, forget those whose slot is gone.
--- Called only by _scanExistingPlayers, which owns the rescheduling and the error boundary.
function CTLDPlayerManager:_scanPlayersOnce()
    local count = 0
    for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE }) do
        local okList, units = pcall(coalition.getPlayers, side)
        for _, unit in ipairs((okList and units) or {}) do
            -- Per unit, not per pass: a single unit DCS is releasing right now must not cost
            -- the other units their menu, nor the eviction pass below its turn.
            local okUnit, unitName = pcall(function()
                if not unit:isExist() or not unit:getPlayerName() then return nil end
                return ctld.utils.safeObjectName(unit)
            end)
            if okUnit and unitName and not self._players[unitName] then
                self:onPlayerEnterUnit({ initiator = unit })
                count = count + 1
            end
        end
    end
    if count > 0 then
        ctld.utils.log("INFO", "CTLDPlayerManager: built menu for %d player(s) via scan", count)
    end

    -- Reverse pass: forget players whose slot is gone. S_EVENT_PLAYER_LEAVE_UNIT is the
    -- fast path, but DCS delivers it with an already-released initiator on slot and
    -- coalition changes, and the handler cannot read a name from that. Without this pass
    -- the entry, its F10 menu and its pending rebuild survive the player.
    -- Every read is pcall-protected: this walks units DCS may be releasing right now.
    local departed = {}
    for unitName in pairs(self._players) do
        local ok, unit = pcall(Unit.getByName, unitName)
        if not ok or not unit then
            departed[#departed + 1] = unitName
        else
            local okExist, alive  = pcall(unit.isExist, unit)
            local okName, player  = pcall(unit.getPlayerName, unit)
            -- getPlayerName() nil is a legitimate departure: the slot went back to AI.
            if not okExist or not alive or not okName or not player then
                departed[#departed + 1] = unitName
            end
        end
    end
    -- One at a time: _forgetPlayer counts the group's remaining players to decide whether
    -- to tear the menu down, so bulk-deleting first would tear it down under a crew member
    -- who is still flying.
    for _, unitName in ipairs(departed) do
        self:_forgetPlayer(unitName)
    end
    if #departed > 0 then
        ctld.utils.log("INFO", "CTLDPlayerManager: forgot %d departed player(s) via scan", #departed)
    end
end

--- DCS S_EVENT_PLAYER_ENTER_UNIT handler.
-- Creates a CTLDPlayer and builds the F10 CTLD menu.
-- AI units (no playerName) are silently ignored.
-- @param event table  DCS event { initiator = Unit, ... }
function CTLDPlayerManager:onPlayerEnterUnit(event)
    local unit     = event and event.initiator
    local unitName = ctld.utils.safeObjectName(unit)   -- nil when DCS already released it
    if not unitName then return end
    -- A half-released object can answer getName() and raise on everything else, so these
    -- two reads are pcall'd rather than called outright.
    local okExist, alive = pcall(unit.isExist, unit)
    if not okExist or not alive then return end
    local okPlayer, player = pcall(unit.getPlayerName, unit)
    if not okPlayer or not player then return end   -- skip AI

    -- Idempotent: this handler is now reachable three ways — the DCS event, the BIRTH safety
    -- net and the 30 s scan. Rebuilding a menu that already exists would wipe and reconstruct
    -- it under a player who may have it open, which is the misfire #147 was about.
    if self._players[unitName] then return end

    -- Pilot name gate: when addPlayerAircraftByType=false, only unit names explicitly listed
    -- in transportPilotNames may use the TRANSPORT functions. It used to return here, which
    -- left the pilot with no CTLD menu at all — and therefore no recon, no smoke, no beacon
    -- list, none of which has anything to do with carrying cargo (#150). The gate now feeds
    -- isTransport, and the seventeen isTransport guards inside the sections do the rest.
    local transportAllowed = true
    if ctld.gs("addPlayerAircraftByType") == false then
        transportAllowed = false
        for _, name in ipairs(ctld.gs("transportPilotNames") or {}) do
            if name == unitName then transportAllowed = true; break end
        end
        if not transportAllowed then
            ctld.utils.log("INFO",
                "CTLDPlayerManager: %s not in transportPilotNames — non-transport CTLD menu only"
                .. " (addPlayerAircraftByType=false)",
                unitName)
        end
    end

    local group = unit:getGroup()
    if not group then
        ctld.utils.log("WARNING", "CTLDPlayerManager:onPlayerEnterUnit — no group for " .. unitName)
        return
    end

    local isTransport, canCarryVehicles = self:_detectCapabilities(unit)
    -- The whitelist wins over the aircraft type: a Huey pilot whose unit name is not listed
    -- must not recover the transport menus through his type, or the setting means nothing.
    if not transportAllowed then
        isTransport, canCarryVehicles = false, false
    end

    local playerObj = CTLDPlayer:new({
        unitName         = unitName,
        groupId          = group:getID(),
        groupName        = group:getName(),
        coalition        = unit:getCoalition(),
        typeName         = unit:getTypeName(),
        isTransport      = isTransport,
        canCarryVehicles = canCarryVehicles,
    })

    self._players[unitName] = playerObj
    self:buildMenu(playerObj)

    ctld.utils.log("INFO", string.format(
        "CTLDPlayerManager: enter unit=%s type=%s transport=%s vehicles=%s",
        unitName, playerObj.typeName,
        tostring(isTransport), tostring(canCarryVehicles)))
end

--- DCS S_EVENT_BIRTH handler — safety net for a missed S_EVENT_PLAYER_ENTER_UNIT.
-- BIRTH fires for every unit in the mission, AI included, so this gets out early and cheaply
-- and delegates to onPlayerEnterUnit: one registration path, one place where the whitelist and
-- the menu build live.
-- @param event table  DCS event { initiator = Unit, ... }
function CTLDPlayerManager:onBirth(event)
    local unit     = event and event.initiator
    local unitName = ctld.utils.safeObjectName(unit)
    if not unitName then return end
    if self._players[unitName] then return end        -- already tracked
    local okPlayer, player = pcall(unit.getPlayerName, unit)
    if not okPlayer or not player then return end     -- AI, or unreadable
    self:onPlayerEnterUnit(event)
end

--- DCS S_EVENT_PLAYER_LEAVE_UNIT handler.
-- Removes the CTLDPlayer and wipes the F10 CTLD menu.
-- For multi-crew aircraft (multiple players sharing the same DCS group), the DCS
-- menu is preserved as long as at least one crew member remains tracked.  Full
-- teardown runs only when the last tracked player in the group leaves.
-- @param event table  DCS event { initiator = Unit, ... }
function CTLDPlayerManager:onPlayerLeaveUnit(event)
    -- DCS releases the unit before delivering this event, so `initiator` is present but
    -- carries no methods: the name is unreadable and the cleanup below cannot run. The
    -- 30 s sweep in _scanExistingPlayers is the backstop for exactly that case.
    local unitName = ctld.utils.safeObjectName(event and event.initiator)
    if not unitName then return end
    self:_forgetPlayer(unitName)
end

--- Forget a tracked player: tear the group's F10 menu down when nobody is left in it,
--- and drop the registry entry. Shared by the PLAYER_LEAVE_UNIT handler and by the
--- recovery sweep, so both paths apply the same multi-crew rule.
-- @param unitName string  the unit name to forget
function CTLDPlayerManager:_forgetPlayer(unitName)
    local playerObj = self._players[unitName]
    if not playerObj then return end

    -- Count players sharing this groupId (includes the departing player).
    local groupId    = playerObj.groupId
    local groupCount = 0
    for _, p in pairs(self._players) do
        if p.groupId == groupId then groupCount = groupCount + 1 end
    end

    if groupCount <= 1 then
        -- Last player in the group: full DCS menu teardown.
        local mmgr     = ctld.MenuManager:getInstance()
        local menuData = mmgr.menus and mmgr.menus[groupId]
        if menuData then
            for _, h in ipairs(menuData._activeHandles or {}) do
                missionCommands.removeItemForGroup(groupId, h)
            end
            mmgr.menus[groupId] = nil
        end
        -- DCS can reuse this numeric groupId for an unrelated slot occupant — a pending
        -- urgent/ambient rebuild left scheduled for the departing group must not silently
        -- swallow or delay the next occupant's first menu build.
        mmgr:cancelPending(groupId)
    end
    -- else: other crew members remain — preserve the DCS menu for them.

    self._players[unitName] = nil
    ctld.utils.log("INFO", "CTLDPlayerManager: leave unit=" .. unitName)
end

--- DCS S_EVENT_LAND handler — rebuild troop menu section for landing unit.
-- Delayed 1 s: S_EVENT_LAND fires before the aircraft has fully settled,
-- so _isInAir() may still return true at the exact moment of the event.
function CTLDPlayerManager:onLand(event)
    local unitName = ctld.utils.safeObjectName(event and event.initiator)
    if not unitName then return end
    local playerObj = self._players[unitName]
    if not playerObj then return end
    local captured = playerObj
    -- Clear flight flag immediately (not deferred) so any refresh between now and
    -- the 1 s timer sees ground state and does not rebuild flight-only items (Pack Equipt).
    captured._isFlying = false
    timer.scheduleFunction(function()
        -- runUrgent: landing is a real, player-noticed state transition (not a silent
        -- background one) even though it fires from a timer, not a menu click — see
        -- AMBIENT vs URGENT REFRESH in CTLD_menu.lua.
        ctld.MenuManager:getInstance():runUrgent(captured.groupId, function()
            -- Pass overrideInAir=false: S_EVENT_LAND fires before inAir() crosses its threshold;
            -- force ground state immediately rather than relying on the speed/AGL check.
            CTLDTroopManager.getInstance():refreshMenuSection(captured, false)
            CTLDCrateManager.getInstance():refreshRequestEquipmentSection(captured)
            CTLDCrateManager.getInstance():refreshLoadCrateSection(captured)
            CTLDCrateManager.getInstance():refreshUnpackSection(captured, true)  -- _noRefresh: refreshCrateFlightSection below calls refresh()
            -- Pass overrideInAir=false: S_EVENT_LAND fires before inAir() crosses its threshold;
            -- force ground state immediately rather than relying on the speed/AGL check.
            CTLDCrateManager.getInstance():refreshCrateFlightSection(captured, false)
            CTLDVehicleSpawner.getInstance():refreshLoadSection(captured)
            CTLDVehicleSpawner.getInstance():refreshUnloadSection(captured)
            CTLDVehicleSpawner.getInstance():refreshParachuteVehicleSection(captured)
            CTLDJTACManager.getInstance():refreshJtacEquipmentSection(captured)
            -- Generic refresh for sections that registered a refreshMethod
            -- (e.g. mine field demine section — proximity-dependent content).
            for _, s in ipairs(self._menuSections) do
                if s.refreshMethod and s.manager and s.manager[s.refreshMethod] then
                    local ok, err = pcall(s.manager[s.refreshMethod], s.manager, captured)
                    if not ok then
                        ctld.utils.log("WARN",
                            "CTLDPlayerManager:onLand refreshMethod '%s' error: %s",
                            tostring(s.refreshMethod), tostring(err))
                    end
                end
            end
        end)
    end, nil, timer.getTime() + 1)
end

--- DCS S_EVENT_TAKEOFF handler — rebuild troop menu section for departing unit.
function CTLDPlayerManager:onTakeoff(event)
    local unitName = ctld.utils.safeObjectName(event and event.initiator)
    if not unitName then return end
    local playerObj = self._players[unitName]
    if not playerObj then return end
    -- Set flight flag immediately so any refresh between now and inAir() reaching threshold
    -- (e.g. _refreshNearbyPackPlayers triggered by vehicle events) sees flight state.
    playerObj._isFlying = true
    -- runUrgent: takeoff is a real, player-noticed state transition (not a silent background
    -- one) even though it has no menu-click context to auto-detect urgency from — see
    -- AMBIENT vs URGENT REFRESH in CTLD_menu.lua.
    ctld.MenuManager:getInstance():runUrgent(playerObj.groupId, function()
        -- Pass overrideInAir=true: S_EVENT_TAKEOFF fires before ctld.utils.inAir() crosses its
        -- speed/AGL threshold, so we explicitly signal flight mode rather than relying on
        -- inAir() at this point.
        CTLDTroopManager.getInstance():refreshMenuSection(playerObj, true)
        CTLDCrateManager.getInstance():refreshRequestEquipmentSection(playerObj)
        CTLDCrateManager.getInstance():refreshCrateFlightSection(playerObj, true)
        CTLDVehicleSpawner.getInstance():refreshLoadSection(playerObj)
        CTLDVehicleSpawner.getInstance():refreshUnloadSection(playerObj)
        CTLDVehicleSpawner.getInstance():refreshParachuteVehicleSection(playerObj)
        CTLDJTACManager.getInstance():refreshJtacEquipmentSection(playerObj)
    end)
end

--- Register a menu section contributed by a manager.
-- Called by each manager in its own init(), before any player enters a unit.
-- sectionDef = {
--   key       = string      unique identifier, e.g. "troops", "beacons"
--   manager   = object      manager instance
--   method    = string      method name: manager[method](manager, playerObj, menu)
--   configKey = string|nil  ctld.gs(configKey) must be true to activate; nil = always active
--   order     = number|nil  render position (ascending); nil = appended last
-- }
-- Idempotent: duplicate keys are silently ignored.
function CTLDPlayerManager:registerMenuSection(sectionDef)
    if not sectionDef or not sectionDef.key then return end
    for _, s in ipairs(self._menuSections) do
        if s.key == sectionDef.key then return end
    end
    table.insert(self._menuSections, sectionDef)
    ctld.utils.log("INFO", "CTLDPlayerManager: registered menu section '%s'", sectionDef.key)
end

--- Return the CTLDPlayer for unitName, or nil if not tracked.
-- @param unitName string
-- @return CTLDPlayer or nil
function CTLDPlayerManager:getPlayer(unitName)
    return self._players[unitName]
end

--- Build (or rebuild) the full F10 CTLD menu for a player.
-- Wipes and reconstructs atomically via ctld.MenuManager.
-- Sections are contributed by managers registered via registerMenuSection().
-- Each section is rendered only when its configKey (if any) resolves to true.
-- runUrgent: nothing is on screen yet for a brand-new menu (or, for a rebuild, the player
-- just triggered this directly — e.g. a language change), so there is no stale-screen race to
-- guard against here — see AMBIENT vs URGENT REFRESH in CTLD_menu.lua. Without this, the
-- section builders' own trailing menu:refresh() calls would take the ambient path by default,
-- delaying a freshly-joined player's first F10 menu appearance by AMBIENT_REBUILD_DELAY_S.
-- @param playerObj CTLDPlayer
function CTLDPlayerManager:buildMenu(playerObj)
    ctld.MenuManager:getInstance():runUrgent(playerObj.groupId, function()
        self:_buildMenuBody(playerObj)
    end)
end

--- Actual body of buildMenu(), run inside runUrgent() by its caller above.
-- @param playerObj CTLDPlayer
function CTLDPlayerManager:_buildMenuBody(playerObj)
    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:createMenuForGroup(playerObj.groupId)
    if not menu then
        ctld.utils.log("WARNING", "CTLDPlayerManager:buildMenu — cannot create menu for group "
            .. tostring(playerObj.groupId))
        return
    end

    -- Reset memory model before rebuilding so sections don't accumulate on successive calls.
    menu.children  = {}
    menu._lookup   = {}
    menu.nextItemId = 1

    local root     = ctld.tr("CTLD")
    local gid      = playerObj.groupId
    local unitName = playerObj.unitName

    -- Root submenu "CTLD" at F1 slot (order 10)
    menu:addSubMenu({}, root, { order = 10 })

    -- "Check Cargo" — queries crates and troops loaded on this transport
    -- Transport only: for anyone else it could only ever answer "no cargo on board".
    if playerObj.isTransport then
        menu:addCommand({ root }, ctld.tr("Check Cargo"),
            function()
                local transport = Unit.getByName(unitName)
                local lines     = {}
                local total     = 0

                -- Crates loaded on this transport — grouped by descriptor.desc
                -- Compare by unit name, not object identity (DCS userdata equality is unreliable)
                local crateMgr   = CTLDCrateManager.getInstance()
                local crateCount = {}   -- desc → { count, totalWeight }
                local crateOrder = {}   -- preserve insertion order for deterministic output
                for _, c in pairs(crateMgr.crates) do
                    if c:isLoaded() and c.loadedBy and c.loadedBy:getName() == unitName then
                        local desc   = (c.descriptor and c.descriptor.desc) or "?"
                        local weight = (c.descriptor and c.descriptor.weight) or 0
                        if not crateCount[desc] then
                            crateCount[desc] = { count = 0, totalWeight = 0 }
                            table.insert(crateOrder, desc)
                        end
                        crateCount[desc].count       = crateCount[desc].count + 1
                        crateCount[desc].totalWeight = crateCount[desc].totalWeight + weight
                        total = total + weight
                    end
                end
                for _, desc in ipairs(crateOrder) do
                    local info = crateCount[desc]
                    table.insert(lines,
                        ctld.tr("%1: %2 crate(s) onboard (%3 kg)", desc, info.count, info.totalWeight))
                end

                -- Troops loaded on this transport (may be multiple groups)
                local troopMgr = CTLDTroopManager.getInstance()
                local tList    = troopMgr:getInTransit(unitName)
                if tList then
                    for _, tGroup in ipairs(tList) do
                        table.insert(lines, ctld.tr("%1 troop(s) onboard (%2 kg)", tGroup.unitTotal, tGroup.weight))
                        total = total + tGroup.weight
                    end
                end

                -- Whole vehicles loaded on this transport (GAP-1)
                if transport then
                    local vehSpawner = CTLDVehicleSpawner.getInstance()
                    local loadedVehs = vehSpawner:findLoadedVehicles(transport)
                    local vehCount = {}
                    local vehOrder = {}
                    for _, v in ipairs(loadedVehs) do
                        local vt = v.vehicleType or "?"
                        if not vehCount[vt] then
                            vehCount[vt] = 0
                            table.insert(vehOrder, vt)
                        end
                        vehCount[vt] = vehCount[vt] + 1
                    end
                    local vWeights = ctld.gs("groundVehicleWeights") or {}
                    for _, vt in ipairs(vehOrder) do
                        local count = vehCount[vt]
                        local w     = (vWeights[vt] or ctld.gs("defaultVehicleWeight")) * count
                        total = total + w
                        table.insert(lines, ctld.tr("%1: %2 vehicle(s) onboard", vt, count))
                    end
                end

                local msg
                if #lines == 0 then
                    msg = ctld.tr("No cargo on board.")
                else
                    table.insert(lines, ctld.tr("Total cargo weight: %1 kg", total))
                    msg = table.concat(lines, "\n")
                end
                trigger.action.outTextForGroup(gid, msg, 10)
            end, {})
    end

    -- Registered sections sorted by order field
    local sorted = {}
    for _, s in ipairs(self._menuSections) do table.insert(sorted, s) end
    table.sort(sorted, function(a, b)
        return (a.order or math.huge) < (b.order or math.huge)
    end)

    for _, section in ipairs(sorted) do
        local active = true
        if section.configKey then
            active = ctld.gs(section.configKey) == true
        end
        if active then
            local fn = section.manager[section.method]
            if fn then
                fn(section.manager, playerObj, menu)
            else
                ctld.utils.log("WARN", "CTLDPlayerManager:buildMenu — section '%s' method '%s' not found",
                    section.key, tostring(section.method))
            end
        end
    end

    menu:refresh()
end

--- Refresh the F10 menu for a single player unit.
-- @param unitName string
function CTLDPlayerManager:refreshForUnit(unitName)
    local playerObj = self._players[unitName]
    if not playerObj then return end
    ctld.MenuManager:getInstance():deferredRefreshForGroup(playerObj.groupId)
end

--- Refresh F10 menus for all currently tracked players.
function CTLDPlayerManager:refreshAll()
    for unitName in pairs(self._players) do
        self:refreshForUnit(unitName)
    end
end

-- ============================================================
-- Private helpers
-- ============================================================

--- Detect transport and vehicle-carry capabilities from a unit.
-- isTransport      : typeName has an entry in ctld.gs("unitActions") map.
-- canCarryVehicles : typeName matches (case-insensitive substring) an entry
--                   in the ctld.gs("vehicleTransportEnabled") list.
-- @param unit DCS Unit
-- @return isTransport bool, canCarryVehicles bool
function CTLDPlayerManager:_detectCapabilities(unit)
    local typeName = unit:getTypeName()
    local caps     = (ctld.gs("capabilitiesByType") or {})[typeName]
    local isTransport      = (caps ~= nil)
    local canCarryVehicles = (caps ~= nil and caps.canTransportWholeVehicle == true)

    return isTransport, canCarryVehicles
end
