---@diagnostic disable
-- tests/ci/unit/zone_menu_refresh_spec.lua
-- FEAT-TRZ-DYNAMIC-OBJECT-AUTODISCOVERY ticket 01 — F10 menu refresh on any dynamic
-- troop/logistic zone create/remove: CTLDPlayerManager subscribes to OnTroopZoneUpdated /
-- OnLogisticZoneUpdated and refreshes every currently on-ground tracked player, without any
-- new proximity/geometry calculation (the refreshed functions already self-filter by zone
-- membership internally — this only asserts the fan-out reaches the right players).
-- ============================================================

describe("CTLDPlayerManager — dynamic zone refresh subscription", function()

    local mgr
    local origUnitGetByName, origInAir
    local origTroopRefresh, origCrateRefresh
    local troopRefreshed, crateRefreshed
    local flying   -- unitName -> bool ("is this player currently flying")

    before_each(function()
        CTLDPlayerManager._instance  = nil
        CTLDDCSEventBridge._instance = nil
        EventDispatcher._instance    = nil
        CTLDTroopManager._instance   = nil
        CTLDCrateManager._instance   = nil

        flying         = {}
        troopRefreshed = {}
        crateRefreshed = {}

        -- Force CTLDTroopManager/CTLDCrateManager's real init() to run now, with no fake
        -- player in existence yet and the real (unspied) refresh functions still in place —
        -- init() has its own unrelated startup side effects (e.g. scene-crate injection) that
        -- may themselves call refreshRequestEquipmentSection/refreshMenuSection for whatever
        -- players CTLDPlayerManager already tracks. Draining that here, before a fake player
        -- exists and before the spies below are installed, keeps the spy counts in the tests
        -- below limited to calls this ticket's own event subscription actually causes.
        CTLDTroopManager.getInstance()
        CTLDCrateManager.getInstance()

        origUnitGetByName = Unit.getByName
        origInAir         = ctld.utils.inAir
        origTroopRefresh  = CTLDTroopManager.refreshMenuSection
        origCrateRefresh  = CTLDCrateManager.refreshRequestEquipmentSection

        -- Spy replacements: this ticket's contract is "the right per-player section refresh
        -- gets called for the right players" — the internal menu-content logic of those two
        -- functions is exercised by their own existing specs, not re-tested here.
        CTLDTroopManager.refreshMenuSection = function(_self, playerObj)
            troopRefreshed[#troopRefreshed + 1] = playerObj.unitName
        end
        CTLDCrateManager.refreshRequestEquipmentSection = function(_self, playerObj)
            crateRefreshed[#crateRefreshed + 1] = playerObj.unitName
        end

        Unit.getByName = function(name)
            if flying[name] == nil then return nil end
            local u = {}
            function u:getName() return name end
            function u:isExist() return true end
            return u
        end
        ctld.utils.inAir = function(unit)
            return flying[unit:getName()] == true
        end

        mgr = CTLDPlayerManager.getInstance()
    end)

    after_each(function()
        Unit.getByName    = origUnitGetByName
        ctld.utils.inAir  = origInAir
        CTLDTroopManager.refreshMenuSection             = origTroopRefresh
        CTLDCrateManager.refreshRequestEquipmentSection = origCrateRefresh
        CTLDTroopManager._instance = nil
        CTLDCrateManager._instance = nil
    end)

    local function addPlayer(unitName, isFlying)
        flying[unitName] = isFlying
        mgr._players[unitName] = CTLDPlayer:new({
            unitName    = unitName,
            groupId     = 1,
            groupName   = "test_group",
            coalition   = coalition.side.BLUE,
            typeName    = "UH-1H",
            isTransport = true,
        })
    end

    it("OnTroopZoneUpdated refreshes an on-ground player's troop section", function()
        addPlayer("p1", false)

        EventDispatcher.getInstance():publish("OnTroopZoneUpdated", {})

        assert.same({ "p1" }, troopRefreshed)
        assert.equals(0, #crateRefreshed)
    end)

    it("OnTroopZoneUpdated does not refresh a flying player", function()
        addPlayer("p1", true)

        EventDispatcher.getInstance():publish("OnTroopZoneUpdated", {})

        assert.equals(0, #troopRefreshed)
    end)

    it("OnLogisticZoneUpdated refreshes an on-ground player's crate section", function()
        addPlayer("p1", false)

        EventDispatcher.getInstance():publish("OnLogisticZoneUpdated", {})

        assert.same({ "p1" }, crateRefreshed)
        assert.equals(0, #troopRefreshed)
    end)

    it("OnLogisticZoneUpdated does not refresh a flying player", function()
        addPlayer("p1", true)

        EventDispatcher.getInstance():publish("OnLogisticZoneUpdated", {})

        assert.equals(0, #crateRefreshed)
    end)

    it("refreshes every on-ground player, skips every flying one, for a mixed roster", function()
        addPlayer("ground1", false)
        addPlayer("air1",    true)
        addPlayer("ground2", false)
        addPlayer("air2",    true)

        EventDispatcher.getInstance():publish("OnTroopZoneUpdated", {})

        table.sort(troopRefreshed)
        assert.same({ "ground1", "ground2" }, troopRefreshed)
    end)

    it("does nothing when no player is tracked", function()
        assert.has_no_error(function()
            EventDispatcher.getInstance():publish("OnTroopZoneUpdated", {})
            EventDispatcher.getInstance():publish("OnLogisticZoneUpdated", {})
        end)
        assert.equals(0, #troopRefreshed)
        assert.equals(0, #crateRefreshed)
    end)

end)
