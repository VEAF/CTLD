---@diagnostic disable
-- tests/ci/unit/menu_gating_spec.lua
-- busted specs for F10 menu section gating (config flags + unit capabilities)
-- and the CTLDPlayerManager cargo-event wiring.
--
-- Re-integrates coverage that previously lived ONLY in the dead FullGas DCS
-- relics (tests/dcs/noPlayer/F-0NN_*.lua). The relic *intent* is preserved; node
-- names / gates were re-verified against the CURRENT src (several were refactored):
--   F-048 buildMenu all flags ON  → every section present
--   F-049 enableCrates=false      → Request Equipment + Crate Commands absent
--   F-050 enabledRadioBeaconDrop=false → Radio Beacons absent
--   F-052 JTAC_jtacStatusF10=false     → JTAC absent
--   F-053 enabledFOBBuilding=false     → FOBs List absent  (was "List FOBs")
--   F-054 packing flags off       → Pack Equipt absent     (was "Pack Vehicle")
--   F-055 non-transport player    → only root + Check Cargo; RECON/JTAC present
--   F-056 canCarryVehicles=true   → Vehicle Commands present
--   F-075 clearBranch + repopulate → new commands present, old absent
--   F-077 refreshMenuForGroup unknown group → {success=false, refreshedCount=0}
--   F-088 _loadUserConfig ingests customLoadableGroups + disableLoadableGroups
--   F-089 troop Embark menu filters by disabled / side / capacity
--   F-025 OnVehicleLoaded/Unloaded → CTLDPlayer.loadedVehicles maintained
--
-- Menu inspection uses the same mechanism as troop_multi_spec:
--   pm:buildMenu(playerObj) → ctld.MenuManager:getMenuByGroupId(gid) → menu:_getNode(path)
-- (memory-model lookup; independent of DCS rendering / enabled flag).
-- ============================================================

local tr = ctld.tr

describe("F10 menu gating (config + capability) + player-manager wiring", function()

    -- ── Config save / restore (toggle a flag via CTLDConfig settings) ────────
    local _changed
    before_each(function() _changed = {} end)
    after_each(function()
        for k, box in pairs(_changed) do
            CTLDConfig.get().settings[k] = box.orig
        end
        _changed = {}
    end)
    local function setCfg(k, v)
        if _changed[k] == nil then
            _changed[k] = { orig = CTLDConfig.get().settings[k] }
        end
        CTLDConfig.get().settings[k] = v
    end

    -- ── Singleton reset + full re-instantiation (so every section re-registers) ──
    local function resetSingletons()
        ctld.MenuManager._instance   = nil
        CTLDPlayerManager._instance  = nil
        CTLDTroopManager._instance   = nil
        CTLDCrateManager._instance   = nil
        CTLDVehicleSpawner._instance = nil
        CTLDFOBManager._instance     = nil
        CTLDBeaconManager._instance  = nil
        CTLDReconManager._instance   = nil
        CTLDJTACManager._instance    = nil
        CTLDZoneManager._instance    = nil
        EventDispatcher._instance    = nil
        CTLDDCSEventBridge._instance = nil
    end

    -- Instantiate every manager: PlayerManager first (owns _menuSections), then
    -- each contributor registers its section during getInstance()/init().
    local function instantiateAll()
        EventDispatcher.getInstance()
        CTLDDCSEventBridge.getInstance()
        CTLDZoneManager.getInstance()
        CTLDPlayerManager.getInstance()
        CTLDTroopManager.getInstance()
        CTLDVehicleSpawner.getInstance()
        CTLDCrateManager.getInstance()
        CTLDFOBManager.getInstance()
        CTLDBeaconManager.getInstance()
        CTLDReconManager.getInstance()
        CTLDJTACManager.getInstance()
    end

    local function makePlayer(opts)
        opts = opts or {}
        return {
            unitName         = opts.unitName or "UH-1H-1",
            groupId          = opts.groupId  or 9901,
            groupName        = opts.groupName or "Grp_gate",
            coalition        = opts.coalition or coalition.side.BLUE,
            typeName         = opts.typeName or "UH-1H",
            isTransport      = (opts.isTransport ~= false),
            canCarryVehicles = opts.canCarryVehicles or false,
        }
    end

    -- Build the full CTLD menu for playerObj and return its ctld.Menu model.
    -- The vehicle section calls findLoadableVehicles(transport), which needs a real DCS
    -- unit object (getTypeName/getCoalition/getPoint). Stub Unit.getByName for the duration
    -- of the build only — the menu model is fully built by the time buildMenu returns, so
    -- node lookups afterwards don't need it, and we restore immediately to avoid polluting
    -- other specs in the shared busted process.
    local function buildFullMenu(playerObj)
        resetSingletons()
        instantiateAll()
        local origGBN = Unit.getByName
        Unit.getByName = function(n)
            if n == playerObj.unitName then
                return {
                    getName       = function() return playerObj.unitName end,
                    getTypeName   = function() return playerObj.typeName end,
                    getCoalition  = function() return playerObj.coalition end,
                    getPoint      = function() return { x = 0, y = 0, z = 0 } end,
                    getPlayerName = function() return "tester" end,
                    isExist       = function() return true end,
                }
            end
            return origGBN(n)
        end
        local ok, err = pcall(function()
            CTLDPlayerManager.getInstance():buildMenu(playerObj)
        end)
        Unit.getByName = origGBN
        assert(ok, err)
        return ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
    end

    local ROOT = tr("CTLD")
    local function has(menu, path) return menu and menu:_getNode(path) ~= nil end

    -- ── F-048 : every gate ON → every section present ────────────────────────
    describe("F-048 — all flags ON, transport heli → every section present", function()
        -- Default config already has all these flags true; UH-1H caps has
        -- troopsEnabled + cratesEnabled. Build with defaults, assert presence.
        local menu
        before_each(function()
            menu = buildFullMenu(makePlayer({ canCarryVehicles = false }))
        end)

        it("root CTLD submenu present",       function() assert.is_true(has(menu, { ROOT })) end)
        it("Troop Commands present",          function() assert.is_true(has(menu, { ROOT, tr("Troop Commands") })) end)
        it("Request Equipment present",       function() assert.is_true(has(menu, { ROOT, tr("Request Equipment") })) end)
        it("Crate Commands present",          function() assert.is_true(has(menu, { ROOT, tr("Crate Commands") })) end)
        it("Smoke present",                   function() assert.is_true(has(menu, { ROOT, tr("Smoke") })) end)
        it("Radio Beacons present",           function() assert.is_true(has(menu, { ROOT, tr("Radio Beacons") })) end)
        it("FOBs List present",               function() assert.is_true(has(menu, { ROOT, tr("FOBs List") })) end)
        it("RECON present",                   function() assert.is_true(has(menu, { ROOT, tr("RECON") })) end)
        it("JTAC present",                    function() assert.is_true(has(menu, { ROOT, tr("JTAC") })) end)
        it("Vehicle Commands absent (canCarryVehicles=false)",
            function() assert.is_false(has(menu, { ROOT, tr("Vehicle Commands") })) end)
    end)

    -- ── F-049 : enableCrates=false → crate sections gone, others stay ────────
    describe("F-049 — enableCrates=false → Request Equipment + Crate Commands absent", function()
        local menu
        before_each(function()
            setCfg("enableCrates", false)
            menu = buildFullMenu(makePlayer())
        end)

        it("Request Equipment absent", function() assert.is_false(has(menu, { ROOT, tr("Request Equipment") })) end)
        it("Crate Commands absent",    function() assert.is_false(has(menu, { ROOT, tr("Crate Commands") })) end)
        it("Smoke still present (enableSmokeDrop=true)",       function() assert.is_true(has(menu, { ROOT, tr("Smoke") })) end)
        it("Radio Beacons still present",                      function() assert.is_true(has(menu, { ROOT, tr("Radio Beacons") })) end)
        it("Troop Commands still present (not gated by crates)", function() assert.is_true(has(menu, { ROOT, tr("Troop Commands") })) end)
    end)

    -- ── F-050 : enabledRadioBeaconDrop=false → Radio Beacons gone ────────────
    describe("F-050 — enabledRadioBeaconDrop=false → Radio Beacons absent", function()
        local menu
        before_each(function()
            setCfg("enabledRadioBeaconDrop", false)
            menu = buildFullMenu(makePlayer())
        end)

        it("Radio Beacons absent",  function() assert.is_false(has(menu, { ROOT, tr("Radio Beacons") })) end)
        it("Smoke still present",   function() assert.is_true(has(menu, { ROOT, tr("Smoke") })) end)
        it("Crate Commands still present", function() assert.is_true(has(menu, { ROOT, tr("Crate Commands") })) end)
    end)

    -- ── F-052 : JTAC_jtacStatusF10=false → JTAC gone ─────────────────────────
    describe("F-052 — JTAC_jtacStatusF10=false → JTAC absent", function()
        local menu
        before_each(function()
            setCfg("JTAC_jtacStatusF10", false)
            menu = buildFullMenu(makePlayer())
        end)

        it("JTAC absent",          function() assert.is_false(has(menu, { ROOT, tr("JTAC") })) end)
        it("RECON still present",  function() assert.is_true(has(menu, { ROOT, tr("RECON") })) end)
        it("Troop Commands still present", function() assert.is_true(has(menu, { ROOT, tr("Troop Commands") })) end)
    end)

    -- ── F-053 : enabledFOBBuilding=false → FOBs List gone ────────────────────
    -- Relic said "List FOBs absent from Crate Commands"; the current build exposes
    -- FOBs as a TOP-LEVEL section "FOBs List" (configKey enabledFOBBuilding, order 55),
    -- no longer nested under Crate Commands. Assertion adapted to the real node.
    describe("F-053 — enabledFOBBuilding=false → FOBs List absent", function()
        it("FOBs List present when enabledFOBBuilding=true (default)", function()
            local menu = buildFullMenu(makePlayer())
            assert.is_true(has(menu, { ROOT, tr("FOBs List") }))
        end)
        it("FOBs List absent when enabledFOBBuilding=false", function()
            setCfg("enabledFOBBuilding", false)
            local menu = buildFullMenu(makePlayer())
            assert.is_false(has(menu, { ROOT, tr("FOBs List") }))
        end)
        it("Crate Commands still present when FOB disabled", function()
            setCfg("enabledFOBBuilding", false)
            local menu = buildFullMenu(makePlayer())
            assert.is_true(has(menu, { ROOT, tr("Crate Commands") }))
        end)
    end)

    -- ── F-054 : packing flags off → Pack Equipt gone ─────────────────────────
    -- Relic node "Pack Vehicle" was renamed "Pack Equipt" and its gate broadened:
    -- the sub-menu is created when (enableFARPRepack OR enablePackingVehicles) is
    -- true AND the unit type has cratesEnabled. Assertions adapted to that combined
    -- gate rather than the legacy single flag.
    describe("F-054 — Pack Equipt visibility follows packing gates", function()
        it("Pack Equipt present when enablePackingVehicles=true (FARP off)", function()
            setCfg("enableFARPRepack", false)
            setCfg("enablePackingVehicles", true)
            local menu = buildFullMenu(makePlayer())
            assert.is_true(has(menu, { ROOT, tr("Crate Commands"), tr("Pack Equipt") }))
        end)
        it("Pack Equipt absent when both packing gates are false", function()
            setCfg("enableFARPRepack", false)
            setCfg("enablePackingVehicles", false)
            local menu = buildFullMenu(makePlayer())
            assert.is_false(has(menu, { ROOT, tr("Crate Commands"), tr("Pack Equipt") }))
        end)
    end)

    -- ── F-055 : non-transport player → only root + Check Cargo ───────────────
    describe("F-055 — non-transport player → transport sections absent", function()
        local menu
        before_each(function()
            menu = buildFullMenu(makePlayer({
                unitName = "F-16C-1", typeName = "F-16C bl.52d",
                isTransport = false, canCarryVehicles = false,
            }))
        end)

        it("root CTLD present",       function() assert.is_true(has(menu, { ROOT })) end)
        it("Check Cargo present at root", function() assert.is_true(has(menu, { ROOT, tr("Check Cargo") })) end)
        it("Troop Commands absent",   function() assert.is_false(has(menu, { ROOT, tr("Troop Commands") })) end)
        it("Request Equipment absent", function() assert.is_false(has(menu, { ROOT, tr("Request Equipment") })) end)
        it("Crate Commands absent",   function() assert.is_false(has(menu, { ROOT, tr("Crate Commands") })) end)
        it("Smoke absent",            function() assert.is_false(has(menu, { ROOT, tr("Smoke") })) end)
        it("Radio Beacons absent",    function() assert.is_false(has(menu, { ROOT, tr("Radio Beacons") })) end)
        it("RECON present (no isTransport guard)", function() assert.is_true(has(menu, { ROOT, tr("RECON") })) end)
        it("JTAC present (no isTransport guard)",  function() assert.is_true(has(menu, { ROOT, tr("JTAC") })) end)
    end)

    -- ── F-056 : canCarryVehicles=true → Vehicle Commands present ─────────────
    describe("F-056 — canCarryVehicles=true → Vehicle Commands present", function()
        it("Vehicle Commands present when canCarryVehicles=true", function()
            local menu = buildFullMenu(makePlayer({ canCarryVehicles = true }))
            assert.is_true(has(menu, { ROOT, tr("Vehicle Commands") }))
        end)
        it("Vehicle Commands absent when canCarryVehicles=false", function()
            local menu = buildFullMenu(makePlayer({ canCarryVehicles = false }))
            assert.is_false(has(menu, { ROOT, tr("Vehicle Commands") }))
        end)
    end)

    -- ── F-075 : clearBranch + repopulate (menu model dynamic-refresh contract) ─
    describe("F-075 — clearBranch empties a branch; repopulation swaps content", function()
        local menu
        before_each(function()
            ctld.MenuManager._instance = nil
            local mm = ctld.MenuManager:getInstance()
            menu = mm:createMenuForGroup(7777)
            menu:addSubMenu({}, "Root")
            menu:addCommand({ "Root" }, "OldCmd", function() end, {})
        end)

        it("old command present before clearBranch", function()
            assert.is_true(has(menu, { "Root", "OldCmd" }))
        end)
        it("clearBranch removes the old command", function()
            menu:clearBranch({ "Root" })
            assert.is_false(has(menu, { "Root", "OldCmd" }))
        end)
        it("container survives clearBranch", function()
            menu:clearBranch({ "Root" })
            assert.is_true(has(menu, { "Root" }))
        end)
        it("repopulation exposes the new command, not the old one", function()
            menu:clearBranch({ "Root" })
            menu:addCommand({ "Root" }, "NewCmd", function() end, {})
            assert.is_true(has(menu, { "Root", "NewCmd" }))
            assert.is_false(has(menu, { "Root", "OldCmd" }))
        end)
    end)

    -- ── F-077 : refreshMenuForGroup on an unknown group → structured failure ─
    describe("F-077 — refreshMenuForGroup unknown group → failure result", function()
        local res
        before_each(function()
            ctld.MenuManager._instance = nil
            res = ctld.MenuManager:getInstance():refreshMenuForGroup(424242)
        end)

        it("success == false",     function() assert.is_false(res.success) end)
        it("refreshedCount == 0",  function() assert.equals(0, res.refreshedCount) end)
        it("message is a string",  function() assert.is_string(res.message) end)
    end)

    -- ── F-088 : _loadUserConfig ingests custom + disabled loadable groups ────
    describe("F-088 — _loadUserConfig ingests ctld_config_user", function()
        local mgr, _origUserCfg
        before_each(function()
            -- Write to _G explicitly: busted insulates each describe's environment, so a bare
            -- `ctld_config_user = {...}` would land in the sandbox and _loadUserConfig (which
            -- reads the real _G global) would see nil — the custom groups would never load.
            _origUserCfg = _G.ctld_config_user
            setCfg("loadableGroups", {
                { name = "Standard Group", inf = 6, mg = 2, at = 2 },
                { name = "Mortar Squad",   mortar = 6 },
                { name = "JTAC Group",     inf = 4, jtac = 1 },
            })
            setCfg("transportLimitByType", {})
            _G.ctld_config_user = {
                customLoadableGroups = {
                    { name = "Recon Team",    composition = { inf = 4, jtac = 1 }, side = coalition.side.BLUE },
                    { name = "AT Squad",      composition = { inf = 2, at = 6  },  side = coalition.side.RED },
                    { name = "Support Heavy", composition = { inf = 8, mg = 4, aa = 2 } },
                },
                disableLoadableGroups = { "Mortar Squad", "Standard Group" },
            }
            resetSingletons()
            CTLDPlayerManager.getInstance()
            mgr = CTLDTroopManager.getInstance()   -- init() runs _loadUserConfig
        end)
        after_each(function()
            _G.ctld_config_user = _origUserCfg
        end)

        it("6 templates total (3 standard + 3 custom)", function()
            assert.equals(6, #mgr._templates)
            assert.equals(6, mgr._templateCount)
        end)
        it("Recon Team created with total=5, custom, side=BLUE", function()
            local r = mgr:_findTemplate("Recon Team")
            assert.is_not_nil(r)
            assert.equals(5, r.total)
            assert.is_true(r.custom)
            assert.equals(coalition.side.BLUE, r.side)
        end)
        it("AT Squad created with total=8, side=RED", function()
            local at = mgr:_findTemplate("AT Squad")
            assert.is_not_nil(at)
            assert.equals(8, at.total)
            assert.equals(coalition.side.RED, at.side)
        end)
        it("Support Heavy created with total=14, side=nil (both)", function()
            local sh = mgr:_findTemplate("Support Heavy")
            assert.is_not_nil(sh)
            assert.equals(14, sh.total)
            assert.is_nil(sh.side)
        end)
        it("Mortar Squad + Standard Group flagged disabled", function()
            assert.is_true(mgr:_findTemplate("Mortar Squad").disabled)
            assert.is_true(mgr:_findTemplate("Standard Group").disabled)
        end)
        it("JTAC Group stays enabled", function()
            assert.is_false(mgr:_findTemplate("JTAC Group").disabled)
        end)
    end)

    -- ── F-089 : troop Embark menu filters by disabled / side / capacity ──────
    describe("F-089 — Embark troop menu filters disabled / side / capacity", function()
        local menu, playerObj
        local _origGetByName, _origInAir

        before_each(function()
            resetSingletons()
            EventDispatcher.getInstance()
            CTLDDCSEventBridge.getInstance()
            CTLDZoneManager.getInstance()
            CTLDPlayerManager.getInstance()
            local tm = CTLDTroopManager.getInstance()

            -- Controlled template set (UH-1H capacity = 8 via capabilitiesByType).
            tm._templates = {}
            tm:createLoadableGroup({ name = "Standard Group", composition = { inf = 4, mg = 1, at = 1 } })          -- 6  ≤ 8, both
            tm:createLoadableGroup({ name = "BLUE Recon",    composition = { inf = 4, jtac = 1 }, side = coalition.side.BLUE }) -- 5, BLUE
            tm:createLoadableGroup({ name = "RED AT",        composition = { inf = 2, at = 6  },  side = coalition.side.RED })  -- 8, RED
            tm:createLoadableGroup({ name = "Big Squad",     composition = { inf = 20 } })                          -- 20 > 8
            tm:createLoadableGroup({ name = "Hidden",        composition = { inf = 3 } })
            tm:disableLoadableGroup("Hidden")

            -- On-ground stubs.
            tm._isInAir           = function() return false end
            tm._findAllNearbyDropped = function() return {} end

            -- Zone manager: one BLUE pickup zone the player is inside, infinite stock.
            local zm = CTLDZoneManager.getInstance()
            zm.getTroopZonesForCoalition = function()
                return { {
                    zoneName        = "Z1",
                    pickMaxStock    = 0,           -- 0 → infinite (see refreshMenuSection)
                    pickCurrentStock = 0,
                    hasPickup       = function() return true end,
                    isInZone        = function() return true end,
                } }
            end

            _origGetByName = Unit.getByName
            Unit.getByName = function(n)
                if n == "BLUE_UH1H_1" then
                    return {
                        getName  = function() return "BLUE_UH1H_1" end,
                        isExist  = function() return true end,
                        getPoint = function() return { x = 0, y = 0, z = 0 } end,
                    }
                end
                return _origGetByName and _origGetByName(n) or nil
            end

            playerObj = makePlayer({
                unitName = "BLUE_UH1H_1", coalition = coalition.side.BLUE, typeName = "UH-1H",
            })
            CTLDPlayerManager.getInstance():buildMenu(playerObj)
            menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
        end)

        after_each(function()
            Unit.getByName = _origGetByName
        end)

        local function loadPath(name)
            return { ROOT, tr("Troop Commands"), tr("Embark / Extract Troops"),
                     tr("Load from %1", "TRZ_Z1"), tr("Load ") .. name }
        end

        it("Standard Group present (6 ≤ cap 8, no side restriction)", function()
            assert.is_true(has(menu, loadPath("Standard Group")))
        end)
        it("BLUE Recon present (5 ≤ cap, side=BLUE matches)", function()
            assert.is_true(has(menu, loadPath("BLUE Recon")))
        end)
        it("RED AT absent (side=RED, player is BLUE)", function()
            assert.is_false(has(menu, loadPath("RED AT")))
        end)
        it("Big Squad absent (20 > cap 8)", function()
            assert.is_false(has(menu, loadPath("Big Squad")))
        end)
        it("Hidden absent (disabled)", function()
            assert.is_false(has(menu, loadPath("Hidden")))
        end)
    end)

    -- ── F-025 : OnVehicleLoaded/Unloaded → CTLDPlayer.loadedVehicles ─────────
    describe("F-025 — player-manager maintains loadedVehicles on vehicle events", function()
        local pm, playerObj, transport, veh

        before_each(function()
            resetSingletons()
            EventDispatcher.getInstance()
            CTLDDCSEventBridge.getInstance()
            pm = CTLDPlayerManager.getInstance()   -- init() subscribes the cargo events

            playerObj = CTLDPlayer:new({
                unitName = "UH-1H-1", groupId = 9901, groupName = "Grp_F25",
                coalition = coalition.side.BLUE, typeName = "UH-1H", isTransport = true,
            })
            pm._players["UH-1H-1"] = playerObj

            transport = { getName = function() return "UH-1H-1" end, isExist = function() return true end }
            veh       = { id = "veh_F25", vehicleType = "M1045 HMMWV TOW" }
        end)

        it("loadedVehicles starts empty", function()
            assert.equals(0, #playerObj.loadedVehicles)
        end)

        it("OnVehicleLoaded appends the ctldVehicleObject", function()
            EventDispatcher.getInstance():publish("OnVehicleLoaded", {
                transportUnitObject = transport, ctldVehicleObject = veh,
            })
            assert.equals(1, #playerObj.loadedVehicles)
            assert.equals(veh, playerObj.loadedVehicles[1])
        end)

        it("OnVehicleUnloaded removes it again", function()
            local ed = EventDispatcher.getInstance()
            ed:publish("OnVehicleLoaded",   { transportUnitObject = transport, ctldVehicleObject = veh })
            ed:publish("OnVehicleUnloaded", { transportUnitObject = transport, ctldVehicleObject = veh })
            assert.equals(0, #playerObj.loadedVehicles)
        end)

        it("event for an untracked unit is ignored (no error)", function()
            local other = { getName = function() return "GHOST-9" end, isExist = function() return true end }
            EventDispatcher.getInstance():publish("OnVehicleLoaded", {
                transportUnitObject = other, ctldVehicleObject = veh,
            })
            assert.equals(0, #playerObj.loadedVehicles)
        end)
    end)

    -- ── refreshMenuSection overrideInAir — forces state despite stale _isInAir() ──
    -- CTLDCrateManager:refreshCrateFlightSection accepts an overrideInAir param so
    -- onTakeoff/onLand can force the correct state immediately, since S_EVENT_LAND/
    -- TAKEOFF fire before ctld.utils.inAir()'s speed/AGL threshold settles.
    -- CTLDTroopManager:refreshMenuSection lacked this — found live (CATCH-UP-PILOT-SCENARIOS
    -- ticket 02, TMFV F-185): Parachute Troops stayed VISIBLE and Disembark Troops
    -- ABSENT right after landing.
    describe("CTLDTroopManager:refreshMenuSection — overrideInAir forces state", function()
        local tm, playerObj, _origGetByName

        before_each(function()
            resetSingletons()
            EventDispatcher.getInstance()
            CTLDDCSEventBridge.getInstance()
            CTLDZoneManager.getInstance()
            CTLDPlayerManager.getInstance()
            tm = CTLDTroopManager.getInstance()

            _origGetByName = Unit.getByName
            Unit.getByName = function(n)
                if n == "BLUE_UH1H_2" then
                    return {
                        getName  = function() return "BLUE_UH1H_2" end,
                        isExist  = function() return true end,
                        getPoint = function() return { x = 0, y = 0, z = 0 } end,
                    }
                end
                return _origGetByName and _origGetByName(n) or nil
            end

            playerObj = makePlayer({
                unitName = "BLUE_UH1H_2", coalition = coalition.side.BLUE, typeName = "UH-1H",
            })
            CTLDPlayerManager.getInstance():buildMenu(playerObj)

            -- Troops onboard (needed for Parachute Troops to appear in flight).
            tm._inTransit["BLUE_UH1H_2"] = { { templateName = "Test Squad", unitTotal = 4, weight = 100 } }

            -- Raw geometry check still says "in the air" (simulates the DCS threshold lag
            -- S_EVENT_LAND fires before inAir() crosses its speed/AGL threshold).
            tm._isInAir = function() return true end
        end)

        after_each(function()
            Unit.getByName = _origGetByName
        end)

        local function menu() return ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId) end
        local function troopPath(name) return { ROOT, tr("Troop Commands"), tr(name) } end

        it("overrideInAir=false forces ground menu even though _isInAir()=true", function()
            tm:refreshMenuSection(playerObj, false)
            assert.is_true(has(menu(), troopPath("Disembark Troops")))
            assert.is_false(has(menu(), troopPath("Parachute Troops")))
        end)

        it("no override (nil) falls back to live _isInAir()=true → flight menu (Disembark present via fast-rope)", function()
            tm:refreshMenuSection(playerObj)
            -- UX-FASTROPE-INFLIGHT: Disembark now visible in flight when enableFastRopeInsertion=true
            assert.is_true(has(menu(), troopPath("Disembark Troops")))
            assert.is_true(has(menu(), troopPath("Parachute Troops")))
        end)

        it("overrideInAir=true forces flight menu even if _isInAir() would say ground (Disembark present via fast-rope)", function()
            tm._isInAir = function() return false end
            tm:refreshMenuSection(playerObj, true)
            -- UX-FASTROPE-INFLIGHT: Disembark now visible in flight when enableFastRopeInsertion=true
            assert.is_true(has(menu(), troopPath("Disembark Troops")))
            assert.is_true(has(menu(), troopPath("Parachute Troops")))
        end)
    end)

end)
