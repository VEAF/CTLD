---@diagnostic disable
-- diag_crate_spawn_override.lua
-- FEAT-NATIVE-CRATE-SPAWN-NEAR ticket 04 -- change where an aircraft type's crates spawn, in the running
-- mission and without a rebuild, to calibrate the declared distance in small steps. It only edits the
-- in-memory configuration (the next crate request uses it); nothing is spawned or saved.
--
-- Edit the three values below, then inject (HTTP path of the integration runner, after CTLD.lua):
--   TYPE     DCS type name of the aircraft ("Mi-8MT", "UH-1H", ...)
--   SECTOR   "side", "rear" or "front"; nil leaves the sector as it is
--   DISTANCE metres from the aircraft centre to the first crate; 0 removes the plan (default rule applies)
-- Lua 5.1.
-- =============================================================================

local TYPE     = "Mi-8MT"
local SECTOR   = nil
local DISTANCE = 4.0

if not ctld or not ctld.utils then
    return "[CSP] ABORT: CTLD not initialized"
end

local caps = CTLDConfig.get().settings.capabilitiesByType
local entry = caps and caps[TYPE]
if not entry then
    return "[CSP] ABORT: no capabilitiesByType entry for " .. TYPE
end

if SECTOR ~= nil then entry.crateSpawnSector = SECTOR end
entry.crateSpawnDistance = DISTANCE

local plan = CTLDCrateManager.getInstance():getCrateSpawnPlan(TYPE)
local msg = plan
    and string.format("[CSP] %s: crates spawn %s at %.2f m from the centre", TYPE, plan.sector, plan.distance)
    or  ("[CSP] " .. TYPE .. ": no plan, the default rule applies")
env.info(msg)
trigger.action.outText(msg, 10)
return msg
