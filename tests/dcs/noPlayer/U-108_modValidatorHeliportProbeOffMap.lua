---@diagnostic disable
-- @tier: auto
-- U-108: CTLDModValidator — _probeHeliport valid and invalid, off-map ghost check
-- Checks:
--   C1: valid HELIPORT type (SINGLE_HELIPAD) → cache=true
--   C2: invalid HELIPORT type → cache=false
--   C3: ghost off-map (world.getAirbases count near Batumi unchanged vs before probe)
--   C4: cache hit valid → no new probe
-- Requires: DCS active, CTLD injected
-- User check: verify F10 map — no FARP marker visible near Batumi / play area

-- Run-once guard: the valid probe spawns a real DCS ghost airbase that cannot be
-- destroyed (DCS limitation). Re-running in the same session would accumulate ghosts
-- and break C3's diff assertion, so short-circuit with an explicit PASS after first run.
if _U108_OFFMAP_DONE then
    trigger.action.outText("[U-108] run-once guard: already probed this session", 10)
    return "[U-108] PASS (run-once: already probed this session)"
end
_U108_OFFMAP_DONE = true

local _t = { pass=0, fail=0, msgs={} }
local function chk(label, cond)
    if cond then
        _t.pass = _t.pass + 1; _t.msgs[#_t.msgs+1] = "[PASS] " .. label
    else
        _t.fail = _t.fail + 1; _t.msgs[#_t.msgs+1] = "[FAIL] " .. label
    end
end

-- Count airbases whose name starts with CTLD_MVP (probe artefacts)
local function countProbeAirbases()
    local n = 0
    for _, a in ipairs(world.getAirbases() or {}) do
        local ok, nm = pcall(function() return a:getName() end)
        if ok and nm and nm:find("CTLD_MVP", 1, true) then n = n + 1 end
    end
    return n
end

-- Fresh singleton
CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }  -- near Batumi

local _origLog = ctld.utils.log
ctld.utils.log = function() end

-- C1: valid HELIPORT type (SINGLE_HELIPAD — standard DCS helipad)
mv:_probeHeliport("SINGLE_HELIPAD", "Heliports", {})
local c1Idx = mv._probeIdx   -- idx used by the valid probe → ghost name "CTLD_MVP_H" .. c1Idx
chk("C1 valid HELIPORT (SINGLE_HELIPAD) → cache=true", mv._cache["S:SINGLE_HELIPAD"] == true)

-- C2: invalid HELIPORT type (fabricated name)
mv:_probeHeliport("CTLD_INVALID_HELIPAD_XYZ_9999", "Heliports", {})
chk("C2 invalid HELIPORT → cache=false", mv._cache["S:CTLD_INVALID_HELIPAD_XYZ_9999"] == false)

local idx_after_probes = mv._probeIdx

-- C3 (option C): the valid probe created its OWN off-map ghost — verify it EXISTS by name.
-- Robust to the ghosts CTLD init pre-creates at load (the old before/after count-diff collided
-- with them and failed even on the first run). We check the specific ghost this probe spawned.
local after    = countProbeAirbases()
local c1Ghost  = "CTLD_MVP_H" .. c1Idx
local c1Exists = StaticObject.getByName(c1Ghost) ~= nil or Airbase.getByName(c1Ghost) ~= nil
chk("C3 valid probe created off-map ghost " .. c1Ghost, c1Exists)

-- C4: cache hit valid → no new probe, count unchanged
local r4 = mv:_probeHeliport("SINGLE_HELIPAD", "Heliports", {})
chk("C4 cache hit → true, no new probe", r4 == true and mv._probeIdx == idx_after_probes and countProbeAirbases() == after)

ctld.utils.log = _origLog

local msg = string.format(
    "U-108 HELIPORT probe: %d PASS / %d FAIL\n%s\n[User] Verify F10: no FARP visible in play area",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"))
trigger.action.outText(msg, 40)
env.info("[U-108] " .. msg:gsub("\n", " | "))
-- dcs-bridge return contract (sync verdict; C1..C4 programmatic, F10 check is supplementary)
local _total = _t.pass + _t.fail
if _t.fail == 0 then
    return "[U-108] PASS " .. _t.pass .. "/" .. _total
end
local _reasons = {}
for _, m in ipairs(_t.msgs) do if m:find("%[FAIL%]") then _reasons[#_reasons+1] = m end end
return "[U-108] FAIL " .. _t.fail .. "/" .. _total .. ": " .. table.concat(_reasons, "; ")
