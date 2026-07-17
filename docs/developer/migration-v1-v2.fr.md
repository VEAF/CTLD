# Migration v1 → v2

CTLD v2 est une réécriture modulaire, mais la surface publique de la v1 est préservée. Les missions
qui appellent les fonctions globales `ctld.*` d'origine depuis un déclencheur **DO SCRIPT**
continuent de fonctionner sans modification — chaque point d'entrée v1 survit sous la forme d'un
wrapper léger qui transmet l'appel au manager v2 correspondant et journalise un avertissement de
dépréciation. Cette page explique le principe des wrappers, donne la correspondance complète v1 → v2,
et montre comment porter le seul construct qui n'est *pas* wrappé : le callback fourre-tout.

## Principe des wrappers

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

## Table de migration

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

## Remplacer `ctld.addCallback`

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

## Exemple complet de migration

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

## Pack de véhicule (nouveau en v2)

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

## Scènes déplacées en plugins (2.0.0)

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
