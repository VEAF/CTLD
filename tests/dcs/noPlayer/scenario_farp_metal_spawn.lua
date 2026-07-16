---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_farp_metal_spawn.lua
-- CTLD — Spawn "Metal FARP" scene at the position of static coord_farp-1
--
-- Runs playSceneAtPos "Metal FARP" at the point of static "coord_farp-1".
-- The helipad spawns 58 m north of the anchor by scene design (step 1 polar offset).
-- One-off utility scenario: single injection, no human steps.
--
-- Prerequisites:
--   - Static object "coord_farp-1" present in the mission
--   - Inject CTLD.lua first, wait 3–5 s for init.
--
-- @scenario  METAL-FARP-SPAWN
-- @version   3.0 — 2026-06-30
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[METAL-FARP-SPAWN] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_METALFARPSPAWN_RESULT = "[METAL-FARP-SPAWN] ABORT: CTLD not initialized"
    return _SCN_METALFARPSPAWN_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_METALFARPSPAWN_RUNNING then
    trigger.action.outText("[METAL-FARP-SPAWN] already running — wait for it to finish or restart DCS.", 10)
    return _SCN_METALFARPSPAWN_RESULT or "[METAL-FARP-SPAWN] RUNNING"
end
_SCN_METALFARPSPAWN_RUNNING = true
_SCN_METALFARPSPAWN_RESULT = "[METAL-FARP-SPAWN] STARTED"

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[METAL-FARP-SPAWN]"
local NAME = "Metal FARP spawn at coord"

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_METALFARPSPAWN_RUNNING = false
    log("cleanup done")
end

-- ── 13. Main execution ───────────────────────────────────────────────────────
log("=== START: "..NAME.." ===")

local ok, err = pcall(function()
    -- coord_farp-1 anchor hardcoded: the static is absent from the VEAF test mission.
    -- Map coords provided by David (X/Z in metres, ~6.4 m ≈ 21 ft).
    local pos         = { x = -356482, y = 6.4, z = 616908 }
    local coalitionId = coalition.side.BLUE
    local countryId   = country.id.USA

    log(string.format("anchor pos=(%.1f, %.1f, %.1f) coa=%d cty=%d",
        pos.x, pos.y, pos.z, coalitionId, countryId))

    local scene = CTLDSceneManager.getInstance():playSceneAtPos(
        "Metal FARP", pos, coalitionId, countryId)

    if scene then
        local msg = TAG..string.format(" ✅ [OK] %s — Metal FARP scene started at (%.0f, %.0f)", NAME, pos.x, pos.z)
        log(msg)
        trigger.action.outText(msg, 15)
        _SCN_METALFARPSPAWN_RESULT = TAG.." PASS"
    else
        local msg = TAG.." ❌ [KO] "..NAME.." — playSceneAtPos returned nil"
        log(msg)
        trigger.action.outText(msg, 15)
        _SCN_METALFARPSPAWN_RESULT = TAG.." FAIL: playSceneAtPos returned nil"
    end
end)

if not ok then
    local msg = TAG.." ❌ [KO] "..NAME.." — ERROR: "..tostring(err)
    log(msg)
    trigger.action.outText(msg, 15)
    _SCN_METALFARPSPAWN_RESULT = TAG.." FAIL: "..tostring(err)
end

cleanup()

end  -- do isolation scope
return _SCN_METALFARPSPAWN_RESULT
