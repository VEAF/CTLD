---@diagnostic disable
-- tests/ci/unit/scene_validator_spec.lua
-- busted specs for the scene manager's remaining runtime guards:
--   CTLDSceneManager:isSceneEnabled()          (registered-or-not)
--   step.critical abort                         (scene execution)
--
-- The runtime scene mod-validation pipeline (_auditAfterModValidator, model._disabled,
-- _purgeDisabledScenes, requiresMod WARN) was removed: scene DCS types are now validated at
-- design time by the busted asset hard-gate (see scene_asset_gate_spec.lua and ADR 0007).
-- ============================================================

local function makeUnit()
    return {
        getName      = function(_) return "test_unit" end,
        getPoint     = function(_) return { x = 0, y = 5, z = 0 } end,
        getPosition  = function(_)
            return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } }
        end,
        getCoalition = function(_) return coalition.side.BLUE end,
        getCountry   = function(_) return 2 end,
        isExist      = function(_) return true end,
    }
end

-- ─────────────────────────────────────────────────────────────
-- U-121 — isSceneEnabled()
-- ─────────────────────────────────────────────────────────────
describe("U-121 — isSceneEnabled()", function()

    local sm

    before_each(function()
        sm = CTLDSceneManager.getInstance()
    end)

    it("C1: returns true for a registered scene", function()
        local model = { name = "EnabledScene_U121",
                        steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)
        assert.is_true(sm:isSceneEnabled("EnabledScene_U121"))
    end)

    it("C2: returns false for an unknown scene name", function()
        assert.is_false(sm:isSceneEnabled("NoSuchScene_XYZ"))
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-125 — step.critical abort
-- ─────────────────────────────────────────────────────────────
describe("U-125 — step.critical: abort when spawn returns nil", function()

    local sm, unit

    before_each(function()
        sm   = CTLDSceneManager.getInstance()
        unit = makeUnit()
    end)

    it("C1: critical step with nil spawn → scene._aborted = true, subsequent steps skipped", function()
        local step2Executed = false

        local model = {
            name  = "CriticalAbortScene",
            steps = {
                {
                    -- registryKey points to a non-existent registry entry → spawnObject returns nil
                    registryKey            = "__nonexistent_registry_key_xyz__",
                    polar                  = { distance = 10, angle = 0 },
                    delayAfterPreviousStep = 0,
                    critical               = true,
                    relativeHeadingInDegrees = 0,
                    relativeAltitudeInMeters = 0,
                },
                {
                    delayAfterPreviousStep = 0,
                    func = function() step2Executed = true end,
                },
            },
        }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "CriticalAbortScene", {}, nil)

        assert.is_not_nil(scene)
        assert.is_true(scene._aborted)
        assert.is_false(step2Executed)
    end)

    it("C2: non-critical step with nil spawn → scene continues, subsequent steps run", function()
        local step2Executed = false

        local model = {
            name  = "NonCriticalScene",
            steps = {
                {
                    registryKey            = "__nonexistent_registry_key_xyz__",
                    polar                  = { distance = 10, angle = 0 },
                    delayAfterPreviousStep = 0,
                    -- critical = false (default, field absent)
                    relativeHeadingInDegrees = 0,
                    relativeAltitudeInMeters = 0,
                },
                {
                    delayAfterPreviousStep = 0,
                    func = function() step2Executed = true end,
                },
            },
        }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "NonCriticalScene", {}, nil)

        assert.is_not_nil(scene)
        assert.is_false(scene._aborted)
        assert.is_true(step2Executed)
    end)

    it("C3: critical step with successful spawn → scene continues normally", function()
        local step2Executed = false
        -- Stub spawnObject to return a non-nil object for a specific key
        local origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function(key, ...)
            if key == "__mock_ok_spawn__" then
                return { isExist = function() return true end, getName = function() return "mock" end }
            end
            return nil
        end

        local model = {
            name  = "CriticalSuccessScene",
            steps = {
                {
                    registryKey            = "__mock_ok_spawn__",
                    polar                  = { distance = 10, angle = 0 },
                    delayAfterPreviousStep = 0,
                    critical               = true,
                    relativeHeadingInDegrees = 0,
                    relativeAltitudeInMeters = 0,
                },
                {
                    delayAfterPreviousStep = 0,
                    func = function() step2Executed = true end,
                },
            },
        }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "CriticalSuccessScene", {}, nil)

        CTLDObjectRegistry.spawnObject = origSpawn  -- restore

        assert.is_not_nil(scene)
        assert.is_false(scene._aborted)
        assert.is_true(step2Executed)
    end)

end)
