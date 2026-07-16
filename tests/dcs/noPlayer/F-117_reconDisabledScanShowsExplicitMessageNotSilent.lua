-- @tier: auto
-- F-117 — RECON disabled: scan() shows explicit message (not silent)
-- Verify: when reconF10Menu=false, scan() emits outTextForGroup with "reconF10Menu" keyword.

local results = {}
local function assert_eq(label, got, exp)
    if got == exp then
        results[#results+1] = "PASS " .. label
    else
        results[#results+1] = string.format("FAIL %s  got=%s  exp=%s", label, tostring(got), tostring(exp))
    end
end
local function assert_true(label, cond)
    assert_eq(label, not not cond, true)
end

local rmgr = CTLDReconManager.getInstance()

-- scan() takes a UNIT, not a live client — no human player needed here. Spawn a throwaway
-- ground observer resolvable via Unit.getByName (a pure mock would not be found by _scanLOS).
local OBS_GRP = "F117_recon_obs_grp"
local OBS     = "F117_recon_obs"
local _spawn  = ctld.utils.dynAdd("F-117:observer", {
    category = Group.Category.GROUND,
    country  = country.id.USA,
    name     = OBS_GRP,
    units    = { { type = "Soldier M4", name = OBS, x = -356482, y = 616908, heading = 0, skill = "Average" } },
})
local pu = _spawn and Group.getByName(_spawn.name) and Group.getByName(_spawn.name):getUnit(1) or nil
if not pu then
    _SCN_F117_RESULT = "[F-117] ABORT: observer spawn failed"
    return _SCN_F117_RESULT
end
local playerName = pu:getName()

_SCN_F117_RESULT = "[F-117] STARTED"

local cfg = CTLDConfig.get().settings

-- ── mock outTextForGroup to capture message ───────────────────────────────────
local _captured = nil
local _orig_otfg = trigger.action.outTextForGroup
trigger.action.outTextForGroup = function(gid, msg, dur)
    _captured = msg
    _orig_otfg(gid, msg, dur)
end

-- ── U-01: reconF10Menu=false → message contains "reconF10Menu" ───────────────
local _origEnabled = cfg["reconF10Menu"]
cfg["reconF10Menu"] = false
pcall(function() rmgr:scan(pu, playerName) end)
assert_true("U-01 message emitted",          _captured ~= nil)
assert_true("U-01 message mentions config",  _captured and _captured:find("reconF10Menu"))

-- ── U-02: reconF10Menu=true → no disabled message ───────────────────────────
_captured = nil
cfg["reconF10Menu"] = true
local _origMinAlt = cfg["reconMinAltitude"]
cfg["reconMinAltitude"] = 0   -- bypass altitude check (ground observer)
pcall(function() rmgr:scan(pu, playerName) end)
-- Message may be nil or be the "no layers" message — must NOT be the disabled message.
local isDisabledMsg = _captured and _captured:find("reconF10Menu")
assert_eq("U-02 no disabled message when enabled", isDisabledMsg, nil)

-- ── restore ───────────────────────────────────────────────────────────────────
cfg["reconF10Menu"]     = _origEnabled
cfg["reconMinAltitude"] = _origMinAlt
trigger.action.outTextForGroup = _orig_otfg
local _obsGrp = Group.getByName(OBS_GRP)
if _obsGrp then pcall(function() _obsGrp:destroy() end) end

local pass = 0; local fail = 0
local failReasons = {}
for _, r in ipairs(results) do
    env.info("[F-117] " .. r)
    if r:sub(1,4) == "PASS" then pass = pass+1 else fail = fail+1; failReasons[#failReasons+1] = r end
end

local summary = string.format("F-117: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(summary, 15)
env.info("[F-117] " .. summary)
local total = pass + fail
if fail == 0 then
    _SCN_F117_RESULT = "[F-117] PASS " .. pass .. "/" .. total
else
    _SCN_F117_RESULT = "[F-117] FAIL " .. fail .. "/" .. total .. ": " .. table.concat(failReasons, "; ")
end
return _SCN_F117_RESULT
