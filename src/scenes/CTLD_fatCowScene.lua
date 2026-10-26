---@diagnostic disable
-- CTLD_fatCowScene.lua
-- Fat Cow FARP scene — what a landed CH-47 "Fat Cow" lays out to refuel and rearm helicopters.
--
-- Measured in DCS 2.9.30.28738 (FEAT-FAT-COW ticket 01): a runtime Invisible FARP has a warehouse
-- and serves a player already in game, but only with a supplier in range, and the FARP Fuel Depot
-- static alone supplies both fuel and weapons. So: no vehicle, no tent, no ammo dump.
--
-- Layout (offsets from the cow, which is the trigger unit):
--   Invisible FARP   — at the cow (distance 0): the airbase whose warehouse holds the cow's stock
--   FARP Fuel Depot  — 25 m behind the ramp (180°): the supplier
--   Ammo crates      — 15 m / 160° and 15 m / 200°: dressing (never loadable: "CTLD_" name prefix)
--   Barrels          — 18 m / 145°: dressing
--   3 infantry       — 20 m / 215°, standing by
--   Warehouse        — set to the cow's stock (ctx.scene._params.fatCow) once laid out
--
-- The scene is played by CTLDFatCowManager, never requested as a crate: it has no `crate` field.
-- Dependencies: CTLDObjectRegistry, CTLDSceneManager, CTLDFatCowManager
-- ====================================================================================================

local fatCowScene = {}
fatCowScene.name  = "Fat Cow FARP"

fatCowScene.steps = {

    -- Step 1: the Invisible FARP at the cow. Its name is what the warehouse is looked up by.
    {
        polar                    = { distance = 0, angle = 0 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_FARP",
        critical                 = true,
        func = function(ctx)
            ctx.scene._params.farpName = ctx.spawnedObj:getName()
            return true
        end,
    },

    -- Step 2: the fuel depot behind the ramp — the only supplier the FARP needs.
    {
        polar                    = { distance = 25, angle = 180 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Fuel_Depot",
        critical                 = true,
    },

    -- Steps 3-5: dressing.
    {
        polar                    = { distance = 15, angle = 160 },
        delayAfterPreviousStep   = 2,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Ammo",
    },
    {
        polar                    = { distance = 15, angle = 200 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 30,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Ammo",
    },
    {
        polar                    = { distance = 18, angle = 145 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Barrels",
    },

    -- Step 6: the crew standing by.
    {
        polar                    = { distance = 20, angle = 215 },
        delayAfterPreviousStep   = 0,
        relativeHeadingInDegrees = 0,
        relativeAltitudeInMeters = 0,
        registryKey              = "FatCow_Crew",
    },

    -- Step 7: stock the warehouse and tell the manager the FARP is open.
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

CTLDObjectRegistry.registerIfAbsent("FatCow_FARP", {
    groupType            = "STATIC",
    namePrefix           = "FatCow_FARP",
    type                 = "Invisible FARP",
    shape_name           = "invisiblefarp",
    category             = "Heliports",
    heliport_frequency   = "127.5",
    heliport_callsign_id = 1,
    heliport_modulation  = 0,
    rate                 = 100,
})

-- Dressing cargo statics. The "CTLD_" prefix keeps CTLDCrateManager:onBirth from registering them as
-- loadable crates (it registers every other cargo static that appears).
CTLDObjectRegistry.registerIfAbsent("FatCow_Ammo", {
    groupType  = "STATIC",
    namePrefix = "CTLD_FatCow_Ammo",
    type       = "ammo_cargo",
    category   = "Cargos",
    shape_name = "ammo_box_cargo",
    rate       = 1,
})

CTLDObjectRegistry.registerIfAbsent("FatCow_Barrels", {
    groupType  = "STATIC",
    namePrefix = "CTLD_FatCow_Barrels",
    type       = "barrels_cargo",
    category   = "Cargos",
    shape_name = "barrels_cargo",
    rate       = 100,
})

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
