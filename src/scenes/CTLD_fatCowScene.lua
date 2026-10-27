---@diagnostic disable
-- CTLD_fatCowScene.lua
-- Fat Cow FARP scene — what a landed CH-47 "Fat Cow" lays out to refuel and rearm helicopters.
--
-- Measured in DCS 2.9.30.28738 (FEAT-FAT-COW ticket 01): a runtime Invisible FARP has a warehouse
-- and serves a player already in game, but only with a supplier in range, and the FARP Fuel Depot
-- static alone supplies both fuel and weapons. So: no vehicle, no tent, no ammo dump.
--
-- Layout (offsets from the cow, which is the trigger unit):
--   Invisible FARP   — at the cow (distance 0): the airbase whose warehouse holds the cow's stock;
--                      one per cow, added again at each deployment, never destroyed
--   FARP Fuel Depot  — 25 m behind the ramp (180°): the supplier
--   Ammo crates      — 20 m / 135° and 20 m / 130°: dressing (never loadable: "CTLD_" name prefix)
--   Barrels          — 21 m / 124°: dressing
--   3 infantry       — 25 m / 225°, standing by (everything clear of the rear rotor)
--   Warehouse        — set to the cow's stock (ctx.scene._params.fatCow) once laid out
--
-- The scene is played by CTLDFatCowManager, never requested as a crate: it has no `crate` field.
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDFatCowManager
-- ====================================================================================================

local fatCowScene = {}
fatCowScene.name  = "Fat Cow FARP"

-- Dressing, behind the cow to its right, clear of the rear rotor (angles clockwise from its nose).
fatCowScene.DRESSING = {
    { tag = "Ammo",    type = "ammo_cargo",    shape_name = "ammo_box_cargo", distance = 20, angle = 135, heading = 0 },
    { tag = "Ammo",    type = "ammo_cargo",    shape_name = "ammo_box_cargo", distance = 20, angle = 130, heading = 30 },
    { tag = "Barrels", type = "barrels_cargo", shape_name = "barrels_cargo",  distance = 21, angle = 124, heading = 0 },
}

fatCowScene.steps = {

    -- Step 1: the Invisible FARP at the cow, under the cow's own FARP name (ctx.scene._params.farpName).
    -- Kept out of the scene's spawned objects, so packing never destroys it (evening run, 2026-10-26):
    -- a destroyed heliport stays on the F10 map, and the AI cow sitting on it blew up. The next
    -- deployment adds it again under the same name, at the new spot.
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            local sc = ctx.scene
            local farp = CTLDObjectRegistry.spawnObject("Invisible_FARP", sc._coalitionId, sc._countryId,
                sc._refX, sc._refZ, sc._refHdgRad, { name = sc._params.farpName })
            if not farp then
                sc:abort("Fat Cow FARP not spawned")
                CTLDFatCowManager.getInstance():onSceneFailed(sc)
            end
            return true
        end,
    },

    -- Step 2: the fuel depot behind the ramp — the only supplier the FARP needs. Not `critical`: the
    -- scene manager would abort without telling the cow, left deploying and its pilot told nothing.
    {
        polar                    = { distance = 25, angle = 180 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Fuel_Depot",
        func = function(ctx)
            if not ctx.spawnedObj then
                ctx.scene:abort("Fat Cow fuel depot not spawned")
                CTLDFatCowManager.getInstance():onSceneFailed(ctx.scene)
            end
            return true
        end,
    },

    -- Step 3: dressing — two ammo crates and a set of barrels. Spawned here rather than through the
    -- registry: their DCS types are already registry entries of their own, and the "CTLD_" name prefix
    -- keeps CTLDCrateManager:onBirth from registering them as loadable crates.
    {
        delayAfterPreviousStep = 2,
        func = function(ctx)
            local sc = ctx.scene
            for i, d in ipairs(fatCowScene.DRESSING) do
                local x, z, hdgDeg = ctld.utils.getRelativeCoords(sc._refX, sc._refZ, sc._refHdgRad, sc._refAlt,
                    d.angle, d.distance, d.heading, 0, sc._magDecDeg)
                local ok, obj = pcall(coalition.addStaticObject, sc._countryId, {
                    name = string.format("CTLD_FatCow_%s_%s_%d", d.tag, sc._name, i),
                    type = d.type, shape_name = d.shape_name, category = "Cargos",
                    x = x, y = z, heading = math.rad(hdgDeg), canCargo = false, dead = false,
                })
                if ok and obj then sc._spawnedObjs[#sc._spawnedObjs + 1] = obj end
            end
            return true
        end,
    },

    -- Step 4: the crew standing by.
    {
        polar                    = { distance = 25, angle = 225 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Crew",
    },

    -- Step 5: stock the warehouse and tell the manager the FARP is open.
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            CTLDFatCowManager.getInstance():onSceneLaidOut(ctx.scene)
            return true
        end,
    },
}

-- ====================================================================================================
-- Registry entries required by this scene (registerIfAbsent: shared keys are left as declared).
-- ====================================================================================================

-- Shape from DCS's db.Units.lua ("FARP Fuel Depot", ShapeName "GSM Rus").
CTLDObjectRegistry.registerIfAbsent("FatCow_Fuel_Depot", {
    groupType  = "STATIC",
    namePrefix = "FatCow_Fuel_Depot",
    type       = "FARP Fuel Depot",
    shape_name = "GSM Rus",
    category   = "Fortifications",
})

CTLDObjectRegistry.registerIfAbsent("FatCow_Crew", {
    groupType  = "GROUND",
    namePrefix = "FatCow_Crew_Grp",
    task       = "Ground Nothing",
    category   = Unit.Category.GROUND_UNIT,
    units = {
        {
            namePrefix     = "FatCow_Crew",
            unitType       = function(cid) return cid == coalition.side.RED and "Infantry AK" or "Soldier M4" end,
            playerCanDrive = false,
            dx = 0, dz = 0, dh = 0,
        },
        {
            namePrefix     = "FatCow_Crew",
            unitType       = function(cid) return cid == coalition.side.RED and "Infantry AK" or "Soldier M4" end,
            playerCanDrive = false,
            dx = 2, dz = 1, dh = 0,
        },
        {
            namePrefix     = "FatCow_Crew",
            unitType       = function(cid) return cid == coalition.side.RED and "Infantry AK" or "Soldier M4" end,
            playerCanDrive = false,
            dx = -1, dz = 2, dh = 0,
        },
    },
})

-- ====================================================================================================
-- Self-registration
-- ====================================================================================================

CTLDSceneManager.getInstance():registerSceneModel(fatCowScene)
