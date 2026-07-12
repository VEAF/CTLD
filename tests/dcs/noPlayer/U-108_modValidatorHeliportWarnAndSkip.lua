---@diagnostic disable
-- @tier: auto
-- U-108: CTLDModValidator — Heliport probe: stock types probed, custom-mod (probeSkip) skipped
-- DCS scripting API cannot distinguish an installed custom-mod heliport from a missing type
-- (getDesc().life == 0 for both) → such registry entries carry probeSkip=true and are skipped
-- from probing to avoid a false NOT FOUND alarm. Stock heliport types (FARP, SINGLE_HELIPAD,
-- Invisible FARP) have no probeSkip and are collected as HELIPORT probeType entries.
-- Checks:
--   C1  : probeSkip heliport (Farp_FG_Petit_Helipad) is ABSENT from HELIPORT probeType entries
--   C1b : the 3 stock heliport types are PRESENT as HELIPORT probeType entries
--   C2  : isStaticInvalid("SINGLE_HELIPAD") → false (not probed in this scenario, not cached invalid)
--   C3  : an INFO "skipped" log (mentioning probeSkip) is emitted, and no spurious WARN
--   C4  : other probe types (GROUND) still function normally (BRDM-2 → true)
-- Requires: DCS active, CTLD injected

local _t = { pass=0, fail=0, msgs={} }
local function chk(label, cond)
    if cond then
        _t.pass = _t.pass + 1; _t.msgs[#_t.msgs+1] = "[PASS] " .. label
    else
        _t.fail = _t.fail + 1; _t.msgs[#_t.msgs+1] = "[FAIL] " .. label
    end
end

-- Capture log calls (INFO and WARN separately)
local logInfos, logWarns = {}, {}
local _origLog = ctld.utils.log
ctld.utils.log = function(level, fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    s = ok and s or tostring(fmt)
    if level == "WARN" then
        logWarns[#logWarns+1] = s
    elseif level == "INFO" then
        logInfos[#logInfos+1] = s
    end
end

-- Fresh singleton
CTLDModValidator._instance = nil
local mv = CTLDModValidator.getInstance()
mv._probePos = { x = -356437, z = 617000 }

-- Collect once; classify HELIPORT entries by typeName
local entries = mv:_collectTypeNames()
local heliportTypes = {}
for _, e in ipairs(entries) do
    if e.probeType == "HELIPORT" then heliportTypes[e.typeName] = true end
end

-- C1: the probeSkip=true heliport is excluded from HELIPORT probe entries
chk("C1 probeSkip heliport 'Farp_FG_Petit_Helipad' absent from HELIPORT entries",
    heliportTypes["Farp_FG_Petit_Helipad"] == nil)

-- C1b: the 3 stock heliport types are collected as HELIPORT (typeName = desc.type)
chk("C1b stock 'FARP' present as HELIPORT",             heliportTypes["FARP"] == true)
chk("C1b stock 'SINGLE_HELIPAD' present as HELIPORT",   heliportTypes["SINGLE_HELIPAD"] == true)
chk("C1b stock 'Invisible FARP' present as HELIPORT",   heliportTypes["Invisible FARP"] == true)

-- C2: isStaticInvalid for a known Heliport type → false (not probed here, not cached as invalid)
-- (cache["S:SINGLE_HELIPAD"] is nil → isStaticInvalid returns nil==false → false)
chk("C2 isStaticInvalid(SINGLE_HELIPAD) → false", mv:isStaticInvalid("SINGLE_HELIPAD") == false)

-- C3: an INFO "skipped" log mentioning probeSkip is emitted for the custom-mod heliport,
--     and _collectTypeNames raised no spurious WARN.
local skipInfoOk = false
for _, m in ipairs(logInfos) do
    if m:find("skipped") and m:find("probeSkip") then
        skipInfoOk = true; break
    end
end
chk("C3 INFO 'skipped' (probeSkip) emitted for custom-mod heliport", skipInfoOk)
chk("C3 no spurious WARN during _collectTypeNames", #logWarns == 0)

-- C4: other probe types still work (sanity: GROUND probe on known valid type)
ctld.utils.log = _origLog  -- restore before probeGround (needs log)
local _origLog2 = ctld.utils.log
ctld.utils.log = function() end
local r4 = mv:_probeGround("BRDM-2")
ctld.utils.log = _origLog2
chk("C4 GROUND probe still works (BRDM-2 → true)", r4 == true)

local msg = string.format("U-108 HELIPORT probe/skip: %d PASS / %d FAIL\n%s\nInfos=%d Warns=%d",
    _t.pass, _t.fail, table.concat(_t.msgs, "\n"), #logInfos, #logWarns)
trigger.action.outText(msg, 35)
env.info("[U-108] " .. msg:gsub("\n", " | "))
-- dcs-bridge return contract (sync verdict; C1..C4 programmatic)
local _total = _t.pass + _t.fail
if _t.fail == 0 then
    return "[U-108] PASS " .. _t.pass .. "/" .. _total
end
local _reasons = {}
for _, m in ipairs(_t.msgs) do if m:find("%[FAIL%]") then _reasons[#_reasons+1] = m end end
return "[U-108] FAIL " .. _t.fail .. "/" .. _total .. ": " .. table.concat(_reasons, "; ")
