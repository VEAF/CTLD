# Référence de l'API { #api-reference }

La surface **publique** de chaque manager CTLD — les méthodes que les scripts de mission et les
intégrations externes sont censés appeler. Les helpers internes (préfixés `_`) ne font pas partie
de l'API stable et sont omis ; les méthodes de construction de menus et les gestionnaires
d'événements DCS relèvent de la plomberie interne et ne sont pas non plus listés ici.

Tous les managers sont des **singletons**. Obtenez toujours l'instance via `Manager.getInstance()`
avant d'appeler une méthode d'instance :

```lua
local troops = CTLDTroopManager.getInstance()
troops:spawnGroupAtTrigger("blue", 4, "pickzone1", 100)
```

La configuration est en lecture seule et s'accède via `ctld.gs("paramName")` — jamais
`config:getSetting()`. Voir [Architecture](architecture.md) pour l'idiome singleton et
[Migration v1 → v2](migration-v1-v2.md) pour le principe des wrappers legacy.

## Sommaire { #contents }

- [EventDispatcher](#eventdispatcher)
- [CTLDTroopManager](#ctldtroopmanager)
- [CTLDZoneManager](#ctldzonemanager)
- [CTLDCrateManager](#ctldcratemanager)
- [CTLDVehicleSpawner](#ctldvehiclespawner)
- [CTLDFOBManager](#ctldfobmanager)
- [CTLDBeaconManager](#ctldbeaconmanager)
- [CTLDJTACManager](#ctldjtacmanager)
- [CTLDReconManager](#ctldreconmanager)
- [CTLDSceneManager](#ctldscenemanager)
- [CTLDCrateAssemblyManager](#ctldcrateassemblymanager)
- [mineFieldScene](#minefieldscene)
- [Legacy wrappers (ctld.*)](#legacy-wrappers-ctld)

## EventDispatcher

*Bus interne de publication/abonnement utilisé par tous les managers. Les scripts externes
peuvent s'abonner à n'importe quel événement CTLD.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → EventDispatcher` | Retourne le singleton. |
| `subscribe` | `(eventName, callback)` | Enregistre un gestionnaire pour l'événement nommé. Plusieurs gestionnaires par événement sont pris en charge. |
| `unsubscribe` | `(eventName, callback)` | Supprime un gestionnaire spécifique. |
| `unsubscribeAll` | `(eventName)` | Supprime tous les gestionnaires d'un événement. |
| `publish` | `(eventName, payload)` | Déclenche tous les gestionnaires de `eventName` avec `payload`. Les erreurs dans les gestionnaires sont journalisées puis absorbées. *(Utilisé en interne par les managers — les appelants externes ne doivent pas publier d'événements CTLD.)* |

```lua
EventDispatcher.getInstance():subscribe("OnTroopsDeployed", function(evt)
    -- evt.groupName, evt.deployedBy, evt.position, evt.trigger
    trigger.action.outText("Troops at " .. tostring(evt.position), 10)
end)
```

Catalogue complet des événements : [Events](events.md).

## CTLDTroopManager

*Gère l'embarquement des troops d'infanterie, le déploiement, l'extraction sur le terrain et le
scripting des troops IA.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDTroopManager` | Retourne le singleton. |
| `spawnGroupAtTrigger` | `(side, number, triggerName, radius)` | Fait spawn un groupe d'infanterie extractible dans une zone de trigger. `side` : `"blue"` / `"red"`. Retourne le nom du groupe. |
| `spawnGroupAtPoint` | `(side, number, point, radius)` | Fait spawn un groupe extractible à un point DCS arbitraire `{x,y,z}`. |
| `preLoadTransport` | `(unitName, number, troops)` | Pré-remplit un transport IA avec des troops (à appeler avant le début de la mission ou à l'exécution). `troops` (optionnel) : liste de templates explicite ; à omettre pour choisir depuis la pickup zone la plus proche. |
| `loadTransport` | `(unitName)` | Force le chargement de troops sur un transport IA depuis sa pickup zone la plus proche. |
| `unloadTransport` | `(unitName)` | Force le déchargement des troops d'un transport IA à sa position actuelle. |
| `unloadInProximityToEnemy` | `(unitName, distance)` | Trigger continu : décharge automatiquement les troops IA si un ennemi se trouve à moins de `distance` mètres. |
| `createLoadableGroup` | `(config)` | Ajoute un nouveau template de troops à l'exécution. `config` a les mêmes champs que les entrées de `loadableGroups`. Retourne le nom du template. |
| `editLoadableGroup` | `(name, config)` | Remplace des champs d'un template existant (fusion). |
| `removeLoadableGroup` | `(name)` | Supprime entièrement un template. |
| `disableLoadableGroup` | `(name)` | Masque un template des menus F10 (reste enregistré). |
| `enableLoadableGroup` | `(name)` | Réaffiche un template désactivé. |
| `startGroupCountWatcher` | `(zoneName, blueFlag, redFlag)` | Trigger continu : écrit le nombre de groupes déployés à l'intérieur de `zoneName` dans `blueFlag` / `redFlag`. |
| `startUnitCountWatcher` | `(zoneName, blueFlag, redFlag)` | Idem, en comptant les soldats individuels. |
| `getInTransit` | `(unitName)` | Retourne le `CTLDTroopGroup` actuellement chargé sur `unitName`, ou `nil`. |
| `hasTroops` | `(unitName)` | Retourne `true` si `unitName` transporte actuellement des troops. |
| `getWeight` | `(unitName)` | Retourne le poids total (kg) des troops chargées sur `unitName`. |

## CTLDZoneManager

*Gère tous les types de zones : TRZ pickup/extract, AIZ, WPZ, zones logistiques LGZ.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDZoneManager` | Retourne le singleton. |
| `setTroopZoneActive` | `(zoneName, active)` | Active (`true`) ou désactive (`false`) une pickup zone TRZ. Déclenche `OnLogisticZoneUpdated`. |
| `changeRemainingGroups` | `(zoneName, amount)` | Ajoute ou retranche au nombre de groupes restants d'une zone TRZ. `amount` peut être négatif. |
| `activateWaypointZone` | `(zoneName)` | Active une WPZ pour que les troops nouvellement déployées marchent vers elle. |
| `deactivateWaypointZone` | `(zoneName)` | Désactive une WPZ. |
| `createExtractZone` | `(zoneName, flagNumber, smoke)` | Enregistre une zone de trigger DCS comme extract zone. `smoke` : `0`=Green … `4`=Blue, `-1`=aucune. |
| `removeExtractZone` | `(zoneName, flagNumber)` | Désenregistre une extract zone. |
| `createTroopZoneAtObject` | `(objectName, trzName)` | Ajoute une zone TRZ pickup sur n'importe quel objet DCS nommé (zone de trigger, unité, statique, groupe, ou airbase/FARP). `trzName` est un nom complet `TRZ_<nom>_<coal>_<stock>_<flag>_<target>`. S'ancre à `objectName` s'il peut bouger ; se retire avec `removeExtractZone`. |
| `parseTRZ` | `(name) → table \| nil, string` | Parse un nom `TRZ_…` en `{zoneName, coalition, pickMaxStock, objectiveFlag, objectiveTarget}`, ou `nil` + une raison. |
| `activateLogisticZone` | `(name)` | Réactive une LGZ suspendue. Déclenche `OnLogisticZoneUpdated`. |
| `deactivateLogisticZone` | `(name)` | Suspend une LGZ — les joueurs à l'intérieur ne peuvent plus faire spawn de crates. Déclenche `OnLogisticZoneUpdated`. |
| `registerFOBAsLogistic` | `(fobName, point, radius, coalitionId)` | Enregistre un FOB comme zone logistique (appelé automatiquement par `CTLDFOBManager` à la construction d'un FOB). |
| `unregisterLogistic` | `(name)` | Supprime une zone logistique par son nom (appelé automatiquement à la destruction d'un FOB). |
| `getTroopZone` | `(zoneName)` | Retourne le `CTLDTroopZone` pour `zoneName`, ou `nil`. |
| `getTroopZonesForCoalition` | `(coalition)` | Retourne toutes les troop zones d'une coalition. |
| `getTroopZoneAtPoint` | `(point, coalition)` | Retourne la troop zone contenant `point`, ou `nil`. |
| `getTroopZoneForUnit` | `(unitName)` | Retourne la troop zone dans laquelle l'unité se tient actuellement, ou `nil`. |
| `isUnitInZone` | `(unitName, zoneType)` | Retourne `true` si `unitName` se trouve dans une zone du type donné. |
| `getLogisticZone` | `(name)` | Retourne le `CTLDLogisticZone` pour `name`, ou `nil`. |
| `getLogisticZonesForCoalition` | `(coalition)` | Retourne toutes les zones logistiques d'une coalition. |
| `getLogisticZoneAtPoint` | `(point, coalition)` | Retourne la zone logistique contenant `point`, ou `nil`. |

## CTLDCrateManager

*Gère le cycle de vie complet des crates : spawn, chargement en vol stationnaire, largage, unpack, assemblage, Pack Equipt.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDCrateManager` | Retourne le singleton. |
| `spawnCrateAtZone` | `(side, weight, zone)` | Fait spawn une crate dans une zone de trigger nommée. `side` : `"blue"` / `"red"`. `weight` doit correspondre à une entrée de `spawnableCrates`. |
| `spawnCrateAtPoint` | `(side, weight, point, hdg)` | Fait spawn une crate à un point DCS arbitraire. `hdg` (optionnel) : cap en radians. |
| `getCrateByName` | `(crateName)` | Retourne l'instance `CTLDCrate` pour un nom de statique DCS, ou `nil`. |
| `getCratesInRange` | `(position, radius)` | Retourne toutes les instances `CTLDCrate` situées à moins de `radius` mètres de `position`. |
| `getLoadedCrateWeight` | `(unitName)` | Retourne le poids total (kg) des crates chargées sur `unitName`. |
| `startCrateCountWatcher` | `(zoneName, flagNumber)` | Trigger continu : met à jour `flagNumber` avec le nombre de crates CTLD à l'intérieur de `zoneName` toutes les 5 s. |
| `findDescriptorByWeight` | `(weight)` | Retourne le descripteur de crate pour une clé de poids donnée, ou `nil`. |
| `findDescriptorByUnitType` | `(typeName)` | Retourne le premier descripteur dont le champ `unit` correspond à `typeName`. |
| `findDescriptorByTypeName` | `(typeName)` | Retourne le descripteur dont le `type` DCS spawn correspond à `typeName`, ou `nil`. |
| `getJTACDescriptors` | `(coalitionId)` | Retourne tous les descripteurs mono-crate avec `isJTAC = true` pour la coalition donnée. |

## CTLDVehicleSpawner

*Gère le transport de véhicules entiers : demande, chargement, déchargement, parachutage, pack.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDVehicleSpawner` | Retourne le singleton. |
| `findPackableVehicles` | `(transport)` | Retourne la liste des objets `CTLDVehicle` dans l'état WAITING près de `transport`. |
| `packVehicle` | `(transportUnitName, packableUnitName, playerObj)` | Détruit un véhicule en attente et fait spawn ses crates près du transport. Déclenche `OnVehiclePacked`. |
| `findLoadableVehicles` | `(transport)` | Retourne les types de véhicules éligibles à l'embarquement sur `transport` à sa position actuelle. |
| `findLoadedVehicles` | `(transport)` | Retourne les objets `CTLDVehicle` actuellement chargés sur `transport`. |
| `getLoadedVehicleWeight` | `(transportUnitName)` | Retourne le poids total (kg) des véhicules chargés sur le transport. |
| `scanMMVehicles` | `()` | Re-scanne les groupes terrestres de la coalition pour les véhicules placés dans l'éditeur de mission (appelé à l'init ; ré-appelable sans risque). |

## CTLDFOBManager

*Gère la construction et le cycle de vie des FOB (création, zone logistique, seuil de destruction).*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDFOBManager` | Retourne le singleton. |
| `getFOBsForCoalition` | `(coalitionId)` | Retourne un tableau des données de FOB actifs pour la coalition donnée. |
| `isInFOBTroopZone` | `(point, coalitionId)` | Retourne `true` si `point` tombe à l'intérieur du rayon de troop pickup d'un FOB actif. |
| `checkSpatialGuards` | `(position, coalitionId)` | Retourne `true` si `position` passe tous les garde-fous de distance pour un nouveau FOB (distance minimale par rapport aux zones existantes). |

## CTLDBeaconManager

*Gère les beacons radio : diffusion VHF/UHF/FM, minuterie de batterie, couche de carte F10.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDBeaconManager` | Retourne le singleton. |
| `createAtPoint` | `(point, coalitionId, countryId, opts) → CTLDBeacon\|nil, raison` | Fait spawn un beacon en un point quelconque, **sans transport ni joueur**. `opts` : `{ name, batteryMinutes (-1 = n'expire jamais), isFOB, frequencies }`. Les champs `vhf` / `uhf` / `fm` (Hz) du beacon retourné sont la réponse pour l'appelant — `beacon:freqText()` les met en forme. N'annonce rien et ne publie aucun événement ; `enabledRadioBeaconDrop` ne s'applique pas (ce réglage gouverne l'action du menu pilote). Retourne `nil` et une chaîne de raison si la demande de fréquence est refusée ou si le spawn échoue. |
| `removeBeacon` | `(name) → boolean` | Retire un beacon par son nom affiché ou par sa clé interne. Silencieux, comme `createAtPoint`. |
| `createAtZone` | `(zoneName, coalitionStr, batteryLife, name)` | Fait spawn un beacon dans une zone de trigger nommée. `coalitionStr` : `"blue"` / `"red"`. `batteryLife` : minutes. `name` (optionnel) : libellé affiché dans la liste F10. Annonce à la coalition et publie `OnBeaconDropped`. |
| `getBeaconsForCoalition` | `(coalitionId)` | Retourne un tableau des données de beacons actifs pour une coalition. |
| `getBeacon` | `(beaconName)` | Retourne la table de données du beacon par son nom interne, ou `nil`. |

```lua
-- Une FARP scriptée place son propre beacon et affiche ses trois fréquences aux pilotes.
local mgr    = CTLDBeaconManager.getInstance()
local beacon = mgr:createAtPoint({ x = 12000, y = 0, z = -4500 },
                                 coalition.side.BLUE, country.id.USA,
                                 { name = "FARP Alpha NDB", batteryMinutes = -1 })
trigger.action.outTextForCoalition(coalition.side.BLUE,
    "FARP Alpha NDB: " .. beacon:freqText(), 20)

-- …et le retire quand la FARP disparaît.
mgr:removeBeacon("FARP Alpha NDB")
```

### Demander des fréquences précises { #beacon-requested-frequencies }

`createAtPoint` tire chacune des trois fréquences au hasard dans le pool. Quand la mission **annonce
en briefing** une fréquence — un canal FM donné à un équipage d'hélicoptère, un NDB imprimé sur une
planchette — passer `opts.frequencies` à la place. N'importe quel sous-ensemble des trois bandes peut
être nommé ; les bandes laissées de côté continuent d'être tirées au hasard.

```lua
local beacon, raison = mgr:createAtPoint(point, coalition.side.BLUE, country.id.USA, {
    name        = "FARP Alpha NDB",
    frequencies = { vhfKHz = 250, fmMHz = 40.5 },   -- l'UHF reste aléatoire
})
if not beacon then
    ctld.utils.log("WARN", "pas de beacon : %s", raison)
end
```

**L'unité fait partie du nom de la clé** — `vhfKHz`, `uhfMHz`, `fmMHz`. C'est l'unité dans laquelle un
mission maker lit une fréquence de beacon (et celle que `freqText()` affiche), alors que le module
stocke des Hz. La plage de chaque bande est assez étroite pour qu'une valeur donnée dans la mauvaise
unité ne puisse pas tomber dans une autre bande : elle est donc refusée, et non acceptée pour autre
chose.

| Clé | Unité | Plage | Pas |
| --- | --- | --- | --- |
| `vhfKHz` | kHz | 200 – 1250 | 10 kHz en dessous de 850, 50 kHz au-dessus |
| `uhfMHz` | MHz | 220 – 398,5 | 0,5 MHz |
| `fmMHz` | MHz | 30 – 75,9 | 0,1 MHz, dans `30–35,9`, `40–45,9`, `50–55,9`, `60–65,9`, `70–75,9` |

Une demande qui ne peut pas être satisfaite **fait échouer tout l'appel** : `createAtPoint` retourne
`nil` et une raison, ne fait rien spawner et ne consomme aucune fréquence. Il ne substitue jamais une
autre fréquence — un beacon qui répond ailleurs que sur la fréquence annoncée est invisible pour le
mission maker et inaudible pour le pilote qui a affiché la fréquence annoncée. Quatre refus :

| Refusé | Exemple | Pourquoi |
| --- | --- | --- |
| Clé inconnue | `{ vhf = 250 }` | L'unité manque dans la clé. L'accepter rendrait une fréquence aléatoire pour une faute de frappe — précisément la panne que cette option supprime. |
| Hors de la bande | `{ vhfKHz = 250000 }` | La forme que prend une erreur d'unité (des Hz là où des kHz étaient demandés, etc.). |
| Absente du pool | `{ vhfKHz = 205 }`, `{ vhfKHz = 440 }` | Hors du pas de la bande, ou l'une des fréquences NDB réelles que le pool VHF retient parce qu'un beacon de la carte l'occupe déjà. |
| Déjà utilisée | une fréquence tenue par un beacon vivant | La collision que le pool existe pour empêcher. |

## CTLDJTACManager

*Gère l'auto-lase JTAC, les corrections de spot, l'orbite, le smoke, le 9-line, la déconfliction multi-JTAC.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDJTACManager` | Retourne le singleton. |
| `autoLase` | `(groupName, laserCode, smoke, lock, colour, radio, orbitParams)` | Active l'auto-lase pour un groupe JTAC ME pré-placé. Tous les paramètres après `groupName` sont optionnels. `laserCode` : 1111–1788. `smoke` : `true` / `false`. `lock` : `"vehicle"` / `"troop"` / `"all"`. `colour` : 0–4. `radio` : table SRS `{freq, mod, name}`. |
| `startLase` | `(groupName, laserCode, smoke, lock, colour, radio, orbitParams)` | Identique à `autoLase` (nom préféré en v2). |
| `stopAutoLase` | `(groupName)` | Arrête l'auto-lase et désenregistre le JTAC. |
| `getJTACByName` | `(groupName)` | Retourne l'instance `CTLDJTAC` pour un nom de groupe, ou `nil`. |
| `killJTAC` | `(groupName, killer)` | Force la destruction d'une unité JTAC et nettoie tout son état. |
| `resumeJTAC` | `(groupName)` | Reprend un JTAC qui était en pause (mode standby). |
| `requestSmoke` | `(groupName)` | Tire du smoke sur la cible actuelle du JTAC (s'il est en train de laser). |
| `registerMMJTAC` | `(group)` | Enregistre manuellement un groupe ME comme JTAC (appelé automatiquement à l'init). |

## CTLDReconManager

*Gère la couche de scan RECON : détection en LOS, marqueurs de carte F10, auto-refresh.*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDReconManager` | Retourne le singleton. |
| `scan` | `(playerUnit, player)` | Déclenche un scan immédiat pour `playerUnit`. Ajoute les ennemis détectés à la couche RECON du joueur. |
| `stopScan` | `(playerUnit, player)` | Arrête l'auto-refresh pour `player` et efface ses marqueurs RECON. |
| `enableAutoRefresh` | `(playerUnit, player)` | Démarre un re-scan périodique pour `player` (intervalle : `reconRefreshInterval`). |
| `disableAutoRefresh` | `(playerUnit, player)` | Arrête le re-scan périodique. |
| `toggleLayer` | `(player, playerUnit, layerId)` | Affiche ou masque une couche RECON nommée sur la carte F10. |
| `getActiveScan` | `(player)` | Retourne la table d'état de scan actuelle pour `player`, ou `nil`. |
| `getPlayerLayers` | `(player)` | Retourne la table des couches de carte pour `player`. |

## CTLDSceneManager

*Exécute des déploiements séquencés dans le temps de statiques et de groupes DCS (FARPs, FOB, minefield…).*

| Method | Signature | Description |
| --- | --- | --- |
| `getInstance` | `() → CTLDSceneManager` | Retourne le singleton. |
| `registerSceneModel` | `(model)` | Enregistre une table de modèle de scène. `model.name` doit être unique. Appelez ceci depuis votre script de mission après le chargement de CTLD. |
| `playScene` | `(unit, modelName, params, onComplete)` | Exécute une scène relative à la position et au cap actuels de `unit`. `params` (optionnel) : données supplémentaires passées aux callbacks `func` des étapes via `ctx.scene._params`. `onComplete` (optionnel) : callback `function()` déclenché après la dernière étape. |
| `playSceneAtPos` | `(modelName, pos, coalitionId, countryId, params)` | Exécute une scène à un point DCS arbitraire. |
| `getModel` | `(name)` | Retourne la table de modèle enregistrée pour `name`, ou `nil`. |
| `getScene` | `(name)` | Retourne l'instance `CTLDScene` active pour `name`, ou `nil`. |
| `isSceneEnabled` | `(name)` | Retourne `true` si le modèle de scène `name` est enregistré et non désactivé. |
| `findNearbyRepackableScenes` | `(pos, radius)` | Retourne un tableau d'objets `CTLDScene` actifs situés à moins de `radius` mètres de `pos` et exposant un hook `onRepack`. |
| `packScene` | `(scene)` | Exécute la séquence de pack : appelle `onRepack`, détruit tous les objets spawn, fait spawn les crates. Retourne `repackData` (peut porter `.warehouseSnapshot`). |

**Champs du modèle de scène :**

```lua
local myScene = {
    name          = "My FARP",         -- unique name, also used as crate `unit` field
    fobCompatible = false,             -- set true to allow as a FOB scene
    onRepack      = function(scene, repackData) ... end,  -- optional: enables Pack Equipt
    steps = {
        -- Polar step: fixed offset from the helicopter
        { objectsDescDbKey = "FARP_Tent",
          polar = { distance = 80, angle = 10 },
          relativeHeadingInDegrees = 90,
          relativeAltitudeInMeters = 0,
          delayAfterPreviousStep   = 2 },

        -- Func-only step: no spawn, just a callback
        { delayAfterPreviousStep = 0,
          func = function(ctx) trigger.action.outText("Done", 5) end },
    }
}
CTLDSceneManager.getInstance():registerSceneModel(myScene)
```

## CTLDCrateAssemblyManager

*Gère l'assemblage en plusieurs parties des systèmes AA, le rearm et la réparation à partir des descripteurs de crates.*

| Method / Field | Signature | Description |
| --- | --- | --- |
| `TEMPLATES` | static table | Règles d'assemblage des systèmes AA (pièces, count, launcher), déclarées statiquement dans `CTLD_aasystem.lua`. Surchargez-le avant l'init de CTLD pour ajouter ou remplacer des systèmes. Chaque entrée : `{ name, side, sectionName, parts = {{DCSTypename, desc, weight, launcher?, amount?, NoCrate?}}, repair = {desc, weight} }`. Les caisses AA déployables sont, elles, des entrées de catalogue ordinaires dans `CTLD_config.yaml` (sections `SAM mid range` / `SAM long range`), et non générées à l'exécution. |
| `getInstance` | `() → CTLDCrateAssemblyManager` | Retourne le singleton. |
| `getTemplateByName` | `(name)` | Retourne la table de template pour `name`, ou `nil`. |
| `getTemplateForUnit` | `(unitName, repairFor)` | Retourne le template qui contient `unitName` comme composant, ou `nil`. |
| `spawnSystemAt` | `(templateName, point, coa, countryId)` | Fait spawn un système AA complet à un point arbitraire (contourne l'exigence de crate — utile pour les systèmes pré-placés par script). |
| `countComplete` | `(coalitionId)` | Retourne le nombre de systèmes AA complets actuellement actifs pour une coalition. |
| `getAllowedCount` | `(coalitionId)` | Retourne la limite de systèmes AA configurée pour une coalition (`AASystemLimitBLUE` / `AASystemLimitRED`). |

## mineFieldScene

*Module (pas un singleton) — appelez les fonctions directement. Pose et dégage des grilles de mines terrestres.*

| Function | Signature | Description |
| --- | --- | --- |
| `setLandMine` | `(unitObj, distFromUnit, nbCols, nbPerCol, colSpacing, rowSpacing) → bool, result` | Déploie une grille de mines terrestres en quinconce devant `unitObj`. Toutes les distances en mètres. Retourne `true, {mines}` en cas de succès, `false, errorString` en cas d'échec. |
| `setLandMineAuto` | `(unitObj, distFromUnit, widthM, lengthM, nbMines) → bool, result` | Variante paramétrique : calcule automatiquement la disposition de la grille à partir des dimensions de la zone et du nombre de mines, puis délègue à `setLandMine`. |
| `clearSet` | `(idx)` | Détruit toutes les mines du set `idx` (index dans `mineFieldScene._sets`) et efface son marqueur F10. |

```lua
-- Deploy ~40 mines in a 50 m wide x 80 m long field starting 30 m ahead
local ok, result = mineFieldScene.setLandMineAuto(
    Unit.getByName("my_helo"), 30, 50, 80, 40)
if not ok then env.error("Minefield error: " .. result) end

-- Clear the first set later
mineFieldScene.clearSet(1)
```

## Legacy wrappers (ctld.*)

Les 22 fonctions globales v1 sont préservées dans `src/legacy/legacy_api.lua` sous forme de
wrappers légers, afin que les missions existantes continuent de fonctionner sans changement.
Chaque wrapper journalise un avertissement de dépréciation et redirige vers le manager v2
correspondant. Voir [Migration v1 → v2](migration-v1-v2.md) pour le guide complet.

| v1 call | v2 equivalent |
| --- | --- |
| `ctld.spawnGroupAtTrigger(side, n, zone, r)` | `CTLDTroopManager.getInstance():spawnGroupAtTrigger(side, n, zone, r)` |
| `ctld.spawnGroupAtPoint(side, n, pt, r)` | `CTLDTroopManager.getInstance():spawnGroupAtPoint(side, n, pt, r)` |
| `ctld.preLoadTransport(unit, n, troops)` | `CTLDTroopManager.getInstance():preLoadTransport(unit, n, troops)` |
| `ctld.loadTransport(unit)` | `CTLDTroopManager.getInstance():loadTransport(unit)` |
| `ctld.unloadTransport(unit)` | `CTLDTroopManager.getInstance():unloadTransport(unit)` |
| `ctld.unloadInProximityToEnemy(unit, dist)` | `CTLDTroopManager.getInstance():unloadInProximityToEnemy(unit, dist)` |
| `ctld.activatePickupZone(zone)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zone, true)` |
| `ctld.deactivatePickupZone(zone)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zone, false)` |
| `ctld.changeRemainingGroupsForPickupZone(z, n)` | `CTLDZoneManager.getInstance():changeRemainingGroups(z, n)` |
| `ctld.activateWaypointZone(zone)` | `CTLDZoneManager.getInstance():activateWaypointZone(zone)` |
| `ctld.deactivateWaypointZone(zone)` | `CTLDZoneManager.getInstance():deactivateWaypointZone(zone)` |
| `ctld.createExtractZone(zone, flag, smoke)` | `CTLDZoneManager.getInstance():createExtractZone(zone, flag, smoke)` |
| `ctld.removeExtractZone(zone, flag)` | `CTLDZoneManager.getInstance():removeExtractZone(zone, flag)` |
| `ctld.countDroppedGroupsInZone(zone, bf, rf)` | `CTLDTroopManager.getInstance():startGroupCountWatcher(zone, bf, rf)` |
| `ctld.countDroppedUnitsInZone(zone, bf, rf)` | `CTLDTroopManager.getInstance():startUnitCountWatcher(zone, bf, rf)` |
| `ctld.cratesInZone(zone, flag)` | `CTLDCrateManager.getInstance():startCrateCountWatcher(zone, flag)` |
| `ctld.spawnCrateAtZone(side, w, zone)` | `CTLDCrateManager.getInstance():spawnCrateAtZone(side, w, zone)` |
| `ctld.spawnCrateAtPoint(side, w, pt, hdg)` | `CTLDCrateManager.getInstance():spawnCrateAtPoint(side, w, pt, hdg)` |
| `ctld.createRadioBeaconAtZone(zone, side, life, name)` | `CTLDBeaconManager.getInstance():createAtZone(zone, side, life, name)` |
| `ctld.JTACAutoLase(group, code, smoke, lock, col, radio)` | `CTLDJTACManager.getInstance():autoLase(group, code, smoke, lock, col, radio)` |
| `ctld.JTACStart(group, code, smoke, lock, col, radio)` | `CTLDJTACManager.getInstance():startLase(group, code, smoke, lock, col, radio)` |
| `ctld.JTACAutoLaseStop(group)` | `CTLDJTACManager.getInstance():stopAutoLase(group)` |

> `ctld.addCallback()` n'est **pas** wrappé. Utilisez plutôt
> `EventDispatcher.getInstance():subscribe(eventName, handler)` — voir [Events](events.md).
