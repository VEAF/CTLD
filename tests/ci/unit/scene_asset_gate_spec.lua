---@diagnostic disable
-- tests/ci/unit/scene_asset_gate_spec.lua
-- Design-time hard-gate for scene assets (ADR 0007).
--
-- Every DCS type a scene spawns must be a known stock type (tests/data/dcs_types.lua) OR a
-- declared non-stock type (scene model `modTypes`). Unknown → FAIL. Unlike config_types_lint_spec
-- (lenient), this gate is strict.
--
-- modTypes is ADDITIVE to the known set (known = datamine ∪ ⋃ modTypes): every other type in the
-- same descriptor is still validated, so a typo in a stock type is still caught even when the
-- descriptor also uses a whitelisted mod type.
--
-- Robustness: the CTLDSceneManager / CTLDObjectRegistry singletons persist and are shared across
-- the whole busted process, and other specs inject synthetic descriptors/models into them. So we
-- do NOT scan the global registry. Instead we capture — via spies during scene load — exactly the
-- descriptors and models the six built-in scene files contribute, and validate only those.
--
-- Two sources of a scene's spawned types (both scene-attributed):
--   1. descriptors the scene registers itself (registerIfAbsent) — e.g. minefield's func spawns
--      "Landmine", which it registers but never references via a step.registryKey;
--   2. registry keys the scene references from its steps without redeclaring — e.g. farpScene
--      uses core-registered SINGLE_HELIPAD / FARP_Tent / … purely via step.registryKey.
--
-- Authored to be copied ~as-is into CTLD_plugins (adjust SCENE_FILES to the plugin's scenes).
-- Ticket: .backlog/SCENE-PLUGINS/tickets/02-scene-asset-hard-gate.md
-- ============================================================

local ROOT = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]ci[\\/]unit[\\/]") or ""

local SCENE_FILES = {
    "CTLD_farpScene", "CTLD_fobScene", "CTLD_mineFieldScene",
    "CTLD_countrysideFarpScene", "CTLD_farpAlphaScene",
}

-- DCS type names a registry descriptor spawns — via the shared collector, which handles both
-- STATIC (desc.type) and GROUND (desc.units[i].unitType(coalitionId), a per-coalition function).
local function spawnedTypesOf(desc)
    return CTLDTypeCollector.typesOfDescriptor(desc)
end

-- "descriptorLabel: type" pairs whose type is not in `known`.
local function unknownTypes(descsByLabel, known)
    local bad = {}
    for label, desc in pairs(descsByLabel) do
        for _, ty in ipairs(spawnedTypesOf(desc)) do
            if not known[ty] then bad[#bad + 1] = tostring(label) .. ": " .. tostring(ty) end
        end
    end
    return bad
end

describe("scene asset hard-gate", function()

    local myModels     -- the built-in scene models (captured, not the polluted _models)
    local sceneDescs   -- label → descriptor, contributed by the scenes (both sources)
    local known        -- datamine ∪ ⋃ scene.modTypes

    setup(function()
        ctld.i18n = ctld.i18n or {}
        for _, lang in ipairs({ "en", "fr", "es", "ko" }) do
            ctld.i18n[lang] = ctld.i18n[lang] or {}
        end

        local reg = CTLDObjectRegistry
        local sm  = CTLDSceneManager.getInstance()

        -- Spy registerIfAbsent (source 1: scene-owned descriptors, captured even on no-op) and
        -- registerSceneModel (capture exactly our models).
        local origReg = reg.registerIfAbsent
        local origMdl = sm.registerSceneModel
        local capturedDescs  = {}
        myModels = {}
        reg.registerIfAbsent = function(key, desc)
            capturedDescs[tostring(key)] = desc
            return origReg(key, desc)
        end
        sm.registerSceneModel = function(self, model)
            if type(model) == "table" then myModels[#myModels + 1] = model end
            return origMdl(self, model)
        end

        local ok, err = pcall(function()
            for _, name in ipairs(SCENE_FILES) do
                dofile(ROOT .. "src/scenes/" .. name .. ".lua")
            end
        end)

        reg.registerIfAbsent   = origReg
        sm.registerSceneModel  = origMdl
        assert(ok, "scene file load failed: " .. tostring(err))

        -- Merge both type sources into one label→descriptor map.
        sceneDescs = {}
        for label, desc in pairs(capturedDescs) do
            sceneDescs["reg:" .. label] = desc
        end
        -- Source 2: step registryKeys referenced without redeclaration (resolve specific keys only).
        for _, model in ipairs(myModels) do
            for i, step in ipairs(model.steps or {}) do
                if step.registryKey then
                    local d = reg._db[step.registryKey]
                    if d then sceneDescs["step:" .. model.name .. "#" .. i] = d end
                end
            end
        end

        -- Known set = stock types ∪ every captured model's declared non-stock types.
        known = {}
        local stock = dofile(ROOT .. "tests/data/dcs_types.lua")
        for t in pairs(stock) do known[t] = true end
        for _, model in ipairs(myModels) do
            if type(model.modTypes) == "table" then
                for _, t in ipairs(model.modTypes) do known[t] = true end
            end
        end
    end)

    it("all built-in scene files register a model", function()
        assert.equals(#SCENE_FILES, #myModels)
    end)

    it("every type the built-in scenes spawn is stock or declared (no unknowns)", function()
        local bad = unknownTypes(sceneDescs, known)
        assert.equals(0, #bad,
            "unknown DCS type(s) — add to datamine or a scene's modTypes:\n  " ..
            table.concat(bad, "\n  "))
    end)

    it("the gate bites: an undeclared bogus type fails", function()
        local fake = { bogus = { groupType = "STATIC", type = "NOT_A_REAL_DCS_TYPE_XYZ" } }
        assert.equals(1, #unknownTypes(fake, known))
    end)

    it("modTypes rescues a declared mod type (additive to known)", function()
        local fake = { modish = { groupType = "STATIC", type = "SOME_MOD_TYPE" } }
        assert.equals(0, #unknownTypes(fake, { SOME_MOD_TYPE = true }))
    end)

    it("GROUND sibling types are still validated when one is whitelisted", function()
        -- A group using a whitelisted mod type AND a bogus stock typo → the typo must still fail.
        local fake = { grp = { groupType = "GROUND", units = {
            { type = "SOME_MOD_TYPE" }, { type = "TYPO_NOT_STOCK" },
        } } }
        local bad = unknownTypes(fake, { SOME_MOD_TYPE = true })
        assert.equals(1, #bad)
        assert.equals("grp: TYPO_NOT_STOCK", bad[1])
    end)

end)
