---@diagnostic disable
-- @tier: auto
-- =============================================================================
-- aiTransport_featureT_troopRotation_F177.lua  [AUTO]
-- F-177 — Feature T: troopTemplates rotation algorithm
--
-- PREREQUISITE: CTLD initialized (classes available in memory).
--   Does not require DCS zones in the .miz.
--
-- GOAL: verify that aiPickTroopTemplate() selects the template with the
--   highest current stock (algorithm C), randomly among ties. Templates
--   with lower stock must never be chosen.
-- =============================================================================

-- ── 1. CTLD-ready guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-177] ABORT: CTLD not initialized. Inject CTLD.lua first.", 15)
    _SCN_F177_RESULT = "[F-177] ABORT: CTLD not initialized"
    return _SCN_F177_RESULT
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F177_RUNNING then
    trigger.action.outText("[F-177] already running.", 10)
    return _SCN_F177_RESULT or "[F-177] RUNNING"
end
_SCN_F177_RUNNING = true
_SCN_F177_RESULT = "[F-177] STARTED"

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-177]"
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

report("==== START " .. START .. " ====")

local _ok, _err = pcall(function()

    -- ── Mock transport manager ─────────────────────────────────────────────
    local mockTm = {
        _weightForGroup = function(self, tmpl) return 0 end,
        _canEmbark      = function(self, typeName, unitName, total, w) return true end,
    }

    -- ── Mock teams list ───────────────────────────────────────────────────
    -- Three templates: A (stock=5), B (stock=3), C (stock=5)
    -- Rotation rule: pick randomly among those with MAX stock → always A or C, never B.
    local teamA = { name = "Alpha Squad", total = 4 }
    local teamB = { name = "Bravo Squad", total = 4 }
    local teamC = { name = "Charlie Squad", total = 4 }
    local teams = { teamA, teamB, teamC }

    -- ── Build zone directly with inline stock table ───────────────────────
    local zone = CTLDTroopZone:new({
        zoneName    = "TEST_ROTATION",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = false,
            init    = { ["Alpha Squad"] = 5, ["Bravo Squad"] = 3, ["Charlie Squad"] = 5 },
            current = { ["Alpha Squad"] = 5, ["Bravo Squad"] = 3, ["Charlie Squad"] = 5 },
        },
    })

    -- ── F-177.1 : run 20 picks — B must never be chosen ───────────────────
    local pickedB = false
    local countA, countC = 0, 0
    for i = 1, 20 do
        local tmpl = zone:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
        if tmpl == nil then
            fail("F-177.1", "aiPickTroopTemplate returned unexpected nil (iter " .. i .. ")")
        end
        if tmpl.name == "Bravo Squad" then pickedB = true end
        if tmpl.name == "Alpha Squad" then countA = countA + 1 end
        if tmpl.name == "Charlie Squad" then countC = countC + 1 end
    end
    check("F-177.1", "Bravo Squad (stock=3) never chosen across 20 picks", not pickedB,
          "Bravo Squad picked at least once")
    check("F-177.2", "Alpha Squad or Charlie Squad (stock=5) always chosen",
          countA + countC == 20, "countA=" .. countA .. " countC=" .. countC)

    -- ── F-177.3 : with stock=0 on Alpha, only Charlie eligible ────────────
    zone._aiTroopStock.current["Alpha Squad"] = 0
    local found_alpha = false
    for i = 1, 10 do
        local tmpl = zone:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
        if tmpl and tmpl.name == "Alpha Squad" then found_alpha = true end
    end
    check("F-177.3", "Alpha Squad excluded (stock=0) — only Charlie eligible", not found_alpha)

    -- ── F-177.4 : all stock=0 → returns nil ───────────────────────────────
    zone._aiTroopStock.current["Alpha Squad"]   = 0
    zone._aiTroopStock.current["Bravo Squad"]   = 0
    zone._aiTroopStock.current["Charlie Squad"] = 0
    local nilResult = zone:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
    check("F-177.4", "All stock=0 → aiPickTroopTemplate returns nil", nilResult == nil,
          tostring(nilResult and nilResult.name))

    -- ── F-177.5 : isAll=true → always return a template ───────────────────
    local zoneAll = CTLDTroopZone:new({
        zoneName    = "TEST_ROTATION_ALL",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = true,
            init    = {},
            current = {},
        },
    })
    local tmplAll = zoneAll:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
    check("F-177.5", "isAll=true → a template is returned (non-nil)", tmplAll ~= nil,
          "returned nil")

    -- ── F-177.6 : _aiTroopStock=nil → returns nil (legacy path) ───────────
    local zoneNoStock = CTLDTroopZone:new({
        zoneName    = "TEST_NOSTOCK",
        isAIPickup  = true,
        pickMaxStock = 0,
    })
    local nilLegacy = zoneNoStock:aiPickTroopTemplate(teams, "UH-1H", "test_unit", mockTm)
    check("F-177.6", "_aiTroopStock=nil → returns nil (legacy fallback)", nilLegacy == nil)

    report("F-177 ALL PASS — troopTemplates rotation correct")

end)

if not _ok then
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_F177_RESULT = TAG .. " FAIL: " .. tostring(_err)
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F177_RUNNING = false
    return _SCN_F177_RESULT
end

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
_SCN_F177_RESULT = TAG .. " PASS"
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F177_RUNNING = false

end  -- do isolation scope
return _SCN_F177_RESULT
