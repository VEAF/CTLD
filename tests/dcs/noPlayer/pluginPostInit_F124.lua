---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- pluginPostInit_F124.lua  [AUTO]
-- F-124 — Scene plugin post-init loading contract
--
-- PREREQUISITE: CTLD initialized (CTLDCoreManager, CTLDPlayerManager running).
--
-- GOAL: verify that registerSceneModel() and deferMenuSection() called AFTER
--   CTLD init honour the load-position-independent contract introduced by
--   SCENE-PLUGINS (PR #26):
--     1. Scene absent from registry before registration.
--     2. registerSceneModel() adds model to registry (getModel returns non-nil).
--     3. deferMenuSection() routes directly into _menuSections (post-init path).
--     4. Pre-init queue _deferredSections is NOT polluted.
--     5. requiresCtld above current version → WARN but still registers (soft-fail).
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-124] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_F124_RESULT = "[F-124] ABORT: CTLD not initialized"
    return _SCN_F124_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F124_RUNNING then
    trigger.action.outText("[F-124] already running.", 10)
    return _SCN_F124_RESULT or "[F-124] RUNNING"
end
_SCN_F124_RUNNING = true
_SCN_F124_RESULT  = "[F-124] STARTED"

do

local TAG   = "[F-124]"
local START = os.date("%Y-%m-%d %H:%M:%S")

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 20); log(msg) end
local function pass(id, desc)   report("[PASS] " .. id .. " — " .. desc) end
local function fail(id, desc, details)
    local msg = "[FAIL] " .. id .. " — " .. desc .. (details and (" | " .. details) or "")
    trigger.action.outText(TAG .. " !! " .. msg, 60); log(msg)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id, desc) else fail(id, desc, details) end
end

-- Helper: search _menuSections list for a given key
local function menuSectionsHasKey(inst, key)
    for _, s in ipairs(inst._menuSections) do
        if s.key == key then return true end
    end
    return false
end

-- Helper: search _deferredSections list for a given key
local function deferredSectionsHasKey(key)
    for _, s in ipairs(CTLDPlayerManager._deferredSections) do
        if s.key == key then return true end
    end
    return false
end

report("==== START " .. START .. " ====")

local _ok, _err = pcall(function()

    local sceneMgr  = CTLDSceneManager.getInstance()
    local playerMgr = CTLDPlayerManager.getInstance()

    -- ── Stubs ────────────────────────────────────────────────────────────────
    local SCENE_NAME    = "TestPlugin_F124"
    local SCENE_NAME_V  = "TestPlugin_F124_V99"
    local SECTION_KEY   = "test_plugin_section_f124"

    local stubScene = {
        name  = SCENE_NAME,
        steps = { { delayAfterPreviousStep = 0, func = function() end } },
    }
    local stubSceneV99 = {
        name         = SCENE_NAME_V,
        requiresCtld = "99.0.0",
        steps        = { { delayAfterPreviousStep = 0, func = function() end } },
    }
    local stubSection = { key = SECTION_KEY, manager = {}, method = "build", order = 99 }

    -- ── F-124.1  Scene absent before registration ─────────────────────────────
    check("F-124.1", "getModel returns nil before registration",
          sceneMgr:getModel(SCENE_NAME) == nil,
          tostring(sceneMgr:getModel(SCENE_NAME)))

    -- ── F-124.2  registerSceneModel adds to registry ──────────────────────────
    sceneMgr:registerSceneModel(stubScene)
    check("F-124.2", "getModel returns non-nil after registerSceneModel",
          sceneMgr:getModel(SCENE_NAME) ~= nil,
          "got nil")

    -- ── F-124.3  Retrieved model is the stub ──────────────────────────────────
    local retrieved = sceneMgr:getModel(SCENE_NAME)
    check("F-124.3", "retrieved model name matches stub",
          retrieved and retrieved.name == SCENE_NAME,
          tostring(retrieved and retrieved.name))

    -- ── F-124.4  deferMenuSection routes directly into _menuSections ──────────
    CTLDPlayerManager.deferMenuSection(stubSection)
    check("F-124.4", "section present in _menuSections after deferMenuSection",
          menuSectionsHasKey(playerMgr, SECTION_KEY),
          "key not found in _menuSections")

    -- ── F-124.5  Pre-init queue not polluted ──────────────────────────────────
    check("F-124.5", "_deferredSections does NOT contain the section",
          not deferredSectionsHasKey(SECTION_KEY),
          "key found in _deferredSections — was queued instead of routed directly")

    -- ── F-124.6  requiresCtld soft-fail: model still registered despite WARN ──
    sceneMgr:registerSceneModel(stubSceneV99)
    check("F-124.6", "model with requiresCtld=99.0.0 is still registered (soft-fail)",
          sceneMgr:getModel(SCENE_NAME_V) ~= nil,
          "model absent from registry — hard-fail occurred")

    -- ── F-124.7  Second model also has correct name ───────────────────────────
    local retrievedV = sceneMgr:getModel(SCENE_NAME_V)
    check("F-124.7", "retrieved V99 model name matches stub",
          retrievedV and retrievedV.name == SCENE_NAME_V,
          tostring(retrievedV and retrievedV.name))

    -- ── Cleanup: remove stubs to avoid state contamination ───────────────────
    sceneMgr._models[SCENE_NAME]   = nil
    sceneMgr._models[SCENE_NAME_V] = nil
    -- Remove stubSection from _menuSections
    local cleaned = {}
    for _, s in ipairs(playerMgr._menuSections) do
        if s.key ~= SECTION_KEY then
            cleaned[#cleaned + 1] = s
        end
    end
    playerMgr._menuSections = cleaned

    report("==== F-124 ALL PASS ====")

end)

if not _ok then
    _SCN_F124_RESULT = TAG .. " FAIL: " .. tostring(_err)
    trigger.action.outText(TAG .. " FAIL: " .. tostring(_err), 60, true)
    _SCN_F124_RUNNING = false
    return _SCN_F124_RESULT
end

_SCN_F124_RESULT = TAG .. " PASS"
trigger.action.outText(TAG .. " ALL PASS", 30, true)
_SCN_F124_RUNNING = false

end  -- do isolation scope
return _SCN_F124_RESULT
