---@diagnostic disable
-- tests/ci/unit/jtac_recon_reintegration_spec.lua
-- busted specs re-integrating coverage that previously lived ONLY in the dead
-- FullGas relics under tests/dcs/noPlayer/F-1NN_*.lua (never re-tooled at the
-- VEAF bootstrap). Each block is anchored on the CURRENT src behaviour, not the
-- relic's stale intent:
--   F-110  JTAC config defaults (drone radius/altitude + JTAC unit types/coalition)
--   F-112  deregisterJTAC — silent (no OnJTACDead), frees laser code, idempotent
--   F-011  recon enable/disableAutoRefresh + their previous/new-state events
--
-- NOTE on F-110 divergence from the relic: the relic asserted a per-coalition
-- `JTAC_unitTypeNames` table (Hummer / SKP-11). That key NO LONGER EXISTS in the
-- current src — JTAC role is now declared via `isJTAC=true` descriptors inside
-- `spawnableCrates` (see CTLD_config.lua l.336-338). The per-coalition JTAC unit
-- declaration is re-integrated against that current model; the drone radius/altitude
-- defaults survive as first-class config keys and are asserted directly.
-- ============================================================

describe("JTAC + recon relic re-integration", function()

    -- Capture every payload published for `eventName` during fn(), then clean up.
    local function capture(eventName, fn)
        local ed    = EventDispatcher.getInstance()
        local fired = {}
        local cb    = function(p) fired[#fired + 1] = p end
        ed:subscribe(eventName, cb)
        local ok, err = pcall(fn)
        ed:unsubscribe(eventName, cb)
        assert(ok, err)
        return fired
    end

    -- ── F-110 : JTAC config defaults ──────────────────────────────────────────
    describe("JTAC config defaults (F-110)", function()

        -- Find a spawnableCrates "Drone" descriptor by its `unit` type name.
        local function droneDescriptor(unitType)
            local crates = ctld.gs("spawnableCrates")
            local drones = crates and crates["Drone"] or {}
            for _, d in ipairs(drones) do
                if d.unit == unitType then return d end
            end
            return nil
        end

        it("JTAC_droneRadius default is 1000 m", function()
            assert.equals(1000, ctld.gs("JTAC_droneRadius"))
        end)

        it("JTAC_droneAltitude default is 4000 m", function()
            assert.equals(4000, ctld.gs("JTAC_droneAltitude"))
        end)

        it("BLUE JTAC drone is the MQ-9 Reaper (side 2), flagged isJTAC", function()
            -- Current model's replacement for the relic's per-coalition JTAC_unitTypeNames.
            local d = droneDescriptor("MQ-9 Reaper")
            assert.is_not_nil(d)
            assert.equals(coalition.side.BLUE, d.side)
            assert.is_true(d.isJTAC)
        end)

        it("RED JTAC drone is the RQ-1A Predator (side 1), flagged isJTAC", function()
            local d = droneDescriptor("RQ-1A Predator")
            assert.is_not_nil(d)
            assert.equals(coalition.side.RED, d.side)
            assert.is_true(d.isJTAC)
        end)

        it("JTAC_lock default is 'all'", function()
            assert.equals("all", ctld.gs("JTAC_lock"))
        end)

    end)

    -- ── F-112 : deregisterJTAC ─────────────────────────────────────────────────
    describe("deregisterJTAC (F-112)", function()

        local mgr, origGetByName

        -- Mock ground infantry group (same shape as functional/jtac_manager_spec).
        local function makeMockGroup(name, unitName)
            local mockUnit = {
                _desc = { attributes = { Infantry = true } },
                getName     = function(self) return unitName end,
                getID       = function(self) return 9901 end,
                getTypeName = function(self) return "Soldier M4 GRG" end,
                getPoint    = function(self) return { x = 0, y = 0, z = 0 } end,
                getDesc     = function(self) return self._desc end,
            }
            return {
                _name = name,
                _coa  = coalition.side.BLUE,
                getName       = function(self) return self._name end,
                getID         = function(self) return 9900 end,
                getCoalition  = function(self) return self._coa end,
                getUnits      = function(self) return { mockUnit } end,
                getUnit       = function(self, _) return mockUnit end,
                getController = function(self) return nil end,
                isExist       = function(self) return true end,
            }
        end

        before_each(function()
            CTLDJTACManager._instance = nil
            EventDispatcher._instance = nil
            origGetByName = Group.getByName
            mgr = CTLDJTACManager.get()
        end)

        after_each(function()
            Group.getByName = origGetByName
        end)

        -- Spawn a JTAC letting the manager assign a code from the pool (tail removal),
        -- so the "code returned to pool" assertion is meaningful.
        local function spawnPooled(groupName, unitName)
            local grp = makeMockGroup(groupName, unitName)
            Group.getByName = function(n)
                if n == groupName then return grp end
                return origGetByName(n)
            end
            return mgr:spawnJTAC(groupName, { smokeEnabled = false, lockMode = "all" }, nil)
        end

        it("removes the JTAC from the registry", function()
            spawnPooled("JTAC_Dereg_A", "JTAC_Unit_A")
            assert.is_not_nil(mgr:getJTACByName("JTAC_Dereg_A"))
            mgr:deregisterJTAC("JTAC_Dereg_A")
            assert.is_nil(mgr:getJTACByName("JTAC_Dereg_A"))
        end)

        it("does NOT publish OnJTACDead (pack is not a combat death)", function()
            spawnPooled("JTAC_Dereg_B", "JTAC_Unit_B")
            local fired = capture("OnJTACDead", function()
                mgr:deregisterJTAC("JTAC_Dereg_B")
            end)
            assert.equals(0, #fired)
        end)

        it("returns the laser code to the pool (tail, pool +1)", function()
            local jtac = spawnPooled("JTAC_Dereg_C", "JTAC_Unit_C")
            local assignedCode = jtac.laserCode
            local poolBefore   = #mgr._laserPool
            mgr:deregisterJTAC("JTAC_Dereg_C")
            assert.equals(poolBefore + 1, #mgr._laserPool)
            assert.equals(assignedCode, mgr._laserPool[#mgr._laserPool])
        end)

        it("is idempotent: a second call is a no-op (no event, no pool change)", function()
            spawnPooled("JTAC_Dereg_D", "JTAC_Unit_D")
            mgr:deregisterJTAC("JTAC_Dereg_D")     -- first call: real deregister
            local poolAfterFirst = #mgr._laserPool
            local fired = capture("OnJTACDead", function()
                mgr:deregisterJTAC("JTAC_Dereg_D") -- second call: no-op
            end)
            assert.equals(0, #fired)
            assert.equals(poolAfterFirst, #mgr._laserPool)
        end)

        it("does nothing for an unknown group (no error, no event)", function()
            local fired = capture("OnJTACDead", function()
                mgr:deregisterJTAC("JTAC_DoesNotExist")
            end)
            assert.equals(0, #fired)
        end)

    end)

    -- ── F-011 : recon enable / disable auto-refresh ────────────────────────────
    describe("recon auto-refresh (F-011)", function()

        local rm

        local function makePlayerUnit(name)
            return {
                getName      = function() return name or "P1_Unit" end,
                getCoalition = function() return coalition.side.BLUE end,
                getGroup     = function() return { getID = function() return 42 end } end,
            }
        end

        before_each(function()
            CTLDReconManager._instance = nil
            rm = CTLDReconManager.getInstance()
            -- Neutralise the F10 menu rebuild — irrelevant to the event contract.
            rm._rebuildReconBranch = function() end
        end)

        it("enableAutoRefresh flips scan.autoRefresh false → true", function()
            rm._activeScans["P1"] = { targets = { {}, {}, {} }, autoRefresh = false }
            rm:enableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            assert.is_true(rm._activeScans["P1"].autoRefresh)
        end)

        it("enableAutoRefresh publishes OnReconAutoRefreshEnabled with previous=false / new=true", function()
            rm._activeScans["P1"] = { targets = { {}, {}, {} }, autoRefresh = false }
            local fired = capture("OnReconAutoRefreshEnabled", function()
                rm:enableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            end)
            assert.equals(1,     #fired)
            assert.is_false(fired[1].previousState)
            assert.is_true(fired[1].newState)
            assert.equals(3,     fired[1].targetsCount)
            assert.equals(10,    fired[1].refreshInterval)   -- reconRefreshInterval default
        end)

        it("enableAutoRefresh is idempotent when already ON (no second event)", function()
            rm._activeScans["P1"] = { targets = { {} }, autoRefresh = true }
            local fired = capture("OnReconAutoRefreshEnabled", function()
                rm:enableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            end)
            assert.equals(0, #fired)
        end)

        it("enableAutoRefresh with no active scan publishes nothing", function()
            local fired = capture("OnReconAutoRefreshEnabled", function()
                rm:enableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            end)
            assert.equals(0, #fired)
        end)

        it("disableAutoRefresh flips scan.autoRefresh true → false", function()
            rm._activeScans["P1"] = { targets = { {}, {} }, autoRefresh = true, refreshTimer = nil }
            rm:disableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            assert.is_false(rm._activeScans["P1"].autoRefresh)
        end)

        it("disableAutoRefresh publishes OnReconAutoRefreshDisabled with previous=true / new=false", function()
            rm._activeScans["P1"] = { targets = { {}, {} }, autoRefresh = true, refreshTimer = nil }
            local fired = capture("OnReconAutoRefreshDisabled", function()
                rm:disableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            end)
            assert.equals(1,    #fired)
            assert.is_true(fired[1].previousState)
            assert.is_false(fired[1].newState)
            assert.equals(2,    fired[1].targetsCount)
        end)

        it("disableAutoRefresh is a no-op when already OFF (no event)", function()
            rm._activeScans["P1"] = { targets = { {} }, autoRefresh = false }
            local fired = capture("OnReconAutoRefreshDisabled", function()
                rm:disableAutoRefresh(makePlayerUnit("P1_Unit"), "P1")
            end)
            assert.equals(0, #fired)
        end)

    end)

end)
