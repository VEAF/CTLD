-- ============================================================
-- CTLD_userConfig.lua
-- User configuration — load BEFORE CTLD.lua in the mission.
--
-- HOW TO USE
--   In the Mission Editor, add a trigger "MISSION START → DO SCRIPT FILE"
--   and select this file BEFORE the CTLD.lua trigger.
--   This file is optional: if omitted, CTLD starts with factory defaults.
--
-- All values below are the factory defaults.
-- Uncomment and edit only the lines you want to change.
-- ============================================================

if ctld == nil then ctld = {} end

-- ============================================================
-- SECTION 1 — SCALAR PARAMETERS (bool / number / string)
-- Comment / uncomment individual lines to override defaults.
-- ============================================================
ctld.yamlConfigDatas = [[

# ============================================================
# General
# ============================================================

# Enable verbose debug logging to CTLD.log.
# Requires a non-sanitized DCS installation (io + lfs must be available).
# Leave false in production missions.
# ctld.debug: false

# Override the log file path (CTLD.log location).
# Leave empty to use the default DCS Saved Games folder.
# ctld.ctldLogPath:

# Show coordinates as Degrees-Minutes-Seconds (DMS) instead of Degrees-Decimal-Minutes.
# ctld.location_DMS: false

# Suppress all smoke at pickup / drop-off zones, regardless of per-zone settings.
# ctld.disableAllSmoke: false


# ============================================================
# Logistics
# ============================================================

# Maximum distance (m) between the transport and a logistic zone to allow crate
# spawning or loading operations.
# ctld.maximumDistanceLogistic: 200

# Radius (m) of the logistic zone created around each LGZ_ trigger zone (dynamic logistic zones).
# ctld.dynamicZoneRadius: 200

# Interval (s) between successive smoke signal refreshes at logistic / troop zones.
# ctld.smokeRefreshInterval: 300


# ============================================================
# Crates
# ============================================================

# Master switch — set to false to disable the entire crate system.
# ctld.enableCrates: true

# Show "All crates" shortcut entries in the F10 menu (spawns every component of a
# multi-crate system at once).
# ctld.enableAllCrates: true

# Enable hover-based slingload pickup (pilot must hover above a crate at the correct
# altitude).  Set to false to allow loading via the F10 menu only.
# ctld.enableHoverSlingload: true

# Allow crate loading via the F10 menu in addition to hover.  Useful when flying
# fixed-wing aircraft that cannot hover.
# ctld.loadCrateFromMenu: true

# Enable the "Drop Smoke" F10 menu entry.
# ctld.enableSmokeDrop: true

# Enable DCS native slingload weight simulation.
# WARNING: some DCS versions crash with slingload enabled — if crashes occur set this
# to false and rely on the virtual hover system instead.
# ctld.slingLoad: false

# Maximum horizontal speed (m/s) allowed while carrying a virtual slingloaded crate.
# Exceeding this speed causes the crate to detach and fall.
# ctld.maxSlingloadSpeed: 50

# Spacing (m) between consecutive crate spawn positions along the spawn axis.
# ctld.crateSpacing: 5

# Extra radius (m) added to the transport's safe-radius when placing troops/crates in a circle.
# ctld.spawnDistanceInCircle: 10



# ============================================================
# Hover parameters (virtual slingload pickup)
# ============================================================

# Minimum AGL height (m) required to initiate a hover pickup.
# ctld.minimumHoverHeight: 7.5

# Maximum AGL height (m) at which a hover pickup is still valid.
# ctld.maximumHoverHeight: 12.0

# Maximum horizontal distance (m) between the transport and the crate centre
# for a hover pickup to count.
# ctld.maxDistanceFromCrate: 5.5

# Time (s) the pilot must maintain a valid hover before the crate is loaded.
# ctld.hoverTime: 10


# ============================================================
# Troops
# ============================================================

# Default number of troops loaded per transport (also acts as maximum group size
# unless overridden per aircraft type in capabilitiesByType[type].maxTroopsOnboard).
# ctld.numberOfTroops: 10

# Maximum total troop weight (kg) a transport can carry.
# 0 = no weight limit (default).  When > 0, groups whose total weight would exceed
# the limit cannot be loaded.
# ctld.maxTransportWeight: 0

# Maximum distance (m) from the transport to a troop group to allow extraction.
# ctld.maxExtractDistance: 125

# Maximum distance (m) deployed troops will search for an enemy unit.
# ctld.maximumSearchDistance: 3000


# Allow pilots to insert troops via fast-rope.
# ctld.enableFastRopeInsertion: true

# Maximum safe AGL height (m) for fast-rope (not rappel) insertion — 60 ft default.
# ctld.fastRopeMaximumHeight: 18.28

# Allow AI transports to randomly pick up infantry teams at pickup zones.
# ctld.allowRandomAiTeamPickups: false


# ============================================================
# Infantry weight simulation
# Each soldier's weight is randomised between 90 % and 120 % of SOLDIER_WEIGHT,
# then the kit and role-specific equipment weights are added on top.
# These values affect whether a group fits inside a transport (maxTroopsOnboard).
# ============================================================

# Base body weight per soldier (kg) before randomisation.
# ctld.SOLDIER_WEIGHT: 80

# Helmet + backpack weight per soldier (kg).
# ctld.KIT_WEIGHT: 20

# Standard infantry rifle kit weight (kg).
# ctld.RIFLE_WEIGHT: 5

# AA soldier MANPAD tube weight (kg).
# ctld.MANPAD_WEIGHT: 18

# AT soldier RPG launcher + rocket weight (kg).
# ctld.RPG_WEIGHT: 7.6

# Machine-gunner weapon + 200-round belt weight (kg).
# ctld.MG_WEIGHT: 10

# Mortar servant tube + shells weight (kg).
# ctld.MORTAR_WEIGHT: 26

# JTAC laser designator + radio + binoculars weight (kg).
# ctld.JTAC_WEIGHT: 15

# Civilian role personal items weight (kg).
# ctld.CIV_WEIGHT: 2


# ============================================================
# FOB (Forward Operating Base)
# ============================================================

# Enable FOB building from crates.
# ctld.enabledFOBBuilding: true

# Allow troops to be picked up at a deployed FOB.
# ctld.troopPickupAtFOB: true

# Minimum distance (m) from any existing logistic zone at which a FOB may be deployed.
# ctld.fobMinDistanceFromZones: 500

# Radius (m) of the logistic zone created around a deployed FOB.
# ctld.fobLogisticZoneRadius: 150

# Fraction of scene objects that must be destroyed before the FOB is considered lost.
# 0.0 = lost if anything is destroyed ; 1.0 = lost only when everything is destroyed.
# ctld.fobDestructionThreshold: 0.5

# Radius (m) within which troops can board a transport at a FOB.
# ctld.fobTroopPickupRadius: 150

# Allow players to pack a deployed FARP back into crates for redeployment elsewhere.
# ctld.enableFARPRepack: true


# ============================================================
# Parachute — virtual parachute drop (Feature A)
# ============================================================

# Minimum AGL altitude (m) required to initiate a parachute drop for crates.
# ctld.parachuteMinAltitudeCrates: 152

# Minimum AGL altitude (m) required to initiate a parachute drop for troops.
# ctld.parachuteMinAltitudeTroops: 152

# Minimum AGL altitude (m) required to initiate a parachute drop for vehicles.
# ctld.parachuteMinAltitudeVehicles: 152

# Vertical descent speed (m/s) for parachuted crates (slower = more accurate landing).
# ctld.parachuteDescentRateCrates: 5

# Vertical descent speed (m/s) for parachuted troops.
# ctld.parachuteDescentRateTroops: 5

# Vertical descent speed (m/s) for parachuted vehicles (heavier loads fall faster).
# ctld.parachuteDescentRateVehicles: 8

# Forward drift factor : fraction of the transport's current speed applied as
# forward inertia to each dropped unit (0.0 = no drift ; 1.0 = full speed drift).
# ctld.parachuteInertiaFactor: 0.3

# Minimum random lateral drift (m) applied per unit during a parachute drop.
# ctld.parachuteLateralDriftMin: 10

# Maximum random lateral drift (m) applied per unit during a parachute drop.
# ctld.parachuteLateralDriftMax: 80

# Search radius (m) used when auto-unpacking parachuted crates after landing.
# Larger than the normal unpack radius to account for dispersion during descent.
# ctld.autoUnpackRadiusParachute: 1000


# ============================================================
# Beacons
# ============================================================

# Allow pilots to deploy radio beacons.
# ctld.enabledRadioBeaconDrop: true

# Battery life (minutes) of a deployed beacon before it stops transmitting.
# ctld.deployedBeaconBattery: 30

# Sound file used for FOB / beacon audio.  Must be added to the mission (.miz) file.
# ctld.radioSound: beacon.ogg

# Silent sound file used for FC3 aircraft so they do not hear all coalition beacons.
# ctld.radioSoundFC3: beaconsilent.ogg


# ============================================================
# AA systems (multi-crate assembly)
# ============================================================

# Default number of launchers added to an AA system when no amount is specified
# in its assembly template.
# ctld.aaLaunchers: 3

# Maximum number of fully functional AA systems that RED / BLUE can have deployed
# simultaneously.  Players can still receive crates beyond the limit, but cannot
# unpack them until an existing system is destroyed.
# ctld.AASystemLimitRED: 20
# ctld.AASystemLimitBLUE: 20

# Enable crate stacking : bringing N times the required crates spawns N times the
# launchers.  Example : 2 × Patriot launcher crates → 2 launchers in the group.
# ctld.AASystemCrateStacking: false


# ============================================================
# JTAC
# ============================================================

# Maximum number of JTAC units that each side may have active at the same time.
# ctld.JTAC_LIMIT_RED: 10
# ctld.JTAC_LIMIT_BLUE: 10

# Allow pilots to spawn JTAC units from the F10 crate menu.
# ctld.JTAC_dropEnabled: true

# Maximum lasing distance (m) — targets beyond this range are ignored.
# ctld.JTAC_maxDistance: 10000

# Which ground unit types the JTAC will track and lase.
# "vehicle" — armoured vehicles only
# "troop"   — infantry only
# "all"     — any ground unit
# ctld.JTAC_lock: all

# Show the JTAC status entry in the F10 menu.
# ctld.JTAC_jtacStatusF10: true

# Include the target's coordinates in JTAC messages.
# ctld.JTAC_location: true

# Allow pilots to toggle a JTAC's lasing on and off (standby mode).
# ctld.JTAC_allowStandbyMode: true

# Enable laser-spot lead correction : the JTAC attempts to lead moving targets,
# accounting for wind and target speed.  Most useful against moving heavy armour.
# ctld.JTAC_laseSpotCorrections: true

# Allow pilots to request a smoke marker on the JTAC's current target.
# ctld.JTAC_allowSmokeRequest: true

# Allow pilots to request a 9-Line from a JTAC.
# ctld.JTAC_allow9Line: true

# Enable target smoke for RED JTACs.
# ctld.JTAC_smokeOn_RED: false

# Enable target smoke for BLUE JTACs.
# ctld.JTAC_smokeOn_BLUE: false

# Smoke colour used by RED JTACs.
# 0=Green  1=Red  2=White  3=Orange  4=Blue
# ctld.JTAC_smokeColour_RED: 4

# Smoke colour used by BLUE JTACs.
# 0=Green  1=Red  2=White  3=Orange  4=Blue
# ctld.JTAC_smokeColour_BLUE: 1

# Maximum allowed error radius (m) when placing smoke on a target.
# ctld.JTAC_smokeMarginOfError: 50

# Smoke position offsets from the exact target point (metres).
# _x = East offset ; _y = vertical offset (Up) ; _z = North offset.
# ctld.JTAC_smokeOffset_x: 0.0
# ctld.JTAC_smokeOffset_y: 2.0
# ctld.JTAC_smokeOffset_z: 0.0

# Reschedule delay (s) for the auto-lase loop when actively lasing a target.
# ctld.JTAC_laseIntervalSeconds: 15

# Reschedule delay (s) for the auto-lase loop when searching for a target.
# ctld.JTAC_searchIntervalSeconds: 10

# Orbit radius (m) used by drone JTAC units around their target.
# ctld.JTAC_droneRadius: 1000

# Orbit altitude (m) for drone JTAC units.
# ctld.JTAC_droneAltitude: 4000


# ============================================================
# Recon
# ============================================================

# Enable the RECON submenu in the F10 CTLD menu.
# ctld.reconF10Menu: true

# Master switch — set to true to activate RECON functionality.
# When false, the Scan Area command does nothing even if the menu is visible.
# ctld.reconEnabled: false

# LOS detection radius (m) around the scanning unit.
# All enemy units within this radius are tested for line-of-sight.
# ctld.reconSearchRadius: 5000

# Minimum AGL altitude (m) required to perform a scan.
# The pilot must be at or above this height, otherwise the scan is rejected.
# ctld.reconMinAltitude: 50

# Auto-refresh interval (s) between successive target position updates.
# Decrease to track fast-moving targets more accurately (increases CPU load).
# ctld.reconRefreshInterval: 10

# Icon size multiplier applied to all RECON icons on the F10 map.
# 1.0 = default sizes (infantry=30m, vehicle=40m, aa=35m, aircraft=40m,
#        helicopter=25m, ship=50×20m).  Use 2.0 to double all icon sizes.
# ctld.reconIconScale: 1.0


# ============================================================
# Minefield
# ============================================================

# Draw a bounding quad on the F10 map when a minefield is deployed.
# ctld.showMinefieldOnF10Map: true


# ============================================================
# Vehicles / pack
# ============================================================

# Allow pilots to pack nearby vehicles into crates using the F10 menu.
# ctld.enablePackingVehicles: true

# Maximum distance (m) from the transport in which packable vehicles are searched.
# ctld.maximumDistancePackableUnitsSearch: 200

]]

-- ============================================================
-- SECTION 2 — COMPLEX CONFIGURATION (crates, troops, zones, capabilities)
--
-- Section 1 above covers scalar parameters. The complex tables are customised
-- here by registering one or more *setup callbacks* in ctld.userSetup. CTLD runs
-- every callback once during initialization, AFTER the factory defaults and the
-- auto-injected AA-system crates are in place — so you patch the real, complete
-- catalogue surgically instead of copy-pasting and owning it wholesale.
--
--   ctld.userSetup = ctld.userSetup or {}
--   table.insert(ctld.userSetup, function(cfg)
--       -- your operations go here (see the helpers below)
--   end)
--
-- Helper functions (call them from inside a callback):
--   ctld.addCrate(section, entry)   add a crate to a spawnableCrates sub-menu
--   ctld.removeCrate(weight)        remove a crate by its unique weight
--   ctld.patchCrate(weight, patch)  change fields of a crate (deep-merge 1 level)
--   ctld.addTroopGroup(entry)       add a loadable infantry group template
--   ctld.removeTroopGroup(name)     remove a loadable group by name
--   ctld.addTo(setting, entry)      append to an array setting (list below)
--   ctld.logDefaults(setting)       dump a setting's current value to CTLD.log
--
-- A duplicate crate weight on addCrate is rejected with an on-screen warning
-- (weights MUST stay unique — they are the crate lookup key). Removing/patching
-- an unknown weight logs a warning and does nothing; other callbacks still run.
--
-- Tables WITHOUT a helper are plain dictionaries — edit them directly on cfg:
--   capabilitiesByType, aiZones, spawnableCratesModels, troopZoneSmokeColor,
--   nbLimitSpawnedTroops, groundVehicleWeights, modTypes, addPlayerAircraftByType.
--
-- DISCOVER THE REAL DEFAULTS AT RUNTIME
--   This file is optional and by default changes nothing. To inspect a setting's
--   real current value, add a separate ME "DO SCRIPT" trigger a few seconds after
--   mission start containing, e.g.:
--       ctld.logDefaults("spawnableCrates")
--   It writes a copy-pasteable Lua representation to CTLD.log (requires debug=true).
-- ============================================================

-- Uncomment the block below and adapt the operations you need.
--
-- ctld.userSetup = ctld.userSetup or {}
-- table.insert(ctld.userSetup, function(cfg)
--
--     -- ── Crates (spawnableCrates) ───────────────────────────────────────────
--     -- Crate descriptor fields:
--     --   weight         (number) : unique kg value used as the lookup key — MUST be unique
--     --   desc           (string) : label shown in the F10 menu
--     --   unit           (string) : DCS unit type name spawned when the crate is unpacked
--     --   cratesRequired (number) : identical crates to assemble within 100 m (default 1)
--     --   side           (number) : 1 = RED only ; 2 = BLUE only ; omit = both coalitions
--     --   isJTAC         (bool)   : JTAC unit (hidden when JTAC_dropEnabled = false)
--     --   spawnAs        (string) : e.g. "AIRPLANE" for drone JTACs
--     --   specificParams (table)  : per-unit params, e.g. drone orbit
--     --                             { speed, alti, orbitRadiusNoLase, orbitRadiusOnLase }
--     -- Default sub-menus: "Combat Vehicles", "Support", "Artillery",
--     -- "SAM short range", "SAM mid range", "SAM long range", "Drone".
--
--     -- Add a custom crate to an existing sub-menu (created if absent):
--     ctld.addCrate("Support", { weight = 2000.01, desc = "Ural Ammo", unit = "Ural-375", side = 1, cratesRequired = 2 })
--
--     -- Remove a default crate by weight:
--     ctld.removeCrate(1000.05)   -- Heavy Tank - Abrams
--
--     -- Change one field of a default crate (all other fields preserved):
--     ctld.patchCrate(1000.02, { cratesRequired = 3 })   -- Humvee - TOW
--
--     -- Patch a single nested field (deep-merge: siblings speed/orbit* preserved):
--     ctld.patchCrate(1006.01, { specificParams = { alti = 5000 } })   -- MQ-9 drone
--
--     -- AA-system crates already exist here (auto-injected before this callback),
--     -- so you can add to or remove from their sections too:
--     ctld.addCrate("SAM mid range", { weight = 2004.01, desc = "Spare HAWK LN", unit = "Hawk ln", side = 2 })
--     ctld.removeCrate(1004.06)   -- HAWK Repair
--
--     -- ── Loadable troop groups (loadableGroups) ─────────────────────────────
--     -- Fields:
--     --   name   : label shown in the F10 "Troops" menu
--     --   inf    : standard riflemen        mg     : M249/PKM machine-gunners
--     --   at     : RPG anti-tank soldiers    aa     : Stinger/Igla MANPAD soldiers
--     --   mortar : 2B11 mortar crews         jtac   : JTAC soldiers (auto-lase)
--     --   side   : 1 = RED only ; 2 = BLUE only ; omit = both coalitions
--     ctld.addTroopGroup({ name = "Recon Team", inf = 3, jtac = 1 })
--     ctld.removeTroopGroup("5x Mortar Squad")
--
--     -- ── Array settings (append with ctld.addTo) ────────────────────────────
--     -- Valid array settings: transportPilotNames, troopZones, wpZones,
--     -- extractableGroups, logisticUnits.
--
--     -- transportPilotNames : ME unit name authorised to carry CTLD
--     ctld.addTo("transportPilotNames", "helicargo_custom_1")
--
--     -- troopZones : { "zone_or_ship_name", "smoke_color", limit, "active", side [, flag] }
--     --   smoke_color : "green"|"red"|"white"|"orange"|"blue"|"none"
--     --   limit       : -1 unlimited ; N max groups     active : "yes"|"no"
--     --   side        : 0 both ; 1 RED ; 2 BLUE          flag (optional) : DCS flag number
--     ctld.addTo("troopZones", { "pickzone_north", "green", -1, "yes", 0 })
--
--     -- wpZones : { "zone_name", "smoke_color", "active", side }  (AI routing waypoints)
--     ctld.addTo("wpZones", { "wpzone_a", "blue", "yes", 2 })
--
--     -- extractableGroups : DCS group name that a transport can extract
--     ctld.addTo("extractableGroups", "recon_team_1")
--
--     -- logisticUnits : unit name near which crate spawning is allowed
--     ctld.addTo("logisticUnits", "supply_depot_1")
--
--     -- ── Aircraft capabilities (capabilitiesByType — direct dict access) ─────
--     -- Only aircraft listed here get CTLD F10 menus. Fields:
--     --   cratesEnabled, troopsEnabled, canParachuteDrop, canSlingload,
--     --   canTransportWholeVehicle, useNativeDcsCargoSystem,
--     --   maxTroopsOnboard, maxCratesOnboard, maxWholeVehiclesOnboard,
--     --   loadableVehiclesRED / loadableVehiclesBLUE (lists of DCS type names)
--
--     -- Patch one capability without rewriting the whole entry:
--     cfg.settings["capabilitiesByType"]["Mi-8MT"].maxTroopsOnboard = 20
--
--     -- Add a new (e.g. mod) aircraft type:
--     cfg.settings["capabilitiesByType"]["UH-60L"] = {
--         cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = true,
--         canTransportWholeVehicle = false, useNativeDcsCargoSystem = false,
--         maxTroopsOnboard = 12, maxCratesOnboard = 2, maxWholeVehiclesOnboard = 0,
--     }
--
--     -- Restrict CTLD to named slots only (AI transports always use transportPilotNames):
--     cfg.settings["addPlayerAircraftByType"] = false
--
--     -- ── AI-only zones (Feature S — direct assignment) ──────────────────────
--     -- Each entry supports pickup and/or dropoff on the same DCS trigger zone.
--     -- Required: dcsZoneName, coalition ("RED"|"BLUE"|"NEUTRAL").
--     -- Pickup (isPickup=true): cargoType "T"|"V"|"TV" ; troopStock/vehicleStock
--     --   tables keyed by template/type name ({ ["Standard Group"]=5 }, -1=unlimited,
--     --   "All"=every template) ; troopTemplates / vehicleTypes whitelists.
--     -- Dropoff (isDropoff=true): aiDropMode "G"|"P"|"GP".
--     cfg.settings["aiZones"] = {
--         { dcsZoneName = "Depot_bleu", coalition = "BLUE", isPickup = true, cargoType = "T",
--           troopStock = { ["Standard Group"] = 5, ["Anti Tank"] = 2 } },
--         { dcsZoneName = "LZ_nord",    coalition = "BLUE", isDropoff = true, aiDropMode = "GP" },
--     }
--
--     -- ── Other dictionaries (direct access) ─────────────────────────────────
--     -- Cumulative troop spawn cap { redLimit, blueLimit } (0 = no limit):
--     cfg.settings["nbLimitSpawnedTroops"] = { 200, 200 }
--     -- Troop-zone smoke by coalition (1=RED,2=BLUE ; -1 none,0 green,1 red,2 white,3 orange,4 blue):
--     cfg.settings["troopZoneSmokeColor"] = { [1] = 1, [2] = 4 }
--     -- Vehicle weights (kg) for loadable-vehicle checks:
--     cfg.settings["groundVehicleWeights"]["BRDM-2"] = 7000
--     -- Non-stock (mod) DCS type names your config uses (silences the asset-check companion):
--     cfg.settings["modTypes"] = { "Some_Mod_Type" }
--
--     -- ── Crate 3D model templates (spawnableCratesModels — direct access) ────
--     -- Slots: "load" (hover/menu), "sling" (ctld.slingLoad=true), "dynamic"
--     -- (dynamicCargoUnits). Each: { category, type [, shape_name], canCargo }.
--     -- canCargo=false for "load", true for "sling"/"dynamic".
--     -- cfg.settings["spawnableCratesModels"]["load"].type = "ammo_cargo"
--
-- end)
