---@diagnostic disable
-- =============================================================================
-- tests/dcs/_reset_state.lua — soft-reset of CTLD shared player/menu state.
--
-- Injected by the integration runners (`run_scenarios.py --reset-before-each`,
-- `run_ia_scenario.py`) BEFORE each scenario, so a scenario never inherits the
-- polluted PlayerManager/MenuManager state left by the previous one.
--
-- WHY: scenarios share CTLD's singletons. Several leave residue that ABORTs the
-- next player-dependent scenario -- observed live: phantom `_players` entries
-- (e.g. `uh1h_slot_1`, `uh1h_slot_whitelisted` from the cl9/cl10 tests) plus a
-- wiped MenuManager menu for the real slotted player, so `getMenuByGroupId`
-- returns nil and the scenario aborts with "no CTLD MenuManager menu". This is
-- the same class as FIX-LIVE-DCS-FAILURES' cross-scenario contamination that a
-- mission reload cleared -- but `net.load_mission` is unavailable on a client,
-- so we can't reload from Lua. This snippet re-establishes a clean player/menu
-- baseline without a reload.
--
-- SCOPE: deliberately player/menu only -- NOT zones/FOBs/scenes/JTAC. Those are
-- mission-defined or each scenario sets up + tears down its own, and blindly
-- resetting them could destroy state a scenario legitimately relies on. If a
-- scenario ever proves to need a deeper reset than this, that's the signal for a
-- human mission reload (Shift+R), which the runner prompts for.
-- =============================================================================
do
    if not ctld or not CTLDPlayerManager then
        return "[RESET-STATE] SKIP: CTLD not initialized"
    end

    local pruned, rebuilt, added = 0, 0, 0
    local ok, err = pcall(function()
        local pm = CTLDPlayerManager.getInstance()
        if not pm or not pm._players then return end

        -- 1. Prune phantom players: any tracked entry whose unit is not a real,
        --    currently player-controlled slot.
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if not (u and u:isExist() and u:getPlayerName()) then
                pm._players[unitName] = nil
                pruned = pruned + 1
            end
        end

        -- 2. Ensure every real slotted player is tracked and has a fresh menu.
        for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE }) do
            for _, u in ipairs(coalition.getPlayers(side) or {}) do
                if u and u:isExist() and u:getPlayerName() then
                    local un = u:getName()
                    if not pm._players[un] then
                        pm:onPlayerEnterUnit({ initiator = u })  -- create player + build menu
                        added = added + 1
                    else
                        pm:buildMenu(pm._players[un])            -- rebuild menu from scratch
                        rebuilt = rebuilt + 1
                    end
                end
            end
        end
    end)

    if not ok then
        env.info("[RESET-STATE] error: " .. tostring(err))
        return "[RESET-STATE] ERROR: " .. tostring(err)
    end
    return string.format("[RESET-STATE] done (pruned=%d rebuilt=%d added=%d)", pruned, rebuilt, added)
end
