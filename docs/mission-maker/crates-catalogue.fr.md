# Catalogue de caisses (crates) { #crate-catalogue }

Cette page traite de **ce que vous proposez aux pilotes de faire spawner** : les crates, les
véhicules complets, les systèmes AA et les unités JTAC qu'un mission maker définit dans la
configuration. Tout ce qui est décrit ici est de la donnée que vous réglez une fois dans
`CTLD_userConfig.lua` ; les pilotes la parcourent ensuite depuis le menu F10 à l'exécution.

Les actions en cockpit — chargement, largage, unpack, requête, pack — sont décrites dans le guide
Pilote : [Crates](../pilot/crates.md), [Véhicules](../pilot/vehicles.md), [JTAC](../pilot/jtac.md).
Les limites de transport par aéronef (quel appareil peut soulever des crates ou des véhicules
complets, et combien) sont réglées dans [Configuration](configuration.md) via `capabilitiesByType`.

## `spawnableCrates`

`spawnableCrates` est le catalogue maître. C'est une table de **sections nommées** (chacune devient
un sous-menu F10), et chaque section contient une liste de descripteurs de crate :

```lua
_cfg.settings["spawnableCrates"] = {
    ["Combat Vehicles"] = {
        { weight = 1000.01, desc = ctld.tr("Humvee - MG"),  unit = "M1043 HMMWV Armament", side = 2, cratesRequired = 3 },
        { weight = 1000.05, desc = ctld.tr("Heavy Tank - Abrams"), unit = "M-1 Abrams",     side = 2, cratesRequired = 4 },
    },
    ["Artillery"] = {
        { weight = 1002.01, desc = ctld.tr("MLRS"), unit = "MLRS", side = 2, cratesRequired = 3 },
    },
}
```

### Champs du descripteur

| Champ | Type | Signification |
|---|---|---|
| `weight` | number | Poids **unique** du crate (kg). Double rôle : la masse de slingload DCS *et* la clé de recherche que CTLD utilise pour résoudre quelle unité faire spawner à l'unpack. Deux crates ne doivent jamais partager un même poids. |
| `desc` | string | Libellé du menu. À encadrer dans `ctld.tr(...)` pour la traduction. |
| `unit` | string | **Type name** DCS de l'unité qui spawn quand le jeu de crates est unpacké (ex. `"M-1 Abrams"`). À vérifier contre le [dataset datamine](https://github.com/Quaggles/dcs-lua-datamine). |
| `side` | number | Coalition à laquelle le crate est proposé : `2` = BLUE, `1` = RED. Omettre pour proposer aux deux. |
| `cratesRequired` | number | Combien de crates de ce type doivent se trouver dans un rayon de 300 m les uns des autres pour l'unpack (défaut `1`). |
| `isJTAC` | bool | Marque l'unité comme un JTAC — voir [unités JTAC](#unites-jtac) plus bas. |
| `spawnAs` | string | Surcharge de catégorie de spawn pour les unités aériennes : `"AIRPLANE"` ou `"HELICOPTER"` (utilisé par les JTAC drones). Les véhicules terrestres n'ont besoin d'aucune surcharge. |
| `specificParams` | table | Paramètres additionnels par unité (ex. `speed`, `alti`, rayons d'orbite d'un drone). |
| `mixedSet` | array | Alternative à `weight` : une entrée dont la valeur est une liste de poids définit un **jeu combiné** — un seul item de menu qui fait spawner plusieurs types de crate différents d'un coup (voir plus bas). |

### Crates simples vs jeux

- Un descripteur avec un **`weight`** est un *type de crate simple*.
- Quand `cratesRequired > 1` et que `enableAllCrates` vaut `true` (défaut), CTLD génère
  automatiquement un raccourci **« All crates »** qui fait spawner le jeu complet de crates
  identiques en une action. Supprimez-le par entrée avec `showSets = false`.
- Un descripteur avec un **`mixedSet`** (une liste de poids) fait spawner un *mélange* de types de
  crate différents en une action. Chaque poids qu'il référence doit résoudre vers un descripteur de
  crate simple **dans la même section**, sinon le jeu est abandonné au démarrage avec un
  avertissement de mission.

### Modèles visuels des crates

`spawnableCratesModels` définit les formes statiques DCS utilisées par les crates (`load`, `sling`,
`dynamic`). Vous avez rarement besoin d'y toucher ; laissez les valeurs par défaut, sauf si vous
voulez une apparence de cargo différente.

### Catalogue par défaut (out of the box)

| Section | Contenu |
|---|---|
| `Combat Vehicles` | Humvee MG/TOW, MRAP, LAV-25, M-1 Abrams (BLUE) ; BTR-D, BRDM-2 (RED) |
| `Support` | Hummer JTAC, camions munitions/ravitaillement (BLUE) ; SKP-11 JTAC, camions munitions (RED) ; EWR Radar (les deux). Les crates de scène FOB/FARP sont auto-injectés ici. |
| `Artillery` | MLRS, SpGH DANA, T155 Firtina, M-109 (BLUE) ; 2S19 Msta (RED) |
| `SAM short range` | Avenger, Chaparral, Roland, Gepard, C-RAM (BLUE) ; Osa, Strela-1/10, Tor, Tunguska (RED) |
| `SAM mid range` | Crates de systèmes AA *auto-injectés* : HAWK, NASAMS (BLUE), BUK, KUB (RED) |
| `SAM long range` | Crates de systèmes AA *auto-injectés* : Patriot (BLUE), S-300 (RED) |
| `Drone` | MQ-9 Reaper JTAC (BLUE), RQ-1A Predator JTAC (RED) |

### Réglages du système de crates

| Paramètre | Défaut | Description |
|---|---|---|
| `enableCrates` | `true` | Interrupteur maître du système de crates. |
| `enableAllCrates` | `true` | Génère les entrées de raccourci « All crates ». |
| `maximumDistanceLogistic` | `200` | Distance max (m) à une unité de logistique pour spawn/chargement. |
| `loadCrateFromMenu` | `true` | Autorise le chargement d'un crate depuis le menu F10 (en plus du ramassage en hover). |
| `enableHoverSlingload` | `true` | Autorise le ramassage de crate en hover. |
| `hoverTime` | `10` | Secondes de hover à tenir pour accrocher un crate. |
| `minimumHoverHeight` / `maximumHoverHeight` | `7.5` / `12.0` | Fenêtre de hover (m) pour le ramassage. |
| `maxDistanceFromCrate` | `5.5` | Distance horizontale max (m) à un crate pendant le ramassage en hover. |
| `maxSlingloadSpeed` | `50` | Vitesse (m/s) au-delà de laquelle un crate en slingload est perdu. |
| `crateSpacing` | `5` | Espacement (m) entre les crates spawnés dans un jeu. |

## Transport de véhicules complets

Au-delà des crates, CTLD peut transporter des **véhicules terrestres complets** à l'intérieur des
aéronefs capables (C-130, Il-76, CH-47, UH-1H…). Ce qu'un appareil donné peut transporter est défini
par aéronef dans [`capabilitiesByType`](configuration.md), et non dans une liste globale séparée :

| Champ de `capabilitiesByType` | Signification |
|---|---|
| `canTransportWholeVehicle` | `true` = cet appareil peut charger/décharger des véhicules complets. |
| `useNativeDcsCargoSystem` | `true` = utilise la soute cargo native DCS (C-130, Il-76, CH-47…) ; sinon le menu F10 gère le chargement. |
| `maxWholeVehiclesOnboard` | Nombre max de véhicules complets embarqués à la fois (`0` = pas de transport de véhicule). |
| `maxVehicleWeight` | Masse max de véhicule soulevable (kg). |
| `loadableVehiclesBLUE` / `loadableVehiclesRED` | Les type names DCS que cet appareil peut transporter en entier, par coalition. |
| `convertNativeLoadToCTLD` | `true` = convertit une charge cargo native DCS en charge gérée par CTLD au chargement (ex. UH-1H, CH-47, où l'UI cargo DCS laisserait des crates fantômes). |

Par exemple, le UH-1H par défaut peut soulever l'un de `M1045 HMMWV TOW`, `M1043 HMMWV Armament` ou
`Hummer` (BLUE), ou `BRDM-2` / `BTR_D` (RED), jusqu'à `maxVehicleWeight = 1360` kg.

Tout aéronef **non** marqué `canTransportWholeVehicle` doit déplacer les véhicules sous forme de
crates : un pilote pack le véhicule en crates, les transporte, et les unpack à destination.

### Réglages de packing de véhicules

| Paramètre | Défaut | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Autorise les pilotes à packer un véhicule terrestre en crates. |
| `maximumDistancePackableUnitsSearch` | `200` | Distance max (m) au transport pour trouver un véhicule packable. |

L'opération inverse — [packer](../pilot/vehicles.md) un véhicule en crates — fait spawner
`cratesRequired` crates du type de crate du véhicule autour de l'aéronef. Il n'y a pas de liste
« véhicules packables » séparée : tout véhicule dont le type DCS correspond au `unit` d'un
descripteur `spawnableCrates` est packable.

## Systèmes AA

Les systèmes AA sont des **kits multi-crates** : un mission maker déclare le système une fois dans
`CTLDCrateAssemblyManager.TEMPLATES`, et CTLD injecte automatiquement les crates de pièces
correspondants ainsi qu'un jeu « All crates » dans `spawnableCrates` au démarrage. **N'ajoutez pas**
à la main des entrées de pièces AA dans `spawnableCrates` — elles apparaîtraient en double.

Un template ressemble à ceci :

```lua
CTLDCrateAssemblyManager.TEMPLATES = {
    {
        name           = "HAWK AA System",   -- display name in messages/events
        count          = 5,                    -- unique part types required for a complete system
        side           = 2,                    -- 2 = BLUE, 1 = RED
        sectionName    = "SAM mid range",      -- spawnableCrates section to inject into
        allCratesLabel = "HAWK - All crates",  -- label for the auto-generated combined set (optional)
        parts = {
            { DCSTypename = "Hawk ln", desc = "HAWK Launcher",     launcher = true, weight = 1004.01 },
            { DCSTypename = "Hawk sr", desc = "HAWK Search Radar", amount = 2,      weight = 1004.02 },
            { DCSTypename = "Hawk tr", desc = "HAWK Track Radar",  amount = 2,      weight = 1004.03 },
            { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",  NoCrate = true, weight = 1004.04 },
            { DCSTypename = "Hawk cwar", desc = "HAWK CWAR", NoCrate = true, amount = 2, weight = 1004.05 },
        },
        repair = { desc = "HAWK Repair", weight = 1004.06 },
    },
    -- more systems...
}
```

### Champs de pièce

| Champ | Signification |
|---|---|
| `DCSTypename` | Type name DCS de l'unité terrestre spawnée à l'assemblage. |
| `desc` | Clé i18n utilisée pour le libellé du menu de crate *et* le message d'assemblage « Missing X ». |
| `weight` | Poids de crate unique (kg) — même double rôle que n'importe quel crate. **À omettre** pour une pièce `NoCrate` sans crate autonome. |
| `launcher` | `true` marque la pièce qui déclenche la détection de rearm. |
| `amount` | Nombre d'unités de cette pièce spawnées par système (défaut `1` ; les launchers utilisent par défaut `aaLaunchers`). |
| `NoCrate` | `true` = la pièce est toujours spawnée à l'assemblage et n'est **pas** comptée dans le jeu « All crates ». Elle peut tout de même porter un `weight` pour être spawnable en crate autonome. |
| `cratesRequired` | Crates de ce type de pièce nécessaires pour la débloquer (défaut `1`). |
| `repair` | Un crate de réparation séparé (`desc` + `weight` unique) qui fait respawner un système endommagé à pleine santé. |

`count` est le nombre de **types de pièces uniques** qui doivent être présents pour que le système
soit considéré comme complet.

### Templates AA intégrés

| Système | Side | `count` | Section | Pièces en crate (à apporter) | Pièces `NoCrate` (auto à l'assemblage) |
|---|---|---|---|---|---|
| HAWK AA System | BLUE | 5 | `SAM mid range` | Launcher, Search Radar ×2, Track Radar ×2 | PCP, CWAR ×2 |
| NASAMS AA System | BLUE | 3 | `SAM mid range` | Launcher 120C, Search/Track Radar, Command Post | — |
| BUK AA System | RED | 3 | `SAM mid range` | Launcher, Search Radar, CC Radar | — |
| KUB AA System | RED | 2 | `SAM mid range` | Launcher, Radar | — |
| Patriot AA System | BLUE | 4 | `SAM long range` | Launcher ×8, Radar ×2, ECS | AMG |
| S-300 AA System | RED | 6 | `SAM long range` | TEL C (launcher), Flap Lid-A TR, Clam Shell SR, Big Bird SR, C2 | TEL D ×2 |

Chaque template injecte aussi un **crate de réparation** dans sa section.

### Réglages AA

| Paramètre | Défaut | Description |
|---|---|---|
| `AASystemLimitBLUE` | `20` | Nombre max de systèmes AA complets simultanés pour BLUE. |
| `AASystemLimitRED` | `20` | Nombre max de systèmes AA complets simultanés pour RED. |
| `AASystemCrateStacking` | `false` | Autorise des jeux de crates supplémentaires à ajouter des launchers à un système existant. |
| `aaLaunchers` | `3` | Launchers ajoutés par système quand une pièce n'a pas d'`amount` explicite. |

## Unités JTAC

Un JTAC n'est qu'un descripteur de crate marqué **`isJTAC = true`** — il n'y a pas de liste de type
JTAC séparée. N'importe quelle unité (véhicule ou drone) peut être un JTAC :

```lua
-- ground JTAC
{ weight = 1001.01, desc = ctld.tr("Hummer - JTAC"), unit = "Hummer", side = 2, cratesRequired = 2, isJTAC = true },
-- drone JTAC
{
    weight = 1006.01, desc = ctld.tr("MQ-9 Repear - JTAC"), unit = "MQ-9 Reaper", side = 2,
    isJTAC = true, spawnAs = "AIRPLANE",
    specificParams = { speed = 150, alti = 3000, orbitRadiusNoLase = 2000, orbitRadiusOnLase = 1000 },
},
```

Le sous-menu F10 **Request JTAC Equipment** est auto-peuplé à partir de chaque descripteur
`isJTAC = true` disponible pour la coalition du joueur — vous ne maintenez pas de seconde table. Le
sous-menu n'apparaît que lorsque `JTAC_dropEnabled ≠ false`, que l'aéronef est un transport, et
qu'au moins un descripteur JTAC existe pour cette coalition. Par défaut, le livrable embarque un
Hummer (BLUE) et un SKP-11 (RED) dans `Support`, plus un MQ-9 Reaper (BLUE) et un RQ-1A Predator
(RED) dans `Drone`.

### Réglages JTAC

| Paramètre | Défaut | Description |
|---|---|---|
| `JTAC_dropEnabled` | `true` | Active le spawn de crate JTAC depuis F10 ; conditionne aussi la visibilité des descripteurs JTAC. |
| `JTAC_LIMIT_BLUE` | `10` | Nombre max d'objets JTAC que BLUE peut faire spawner (définitif — non réapprovisionné à la mort). |
| `JTAC_LIMIT_RED` | `10` | Nombre max d'objets JTAC que RED peut faire spawner (idem). |
| `JTAC_maxDistance` | `10000` | Portée de scan en ligne de vue du JTAC (m). |
| `JTAC_lock` | `"all"` | Filtre de cible : `"vehicle"`, `"troop"` ou `"all"`. |
| `JTAC_allowStandbyMode` | `true` | Autorise les pilotes à activer/désactiver le laser. |
| `JTAC_allow9Line` | `true` | Active l'affichage de la requête CAS 9-line. |
| `JTAC_targetDeconfliction` | `true` | Empêche plusieurs JTAC de lase la même cible simultanément. |
| `JTAC_droneRadius` | `1000` | Rayon d'orbite de repli (m) quand un descripteur de drone n'a pas de `specificParams`. |

Une fois un JTAC déployé, tout ce qui concerne son **utilisation** — auto-lasing, codes laser,
fumigène, 9-line — est couvert dans le [guide JTAC Pilote](../pilot/jtac.md).
