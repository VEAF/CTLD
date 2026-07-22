-- ============================================================
-- CTLD_bootstrap.lua
-- Engine bootstrap — merged last into CTLD.lua.
--
-- Defines ctld.initialize() and triggers the auto-start.
-- Set ctld.dontInitialize = true in your mission script BEFORE
-- loading CTLD.lua if you need to call ctld.initialize()
-- manually (e.g. to run additional setup between loading and
-- starting).
-- ============================================================

---@diagnostic disable-next-line: lowercase-global
function ctld.initialize()
    CTLDConfig.get():load()
    ctld.utils.initLog()

    -- Materialise the full configuration before any manager reads it:
    --   1) inject the AA system crate entries into spawnableCrates,
    --   2) run the Mission Maker userSetup callbacks (add/remove/patch).
    -- This is the single place that controls config materialisation order, so managers
    -- always see the final, complete config table (ADR 0008/0009).
    CTLDCrateAssemblyManager.injectAACrates(ctld.gs("spawnableCrates"))
    ctld.runUserSetup()

    -- Boot all domain managers first so they can register their menu sections.
    -- Order matters: PlayerManager must be up before any other manager calls
    -- registerMenuSection(), and _scanExistingPlayers() must run last so all
    -- sections are registered before menus are built for pre-existing players.
    CTLDPlayerManager.getInstance()   -- creates _menuSections registry
    CTLDZoneManager.getInstance()
    CTLDTroopManager.getInstance()    -- registers "troops" section
    CTLDCrateManager.getInstance()    -- registers "crates" + "smoke" sections
    CTLDVehicleSpawner.getInstance()  -- registers "vehicles" section
    CTLDFOBManager.getInstance()
    CTLDBeaconManager.getInstance()   -- registers "beacons" section
    CTLDReconManager.getInstance()    -- registers "recon" section
    CTLDJTACManager.getInstance()             -- registers "jtac" section
    CTLDCrateAssemblyManager.getInstance()
    CTLDCoreManager.getInstance()     -- INIT-B (MM crates) + INIT-C (MM JTACs)

    -- Now that all sections are registered, build menus for any player
    -- already in a slot (no retroactive S_EVENT_PLAYER_ENTER_UNIT).
    CTLDPlayerManager.getInstance():_scanExistingPlayers()

    ctld.startupReport.flush()
    ctld.utils.log("INFO", "CTLD initialized.")
end

if ctld.dontInitialize then
    ctld.utils.log("INFO", "CTLD auto-start skipped (ctld.dontInitialize=true). Call ctld.initialize() manually.")
else
    ctld.initialize()
end
