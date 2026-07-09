---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_farp_countryside_spawn.lua
-- CTLD — Spawn scène "Countryside FARP" à la position du static coord_farp-1
--
-- Exécute playSceneAtPos "Countryside FARP" au point du static "coord_farp-1".
-- Scénario d'utilité ponctuelle : injection unique, pas de steps humains.
--
-- Prérequis :
--   - Static object "coord_farp-1" présent dans la mission
--   - Inject CTLD.lua first, wait 3–5 s for init.
--
-- @scenario  CS-FARP-SPAWN
-- @version   3.0 — 2026-06-30
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CS-FARP-SPAWN] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_CSFARPSPAWN_RESULT = "[CS-FARP-SPAWN] ABORT: CTLD not initialized"
    return _SCN_CSFARPSPAWN_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_CSFARPSPAWN_RUNNING then
    trigger.action.outText("[CS-FARP-SPAWN] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return _SCN_CSFARPSPAWN_RESULT or "[CS-FARP-SPAWN] RUNNING"
end
_SCN_CSFARPSPAWN_RUNNING = true
_SCN_CSFARPSPAWN_RESULT = "[CS-FARP-SPAWN] STARTED"

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[CS-FARP-SPAWN]"
local NAME = "Countryside FARP spawn at coord"

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_CSFARPSPAWN_RUNNING = false
    log("cleanup done")
end

-- ── 13. Exécution principale ─────────────────────────────────────────────────
log("=== START: "..NAME.." ===")

local ok, err = pcall(function()
    local anchor = StaticObject.getByName("coord_farp-1")
    if not anchor or not anchor:isExist() then
        trigger.action.outText(TAG.." [FAIL] static 'coord_farp-1' not found", 15)
        log("[FAIL] static 'coord_farp-1' not found")
        _SCN_CSFARPSPAWN_RESULT = TAG.." FAIL: static 'coord_farp-1' not found"
        return
    end

    local pos         = anchor:getPoint()
    local coalitionId = coalition.side.BLUE
    local countryId   = anchor:getCountry()

    log(string.format("anchor pos=(%.1f, %.1f, %.1f) coa=%d cty=%d",
        pos.x, pos.y, pos.z, coalitionId, countryId))

    local scene = CTLDSceneManager.getInstance():playSceneAtPos(
        "Countryside FARP", pos, coalitionId, countryId)

    if scene then
        local msg = TAG..string.format(" ✅ [OK] %s — Countryside FARP scene started at (%.0f, %.0f)", NAME, pos.x, pos.z)
        log(msg)
        trigger.action.outText(msg, 15)
        _SCN_CSFARPSPAWN_RESULT = TAG.." PASS"
    else
        local msg = TAG.." ❌ [KO] "..NAME.." — playSceneAtPos returned nil"
        log(msg)
        trigger.action.outText(msg, 15)
        _SCN_CSFARPSPAWN_RESULT = TAG.." FAIL: playSceneAtPos returned nil"
    end
end)

if not ok then
    local msg = TAG.." ❌ [KO] "..NAME.." — ERREUR: "..tostring(err)
    log(msg)
    trigger.action.outText(msg, 15)
    _SCN_CSFARPSPAWN_RESULT = TAG.." FAIL: "..tostring(err)
end

cleanup()

end  -- do isolation scope
return _SCN_CSFARPSPAWN_RESULT
