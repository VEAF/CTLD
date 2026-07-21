# Cycle de vie troupes + JTAC (troops) { #troop-jtac-lifecycle }

**Source :** `src/CTLD_troop.lua`, `src/CTLD_jtac.lua`
**Entités :** `CTLDTroopGroup`, `CTLDJTAC`, `CTLDJTACDetector` (helpers statiques), `CTLDJTACMessage` (statique)
**Singletons :** `CTLDTroopManager`, `CTLDJTACManager`

Les troops et le JTAC sont documentés ensemble parce qu'un JTAC n'est **pas un type d'unité** — c'est une
capacité qui peut être portée par trois vecteurs différents, dont l'un est un soldat d'infanterie à l'intérieur d'un
troop group composite. La machine à états des troops et le registre JTAC sont donc étroitement
couplés : déployer, extraire ou perdre un troop group doit démarrer, geler ou démanteler les instances JTAC
qui vivent à l'intérieur.

Les deux managers suivent l'idiome singleton décrit dans [Architecture](../architecture.md) : une seule
instance par domaine, obtenue via `CTLDTroopManager.getInstance()` / `CTLDJTACManager.getInstance()`,
chacune construite sur `class()` depuis `src/core/class.lua`. Les notifications transversales sont publiées sur le
bus d'événements (`EventDispatcher`) — voir [Events](../events.md) pour le catalogue complet `OnJTAC*` /
`OnTroops*`.

Deux diagrammes accompagnent cette page :

- [Machine à états du cycle de vie Troop + JTAC](../../assets/troops_jtac_lifecycle.svg) — chaque état et chaque transition.
- [Flux de transport des troops](../../assets/troops_transport_flows.svg) — chemins de chargement / déploiement / parachutage.

## Les trois variantes de JTAC

Un descripteur JTAC pilote le lasage quelle que soit sa catégorie DCS. Ce qui diffère d'une variante à l'autre, c'est
si le vecteur peut être **packed** (détruit et retransformé en crates) et s'il peut être **loaded**
(embarqué sur un transport).

| Variante | Catégorie DCS | Spawned par | Packable | Loadable | Clé de registre |
| --- | --- | --- | --- | --- | --- |
| **Troop** (infanterie avec `jtac=N`) | GROUND group | `embarkFromTroopZone()` → `disembark()` | Non | Oui — conservé virtuellement dans `_inTransit` | `unitName` (clé unité) |
| **Vehicle** (Hummer / SKP-11) | GROUND group | `spawnJTACVehicleForTransport()` ou unpack de crate | Oui — `packVehicle()` → `deregisterJTAC()` | Oui — `loadVehicle()` (virtuel ou natif DCS) | `groupName` (clé groupe) |
| **Drone** (MQ-9 / RQ-1A) | AIRPLANE | `deployAirJTAC()` ou crate de drone (`spawnAs = "AIRPLANE"`) | Non (aéronef) | Non — les aéronefs ne sont pas du cargo dans CTLD | `groupName` (clé groupe) |

La détection se fait uniquement par flag de descripteur : un descripteur de crate avec `isJTAC == true` devient un JTAC au
unpack. Il n'y a pas de table `JTAC_unitTypeNames` séparée — ce paramètre legacy a été supprimé, et
les drones atteignent désormais la carte via le menu standard Request Equipment crate
(`spawnAs = "AIRPLANE"`), et non via un menu de spawn de véhicule dédié.

Les méthodes de spawn/pack/load côté véhicule et drone vivent dans les managers de crate et de véhicule
(`CTLDVehicleSpawner:registerJTACVehicle()`, `CTLDVehicleSpawner:packVehicle()`,
`CTLDJTACManager:deployAirJTAC()`) ; cette page décrit comment elles appellent `CTLDJTACManager`, pas
leurs rouages internes.

## Machine à états du troop group

Un `CTLDTroopGroup` suit les troops du chargement à la disposition finale. Ce n'est **pas un objet DCS** — il vit
entièrement en mémoire Lua, dans `CTLDTroopManager._inTransit[unitName]` (une liste, pour qu'un transport puisse
porter plusieurs groupes) ou, une fois au sol, sous forme de nom dans `CTLDTroopManager._droppedGroups[coalition]`.

`CTLDTroopGroup.STATE` déclare cinq constantes :

```lua
CTLDTroopGroup.STATE = {
    TRZ_LOADED      = "TRZ_LOADED",    -- onboard, loaded from a TroopZone
    DEPLOYED        = "deployed",      -- on the ground as a live DCS group
    FIELD_LOADED    = "FIELD_LOADED",  -- onboard, recovered from the field
    DEPLOYED_EXZ    = "DEPLOYED_EXZ",  -- (declared; see note below)
    RETURNED_TO_TRZ = "RETURNED_TO_TRZ",
}
```

Les transitions réellement pilotées par le code actuel :

```
                 embarkFromTroopZone()                    disembark()
   (pickup TRZ) ─────────────────────► TRZ_LOADED ───────────────────────► DEPLOYED
                                            │                              (DCS group spawned)
                                            │                                   │
                     returnToTroopZone()    │                                   │ embarkFromField()
              (instance discarded, stock    │                                   ▼
               restored, JTACs freed)  ◄─────┘                              FIELD_LOADED
                                                                                │
                                                     disembark() (re-deploy)    │
                                            DEPLOYED ◄──────────────────────────┘

   disembark() while inside an extract zone with objectiveFlag:
              troops counted into the flag, group:deploy(nil), no DCS group, no JTAC
```

- Lors d'un **nouveau chargement** (`embarkFromTroopZone()`), le groupe est stocké dans `_inTransit` avec
  `_aliveUnits` / `_jtacUnits` pré-construits à partir de la composition de rôles du template. **Aucun DCS group et aucun
  JTAC n'existent encore.**
- Lors d'un **déploiement** (`disembark()`), le DCS group est spawné par `CTLDObjectRegistry.spawnObject()`,
  `group:disembark(dcsGroup)` exécute `_syncFromDCSGroup()` pour reconstruire `_aliveUnits` / `_jtacUnits`
  à partir des vrais noms d'unités DCS, le nom du groupe est poussé dans `_droppedGroups`, et son
  template/poids/total sont mis en cache dans `_droppedTemplates` pour un re-déploiement exact après un field
  pickup.
- Lors d'un **field pickup** (`embarkFromField()`), le groupe ami dropped le plus proche est retransformé en
  `CTLDTroopGroup` `FIELD_LOADED` et son DCS group est détruit.

**Note — états déclarés mais non assignés.** `DEPLOYED_EXZ` et `RETURNED_TO_TRZ` sont déclarés dans la
table `STATE`, mais les chemins actuels ne les assignent pas. Un drop en objective zone réutilise `DEPLOYED`
(via `group:deploy(nil)` — pas de DCS group, l'`objectiveFlag` de l'extract zone est simplement incrémenté de
`group.unitTotal`), et `returnToTroopZone()` jette purement et simplement l'instance
(`_inTransit[unitName] = nil`) plutôt que de la garer dans un état terminal.

### Suivi des unités de `CTLDTroopGroup`

```lua
self._aliveUnits = {}  -- [unitName] = dcsUnit (DCS Unit reference, not an index)
self._jtacUnits  = {}  -- [unitName] = true (subset of _aliveUnits flagged as JTAC)
```

`_syncFromDCSGroup()` reconstruit intégralement les deux maps à partir du DCS group vivant. Les soldats JTAC sont
identifiés par le **préfixe de nom `JTAC`** (`name:match("^JTAC")`), posé par `_registerOneTemplate()`
pour chaque unité de rôle `jtac` ; le préfixe est exclusif à ce rôle — tous les autres rôles utilisent
les préfixes `INF` / `MG` / `AT` / `AA` / `MORTAR` / personnalisés. Les servants de mortier (préfixe `SVNT`) sont
exclus des deux maps et de `unitTotal`. Une clé par `unitName` (jamais par index de groupe) signifie que la
ré-indexation par DCS des unités survivantes après une mort ne peut pas corrompre le suivi.

## Modèle d'instance JTAC

`CTLDJTAC.STATE` possède cinq valeurs : `IDLE`, `LASING`, `ORBITING` (en vol, implique le lasage),
`IN_TRANSIT` (JTAC au sol embarqué) et `DEAD`. Le manager conserve **un `CTLDJTAC` par unité JTAC
vivante**, pas un par groupe — un troop group composite avec deux soldats JTAC détient deux entrées.

Deux conventions de registre coexistent dans `CTLDJTACManager.jtacs`, distinguées par le champ
`unitName` de l'entité :

| Type de JTAC | Point d'entrée | Clé dans `jtacs` | Champ `unitName` | La boucle résout l'unité via |
| --- | --- | --- | --- | --- |
| JTAC drone / véhicule | `startLase(groupName)` → `autoLase()` → `spawnJTAC()` | `groupName` | `nil` | `Group.getByName(groupName):getUnits()[1]` |
| JTAC d'infanterie dans un troop group | `startLaseTroopUnit(unitName)` | `unitName` | renseigné | `Unit.getByName(unitName)` |

La distinction est critique à la mort. Un JTAC **clé groupe** dont le DCS group a disparu est nettoyé
par `killJTAC(groupName)`, qui détruit le groupe et publie `OnJTACDead`. Un JTAC d'infanterie **clé unité**
ne doit **jamais** appeler `killJTAC` — le faire détruirait tout le groupe composite et
tuerait son infanterie survivante. À la place, son `_autoLaseLoop` renvoie simplement `nil` (s'arrête) quand
`Unit.getByName()` échoue, et le nettoyage se fait via `S_EVENT_DEAD → onUnitDead → deregisterJTAC(unitName)`.

Chaque JTAC se voit attribuer un laser code depuis un pool séquentiel (`LASER_CODE_MIN = 1111` …
`LASER_CODE_MAX = 1688`), libéré à la mort/deregister. `CTLDJTACDetector.calculateFMRadio()` dérive
une fréquence de guidage FM à partir du code (`30 + floor((code-1000)/100) + ((code-1000) mod 100) * 0.05`),
donnant environ 31,5–40,4 MHz sur l'ensemble du pool.

## Points d'entrée de spawn JTAC par variante

| Variante | Chemin | JTAC enregistré par | État résultant |
| --- | --- | --- | --- |
| Troop — chargement via TRZ puis déploiement | `embarkFromTroopZone()` → `disembark()` | `disembark()` boucle sur `_jtacUnits`, appelle `startLaseTroopUnit(unitName)` pour chacun | `IDLE` → `LASING` |
| Troop — parachutage | `parachuteTroops()` | le callback d'atterrissage mappe les noms de slots `_jtacUnits` (`_u<idx>`) aux unités spawnées par position, appelle `startLaseTroopUnit()` | `IDLE` → `LASING` |
| Vehicle — Request JTAC Equipment | `spawnJTACVehicleForTransport()` | `registerJTACVehicle()` + `startLase()` | `IDLE` → `LASING` |
| Vehicle — unpack de crate `isJTAC` (GROUND) | `_spawnUnpacked()` → `_dispatchPostSpawn()` | `_dispatchPostSpawn()` voit `desc.isJTAC`, appelle `startLase()` + `registerJTACVehicle()` | `IDLE` → `LASING` |
| Drone — unpack de crate (`spawnAs = "AIRPLANE"`) | `_spawnUnpacked()` → `_dispatchPostSpawn()` | `_dispatchPostSpawn()` vérifie `desc.isJTAC` sans distinction air/sol, appelle `startLase()` | `ORBITING` |
| Drone — `deployAirJTAC()` | chemin de menu direct → `spawnFromDescriptor("AIRPLANE")` | `deployAirJTAC()` appelle `startLase()` directement | `ORBITING` |

`embarkFromTroopZone()` ne spawne délibérément rien — il stocke un `CTLDTroopGroup` virtuel
dans `_inTransit`. C'est pourquoi un soldat JTAC ne lase rien pendant qu'il voyage sur un transport (son unité DCS
n'existe pas encore). `startLaseTroopUnit()` tolère une unité pas-encore-vivante : le premier `_autoLaseLoop`
est décalé de +1 s et se contente de re-sonder.

## Règles de transition Troop-JTAC par chemin de sortie

| Chemin de sortie | État | Action JTAC requise |
| --- | --- | --- |
| `embarkFromTroopZone()` | → `TRZ_LOADED` | Aucune — aucune instance JTAC n'existe encore |
| `disembark()` (premier déploiement) | → `DEPLOYED` | `startLaseTroopUnit(unitName)` pour chaque clé de `_jtacUnits` |
| `parachuteTroops()` | → groupe dropped | À l'atterrissage, `startLaseTroopUnit()` par slot JTAC mappé à une unité spawnée |
| `embarkFromField()` | → `FIELD_LOADED` | **`deregisterJTAC(unitName)` pour chaque clé de `_jtacUnits` AVANT `group:destroy()`** |
| `disembark()` (re-déploiement après field) | → `DEPLOYED` | `startLaseTroopUnit(unitName)` pour chaque clé de `_jtacUnits` |
| `returnToTroopZone()` | instance jetée | `deregisterJTAC(unitName)` pour chaque clé de `_jtacUnits` |
| disembark dans une extract zone avec `objectiveFlag` | → `DEPLOYED` (pas de DCS group) | Aucune — aucun groupe spawné, aucun JTAC jamais instancié |
| Transport détruit alors que `FIELD_LOADED` | entrée retirée | Tous les orphelins `_jtacUnits` → `deregisterJTAC()` dans `cleanupDeadTransports()` |

L'ordonnancement **deregister-before-destroy** dans `embarkFromField()` est l'invariant de correction clé :
`group:destroy()` déclenche `S_EVENT_DEAD` pour chaque unité JTAC, et sans deregister préalable cet
événement déclencherait à tort `killJTAC()` sur un JTAC qui est en réalité récupéré, pas tué.

## Transitions Vehicle & drone

Les JTAC de véhicules terrestres et de drones sont clé groupe ; leurs transitions load/unload/pack appellent donc
directement les méthodes clé groupe de `CTLDJTACManager`. Résumé des états qu'ils pilotent :

| Transition | Déclencheur | État avant → après | `jtacs[]` | Action JTAC |
| --- | --- | --- | --- | --- |
| Load (menu) | `loadVehicle(method = menu_ctld)` | `LASING`/`IDLE` → `IN_TRANSIT` | libéré à `nil` | `setJTACInTransit()` → `setInTransit()` (stop lase, code libre conservé sur l'entité) |
| Load (natif DCS) | le véhicule entre dans la bbox du transport | `LASING`/`IDLE` → `IN_TRANSIT` | libéré à `nil` | `setJTACInTransit()` ; l'unité DCS reste vivante, liée à l'intérieur de l'aéronef |
| Unload (menu) | `unloadVehicle(method = menu_ctld)` | `IN_TRANSIT` → `IDLE` | recréé | `resumeJTAC()` → `startLase()` |
| Unload (natif DCS) | le véhicule sort de la bbox du transport | `IN_TRANSIT` → `IDLE` | recréé | `resumeJTAC()` → `startLase()` |
| Parachute vehicle | `parachuteVehicle()` | `LOADED` → `WAITING` | recréé | `resumeJTAC()` dans le callback d'atterrissage |
| Pack | `packVehicle()` | `LASING`/`IDLE` → retiré | libéré à `nil` | `deregisterJTAC()` — silencieux, pas d'`OnJTACDead` |
| Détruit (combat) | `S_EVENT_DEAD` | quelconque → `DEAD` | libéré à `nil` | `killJTAC()` publie `OnJTACDead` |
| Drone détruit | `S_EVENT_DEAD` | `ORBITING`/`LASING` → `DEAD` | libéré à `nil` | `killJTAC()` |

`setJTACInTransit()` appelle le `setInTransit()` de l'entité, qui arrête le laser et positionne l'état
`IN_TRANSIT` ; pendant le transit, `_autoLaseLoop` renvoie l'intervalle de recherche sans sonder l'existence de
l'unité DCS, parce que l'unité est intentionnellement absente de la carte (détruite au load virtuel, ou
cachée à l'intérieur de l'aéronef au load natif DCS). `deregisterJTAC()` est le chemin **silencieux**
(véhicule repacké en crates) : il arrête le lasage, libère les revendications de cible, libère le laser code,
retire l'entrée du registre, et ne publie **pas** `OnJTACDead` — un pack n'est pas une mort au combat.
Les drones ne peuvent pas être loaded, donc `IN_TRANSIT` ne s'applique jamais à eux.

## Synchronisation `S_EVENT_DEAD`

Chaque mort d'une unité dans un troop group déployé est routée depuis `CTLDDCSEventBridge` vers
`CTLDTroopManager:onUnitDead(unitName)` :

1. `_findGroupByAliveUnit(unitName)` localise le `CTLDTroopGroup` propriétaire (en cherchant d'abord dans `_inTransit`,
   puis en reconstruisant depuis `_droppedGroups`).
2. `wasJtac` est capturé **avant** mutation (`grp._jtacUnits[unitName] ~= nil`).
3. `_removeDeadUnit(unitName)` retire l'unité de `_aliveUnits` et `_jtacUnits` et recalcule
   `unitTotal`.
4. Si `wasJtac`, `CTLDJTACManager:deregisterJTAC(unitName)` est appelé — le nettoyage clé unité qui
   libère le laser sans toucher au groupe composite survivant.

## Kill de transport avec troops FIELD_LOADED

Quand un transport portant des troops `FIELD_LOADED` est abattu, les `_jtacUnits` que ces troops détenaient sont
encore référencés dans `CTLDJTACManager.jtacs` et deviendraient des zombies orphelins (les unités DCS n'existent
plus, mais les entrées JTAC et leurs laser codes sont toujours alloués). `cleanupDeadTransports()`
gère cela : pour chaque entrée `_inTransit` obsolète dont le transport `Unit.getByName()` n'existe
plus, il itère les `_jtacUnits` de chaque groupe et appelle `deregisterJTAC()` avant de vider le
slot `_inTransit`. `onTransportDead()` déclenche ce nettoyage immédiatement sur l'événement de mort du transport
plutôt que d'attendre le prochain tick de poll.

## Terminologie legacy (v1 → v2)

La réécriture v2 a renommé le vocabulaire du cycle de vie des troops pour rendre explicite la sémantique
load/deploy/recover. Voir [Migration v1 → v2](../migration-v1-v2.md) pour la couche wrapper.

| Nom v1 | Nom v2 |
| --- | --- |
| `loadFromZone()` | `embarkFromTroopZone()` |
| `deploy()` / `unload()` | `disembark()` |
| `extract()` | `embarkFromField()` |
| `returnToBase()` | `returnToTroopZone()` |
| état `LOADED` | `TRZ_LOADED` |
| état `EXTRACTED` | `FIELD_LOADED` |
| `hasJtac` (booléen) | `_jtacUnits` (map) |
| suivi basé sur l'index de groupe | suivi par map basé sur `unitName` |

`CTLDTroopGroup.deploy` est conservé comme alias de `disembark` pour la compatibilité ascendante pendant la
transition.

## Déconfliction de cibles multi-JTAC

Quand plusieurs JTAC sont actifs simultanément — n'importe quel mélange d'infanterie, de véhicule et de drone — `CTLDJTACManager`
les empêche de tous laser la même cible via une table de revendications partagée :

```lua
self._claimedTargets = {}  -- { [enemyUnitName] = jtacKey }
-- jtacKey = unitName (unit-keyed infantry) or groupName (group-keyed vehicle/drone)
```

**Cycle de vie d'une revendication :**

| Événement | Action |
| --- | --- |
| Un JTAC verrouille une nouvelle cible | `_claimTarget(jtacKey, enemyUnitName)` |
| Le lasage s'arrête (pour quelque raison que ce soit) | `_releaseTarget(enemyUnitName)` — depuis `_stopLaseAndPublish()` |
| JTAC deregistered / killed | `_releaseTarget()` + `_releaseAllTargetsFor(jtacKey)` (ceinture et bretelles) |
| `cleanup()` | `_claimedTargets = {}` |

**Sélection de cible** (phase de recherche de `_autoLaseLoop`), gardée par `ctld.gs("JTAC_targetDeconfliction")`
(activée sauf si explicitement `false`) :

1. `CTLDJTACDetector.findAllVisibleEnemies()` renvoie tout ennemi visible en LOS dans
   `JTAC_maxDistance`, trié par priorité puis distance. Paliers de priorité : `hpriority` (1) >
   `priority` (2) > Air Defence (3) > standard (4). La LOS utilise `land.isVisible` avec un décalage de hauteur de +2 m
   sur les deux extrémités.
2. Itérer les candidats, en sautant tout `candidate.unitName` déjà présent dans `_claimedTargets`.
3. Le premier candidat non revendiqué est revendiqué **avant** que les spots DCS ne soient créés — empêchant une
   boucle JTAC concurrente de saisir la même cible dans le même tick de scheduler — puis le lasage
   démarre.

Avec la déconfliction désactivée, la boucle prend simplement `candidates[1]`.

**Renouvellement de cible** (le cas critique — cible détruite ou LOS perdue) : `_stopLaseAndPublish()`
libère la revendication sur la cible perdue, et l'exécution enchaîne directement sur la phase de recherche dans
le même tick de `_autoLaseLoop`, de sorte que le JTAC choisit immédiatement le prochain candidat non revendiqué depuis un
appel `findAllVisibleEnemies()` frais. Plusieurs JTAC perdant leur cible simultanément (p. ex. une seule
explosion) acquièrent donc chacun une cible suivante **différente** au lieu de converger sur la même.

`CTLDJTACDetector.findNearestVisibleEnemy()` est désormais un fin wrapper renvoyant
`findAllVisibleEnemies()[1]`, conservé pour les callsites qui n'ont besoin que du meilleur candidat unique et ne
requièrent pas de déconfliction.
