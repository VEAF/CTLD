# Migration v1 → v2

CTLD v2 est une réécriture modulaire, mais la surface publique de la v1 est préservée. Les missions
qui appellent les fonctions globales `ctld.*` d'origine depuis un déclencheur **DO SCRIPT**
continuent de fonctionner sans modification — chaque point d'entrée v1 survit sous la forme d'un
wrapper léger qui transmet l'appel au manager v2 correspondant et journalise un avertissement de
dépréciation. Cette page explique le principe des wrappers, donne la correspondance complète v1 → v2,
et montre comment porter le seul construct qui n'est *pas* wrappé : le callback fourre-tout.

## Principe des wrappers { #wrapper-principle }

Les 22 fonctions globales v1 (`ctld.spawnGroupAtTrigger`, `ctld.JTACAutoLase`, …) résident dans
`src/legacy/legacy_api.lua`. Chaque wrapper fait deux choses :

- il transmet l'appel, argument pour argument, à la méthode équivalente du manager v2 obtenue via
  `Manager.getInstance()` ;
- il journalise un avertissement de dépréciation au niveau `WARN` via `ctld.logWarning()`, de sorte
  qu'il apparaisse à la fois dans `DCS.log` et `CTLD.log`.

Il n'y a aucun changement de comportement — le wrapper est un pur délégué. Les missions legacy
tournent telles quelles ; les avertissements sont une incitation à migrer, pas une erreur.

```lua
--- @deprecated Use CTLDJTACManager:autoLase()
function ctld.JTACAutoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
    ctld.logWarning("DEPRECATED: ctld.JTACAutoLase — use CTLDJTACManager:autoLase()")
    CTLDJTACManager.getInstance():autoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
end
```

Le fichier legacy est chargé en dernier (après tous les managers, juste avant
`CTLD_userConfig.lua`) afin que chaque manager cible soit défini au moment où un wrapper peut être
appelé.

## Table de migration { #migration-table }

Remplacez chaque appel v1 `ctld.*` par la forme v2 sur la droite. L'ordre et les noms des arguments
ci-dessous correspondent aux signatures réelles des wrappers dans `src/legacy/legacy_api.lua` —
certaines documentations legacy citaient un ordre différent.

### Troops / transport — `CTLDTroopManager`

| Appel v1 | Équivalent v2 |
| --- | --- |
| `ctld.spawnGroupAtTrigger(side, number, triggerName, searchRadius)` | `CTLDTroopManager.getInstance():spawnGroupAtTrigger(side, number, triggerName, searchRadius)` |
| `ctld.spawnGroupAtPoint(side, number, point, searchRadius)` | `CTLDTroopManager.getInstance():spawnGroupAtPoint(side, number, point, searchRadius)` |
| `ctld.preLoadTransport(unitName, number, troops)` | `CTLDTroopManager.getInstance():preLoadTransport(unitName, number, troops)` |
| `ctld.loadTransport(unitName)` | `CTLDTroopManager.getInstance():loadTransport(unitName)` |
| `ctld.unloadTransport(unitName)` | `CTLDTroopManager.getInstance():unloadTransport(unitName)` |
| `ctld.unloadInProximityToEnemy(unitName, distance)` | `CTLDTroopManager.getInstance():unloadInProximityToEnemy(unitName, distance)` |

### Zones — `CTLDZoneManager`

| Appel v1 | Équivalent v2 |
| --- | --- |
| `ctld.activatePickupZone(zoneName)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zoneName, true)` |
| `ctld.deactivatePickupZone(zoneName)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zoneName, false)` |
| `ctld.changeRemainingGroupsForPickupZone(zoneName, amount)` | `CTLDZoneManager.getInstance():changeRemainingGroups(zoneName, amount)` |
| `ctld.activateWaypointZone(zoneName)` | `CTLDZoneManager.getInstance():activateWaypointZone(zoneName)` |
| `ctld.deactivateWaypointZone(zoneName)` | `CTLDZoneManager.getInstance():deactivateWaypointZone(zoneName)` |
| `ctld.createExtractZone(zone, flagNumber, smoke)` | `CTLDZoneManager.getInstance():createExtractZone(zone, flagNumber, smoke)` |
| `ctld.removeExtractZone(zone, flagNumber)` | `CTLDZoneManager.getInstance():removeExtractZone(zone, flagNumber)` |
| `ctld.countDroppedGroupsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager.getInstance():startGroupCountWatcher(zone, blueFlag, redFlag)` |
| `ctld.countDroppedUnitsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager.getInstance():startUnitCountWatcher(zone, blueFlag, redFlag)` |

Deux opérations de zone n'ont pas de prédécesseur v1 et ne sont accessibles que via l'API v2 :

| Nouveau en v2 | Objet |
| --- | --- |
| `CTLDZoneManager.getInstance():activateLogisticZone(name)` | Activer une zone logistique (spawn de crate) |
| `CTLDZoneManager.getInstance():deactivateLogisticZone(name)` | Désactiver une zone logistique |

> **Note.** `activatePickupZone` / `deactivatePickupZone` et les deux helpers de comptage des largages
> ne correspondent pas à des méthodes v2 de même nom. L'activation de pickup est désormais une bascule
> unique, `setTroopZoneActive(name, active)`, et les helpers de comptage ont été déplacés vers
> `CTLDTroopManager` sous les noms `startGroupCountWatcher` / `startUnitCountWatcher`.

#### `dropOffZones` a disparu — utilisez une entrée `aiZones` { #dropoffzones-is-gone-use-an-aizones-entry }

**En v1.** `dropOffZones` listait des enregistrements `{ nom de zone, couleur de fumigène, camp }` et
faisait deux choses : un **transport IA** chargé de troupes ou d'un véhicule se déchargeait
automatiquement en atterrissant à l'intérieur, et la zone était **fumigénée** dans sa couleur au
rafraîchissement périodique.

**La v2 ne lit rien sous cette clé.** Une mission migrée dont les transports IA ont cessé de se
décharger a exactement ce problème. CTLD 2 le signale une fois au démarrage, dans le rapport de
démarrage :

```
[NOTICE] config: dropOffZones n'est pas lu par CTLD 2 — déclarez chaque point de dépose IA
comme une entrée aiZones avec isDropoff: true
```

Le remplacement est plus riche : une entrée `aiZones` dépose **troupes, véhicules virtuels et
véhicules physiques**, et `aiDropMode` choisit comment — `G` au sol uniquement, `P` en parachute
uniquement, `GP` les deux.

```yaml
# v1
#   dropOffZones:
#     - [dropzone1, green, 2]     # BLEU, fumigène vert
#     - [dropzone2, red,   1]     # ROUGE, fumigène rouge

# v2 — les deux mêmes zones, dans mm_facing :
aiZones:
  - dcsZoneName: dropzone1
    coalition: BLUE
    isPickup: false
    isDropoff: true
    aiDropMode: GP
  - dcsZoneName: dropzone2
    coalition: RED
    isPickup: false
    isDropoff: true
    aiDropMode: GP
```

Les trigger zones gardent leurs noms dans l'éditeur de mission ; seule la déclaration change.

!!! info "Une zone IA n'est pas fumigénée — délibérément"
    La couleur de la v1 n'a pas d'équivalent, et c'est une décision, pas un oubli : une zone de
    dépose IA existe pour le routage de l'IA, et aucun pilote n'a besoin de la trouver sur la carte.
    Si vous voulez malgré tout marquer l'endroit, posez par-dessus une seconde troop zone inerte
    (`TRZ_<nom>_<camp>_0_nil_0`) — elle est fumigénée dans la couleur de coalition issue de
    `troopZoneSmokeColor`.

    **Donnez-lui un nom logique différent.** Une TRZ est enregistrée sous son nom analysé
    (`TRZ_dropzone1_B_0_nil_0` s'enregistre sous `dropzone1`), et une entrée `aiZones` dont le
    `dcsZoneName` correspond à une troop zone déjà connue est ignorée — nommer le marqueur d'après la
    zone IA désactive donc silencieusement cette dernière. Appelez le marqueur
    `TRZ_dropmarker1_B_0_nil_0` et les deux fonctionnent.

### Crates — `CTLDCrateManager`

| Appel v1 | Équivalent v2 |
| --- | --- |
| `ctld.spawnCrateAtZone(side, weight, zone)` | `CTLDCrateManager.getInstance():spawnCrateAtZone(side, weight, zone)` |
| `ctld.spawnCrateAtPoint(side, weight, point, hdg)` | `CTLDCrateManager.getInstance():spawnCrateAtPoint(side, weight, point, hdg)` |
| `ctld.cratesInZone(zone, flagNumber)` | `CTLDCrateManager.getInstance():startCrateCountWatcher(zone, flagNumber)` |

### Beacons — `CTLDBeaconManager`

| Appel v1 | Équivalent v2 |
| --- | --- |
| `ctld.createRadioBeaconAtZone(zone, coalition, batteryLife, name)` | `CTLDBeaconManager.getInstance():createAtZone(zone, coalition, batteryLife, name)` |

### JTAC — `CTLDJTACManager`

| Appel v1 | Équivalent v2 |
| --- | --- |
| `ctld.JTACAutoLase(group, code, smoke, lock, colour, radio)` | `CTLDJTACManager.getInstance():autoLase(group, code, smoke, lock, colour, radio)` |
| `ctld.JTACStart(group, code, smoke, lock, colour, radio)` | `CTLDJTACManager.getInstance():startLase(group, code, smoke, lock, colour, radio)` |
| `ctld.JTACAutoLaseStop(group)` | `CTLDJTACManager.getInstance():stopAutoLase(group)` |

## Remplacer `ctld.addCallback` { #replacing-ctldaddcallback }

`ctld.addCallback` est le seul construct v1 qui n'est **pas** wrappé. La v1 enregistrait un unique
handler fourre-tout qui recevait chaque événement et le démultiplexait sur un identifiant numérique :

```lua
-- v1
ctld.addCallback(function(event)
    if event.id == ctld.events.S_EVENT_CRATE_SPAWNED then
        -- handle
    end
end)
```

La v2 remplace cela par des abonnements ciblés sur le bus d'événements interne. Abonnez-vous par nom
d'événement via `EventDispatcher` ; seul le handler correspondant se déclenche, et un nombre
quelconque d'abonnés peut écouter le même événement :

```lua
-- v2
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    -- evt.crateName, evt.coalition, evt.spawnedBy, evt.position
end)
```

Cela supprime la chaîne `if/elseif`, évite d'exécuter des handlers sans rapport, et permet à des
fonctionnalités indépendantes de s'abonner au même événement sans interférer. Voir
[Événements](events.md) pour le catalogue complet des événements et la forme de leurs payloads.

## Exemple complet de migration { #complete-migration-example }

Un **DO SCRIPT** v1 représentatif et son équivalent v2.

**v1 :**

```lua
ctld.spawnGroupAtTrigger(coalition.side.BLUE, 10, "LZ_NORTH", 100)
ctld.JTACAutoLase("ENEMY_ARMOUR", 1688, true)
ctld.addCallback(function(e)
    if e.id == ctld.events.S_EVENT_TROOPS_DEPLOYED then
        trigger.action.outText("Troops landed!", 10)
    end
end)
```

**v2 :**

```lua
local tm   = CTLDTroopManager.getInstance()
local jtac = CTLDJTACManager.getInstance()
local ed   = EventDispatcher.getInstance()

tm:spawnGroupAtTrigger(coalition.side.BLUE, 10, "LZ_NORTH", 100)
jtac:autoLase("ENEMY_ARMOUR", 1688, true)
ed:subscribe("OnTroopsDeployed", function(evt)
    trigger.action.outText("Troops landed!", 10)
end)
```

## Quels appareils sont des transports { #which-aircraft-are-transports }

La v2 tranche à partir de `capabilitiesByType` seule : un appareil qui y a une entrée est un
transport, un appareil absent conserve le menu CTLD mais rien de ce qui transporte — voir
[Configuration](../mission-maker/configuration.fr.md#per-aircraft-capabilities).

CTLD 2 livre les entrées des variantes de Gazelle (`SA342L`, `SA342M`, `SA342Minigun`,
`SA342Mistral`) et du `Yak-52`, conformes à ce que la v1 déclarait pour eux : un soldat, pas de
caisse. Avec cette limite, le menu d'embarquement ne propose qu'un template d'un seul homme —
`Single JTAC` dans le catalogue standard — ce qu'un appareil léger d'observation insère
réellement.

!!! warning "Le Ka-50 est délibérément absent"
    La v1 laissait un `Ka-50` élinguer des caisses et embarquer `numberOfTroops` soldats. Ce
    n'était pas une décision : il n'avait pas non plus d'entrée dans les tables de la v1, et
    `ctld.getUnitActions` / `ctld.getTransportLimit` retombaient sur `{crates = true, troops = true}`
    et sur la limite globale
    ([CTLD.lua:11088-11102](https://github.com/VEAF/CTLD/blob/master/migration/source/CTLD.lua#L11088)).

    CTLD 2 ne reprend pas ce comportement. Un hélicoptère d'attaque monoplace n'est pas un
    transport, et lui donner une entrée dont tous les champs de transport valent `false`
    n'ajouterait qu'une seule chose — la pose d'une balise radio — tout en annonçant un transport
    qui n'en est pas un. Le recon et le statut JTAC, les raisons qu'on avance d'ordinaire pour le
    lister, fonctionnent sans aucune entrée.

    Si votre mission veut un Ka-50 poseur de balises, ajoutez l'entrée vous-même : c'est de la
    configuration, pas du comportement moteur.

## Pack de véhicule (nouveau en v2) { #pack-vehicle-new-in-v2 }

La v1 n'avait aucun chemin fonctionnel de pack de véhicule. La v2 l'ajoute sur `CTLDVehicleSpawner`,
piloté depuis le menu F10 mais aussi appelable directement :

```lua
-- Find CTLD-managed vehicles in WAITING state within pack range of a transport.
-- Returns an array of { unitName = string, descriptor = table }.
local vehicles = CTLDVehicleSpawner.getInstance():findPackableVehicles(transportUnit)

-- Pack one: destroys the vehicle DCS unit, spawns the required crates near the transport,
-- and publishes OnVehiclePacked.
CTLDVehicleSpawner.getInstance():packVehicle(transportName, vehicleName, playerObj)
```

`findPackableVehicles` ne renvoie que les véhicules gérés par CTLD qui sont dans l'état `WAITING`, de
sorte que les props de décor (guards, workers, décoration statique) ne polluent jamais le résultat.
Le sous-menu F10 **Pack Vehicle** est peuplé automatiquement lorsqu'un transport se pose à moins de
`ctld.gs("maximumDistancePackableUnitsSearch")` d'un véhicule packable.

## Scènes déplacées en plugins (2.0.0) { #scenes-moved-to-plugins-200 }

La scène **Metal FARP** n'est plus embarquée dans `CTLD.lua`. C'est désormais un plugin optionnel du
dépôt [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) (elle dépend du mod
`Farp_FG_Petit_Helipad`, qui n'a pas sa place dans le livrable de base).

Si votre mission proposait Metal FARP, téléchargez le `.lua` du plugin depuis le
[catalogue des plugins](https://veaf.github.io/CTLD_plugins/) et chargez-le depuis un déclencheur
au **démarrage de la mission, après** le déclencheur qui charge `CTLD.lua` :

```
Déclencheur 1 (MISSION START) : DO SCRIPT FILE → CTLD.lua
Déclencheur 2 (MISSION START) : DO SCRIPT FILE → metal-farp.lua
```

La scène s'enregistre alors exactement comme avant et sa caisse réapparaît dans **Request
Equipment**. Aucun autre changement n'est nécessaire ; les autres scènes FARP/FOB/champ de mines
restent intégrées.

---

Voir [Architecture](architecture.md) pour l'idiome manager / singleton sur lequel ces appels
reposent, et la [Référence de l'API](api-reference.md) pour la surface complète des méthodes de chaque
manager.
