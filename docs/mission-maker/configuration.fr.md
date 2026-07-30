# Configuration

CTLD est livré avec des valeurs par défaut sensées pour chaque paramètre. Vous n'éditez jamais
les fichiers source : toute la personnalisation vit dans un unique fichier,
**`CTLD_userConfig.lua`**, que votre mission charge via un trigger `DO SCRIPT FILE`.

Ce fichier porte un **instantané de configuration complet** — toute la configuration de CTLD, et non
une liste de modifications — et il **remplace intégralement** les valeurs par défaut intégrées. Vous
partez donc toujours des valeurs par défaut courantes pour les ajuster, ce que `ctld-tools` fait
précisément pour vous.

!!! tip "Recommandé : utiliser l'application `ctld-tools`"
    Plutôt que d'écrire l'instantané à la main, le flux recommandé est l'application **`ctld-tools`** :
    double-cliquez-la, éditez la configuration complète de CTLD dans votre navigateur via des
    formulaires, et injectez-la dans votre mission. Elle part des valeurs par défaut courantes, valide
    vos changements contre le vrai catalogue et la liste des types DCS, et détecte les erreurs avant
    DCS. `ctld-tools.exe` est attaché à chaque Release GitHub (pas besoin de Python) — voir
    [Configurer CTLD avec `ctld-tools`](ctld-tools.fr.md). L'écriture manuelle de l'instantané reste
    entièrement possible pour les utilisateurs avancés, et cette page documente chaque réglage qu'il
    contient.

Cette page couvre les **réglages globaux** et les **capacités par appareil**
(`capabilitiesByType`). Les listes de zones, les définitions de crate, les scènes FOB, le
minefield et les traductions ont chacun leur propre page — voir [Où le reste se configure](#where-the-rest-is-configured).

## Comment fonctionne la configuration { #how-configuration-works }

Au démarrage, CTLD analyse **un seul** document de configuration : `ctld.configUser` si votre mission
en fournit un, sinon les valeurs par défaut embarquées dans `CTLD.lua`. Les deux ne sont jamais
fusionnés. Un `ctld.configUser` qui ne s'analyse pas est une erreur fatale plutôt qu'un retour
silencieux aux défauts — une raison de plus de le produire avec `ctld-tools`, qui valide avant export.

Tout au long de la mission en cours, chaque paramètre est lu via un unique accesseur :

```lua
ctld.gs("parameterName")   -- the only authorised read form
```

### Ordre de chargement dans le Mission Editor { #load-order-in-the-mission-editor }

`CTLD.lua` démarre automatiquement avec les valeurs par défaut — aucun fichier de config
n'est requis. Si vous souhaitez personnaliser, ajoutez `CTLD_userConfig.lua` comme **premier**
trigger, avant `CTLD.lua` :

| Ordre | Action | Fichier | Requis ? |
|---|---|---|---|
| 1 | DO SCRIPT FILE | `CTLD_userConfig.lua` | Optionnel — uniquement si personnalisation |
| 2 | DO SCRIPT FILE | `CTLD.lua` | Toujours |

`CTLD_userConfig.lua` pose `ctld.configUser` dans l'environnement global ; `CTLD.lua` l'analyse
au démarrage et initialise CTLD automatiquement. L'action **Injecter dans la mission…** de
`ctld-tools` écrit exactement ce trigger, à cette position, pour vous. (Si vous devez exécuter une
configuration supplémentaire entre le chargement et le démarrage, positionnez
`ctld.dontInitialize = true` avant le chargement de `CTLD.lua` et appelez `ctld.initialize()`
vous-même.)

### À quoi ressemble l'instantané { #what-the-snapshot-looks-like }

L'instantané est du **YAML dans une chaîne longue Lua**, au même format que le
`src/CTLD_config.yaml` de CTLD : une balise `configVersion`, puis les sections `mm_facing` et
`advanced` qui portent chaque réglage et chaque table du catalogue. `mm_facing` regroupe ce qu'un
concepteur de mission touche habituellement, `advanced` le reste ; le moteur fusionne les deux, la
séparation n'existe que pour la lisibilité. Si vous écrivez un instantané à la main, recopiez la
structure de `src/CTLD_config.yaml` (ou exportez-en un depuis `ctld-tools`) plutôt que d'inventer le
placement.

```lua
-- CTLD_userConfig.lua — a COMPLETE configuration snapshot, not a list of overrides.
ctld = ctld or {}
ctld.configUser = [[
configVersion: "2.0.0"
mm_facing:
  numberOfTroops: 8
  maximumDistanceLogistic: 300
  slingLoad: true
  spawnableCrates:
    # ... every crate section ...
  # ... every other mm_facing setting and table ...
advanced:
  maximumDistancePackableUnitsSearch: 350
  # ... every advanced setting ...
]]
```

`configVersion` enregistre la version de configuration contre laquelle votre instantané a été écrit.
Lors d'une mise à jour de CTLD, `ctld-tools` la lit et vous dit ce qui a changé — réglages apparus,
réglages devenus inutiles, valeurs par défaut déplacées — sans jamais rien fusionner à votre insu.

!!! warning "Ce que signifie une omission"
    Les deux natures de valeur ne se comportent pas pareil, et c'est volontaire :

    - un **réglage** (une valeur unique — booléen, nombre, chaîne) que vous omettez retombe sur la
      valeur par défaut de CTLD, car le moteur a besoin d'une valeur pour calculer. Chaque réglage
      résolu de cette façon est nommé une fois dans le rapport de démarrage à l'écran : un instantané
      écrit à la main qui a dérivé fonctionne quand même, et vous le dit.
    - une **liste** (une section de caisses, un groupe de troupes, une entrée de zone, un nom de
      pilote) que vous omettez est réellement absente. C'est ainsi qu'on en retire une — et c'est
      pourquoi rien n'est fusionné.

    La validation de `ctld-tools` signale un réglage manquant comme une erreur et refuse d'injecter :
    un instantané produit par l'outil est donc toujours complet.

!!! note "Passez à un niveau de crochets supérieur si nécessaire"
    L'instantané se place entre `[[` et `]]`. Si votre texte contient un jour `]]`, utilisez
    `[==[ ... ]==]`.

## Réglages globaux { #global-settings }

### Système { #system }

| Paramètre | Défaut | Description |
|---|---|---|
| `debug` | `false` | Journalisation verbeuse vers `CTLD.log` (nécessite une installation DCS non sanitized) |
| `i18n_lang` | `"en"` | Langue de l'interface CTLD : `en`, `fr`, `es` ou `ko` |
| `ctldLogPath` | `""` | Surcharge le chemin du fichier de log ; vide = dossier Saved Games DCS par défaut |
| `debugScreenLog` | `false` | Répète aussi les messages de log à l'écran DCS via `outText` |
| `location_DMS` | `false` | Affiche les coordonnées en Degrés-Minutes-Secondes au lieu de Degrés-Minutes-Décimales |
| `disableAllSmoke` | `false` | Désactive globalement toute la smoke aux zones de pickup et de drop-off |
| `modTypes` | `{}` | Noms de types DCS hors-stock (mod) utilisés par votre config custom (crates, parts AA, rôles de troupes). Consulté uniquement par le [compagnon asset-check](asset-validation.md) dev-time pour ne pas les signaler — voir cette page |

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

### Simulation du poids de l'infanterie { #infantry-weight-simulation }

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

### Véhicules & packing { #vehicles-packing }

| Paramètre | Défaut | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Autorise le pack des véhicules de nouveau en crate |
| `groundVehicleWeights` | `{...}` | Poids (kg) par type DCS de véhicule, comparé au `maxVehicleWeight` de chaque appareil pour le transport de véhicule entier (table Lua) |
| `capabilitiesByType` | `{...}` | Table unifiée des capacités par appareil — voir [Capacités par appareil](#per-aircraft-capabilities) ci-dessous |

### Beacons

| Paramètre | Défaut | Description |
|---|---|---|
| `enabledRadioBeaconDrop` | `true` | Autorise le déploiement de beacon |
| `deployedBeaconBattery` | `30` | Durée de vie de la batterie du beacon (minutes) |
| `radioSound` | `"beacon.ogg"` | Fichier son du beacon — **doit** être ajouté au `.miz` de la mission, sinon les beacon ne fonctionneront pas |
| `radioSoundFC3` | `"beaconsilent.ogg"` | Fichier de beacon silencieux pour les appareils FC3 |

### Systèmes AA { #aa-systems }

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
| `JTAC_droneRadiusNoLase` | `2000` | Rayon d'orbite (m) tant qu'un JTAC drone cherche sans laser |
| `JTAC_droneRadiusOnLase` | `1000` | Rayon d'orbite (m) une fois qu'un JTAC drone illumine une cible — plus serré, pour rester près de ce qu'il désigne |
| `JTAC_droneAltitude` | `3000` | Altitude d'orbite AGL (m) des JTAC drones, utilisée aussi pour l'altitude d'apparition |
| `JTAC_droneSpeed` | `150` | Vitesse d'orbite (km/h) des JTAC drones, utilisée aussi pour la vitesse d'apparition |

#### Groupes JTAC pré-placés (auto-détection) { #pre-placed-jtac-groups-auto-detection }

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

## Capacités par appareil { #per-aircraft-capabilities }

`capabilitiesByType` est l'unique table qui définit chaque capacité par appareil. **Seuls les
appareils listés ici reçoivent les menus F10 de CTLD.** Chaque clé est le **nom de type DCS
exact** de l'appareil (mods inclus, ex. `"Hercules"`, `"76MD"`, `"UH-60L"`).

Dans `ctld-tools`, c'est la famille **Appareils** : choisissez un type dans la liste DCS et
remplissez le formulaire. Dans un instantané écrit à la main, cette table vit sous `mm_facing` :

```yaml
mm_facing:
  capabilitiesByType:
    UH-1H:
      cratesEnabled: true              # can load/unpack crates
      troopsEnabled: true              # can load/deploy infantry
      canParachuteDrop: true           # enables Parachute F10 entries
      canSlingload: true               # enables hover-pickup + Slingload menus
      canTransportWholeVehicle: true   # whole-vehicle transport
      useNativeDcsCargoSystem: true    # use the DCS native cargo system for crates
      convertNativeLoadToCTLD: true    # convert DCS-native cargo loads to CTLD-managed
      maxTroopsOnboard: 8              # max soldiers (overrides numberOfTroops)
      maxCratesOnboard: 1              # max crates carried at once
      maxWholeVehiclesOnboard: 1       # max whole vehicles carried at once
      maxVehicleWeight: 1360           # max whole-vehicle weight (kg) this aircraft can lift
      loadableVehiclesRED:
      - BRDM-2
      - BTR_D
      loadableVehiclesBLUE:
      - M1045 HMMWV TOW
      - M1043 HMMWV Armament
      - Hummer
    C-130J-30:
      cratesEnabled: true
      troopsEnabled: true
      canParachuteDrop: true
      canSlingload: false
      canTransportWholeVehicle: true
      useNativeDcsCargoSystem: true
      convertNativeLoadToCTLD: false
      maxTroopsOnboard: 80
      maxCratesOnboard: 22
      maxWholeVehiclesOnboard: 2
      maxVehicleWeight: 20000
      loadableVehiclesRED:
      - BRDM-2
      - BTR_D
      loadableVehiclesBLUE:
      - M1045 HMMWV TOW
      - M1043 HMMWV Armament
      - Hummer
    # ... one entry per aircraft type
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

Les appareils **non** listés dans `capabilitiesByType` ne reçoivent aucun menu CTLD. L'instantané
étant complet, la table que vous livrez *est* la table utilisée par CTLD : incluez chaque appareil que
vous voulez rendre CTLD-capable. Pour changer un seul champ sur un seul appareil — disons
`maxTroopsOnboard` sur le `Mi-8MT` — partez de la table par défaut et modifiez ce champ sur place ;
n'écrivez pas une table ne contenant que votre appareil, sinon tous les autres types perdent leurs
menus. `ctld-tools` s'en charge : il part toujours de la table par défaut complète et marque les
champs que vous avez modifiés.

## Contrôle d'accès { #access-control }

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

```yaml
mm_facing:
  addPlayerAircraftByType: false
  transportPilotNames:
  - transport_slot_1
  - transport_slot_2
  - transport_slot_3
```

!!! note "AI transports"
    Les transports IA utilisent toujours `transportPilotNames`, indépendamment de
    `addPlayerAircraftByType`. Ajoutez-y les noms d'unité IA pour activer le comportement
    d'auto-pickup / drop-off.

## Où le reste se configure { #where-the-rest-is-configured }

La configuration qui n'est pas globale vit sur des pages dédiées :

| Sujet | Page |
|---|---|
| Zones de troop / logistique / extract / waypoint (`troopZones`, `aiZones`, `wpZones`…) | [Zone setup](zones.md) |
| Construction de FOB et déploiement de scène | [Scenes & FOB](scenes-fob.md) |
| `spawnableCrates`, descripteurs de crate et templates AA | [Crate catalogue](crates-catalogue.md) |
| Déploiement de minefield | [Minefield](minefield.md) |
| Localisation et surcharges de traduction | [Translations](translations.md) |
| Compatibilité v1 `ctld.*` pour les scripts existants | [Legacy API](legacy-api.md) |

Pour opérer CTLD depuis le cockpit (le menu F10), voir le [guide Pilote](../pilot/index.md).
