# Événements { #events }

CTLD dispose de **deux canaux d'événements distincts**, qui ne se chevauchent jamais :

| Canal | Classe | Transporte | Page source |
| --- | --- | --- | --- |
| Événements métier | `EventDispatcher` | Événements de domaine CTLD (`OnCrateLoaded`, `OnTroopsDeployed`, …) | cette page |
| Événements moteur DCS | `CTLDDCSEventBridge` | `S_EVENT_*` bruts issus du simulateur | voir [Architecture](architecture.md) |

`EventDispatcher` est le bus pub/sub interne que les managers utilisent pour signaler les
changements de domaine entre eux et aux scripts de mission externes. Les événements moteur DCS
(`S_EVENT_DEAD`, `S_EVENT_BIRTH`, …) n'y transitent **jamais** : ils arrivent via
`CTLDDCSEventBridge`, sont traités par le manager concerné, puis seulement ré-émis comme
événements métier lorsque c'est utile.

## L'API `EventDispatcher` { #the-eventdispatcher-api }

`EventDispatcher` est un singleton déclaré dans `src/CTLD_core.lua`. On l'obtient avec
`getInstance()` ; il n'a pas de point d'entrée `:new()`.

```lua
local ed = EventDispatcher.getInstance()
```

### `subscribe(eventName, callback)`

Enregistre un callback pour un événement nommé. Le callback reçoit la table de payload de
l'événement comme unique argument.

```lua
EventDispatcher.getInstance():subscribe("OnCrateLoaded", function(evt)
    -- evt.crateName, evt.carrierUnitName, evt.coalition, ...
end)
```

Le même callback peut être enregistré plusieurs fois ; chaque enregistrement produit un appel
supplémentaire lors de la publication. Il incombe aux appelants d'éviter les abonnements en
double accidentels. Un `callback` qui n'est pas une fonction est ignoré silencieusement.

### `unsubscribe(eventName, callback)`

Retire un callback précédemment enregistré. L'argument `callback` doit être la **référence de
fonction exactement identique** utilisée au moment de l'abonnement (conservez une référence
locale si vous comptez vous désabonner). Seule la dernière occurrence correspondante enregistrée
est retirée par appel.

```lua
local function onLoaded(evt) --[[ ... ]] end
local ed = EventDispatcher.getInstance()
ed:subscribe("OnCrateLoaded", onLoaded)
-- plus tard :
ed:unsubscribe("OnCrateLoaded", onLoaded)
```

### `unsubscribeAll(eventName)`

Supprime tous les abonnés d'un événement — utilisé à la fermeture d'un module.

```lua
EventDispatcher.getInstance():unsubscribeAll("OnCrateLoaded")
```

### `publish(eventName, payload)`

Distribue `payload` à chaque abonné de `eventName`.

```lua
EventDispatcher.getInstance():publish("OnMySomethingHappened", {
    unitName  = "UH-1H-1",
    coalition = coalition.side.BLUE,
    timestamp = timer.getAbsTime(),
})
```

Deux garanties comptent pour les auteurs :

- **Isolation des callbacks.** Chaque abonné est invoqué dans un `pcall`. Un callback qui lève
  une erreur est journalisé (`ERROR`, `EventDispatcher:publish [<event>] callback error: …`) et
  **n'interrompt pas** les abonnés restants.
- **Sûreté vis-à-vis de la réentrance.** La liste des abonnés est copiée avant l'itération, si
  bien qu'un callback peut sans risque `subscribe` ou `unsubscribe` pendant la distribution sans
  affecter la distribution en cours.

Publier un événement sans abonné est une opération sans effet (retour anticipé peu coûteux).

### Convention de payload { #payload-convention }

Par convention, chaque événement CTLD porte un champ `timestamp` positionné à
`timer.getAbsTime()`. Au-delà, les champs sont propres à chaque événement — voir le catalogue
ci-dessous. Les managers publient via de fines fonctions utilitaires privées
(`CTLDCrateManager:_publish`, `CTLDJTACManager:_publishEvent`) qui transmettent à
`EventDispatcher:publish` ; les abonnés ne voient aucune différence.

### Migration depuis le callback v1 { #migrating-from-the-v1-callback }

La v1 utilisait un unique `ctld.addCallback` fourre-tout avec une chaîne de tests
`if event.id == …`. La v2 le remplace par des abonnements ciblés — voir
[Migration v1 → v2](migration-v1-v2.md) pour l'exemple complet détaillé.

```lua
-- v2 : un abonnement par événement d'intérêt, pas de chaîne de dispatch par id
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    -- evt.crateName, evt.coalition, evt.spawnedBy, evt.position
end)
```

## Catalogue des événements { #event-catalogue }

Les événements sont regroupés par domaine de publication. Chaque payload porte aussi
`timestamp` (omis des tableaux sauf s'il s'agit du seul champ). « Published by » nomme le manager
et la ou les méthodes qui émettent l'événement, vérifiés dans `src/`.

Presque tous les noms d'événements suivent la convention `On<Something>`. Les deux exceptions sont
les événements RECON FARP (`ReconFarpDetected`, `ReconFarpLost`), qui n'ont pas de préfixe `On` —
abonnez-vous à eux par leurs noms exacts.

### Événements beacon (5) { #beacon-events-5 }

#### `OnBeaconDropped`
Un radio beacon est déployé (par un joueur ou depuis une zone).

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | Nom du joueur, ou `"MissionMaker"` si depuis une zone |
| `playerUnit` | Unit ou nil | Objet Unit DCS |
| `coalition` | number | ID de coalition |
| `beacon` | table | Payload beacon complet (voir note) |

Sous-table `beacon` : `{ beaconName, name, position (vec3), mgrsCoords, frequencies { vhf, uhf, fm }, battery { remainingTime, wasInfinite, duration, infinite } }`

**Published by** : `CTLDBeaconManager:dropBeacon()`, `:createAtZone()`

#### `OnBeaconRemoved`
Un joueur retire manuellement le beacon le plus proche.

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `beacon` | table | `{ beaconName, name, position, mgrsCoords, frequencies, battery, distance }` |
| `reason` | string | `"manual"` |
| `frequenciesFreed` | table | `{ vhf, uhf, fm }` |

**Published by** : `CTLDBeaconManager:removeClosestBeacon()`

#### `OnBeaconDestroyed`
La batterie d'un beacon s'épuise, ou ses units DCS sont détruites.

| Champ | Type | Description |
| --- | --- | --- |
| `beacon` | table | `{ beaconName, name, position, mgrsCoords, frequencies, battery, unitsAlive, durationAlive }` |
| `reason` | string | `"battery"` ou `"units"` |
| `frequenciesFreed` | table | `{ vhf, uhf, fm }` |

**Published by** : `CTLDBeaconManager:_refreshAll()` (tick périodique — batterie épuisée ou trop peu d'units radio en vie)

#### `OnBeaconRefreshed`
Émis à chaque tick du beacon-manager avec un résumé de tous les beacons actifs.

| Champ | Type | Description |
| --- | --- | --- |
| `beacons` | table | Tableau de payloads beacon |
| `totalBeaconsRefreshed` | number | |
| `totalBeaconsDestroyed` | number | Beacons détruits durant ce tick |

**Published by** : `CTLDBeaconManager:_refreshAll()`

#### `OnBeaconLayerToggled`
Un joueur bascule la couche beacon de la carte F10.

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `previousState` | bool | |
| `newState` | bool | |
| `action` | string | `"enabled"` ou `"disabled"` |
| `beaconsDisplayed` | table | Tableau des beacons désormais affichés |
| `totalBeaconsDisplayed` | number | |

**Published by** : `CTLDBeaconManager:toggleLayer()`

### Événements crate (10) { #crate-events-10 }

#### `OnCrateSpawned`
Une crate quelconque apparaît sur la carte.

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | Objet crate interne |
| `crateName` | string | Identifiant unique de la crate |
| `descriptor` | table | Descripteur de crate |
| `position` | vec3 | |
| `coalition` | number | |
| `spawnedBy` | string ou nil | Nom du joueur / mission-maker |
| `spawnMethod` | string | `"request_crate"`, `"parachute_drop"`, `"slingload_cut"`, `"mm_late_activation"`, … |

**Published by** : `CTLDCrateManager:spawnCrate()`, `:unloadCrate()`, `:cutSlingload()`, `:parachuteCrates()`

#### `OnCrateLoaded`
Une crate est ramassée (slingload ou cargo natif DCS).

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `carrierUnitName` | string | Nom de l'unit de transport |
| `coalition` | number | |
| `descriptor` | table | |
| `trigger` | string | `"slingload"` ou `"dcs_native"` |
| `method` | string ou nil | `"dcs_native"` (absent pour le slingload) |

**Published by** : `CTLDCrateManager:loadCrate()`, `:checkHoverStatus()`, `:_checkNativeDCSCargo()`

#### `OnCrateUnloaded`
Une crate est larguée ou déchargée (pas unpacked).

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `descriptor` | table | |
| `method` | string ou nil | `"dcs_native"` si natif, absent pour le slingload |

**Published by** : `CTLDCrateManager:unloadCrate()`, `:cutSlingload()`, `:_checkNativeDCSCargo()`

#### `OnCrateLost`
Une crate est détruite par slingload en survitesse ou par l'impact d'un cut-slingload.

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `transport` | Unit | L'aéronef porteur |
| `trigger` | string | `"slingload_overspeed"` ou `"slingload_cut_impact"` |

**Published by** : `CTLDCrateManager:checkHoverStatus()`, `:cutSlingload()`

#### `OnCrateCleared`
Une crate est retirée du monde (unpacked, détruite, ou chargée nativement).

| Champ | Type | Description |
| --- | --- | --- |
| `crateName` | string | |
| `position` | vec3 | Dernière position connue |
| `coalition` | number | |
| `descriptor` | table | |
| `reason` | string | `"destroyed"`, `"unpacked"`, ou `"loaded"` |

**Published by** : `CTLDCrateManager:cutSlingload()`, `:loadCrate()`, `:unpackCrate()`, `:destroyCrate()`

#### `OnCrateUnpacked`
Une crate est unpacked avec succès (assemblée en équipement).

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | Emplacement d'unpack |
| `coalition` | number | |
| `carrierUnitName` | string ou nil | Unit effectuant l'unpack |

**Published by** : `CTLDCrateManager:unpackCrate()`

#### `OnCrateDestroyed`
Une crate est détruite à l'impact d'un largage en haute altitude (distinct de la perte en slingload).

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `reason` | string | `"drop_impact"` |

**Published by** : rien — **cet événement n'est plus émis.** Son seul émetteur était
`CTLDCrateManager:dropCrate()`, une méthode inatteignable supprimée dans `FIX-CATALOGUE-TRUTH` : aucune
entrée de menu ne l'appelait, et le largage en vol qu'elle implémentait est assuré par
`parachuteCrates()`. Le nom et la charge utile de l'événement restent documentés ici afin qu'un plugin
qui s'y abonne sache que son handler ne se déclenchera pas ; rien dans le moteur ne l'émet depuis.

#### `OnCrateParachuting`
Une crate est larguée en mode parachute-drop.

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `dropPosition` | vec3 | Position au largage |
| `landingPosition` | vec3 | Position d'atterrissage estimée |
| `altitude` | number | AGL en mètres |
| `descentTime` | number | Secondes estimées jusqu'à l'atterrissage |
| `carrierUnitName` | string | |
| `player` | string | |

**Published by** : `CTLDCrateManager:parachuteCrates()`

#### `OnCrateParachuteLanded`
Une crate parachutée atterrit (asynchrone, après le sondage de descente).

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | Position d'atterrissage |
| `coalition` | number | |
| `startAltitude` | number | AGL au largage |

**Published by** : `CTLDCrateManager:parachuteCrates()` (callback de sondage d'atterrissage)

#### `OnMMCrateDetected`
Une crate pré-placée par le mission-maker est enregistrée (y compris à l'activation tardive).

| Champ | Type | Description |
| --- | --- | --- |
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | |
| `coalition` | number | |

**Published by** : `CTLDCrateManager:registerMMCrate()`

### Événements vehicle (9) { #vehicle-events-9 }

#### `OnVehicleSpawnedForTransport`
Un véhicule est spawné à l'état `WAITING`, prêt pour le transport (Request Equipment).

| Champ | Type | Description |
| --- | --- | --- |
| `vehicleId` | string | ID de véhicule CTLD interne |
| `vehicle` | Unit | Objet Unit DCS |
| `vehicleType` | string | Nom de type DCS |
| `spawner` | string ou nil | Nom du joueur |
| `logisticZone` | table ou nil | Zone où le spawn a eu lieu |
| `spawnMethod` | string | `"request_vehicle"` |
| `position` | vec3 | |

**Published by** : `CTLDVehicleSpawner:spawnVehicleForTransport()`

#### `OnVehicleLoaded`
Un véhicule est chargé dans un transport.

| Champ | Type | Description |
| --- | --- | --- |
| `vehicleId` | string | |
| `ctldVehicleObject` | CTLDVehicle | |
| `dcsUnitObject` | Unit ou nil | Présent si chargement natif |
| `vehicleType` | string | |
| `transportUnitObject` | Unit | |
| `player` | string | |
| `method` | string | `"slingload"` ou `"dcs_native"` |
| `spawnMethod` | string | |
| `position` | vec3 | |
| `transportPosition` | vec3 | |

**Published by** : `CTLDVehicleSpawner:loadVehicle()`

#### `OnVehicleUnloaded`
Un véhicule est déchargé d'un transport. Mêmes champs que `OnVehicleLoaded`.

**Published by** : `CTLDVehicleSpawner:unloadVehicle()`

#### `OnVehiclePacked`
Un véhicule est packed en crates.

| Champ | Type | Description |
| --- | --- | --- |
| `vehicleType` | string | |
| `descriptor` | table | Descripteur de crate utilisé |
| `transport` | string | Nom de l'unit de transport |
| `player` | string ou nil | |
| `cratesSpawned` | number | Nombre de crates spawnées |

**Published by** : `CTLDVehicleSpawner:packVehicle()`

#### `OnVehicleParachuting`
Un véhicule est largué en mode parachute.

| Champ | Type | Description |
| --- | --- | --- |
| `vehicle` | CTLDVehicle | |
| `transport` | string | Nom de l'unit de transport |
| `player` | string | |
| `altitude` | number | AGL en mètres |
| `dropPosition` | vec3 | |
| `estimatedLandingPos` | vec3 | |
| `estimatedLandingTime` | number | `timer.getAbsTime() + descentTime` |

**Published by** : `CTLDVehicleSpawner:parachuteVehicle()`

#### `OnVehicleParachuteLanded`
Un véhicule parachuté atterrit.

| Champ | Type | Description |
| --- | --- | --- |
| `vehicle` | CTLDVehicle | |
| `position` | vec3 | |
| `transport` | string | |
| `player` | string | |
| `startAltitude` | number | AGL au largage |

**Published by** : `CTLDVehicleSpawner:parachuteVehicle()` (callback d'atterrissage)

#### `OnVehicleDead`
Un véhicule CTLD suivi est détruit.

| Champ | Type | Description |
| --- | --- | --- |
| `vehicleId` | string | |
| `vehicle` | Unit | Initiateur de `S_EVENT_DEAD` |
| `vehicleType` | string | |
| `coalition` | number ou nil | |
| `position` | vec3 | |
| `durationAlive` | number | Secondes depuis le spawn |

**Published by** : `CTLDVehicleSpawner:onDead()` (handler `S_EVENT_DEAD`)

#### `OnGroundUnitSpawned` / `OnGroundUnitRemoved`
Une unit au sol suivie par CTLD apparaît ou disparaît. Ces deux événements sont transversaux —
le vehicle spawner et le crate manager publient tous deux `OnGroundUnitSpawned`.

| Champ | Type | Description |
| --- | --- | --- |
| `vehicleType` | string | Nom de type DCS |
| `position` | vec3 | |
| `coalitionId` | number | (`OnGroundUnitSpawned` uniquement) |
| `reason` | string | (`OnGroundUnitRemoved` uniquement) `"loaded"`, `"packed"`, `"dead"` |

**Published by** :

- `OnGroundUnitSpawned` : `CTLDVehicleSpawner:_spawnGroundUnit()`, `CTLDCrateManager:_spawnUnpacked()`
- `OnGroundUnitRemoved` : `CTLDVehicleSpawner:loadVehicle()`, `:onDead()`, `:packVehicle()`

### Événements troop (2) { #troop-events-2 }

#### `OnTroopsDeployed`
Des troops sont déployées par parachute.

| Champ | Type | Description |
| --- | --- | --- |
| `troops` | CTLDTroopGroup | |
| `carrierUnitName` | string | |
| `player` | string | |
| `trigger` | string | `"parachute"` |
| `destination` | table | `{ type="combat", troopZone=nil }` |

**Published by** : `CTLDTroopManager:parachuteTroops()`

#### `OnTroopsParachuteLanded`
Des troops parachutées atterrissent (asynchrone, après le timer de descente).

| Champ | Type | Description |
| --- | --- | --- |
| `troops` | CTLDTroopGroup | |
| `spawnedGroup` | Group | Group DCS spawné au sol |
| `positions` | table | Tableau de vec3, un par soldat |
| `transport` | string | |
| `player` | string | |
| `startAltitude` | number | |

**Published by** : `CTLDTroopManager:parachuteTroops()` (callback d'atterrissage)

### Événements JTAC (8) { #jtac-events-8 }

#### `OnJTACSpawned`
Un JTAC est spawné — véhicule, drone, ou soldat d'infanterie au sein d'un troop group.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.groupId` | number | |
| `jtac.unitName` | string | |
| `jtac.unitId` | number ou nil | |
| `jtac.unitType` | string ou nil | |
| `jtac.coalition` | number | |
| `jtac.position` | vec3 ou nil | |
| `jtac.isFlying` | bool | `true` pour les JTAC de type drone |
| `jtac.isInfantry` | bool | |
| `jtac.route` | table ou nil | Route de patrouille du drone |
| `spawner` | string | Nom de l'unit du joueur ou `"MissionMaker"` |
| `laserCode` | number | Code laser assigné (`0` si aucun) |
| `smokeEnabled` | bool | |
| `smokeColor` | string ou nil | |
| `lockMode` | string | Réglage du lock-mode du JTAC |
| `radio` | table ou nil | `{ freq, modulation }` |

**Published by** : `CTLDJTACManager:spawnJTAC()`, `:startLaseTroopUnit()` (JTAC infanterie)

#### `OnJTACInTransit`
Un JTAC de type véhicule est embarqué dans un transport.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `transport` | Unit | |

**Published by** : `CTLDJTACManager:setJTACInTransit()`

#### `OnJTACLaseStart`
Un JTAC acquiert une cible et commence à la laser.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.unitName` | string | |
| `jtac.position` | vec3 | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.unitId` | number | |
| `target.unitType` | string | |
| `target.coalition` | number | |
| `target.position` | vec3 | |
| `target.priority` | number | Score de priorité de la cible |
| `target.selectionMethod` | string | `"auto_nearest"` ou `"manual"` |
| `target.wasManuallySelected` | bool | |
| `laserCode` | number | |
| `lockMode` | string | |
| `distance` | number | Mètres du JTAC à la cible |
| `lineOfSight` | bool | LOS confirmée au moment du lock |
| `radio` | table ou nil | |
| `message` | string ou nil | Message de statut affiché au joueur |

**Published by** : `CTLDJTACManager:_autoLaseLoop()` (à l'acquisition)

#### `OnJTACTargetLased`
Émis à chaque cycle de lase tant qu'un JTAC lase activement.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.unitName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | Position corrigée pour les drones |
| `laserCode` | number | |

**Published by** : `CTLDJTACManager:_autoLaseLoop()` (chaque cycle)

#### `OnJTACLaseStop`
Un JTAC arrête de laser.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `jtac.laserCode` | number | |
| `target.unitName` | string ou nil | |
| `target.unitType` | string | |
| `target.lastKnownPosition` | vec3 | |
| `reason` | string | `"target_dead"`, `"out_of_range"`, `"manual"` |

**Published by** : `CTLDJTACManager:_stopLaseAndPublish()`

#### `OnJTACOrbitStart`
Un JTAC de type drone commence son orbite au-dessus d'une cible.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | |

**Published by** : `CTLDJTACManager:_updateOrbit()`

#### `OnJTACSmokeTarget`
Un JTAC fume sa cible courante à la demande du joueur.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | |
| `smokePosition` | vec3 | Point de spawn réel de la fumée |
| `smokeColor` | number | Constante `trigger.smokeColor.*` |

**Published by** : `CTLDJTACManager:requestSmoke()`

#### `OnJTACDead`
Un JTAC est détruit au combat.

| Champ | Type | Description |
| --- | --- | --- |
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `jtac.laserCode` | number | |
| `killer` | table ou nil | `{ unitName, playerName }` |
| `lastTarget` | table ou nil | Dernière cible lasée |

**Published by** : `CTLDJTACManager:killJTAC()` (handler `S_EVENT_DEAD`)

> Packer un véhicule JTAC n'est **pas** une mort — `OnJTACDead` ne se déclenche pas lorsqu'un
> véhicule JTAC est ré-embarqué.

### Événements RECON (8) { #recon-events-8 }

#### `ReconFarpDetected`
Un joueur en mode RECON détecte un FARP ou un FOB ennemi. (Pas de préfixe `On` — nom historique.)

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | Nom du joueur |
| `playerUnit` | Unit | Objet Unit DCS |
| `coalition` | number | ID de la coalition ennemie |
| `playerCoalition` | number | ID de la coalition du joueur |
| `position` | vec3 | Position du FARP/FOB |
| `id` | string | ID de mark interne (mis en correspondance par `ReconFarpLost`) |

**Published by** : `CTLDReconManager:_syncFarpMarks()`

#### `ReconFarpLost`
Un FARP/FOB ennemi précédemment détecté quitte le rayon de scan ou est détruit. (Pas de préfixe
`On`.)

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `id` | string | ID de mark correspondant à l'événement `ReconFarpDetected` |

**Published by** : `CTLDReconManager:_syncFarpMarks()`

#### `OnReconScan`
Un joueur effectue un scan RECON.

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `position` | vec3 | Position du scanner |
| `altitude` | number | AGL en mètres |
| `searchRadius` | number | Mètres |
| `activeLayers` | table | Tableau des descripteurs de couches actives |
| `targets` | table | Tableau des cibles détectées |
| `targetsByLayer` | table | Map `layerId → targets` |
| `totalTargetsDetected` | number | |
| `totalMarksCreated` | number | |

**Published by** : `CTLDReconManager:scan()`

#### `OnReconScanRefresh`
Émis à chaque cycle d'auto-refresh avec des informations de delta.

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `position` | vec3 | |
| `altitude` | number | |
| `activeLayers` | table | |
| `targets` | table | Toutes les cibles courantes |
| `newTargets` | table | Nouvellement détectées durant ce cycle |
| `movedTargets` | table | Cibles qui ont bougé |
| `lostTargets` | table | Cibles qui ont disparu |
| `totalTargetsCurrent` | number | |
| `totalTargetsNew` | number | |
| `totalTargetsMoved` | number | |
| `totalTargetsLost` | number | |

**Published by** : `CTLDReconManager:_doRefresh()` (timer d'auto-refresh)

#### `OnReconHideTargets`
Un joueur arrête le RECON et tous les marks sont retirés.

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `marksRemoved` | table | Tableau des enregistrements de marks retirés |
| `totalMarksRemoved` | number | |
| `refreshStopped` | bool | Indique si l'auto-refresh était en cours |

**Published by** : `CTLDReconManager:stopScan()`

#### `OnReconLayerToggled`
Un joueur active/désactive une couche de détection RECON.

| Champ | Type | Description |
| --- | --- | --- |
| `layerId` | string | ex. `"infantry"`, `"ground_vehicles"` |
| `layerName` | string | Nom de couche lisible |
| `visible` | bool | Nouvel état |
| `coalition` | number | |
| `player` | string | |

**Published by** : `CTLDReconManager:toggleLayer()`

#### `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled`
Un joueur active ou désactive l'auto-refresh RECON.

| Champ | Type | Description |
| --- | --- | --- |
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `previousState` | bool | |
| `newState` | bool | |
| `targetsCount` | number | Nombre de cibles courant |
| `refreshInterval` | number | Secondes entre les refreshs |

**Published by** : `CTLDReconManager:enableAutoRefresh()`, `:disableAutoRefresh()`

### Événements FOB (2) { #fob-events-2 }

#### `OnFOBDeployed`
Un FOB est entièrement assemblé et déployé.

| Champ | Type | Description |
| --- | --- | --- |
| `fob.fobId` | string | |
| `fob.name` | string | |
| `fob.coalitionId` | number | |
| `cratesUsed` | table | Tableau des crates consommées |
| `totalCratesUsed` | number | |
| `position` | vec3 | |
| `sceneObjects` | table | StaticObjects DCS spawnés |
| `logisticZone` | table | LGZ créée `{ name, radius, type="static" }` |
| `player` | string | Nom de l'unit du joueur ayant déclenché le déploiement |

**Published by** : `CTLDFOBManager:_registerDeployedFOB()`

#### `OnFOBDestroyed`
L'intégrité d'un FOB tombe sous le seuil de destruction.

| Champ | Type | Description |
| --- | --- | --- |
| `fob.fobId` | string | |
| `fob.name` | string | |
| `fob.coalitionId` | number | |
| `position` | vec3 | |
| `destruction.killerUnit` | Unit ou nil | |
| `destruction.killerCoalition` | number ou nil | |
| `destruction.objectsDestroyed` | number | |
| `destruction.objectsTotal` | number | |
| `destruction.destructionThreshold` | number | Config `fobDestructionThreshold` (défaut `0.5`) |
| `destruction.integrityPercent` | number | `0.0`–`1.0` au moment de l'événement |
| `logisticZone` | table | `{ name, wasActive=true }` |
| `durationAlive` | number | Secondes du déploiement à la destruction |

**Published by** : `CTLDFOBManager:_destroyFOB()` (depuis le handler `S_EVENT_DEAD` `onDead()`)

### Événements AA system (3) { #aa-system-events-3 }

#### `OnAASystemDeployed`
Un système AA est entièrement assemblé.

| Champ | Type | Description |
| --- | --- | --- |
| `systemName` | string | `"HAWK"`, `"PATRIOT"`, … |
| `groupName` | string | Nom de group DCS |
| `heli` | Unit ou nil | `nil` si déployé par l'IA |
| `coalition` | number | |
| `position` | vec3 | |

**Published by** : `CTLDCrateAssemblyManager:spawnSystemAt()`, `:_assemble()`

#### `OnAASystemRearmed`
Un lanceur est ajouté à un système AA existant.

| Champ | Type | Description |
| --- | --- | --- |
| `systemName` | string | |
| `groupName` | string | |
| `heli` | Unit | |
| `coalition` | number | |

**Published by** : `CTLDCrateAssemblyManager:_rearm()`

#### `OnAASystemRepaired`
Un système AA complet est réparé et re-spawné. Mêmes champs que `OnAASystemRearmed`.

**Published by** : `CTLDCrateAssemblyManager:_repair()`

### Événements zone (2) { #zone-events-2 }

#### `OnZoneSmokeRefreshed`
Émis à chaque cycle du timer de smoke-refresh.

| Champ | Type | Description |
| --- | --- | --- |
| `troopZones` | table | Tableau de payloads troop-zone |
| `logisticZones` | table | Tableau de payloads logistic-zone |
| `refreshInterval` | number | Secondes |

**Published by** : `CTLDZoneManager:_scheduleSmoke()` (timer périodique)

#### `OnLogisticZoneUpdated`
Des units de zone dynamique sont ajoutées ou retirées.

| Champ | Type | Description |
| --- | --- | --- |
| `zones` | table | Toutes les zones après mise à jour |
| `unitsAdded` | table | Units nouvellement enregistrées |
| `unitsRemoved` | table | Units ayant quitté la zone |

**Published by** : `CTLDZoneManager:_publishLogisticZoneUpdated()`

### Résumé du catalogue { #catalogue-summary }

| Domaine | Nombre |
| --- | --- |
| Beacon | 5 |
| Crate | 10 |
| Vehicle | 9 |
| Troop | 2 |
| JTAC | 8 |
| RECON | 8 |
| FOB | 2 |
| AA System | 3 |
| Zone | 2 |
| **Total** | **49** |

Une dizaine d'événements environ ont des abonnés internes (rafraîchissement de menu et
coordination entre managers) ; les autres sont publiés purement pour la consommation par le
mission-maker et n'ont aucun listener interne tant que vous ne vous y abonnez pas.

## Le pont d'événements DCS (à titre de contraste) { #the-dcs-event-bridge-for-contrast }

Les événements moteur DCS ne transitent **pas** par `EventDispatcher`. Un unique singleton
`CTLDDCSEventBridge` enregistre un seul `world.addEventHandler` et route chaque `S_EVENT_*` vers
les managers qui s'y sont enregistrés, via `bridge:register(target, eventId, "methodName")`. Le
pont ne filtre rien au-delà de l'id d'événement — chaque manager filtre en interne. Voir
[Architecture](architecture.md) pour la conception de `CTLDDCSEventBridge`.

Les événements moteur actuellement traités, et par qui :

| Événement DCS | Handler(s) |
| --- | --- |
| `S_EVENT_PLAYER_ENTER_UNIT` | `CTLDPlayerTracker:onPlayerEnterUnit()`, `CTLDPlayerManager:onPlayerEnterUnit()` |
| `S_EVENT_PLAYER_LEAVE_UNIT` | `CTLDPlayerTracker:onPlayerLeaveUnit()`, `CTLDPlayerManager:onPlayerLeaveUnit()` |
| `S_EVENT_BIRTH` | `CTLDPlayerTracker:onBirth()`, `CTLDCrateManager:onBirth()`, `CTLDJTACManager:onBirth()`, `CTLDVehicleSpawner:onBirth()` |
| `S_EVENT_LAND` | `CTLDPlayerManager:onLand()`, `CTLDCoreManager:onAILand()` |
| `S_EVENT_TAKEOFF` | `CTLDPlayerManager:onTakeoff()` |
| `S_EVENT_DEAD` | `CTLDTroopManager:onUnitDead()` + `:onTransportDead()`, `CTLDVehicleSpawner:onDead()`, `CTLDCrateManager:onCrateDead()`, `CTLDFOBManager:onDead()`, `CTLDZoneManager:onDead()` |

> **`S_EVENT_STATIC_DEAD` — un événement synthétique.** `S_EVENT_DEAD` n'est pas fiable pour les
> objets statiques et de base. `CTLDStaticWatcher` sonde les objets enregistrés sur un timer d'1 s
> et, lorsque l'un d'eux disparaît, distribue un `S_EVENT_STATIC_DEAD` synthétique (payload
> `{ id, meta }`) via `EventDispatcher`. Il circule sur le bus métier mais n'est ni un événement
> moteur DCS ni un événement de domaine `On*`.
