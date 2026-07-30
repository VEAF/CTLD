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

    -- ADR 0011 Addendum 1: the mission snapshot may omit parameters — hand-edited YAML, or a
    -- config authored against an older catalogue. They resolved to the CTLD default; say so on
    -- screen, because nothing obliges a Mission Maker to run ctld-tools, so a hand-written
    -- config never meets `validate` and this is the only signal its author will get.
    local _defaulted = CTLDConfig.get():getDefaultedParameters()
    if #_defaulted > 0 then
        ctld.startupReport.add("NOTICE", "config", ctld.tr(
            "%1 setting(s) absent from the mission config — CTLD default used: %2",
            #_defaulted, table.concat(_defaulted, ", ")))
    end

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

    -- i18n completeness audit: report untranslated stubs for the active language (log-only)
    local _ok, _fromSetting = pcall(function() return ctld.gs and ctld.gs("i18n_lang") end)
    local _i18nLang = (_ok and _fromSetting) or ctld.i18n_lang or "en"
    if _i18nLang ~= "en" then
        local _i18nResult = ctld.i18n_audit(_i18nLang)
        if _i18nResult then
            local _n = #_i18nResult.untranslated
            if _n > 0 then
                ctld.startupReport.add("INFO", "i18n",
                    string.format("%d untranslated key(s) in '%s' — rebuild to translate", _n, _i18nLang))
            end
        end
    end

    ctld.startupReport.flush()
    ctld.utils.log("INFO", "CTLD initialized.")
end

if ctld.dontInitialize then
    ctld.utils.log("INFO", "CTLD auto-start skipped (ctld.dontInitialize=true). Call ctld.initialize() manually.")
else
    ctld.initialize()
end
