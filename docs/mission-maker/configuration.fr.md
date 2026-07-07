# Configuration

CTLD est livré avec des valeurs par défaut sensées pour chaque paramètre. Vous n'éditez jamais
les fichiers source : toute la personnalisation vit dans un unique fichier,
**`CTLD_userConfig.lua`**, que votre mission charge via un trigger `DO SCRIPT FILE`. Vous ne
surchargez que ce que vous voulez modifier — tout ce que vous laissez tel quel conserve sa
valeur par défaut.

Cette page couvre les **réglages globaux** et les **capacités par appareil**
(`capabilitiesByType`). Les listes de zones, les définitions de crate, les scènes FOB, le
minefield et les traductions ont chacun leur propre page — voir [Où le reste se configure](#ou-le-reste-se-configure).

## Comment fonctionne la configuration

Au démarrage, `CTLDConfig` remplit chaque paramètre avec sa valeur par défaut. Votre
`CTLD_userConfig.lua` applique ensuite vos surcharges par-dessus. Tout au long de la mission en
cours, chaque paramètre est lu via un unique accesseur :

```lua
ctld.gs("parameterName")   -- the only authorised read form
```

### Ordre de chargement dans le Mission Editor

Ajoutez deux triggers `DO SCRIPT FILE` au **MISSION START**, dans cet ordre :

| Ordre | Action | Fichier |
|---|---|---|
| 1 | DO SCRIPT FILE | `CTLD.lua` |
| 2 | DO SCRIPT FILE | `CTLD_userConfig.lua` |

`CTLD.lua` définit le framework ; `CTLD_userConfig.lua` applique vos surcharges puis démarre
automatiquement CTLD. (Si vous devez exécuter une configuration supplémentaire entre le
chargement et le démarrage, positionnez `ctld.dontInitialize = true` avant le chargement de
`CTLD.lua` et appelez `ctld.initialize()` vous-même.)

### Deux façons de surcharger

Les **scalaires** (booléens, nombres, chaînes) vont dans le bloc `ctld.yamlConfigDatas`, une
ligne `ctld.parameterName: value` par valeur :

```lua
-- CTLD_userConfig.lua — only override what differs from the defaults.
ctld = ctld or {}
ctld.yamlConfigDatas = [[

ctld.enablePackingVehicles: true
ctld.maximumDistancePackableUnitsSearch: 350
ctld.numberOfTroops: 8
ctld.maximumDistanceLogistic: 300
ctld.slingLoad: true

]]
```

Les **tables** (capacités d'appareils, listes de zones, catalogues de crate…) sont affectées
directement sur l'instance de configuration. Chaque table que vous affectez **remplace**
entièrement sa valeur par défaut :

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["capabilitiesByType"] = { --[[ ... ]] }
```

## Réglages globaux

### Système

| Paramètre | Défaut | Description |
|---|---|---|
| `debug` | `false` | Journalisation verbeuse vers `CTLD.log` (nécessite une installation DCS non sanitized) |
| `ctldLogPath` | `""` | Surcharge le chemin du fichier de log ; vide = dossier Saved Games DCS par défaut |
| `debugScreenLog` | `false` | Répète aussi les messages de log à l'écran DCS via `outText` |
| `location_DMS` | `false` | Affiche les coordonnées en Degrés-Minutes-Secondes au lieu de Degrés-Minutes-Décimales |
| `disableAllSmoke` | `false` | Désactive globalement toute la smoke aux zones de pickup et de drop-off |

### Crates & slingload

| Paramètre | Défaut | Description |
|---|---|---|
| `enableCrates` | `true` | Interrupteur maître pour le spawn et le déballage des crate |
| `enableAllCrates` | `true` | Affiche les entrées raccourci « All crates » dans les menus Request Equipment. Mettre à `false` pour ne conserver que les entrées de crate individuelles |
| `slingLoad` | `false` | Utilise la physique sling-load de DCS au lieu du système virtuel de hover |
| `enableHoverSlingload` | `true` | Autorise le chargement de crate en hover au-dessus. Si `false`, les crate ne se chargent que via le menu F10 (`loadCrateFromMenu`) |
| `loadCrateFromMenu` | `true` | Autorise le chargement de crate via le menu F10 (utile pour les fixed-wing incapables de hover) |
| `enableSmokeDrop` | `true` | Active l'entrée F10 « Drop Smoke » |

### Distances (mètres)

| Paramètre | Défaut | Description |
|---|---|---|
| `maximumDistanceLogistic` | `200` | Distance max depuis une zone logistique pour charger ou spawn une crate |
| `maxExtractDistance` | `125` | Distance max entre le véhicule et les troops pour l'extraction |
| `maximumSearchDistance` | `3000` | Distance max pour que les troops IA déployées cherchent des ennemis |
| `maximumDistancePackableUnitsSearch` | `200` | Distance max pour chercher des véhicules pack-ables |

### Troops

| Paramètre | Défaut | Description |
|---|---|---|
| `numberOfTroops` | `10` | Taille de groupe de troops par défaut / max par transport (surchargée par appareil via `maxTroopsOnboard`) |
| `enableFastRopeInsertion` | `true` | Autorise le déploiement en fast-rope |
| `fastRopeMaximumHeight` | `18.28` | Hauteur max (m) pour l'insertion fast-rope (≈ 60 ft) |
| `allowRandomAiTeamPickups` | `false` | Autorise les transports IA à choisir aléatoirement un template de troop aux zones de pickup. Si `false`, l'IA prend toujours le premier template disponible pour sa coalition |
| `nbLimitSpawnedTroops` | `{0, 0}` | Plafond cumulé de troops par coalition `{RED, BLUE}` — `0` = illimité (table Lua) |

### Simulation du poids de l'infanterie

CTLD estime le poids de chaque groupe de troops pour vérifier s'il tient dans un transport (voir
`capabilitiesByType[type].maxTroopsOnboard` et les poids de véhicules). Chaque soldat pèse un
aléatoire de 90–120 % de `SOLDIER_WEIGHT`, plus l'équipement et le matériel propre au rôle.

| Paramètre | Défaut | Description |
|---|---|---|
| `SOLDIER_WEIGHT` | `80` | Poids corporel de base par soldat (kg) |
| `KIT_WEIGHT` | `20` | Casque + sac à dos par soldat (kg) |
| `RIFLE_WEIGHT` | `5` | Équipement standard de fusilier (kg) |
| `MANPAD_WEIGHT` | `18` | Tube MANPAD du soldat AA (kg) |
| `RPG_WEIGHT` | `7.6` | RPG + roquette du soldat AT (kg) |
| `MG_WEIGHT` | `10` | Arme du mitrailleur + bande de 200 cartouches (kg) |
| `MORTAR_WEIGHT` | `26` | Tube + obus de l'équipe de mortier (kg) |
| `JTAC_WEIGHT` | `15` | Laser + radio + jumelles du JTAC (kg) |
| `CIV_WEIGHT` | `2` | Effets personnels légers pour le rôle civil (kg) |

### FOB

| Paramètre | Défaut | Description |
|---|---|---|
| `enabledFOBBuilding` | `true` | Autorise la construction de FOB depuis des crate |
| `troopPickupAtFOB` | `true` | Autorise le pickup de troops aux FOB construits |
| `fobMinDistanceFromZones` | `500` | Distance minimale (m) de toute zone logistique à laquelle un FOB peut être déployé |
| `fobLogisticZoneRadius` | `150` | Rayon (m) de la zone logistique créée autour d'un FOB déployé |
| `fobTroopPickupRadius` | `150` | Rayon (m) dans lequel les troops peuvent embarquer à un FOB |
| `fobDestructionThreshold` | `0.5` | Fraction d'objets de scène détruits avant qu'un FOB soit considéré perdu (0.0–1.0) |
| `enableFARPRepack` | `true` | Autorise les joueurs à pack une scène FARP déployée de nouveau en crate pour redéploiement |

!!! note
    Le nombre de crate nécessaires pour construire un FOB n'est **pas** un réglage global — il
    provient du modèle de scène FOB (`cratesRequired`, défaut 3), collectées dans un rayon de
    750 m. Voir [Scenes & FOB](scenes-fob.md).

### Véhicules & packing

| Paramètre | Défaut | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Autorise le pack des véhicules de nouveau en crate |
| `groundVehicleWeights` | `{...}` | Poids (kg) par type DCS de véhicule, comparé au `maxVehicleWeight` de chaque appareil pour le transport de véhicule entier (table Lua) |
| `capabilitiesByType` | `{...}` | Table unifiée des capacités par appareil — voir [Capacités par appareil](#capacites-par-appareil) ci-dessous |

### Beacons

| Paramètre | Défaut | Description |
|---|---|---|
| `enabledRadioBeaconDrop` | `true` | Autorise le déploiement de beacon |
| `deployedBeaconBattery` | `30` | Durée de vie de la batterie du beacon (minutes) |
| `radioSound` | `"beacon.ogg"` | Fichier son du beacon — **doit** être ajouté au `.miz` de la mission, sinon les beacon ne fonctionneront pas |
| `radioSoundFC3` | `"beaconsilent.ogg"` | Fichier de beacon silencieux pour les appareils FC3 |

### Systèmes AA

| Paramètre | Défaut | Description |
|---|---|---|
| `AASystemLimitBLUE` | `20` | Nombre max de systèmes AA actifs pour BLUE |
| `AASystemLimitRED` | `20` | Nombre max de systèmes AA actifs pour RED |
| `AASystemCrateStacking` | `false` | Autorise plusieurs jeux de crate à ajouter des launchers supplémentaires (N×crates → N×launchers) |
| `aaLaunchers` | `3` | Nombre par défaut de launchers par système AA quand le template n'en précise pas |

### JTAC

| Paramètre | Défaut | Description |
|---|---|---|
| `JTAC_LIMIT_BLUE` | `10` | Nombre max d'objets JTAC que BLUE peut spawn (quota fixe — non réapprovisionné lorsqu'un JTAC est tué) |
| `JTAC_LIMIT_RED` | `10` | Nombre max d'objets JTAC que RED peut spawn (idem) |
| `JTAC_dropEnabled` | `true` | Autorise le spawn de crate JTAC depuis F10 |
| `JTAC_maxDistance` | `10000` | Portée en ligne de vue du JTAC (mètres) |
| `JTAC_lock` | `"all"` | Filtre de cible : `"vehicle"` \| `"troop"` \| `"all"` |
| `JTAC_allowStandbyMode` | `true` | Autorise l'activation/désactivation du lasing |
| `JTAC_laseSpotCorrections` | `true` | Anticipe les cibles mobiles, en tenant compte du vent et de la vitesse de la cible |
| `JTAC_allow9Line` | `true` | Autorise les requêtes 9-line |
| `JTAC_allowSmokeRequest` | `true` | Autorise les requêtes de smoke-on-target |
| `JTAC_smokeOn_RED` | `false` | Active le marquage smoke pour les JTAC RED |
| `JTAC_smokeOn_BLUE` | `false` | Active le marquage smoke pour les JTAC BLUE |
| `JTAC_smokeColour_RED` | `4` | Couleur de smoke du JTAC RED — 0=Green 1=Red 2=White 3=Orange 4=Blue |
| `JTAC_smokeColour_BLUE` | `1` | Couleur de smoke du JTAC BLUE — 0=Green 1=Red 2=White 3=Orange 4=Blue |
| `JTAC_smokeMarginOfError` | `50` | Rayon max d'erreur de placement aléatoire (m) pour la smoke |
| `JTAC_smokeOffset_x` | `0.0` | Offset Est/Ouest fixe (m) ajouté avant l'erreur aléatoire |
| `JTAC_smokeOffset_y` | `2.0` | Offset vertical fixe (m) — garde la smoke visible au-dessus du terrain |
| `JTAC_smokeOffset_z` | `0.0` | Offset Nord/Sud fixe (m) ajouté avant l'erreur aléatoire |
| `JTAC_droneRadius` | `1000` | Rayon d'orbite de repli (m) pour les JTAC drones quand la crate n'a pas de `specificParams` |
| `JTAC_droneAltitude` | `4000` | Altitude d'orbite de repli AGL (m) pour les JTAC drones quand la crate n'a pas de `specificParams` |

#### Groupes JTAC pré-placés (auto-détection)

CTLD détecte au démarrage les groupes JTAC placés dans le Mission Editor. Un groupe est reconnu
comme JTAC lorsque son **nom de groupe contient `jtac`** (insensible à la casse) — par exemple
`jtac_blue_1`, `JTAC_Red_Forward`, `blue_jtac_drone`.

!!! warning "Naming rule (mandatory)"
    Tout groupe JTAC placé dans le Mission Editor **doit** inclure `jtac` dans son nom de groupe.
    CTLD utilise le nom de groupe — pas le type d'unité — pour identifier les JTAC pré-placés. Un
    groupe contenant un Hummer ou un SKP-11 ne sera **pas** détecté à moins que son nom contienne
    `jtac`. Les groupes JTAC en late-activation sont supportés et enregistrés automatiquement
    lors de leur activation.

### RECON

| Paramètre | Défaut | Description |
|---|---|---|
| `reconF10Menu` | `true` | Active le sous-menu F10 RECON |
| `reconEnabled` | `false` | Interrupteur maître — doit être `true` pour que les commandes de scan fonctionnent |
| `reconSearchRadius` | `5000` | Rayon de scan en ligne de vue (mètres) |
| `reconMinAltitude` | `50` | Altitude AGL minimale (m) requise pour effectuer un scan |
| `reconRefreshInterval` | `10` | Intervalle de rafraîchissement automatique (secondes) |
| `reconIconScale` | `1.0` | Multiplicateur de taille d'icône (1.0 = défaut, 2.0 = double) |

### Minefield

| Paramètre | Défaut | Description |
|---|---|---|
| `showMinefieldOnF10Map` | `true` | Dessine un quadrilatère englobant sur la carte F10 lorsqu'un minefield est déployé |
| `demineRadius` | `150` | Distance max (m) du joueur au centre du minefield pour que l'entrée « Clear Mine Field » apparaisse |

Voir [Minefield](minefield.md) pour le déploiement.

## Capacités par appareil

`capabilitiesByType` est l'unique table qui définit chaque capacité par appareil. **Seuls les
appareils listés ici reçoivent les menus F10 de CTLD.** Chaque clé est le **nom de type DCS
exact** de l'appareil (mods inclus, ex. `"Hercules"`, `"76MD"`, `"UH-60L"`).

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["capabilitiesByType"] = {
    ["UH-1H"] = {
        cratesEnabled            = true,   -- can load/unpack crates
        troopsEnabled            = true,   -- can load/deploy infantry
        canParachuteDrop         = true,   -- enables Parachute F10 entries
        canSlingload             = true,   -- enables hover-pickup + Slingload menus
        canTransportWholeVehicle = true,   -- whole-vehicle transport
        useNativeDcsCargoSystem  = true,   -- use the DCS native cargo system for crates
        convertNativeLoadToCTLD  = true,   -- convert DCS-native cargo loads to CTLD-managed
        maxTroopsOnboard         = 8,      -- max soldiers (overrides ctld.numberOfTroops)
        maxCratesOnboard         = 1,      -- max crates carried at once
        maxWholeVehiclesOnboard  = 1,      -- max whole vehicles carried at once
        maxVehicleWeight         = 1360,   -- max whole-vehicle weight (kg) this aircraft can lift
        loadableVehiclesRED      = { "BRDM-2", "BTR_D" },
        loadableVehiclesBLUE     = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
    },
    ["C-130J-30"] = {
        cratesEnabled = true, troopsEnabled = true, canParachuteDrop = true, canSlingload = false,
        canTransportWholeVehicle = true, useNativeDcsCargoSystem = true, convertNativeLoadToCTLD = false,
        maxTroopsOnboard = 80, maxCratesOnboard = 22, maxWholeVehiclesOnboard = 2,
        maxVehicleWeight = 20000,
        loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
        loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
    },
    -- ... one entry per aircraft type
}
```

**Référence des champs :**

| Champ | Type | Description |
| --- | --- | --- |
| `cratesEnabled` | bool | Peut charger / spawn / déballer des crate |
| `troopsEnabled` | bool | Peut charger / déployer des groupes d'infanterie |
| `canParachuteDrop` | bool | Active les entrées F10 « Parachute » |
| `canSlingload` | bool | Active le hover-pickup et les menus « Release/Cut Slingload » |
| `canTransportWholeVehicle` | bool | Peut charger et redéployer des véhicules entiers |
| `useNativeDcsCargoSystem` | bool | Si `true`, CTLD fait spawn les crate comme objets cargo DCS (intégration cargo native). Si `false`, les crate sont créées directement comme objets statiques |
| `convertNativeLoadToCTLD` | bool | Si `true`, toute crate chargée via l'UI cargo DCS est immédiatement convertie en crate gérée par CTLD (détruit le slot DCS, empêche les crate fantômes). Mettre à `true` pour les hélicoptères où l'UI cargo DCS est exposée mais où le parachute CTLD est nécessaire (`UH-1H`, `CH-47Fbl1`) ; laisser à `false` pour les appareils qui s'appuient sur le cargo natif DCS pour les opérations au sol (`C-130J-30`, `76MD`, `Hercules`) |
| `maxTroopsOnboard` | number | Nombre max de soldats que cet appareil peut transporter (surcharge `numberOfTroops`) |
| `maxCratesOnboard` | number | Nombre max de crate chargées à la fois (repli : 1 pour les types non listés) |
| `maxWholeVehiclesOnboard` | number | Nombre max de véhicules entiers transportés à la fois (0 = désactivé) |
| `maxVehicleWeight` | number | Poids max de véhicule entier (kg) que cet appareil peut soulever ; les véhicules plus lourds sont ignorés par l'auto-pickup de l'IA. Omettre ou mettre à `nil` pour illimité |
| `loadableVehiclesRED` | string[] | Noms de type DCS des véhicules de coalition RED que cet appareil peut transporter entiers |
| `loadableVehiclesBLUE` | string[] | Noms de type DCS des véhicules de coalition BLUE que cet appareil peut transporter entiers |

!!! note
    Quand `canTransportWholeVehicle = true` et que `loadableVehiclesRED/BLUE` liste un type de
    véhicule, ce type apparaît dans le menu F10 **Request Equipment**. Le sélectionner fait spawn
    le véhicule comme unité en attente près du transport (au lieu d'une crate) ; le pilote le
    charge ensuite depuis le cockpit. Voir le [guide Pilote](../pilot/index.md) pour le
    déroulement en cockpit.

Les appareils **non** listés dans `capabilitiesByType` ne reçoivent aucun menu CTLD. Affecter
votre propre table `capabilitiesByType` remplace entièrement celle intégrée, donc incluez chaque
appareil que vous voulez rendre CTLD-capable.

## Contrôle d'accès

Deux paramètres décident quelles unités joueur reçoivent les menus F10 de CTLD.

| Paramètre | Défaut | Description |
|---|---|---|
| `addPlayerAircraftByType` | `true` | Comment CTLD sélectionne les unités joueur qui reçoivent les menus |
| `transportPilotNames` | `{...}` | Liste blanche de **noms d'unité** DCS — active quand `addPlayerAircraftByType = false`, et toujours utilisée pour les transports IA |

**`addPlayerAircraftByType = true`** (défaut) — tout joueur dont le type d'appareil est listé
dans `capabilitiesByType` obtient automatiquement les menus CTLD en entrant dans un slot.
Recommandé pour les serveurs multijoueurs ouverts.

**`addPlayerAircraftByType = false`** — seuls les noms d'unité explicitement listés dans
`transportPilotNames` obtiennent les menus CTLD. Utilisez ceci pour restreindre CTLD à un
ensemble fixe de slots nommés (ex. une escadrille de transport dédiée). Les appareils
CTLD-capables **non** listés rejoignent la mission normalement mais n'ont aucun accès CTLD.

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["addPlayerAircraftByType"] = false
_cfg.settings["transportPilotNames"] = {
    "transport_slot_1",
    "transport_slot_2",
    "transport_slot_3",
}
```

!!! note "AI transports"
    Les transports IA utilisent toujours `transportPilotNames`, indépendamment de
    `addPlayerAircraftByType`. Ajoutez-y les noms d'unité IA pour activer le comportement
    d'auto-pickup / drop-off.

## Où le reste se configure

La configuration qui n'est pas globale vit sur des pages dédiées :

| Sujet | Page |
|---|---|
| Zones de troop / logistique / extract / waypoint (`troopZones`, `AIZones`, `wpZones`…) | [Zone setup](zones.md) |
| Construction de FOB et déploiement de scène | [Scenes & FOB](scenes-fob.md) |
| `spawnableCrates`, descripteurs de crate et templates AA | [Crate catalogue](crates-catalogue.md) |
| Déploiement de minefield | [Minefield](minefield.md) |
| Localisation et surcharges de traduction | [Translations](translations.md) |
| Compatibilité v1 `ctld.*` pour les scripts existants | [Legacy API](legacy-api.md) |

Pour opérer CTLD depuis le cockpit (le menu F10), voir le [guide Pilote](../pilot/index.md).
