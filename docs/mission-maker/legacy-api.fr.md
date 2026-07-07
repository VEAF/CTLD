# API historique

Si vous avez déjà une mission construite sur **CTLD v1**, ses triggers `DO SCRIPT` et scripts
utilitaires continuent de fonctionner sous v2. CTLD fournit de fins wrappers de compatibilité
qui reproduisent les fonctions globales `ctld.*` de v1 et transmettent chaque appel au manager
v2 correspondant.

## La promesse de compatibilité

- **22 fonctions v1 sont wrappées.** Chacune délègue en interne à un manager v2, de sorte que
  vos appels existants se comportent comme en v1.
- **Chaque appel journalise un avertissement de dépréciation** dans `ctld.log` (et DCS.log).
  Les wrappers sont pris en charge en v2 mais seront **supprimés en v3** — prévoyez de migrer
  avant.
- **`ctld.addCallback` n'est *pas* wrappé.** Les callbacks v1 n'ont pas de remplacement direct ;
  utilisez plutôt le système d'événements v2 (voir [Callbacks](#callbacks) ci-dessous).

Pour les nouvelles missions, préférez directement les managers v2. Le mapping complet et les
étapes de migration se trouvent dans la documentation développeur — cette page ne couvre que ce
dont un mission maker disposant d'un script v1 a besoin.

> Consultez le guide [Migration v1 → v2](../developer/migration-v1-v2.md) pour le parcours de
> migration complet, fonction par fonction.

## Troops et transport

| Fonction v1 | Délègue à |
|---|---|
| `ctld.spawnGroupAtTrigger(groupSide, number, triggerName, searchRadius)` | `CTLDTroopManager:spawnGroupAtTrigger()` |
| `ctld.spawnGroupAtPoint(groupSide, number, point, searchRadius)` | `CTLDTroopManager:spawnGroupAtPoint()` |
| `ctld.preLoadTransport(unitName, number, troops)` | `CTLDTroopManager:preLoadTransport()` |
| `ctld.loadTransport(unitName)` | `CTLDTroopManager:loadTransport()` |
| `ctld.unloadTransport(unitName)` | `CTLDTroopManager:unloadTransport()` |
| `ctld.unloadInProximityToEnemy(unitName, distance)` | `CTLDTroopManager:unloadInProximityToEnemy()` |

**Exemple — spawn de troops depuis un `DO SCRIPT` :**

```lua
ctld.spawnGroupAtTrigger(coalition.side.BLUE, 6, "LZ_NORTH", 1000)
```

## Zones de pickup, de waypoint et d'extract

| Fonction v1 | Délègue à |
|---|---|
| `ctld.activatePickupZone(zoneName)` | `CTLDZoneManager:setTroopZoneActive(name, true)` |
| `ctld.deactivatePickupZone(zoneName)` | `CTLDZoneManager:setTroopZoneActive(name, false)` |
| `ctld.changeRemainingGroupsForPickupZone(zoneName, amount)` | `CTLDZoneManager:changeRemainingGroups()` |
| `ctld.activateWaypointZone(zoneName)` | `CTLDZoneManager:activateWaypointZone()` |
| `ctld.deactivateWaypointZone(zoneName)` | `CTLDZoneManager:deactivateWaypointZone()` |
| `ctld.createExtractZone(zone, flagNumber, smoke)` | `CTLDZoneManager:createExtractZone()` |
| `ctld.removeExtractZone(zone, flagNumber)` | `CTLDZoneManager:removeExtractZone()` |
| `ctld.countDroppedGroupsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager:startGroupCountWatcher()` |
| `ctld.countDroppedUnitsInZone(zone, blueFlag, redFlag)` | `CTLDTroopManager:startUnitCountWatcher()` |

**Exemple — activer une zone de pickup au démarrage de la mission :**

```lua
ctld.activatePickupZone("TRZ_ALPHA")
```

Voir [Configuration des zones](zones.md) pour savoir comment ces zones sont définies dans
l'éditeur de mission.

## Crates

| Fonction v1 | Délègue à |
|---|---|
| `ctld.spawnCrateAtZone(side, weight, zone)` | `CTLDCrateManager:spawnCrateAtZone()` |
| `ctld.spawnCrateAtPoint(side, weight, point, hdg)` | `CTLDCrateManager:spawnCrateAtPoint()` |
| `ctld.cratesInZone(zone, flagNumber)` | `CTLDCrateManager:startCrateCountWatcher()` |

**Exemple — spawn d'un crate sur une trigger zone :**

```lua
ctld.spawnCrateAtZone(coalition.side.BLUE, 800, "FARP_BRAVO")
```

L'argument `weight` sélectionne le crate à spawner. Voir le
[Catalogue des crates](crates-catalogue.md) pour les définitions de crates disponibles.

## Radio beacon

| Fonction v1 | Délègue à |
|---|---|
| `ctld.createRadioBeaconAtZone(zone, coalition, batteryLife, name)` | `CTLDBeaconManager:createAtZone()` |

## JTAC

| Fonction v1 | Délègue à |
|---|---|
| `ctld.JTACAutoLase(jtacGroupName, laserCode, smoke, lock, colour, radio)` | `CTLDJTACManager:autoLase()` |
| `ctld.JTACStart(jtacGroupName, laserCode, smoke, lock, colour, radio)` | `CTLDJTACManager:startLase()` |
| `ctld.JTACAutoLaseStop(jtacGroupName)` | `CTLDJTACManager:stopAutoLase()` |

**Exemple — auto-lase sur un groupe blindé ennemi, puis arrêt :**

```lua
ctld.JTACAutoLase("ENEMY_ARMOUR_1", 1688, true)
-- ... une fois la frappe terminée :
ctld.JTACAutoLaseStop("ENEMY_ARMOUR_1")
```

## Callbacks

En v1, les scripts externes enregistraient un callback avec `ctld.addCallback(fn)` pour réagir
aux événements CTLD. **Cette fonction n'est pas fournie en v2** — il n'existe aucun wrapper de
compatibilité. Abonnez-vous plutôt au dispatcher d'événements v2 :

```lua
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(event)
    -- réagir à l'événement
end)
```

Les événements disponibles incluent `OnCrateSpawned`, `OnCrateLoaded`, `OnCrateUnloaded`,
`OnCrateUnpacked`, `OnVehiclePacked`, `OnTroopsBoarded`, `OnTroopsDeployed`,
`OnTroopsExtracted`, `OnJTACSpawned`, `OnLaseStart`, `OnLaseStop`, `OnBeaconDropped` et
`OnFOBDeployed`. Le guide [Migration v1 → v2](../developer/migration-v1-v2.md) liste le
catalogue complet des événements ainsi que le mapping callback-vers-événement.
