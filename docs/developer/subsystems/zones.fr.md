# Gestion des zones { #zone-management }

**Source :** `src/CTLD_zone.lua`
**Entités :** `CTLDTroopZone`, `CTLDLogisticZone`
**Singleton :** `CTLDZoneManager`

Les zones sont les ancres spatiales de CTLD : c'est là que les troops embarquent et se
déploient, que les objectifs de mission sont comptabilisés, que les crates et les véhicules
peuvent être servis, et que les transports IA chargent et déchargent leur cargaison. Un unique
manager possède chaque zone ; les entités portent l'état propre à chaque zone et les tests de
géométrie.

`CTLDZoneManager` suit l'idiome singleton décrit dans
[Architecture](../architecture.md) — `CTLDZoneManager = class()`, une `_instance` privée et une
fabrique `getInstance()` qui exécute `init()` au premier accès. Les deux classes d'entité sont
de simples types `class()` instanciés via `:new(data)`.

## Types de zone { #zone-types }

| Type | Préfixe / source | Entité | Rôle |
| --- | --- | --- | --- |
| TRZ | zone de trigger DCS `TRZ_` | `CTLDTroopZone` | Pickup de troops, objectif d'extract, mixte, ou marqueur inerte |
| WPZ | zone de trigger DCS `WPZ_` | `CTLDTroopZone` (`isWaypoint`) | Destination de marche pour les troops déployées |
| LGZ | zone de trigger DCS `LGZ_` | `CTLDLogisticZone` | Services logistiques crate / véhicule |
| AIZ | table de config `aiZones` | `CTLDTroopZone` (`isAIPickup` / `isAIDropoff`) | Pickup / dropoff réservé au transport IA (Feature S/T) |
| Legacy | config `troopZones` / `wpZones` / `logisticUnits` | `CTLDTroopZone` / `CTLDLogisticZone` | Rétrocompatibilité avec les anciennes conventions PKZ/IAZ/WPZ/EXZ |
| Découverte par type | config `logisticUnitTypes` / `troopZoneShipTypes` | `CTLDLogisticZone` / `CTLDTroopZone` | Chaque objet de la mission d'un type DCS listé, ancré à cet objet |
| EXZ (dynamique) | `createExtractZone()` à l'exécution | `CTLDTroopZone` | Extract zone créée depuis un `DO SCRIPT` de mission |
| TRZ (dynamique, tout objet) | `createTroopZoneAtObject()` à l'exécution | `CTLDTroopZone` | TRZ pickup créée depuis un `DO SCRIPT`, sur une zone de trigger, une unité, un statique, un groupe, ou un airbase/FARP |

Les zones TRZ, WPZ et LGZ sont découvertes en parcourant `env.mission.triggers.zones` à
l'init. Les zones AIZ sont chargées depuis `ctld.gs("aiZones")` et référencent par leur nom une
zone de trigger existante de l'éditeur de mission (`dcsZoneName`), résolue via
`trigger.misc.getZone`. Les zones legacy proviennent des tables de config `ctld.gs(...)` et sont
chargées en dernier afin qu'une définition moderne `TRZ_`/`LGZ_` l'emporte toujours : **les
entrées existantes ne sont jamais écrasées**.

## Convention de nommage TRZ { #trz-naming-convention }

Une troop zone encode tout son comportement dans le nom de la zone de trigger — un schéma
positionnel strict où **les cinq champs sont tous requis** :

```
TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>
```

| Position | Champ | Type | Valeurs | Signification |
| --- | --- | --- | --- | --- |
| 1 | `TRZ_` | préfixe | littéral | Identifiant du type de zone |
| 2 | `name` | string | quelconque, sans underscore, hors mots réservés | Identifiant de zone (`zoneName`) |
| 3 | `coalition` | enum | `A` `R` `B` `N` | **A**=all, **R**=RED, **B**=BLUE, **N**=NEUTRAL |
| 4 | `stock` | entier 0–999 | `0`=pas de pickup, `1–998`=limité, `999`=illimité | Capacité d'embarquement des troops |
| 5 | `flag` | string | nom de flag DCS, ou `nil` | Flag d'objectif incrémenté à l'extract ; `nil`=pas d'objectif |
| 6 | `target` | entier ≥0 | `0`=pas de condition de victoire, `N≥1`=seuil de soldats | Nombre de soldats requis pour compléter l'objectif |

Mots réservés qui ne peuvent pas être utilisés comme `name` : `nil`, `A`, `R`, `B`, `N`.

### Sémantique des champs { #field-semantics }

Le parser convertit les valeurs des champs affichés à l'écran vers un stockage interne
volontairement différent, de sorte que `nil` puisse signifier « capacité absente » :

| Valeur `stock` | `pickMaxStock` interne | Signification |
| --- | --- | --- |
| `0` | `nil` | La zone ne peut pas embarquer de troops |
| `1–998` | `1–998` | Stock limité, décrémenté au chargement |
| `999` | `0` | Pickup illimité |

| Valeur `flag` | `objectiveFlag` interne | Signification |
| --- | --- | --- |
| `nil` | `nil` | Pas de flag d'objectif |
| n'importe quelle string | la string | Nom de flag DCS, incrémenté du nombre de soldats à l'extract |

| Valeur `target` | `objectiveTarget` interne | Signification |
| --- | --- | --- |
| `0` | `nil` | Aucun seuil de victoire défini |
| `N≥1` | `N` | Nombre de soldats requis pour compléter l'objectif |

> Utilisez `999` pour un pickup illimité — **et non** `0`. `0` signifie « cette zone ne peut pas
> embarquer de troops ».

Pour la coalition, `A→0`, `R→coalition.side.RED` (1), `B→coalition.side.BLUE` (2),
`N→coalition.side.NEUTRAL` (0). `A` et `N` stockent tous deux `0` ; en interne, CTLD traite `0`
comme « accepte toutes les coalitions », et le multijoueur DCS n'a pas de joueurs NEUTRAL, donc
les deux se comportent de manière identique.

### Rôles de zone { #zone-roles }

Une TRZ peut jouer n'importe quelle combinaison de :

- **Pickup** (`stock > 0`) : les troops embarquent ici ; l'embarquement décrémente le stock.
- **Extract** (`flag ≠ nil`) : les troops déployées ici incrémentent le flag d'objectif du
  nombre de soldats.
- **Mixte** (les deux) : prend en charge l'embarquement et l'extract d'objectif.
- **Inerte** (`stock=0`, `flag=nil`) : parsée mais sans fonction — un marqueur nommé.

### Exemples { #examples }

| Nom de zone | Rôle | Embarquement | Objectif |
| --- | --- | --- | --- |
| `TRZ_base_B_50_nil_0` | Pickup | 50 soldats | — |
| `TRZ_depot_A_999_nil_0` | Pickup ∞ | illimité | — |
| `TRZ_exfil_R_0_rescue_0` | Extract | — | flag `rescue`, pas de seuil |
| `TRZ_lz_B_0_secure_100` | Extract | — | flag `secure`, 100 soldats |
| `TRZ_fob_N_30_defend_50` | Mixte | 30 soldats | flag `defend`, 50 soldats |
| `TRZ_marker_B_0_nil_0` | Inerte | — | — |

```
TRZ  _  fob  _  N   _  30     _  defend  _  50
 │       │      │      │          │          │
 │       │      │      │          │          └─ target : 50 soldats pour l'objectif
 │       │      │      │          └──────────── flag : "defend" (nom de flag DCS)
 │       │      │      └─────────────────────── stock : 30 troops max (limité)
 │       │      └────────────────────────────── coalition : NEUTRAL
 │       └───────────────────────────────────── name : "fob"
 └───────────────────────────────────────────── préfixe TRZ
```

### Validation du parser { #parser-validation }

`CTLDZoneManager:_parseTRZ(name)` retourne une table parsée en cas de succès, ou `nil` plus une
chaîne d'erreur en cas d'échec :

| Violation | Message d'erreur |
| --- | --- |
| Préfixe ≠ TRZ | `"not a TRZ"` |
| Name manquant ou vide | `"missing zoneName"` |
| Name est un mot réservé | `"zoneName cannot be a reserved word: <word>"` |
| Coalition manquante | `"missing coalition (A|R|B|N)"` |
| Coalition ≠ A/R/B/N | `"invalid coalition '<x>' — expected A, R, B or N"` |
| Stock manquant / non entier / hors 0–999 | `"invalid stock '<x>' — expected integer 0-999 …"` |
| Flag manquant | `"missing flag (DCS flag name or 'nil')"` |
| Flag est un nombre | `"flag must be a string or 'nil', not a number"` |
| Target manquant / négatif / non entier | `"invalid target '<x>' — expected integer ≥0 …"` |

`WPZ_` et `LGZ_` utilisent la forme plus simple `<PREFIX>_<name>_[R|B|N]` (coalition
optionnelle, défaut `0`) ; `_parseWPZ` partage `_parseSimpleZone` et `_parseLGZ` est autonome.

## Algorithme de découverte { #discovery-algorithm }

`CTLDZoneManager:init()` enregistre `S_EVENT_DEAD` sur le bridge d'événements DCS, puis exécute
les phases suivantes **dans cet ordre** :

1. `_validateZoneNames()` — parcourt chaque zone de trigger et la config `aiZones`, accumule les
   erreurs et les avertissements (voir plus bas), et les reporte une fois dans le log DCS et à
   l'écran.
2. `_discoverTRZ()` — pour chaque zone de trigger commençant par `TRZ_`, parse le nom avec
   `_parseTRZ` ; en cas de succès, construit une `CTLDTroopZone` (géométrie issue de la zone de
   trigger, `smoke` issu de `troopZoneSmokeColor[coalition]`) et remet à 0 tout `objectiveFlag`.
3. `_loadAIZonesFromConfig()` — lit `ctld.gs("aiZones")` ; chaque entrée valide devient une
   `CTLDTroopZone` marquée `isAIPickup` / `isAIDropoff`, avec un stock par template/par type.
4. `_discoverWPZ()` — les zones de trigger commençant par `WPZ_` deviennent des waypoint troop
   zones (`isWaypoint = true`).
5. `_discoverLGZ()` — les zones de trigger commençant par `LGZ_` deviennent des objets
   `CTLDLogisticZone` (rayon issu de `dynamicZoneRadius`, défaut 200 m).
6. `_discoverTroopZoneShipTypes()` — chaque **unité** de la mission dont le `getTypeName()`
   figure dans `troopZoneShipTypes` devient une `CTLDTroopZone` ancrée à cette unité
   (`linkedUnit`, rayon de 200 m, stock illimité).
7. `_discoverLogisticUnitTypes()` — chaque unité **et statique** de la mission dont le
   `getTypeName()` figure dans `logisticUnitTypes` devient une `CTLDLogisticZone` ancrée à cet
   objet (`linkedUnit`, rayon issu de `maximumDistanceLogistic`). Les deux sont entièrement
   sautées quand leur liste est vide.
8. `_loadLegacyZones()` — passe de rétrocompatibilité sur les tables de config `troopZones`,
   `wpZones` et `logisticUnits`.
9. `_scheduleSmoke()` — démarre la boucle récurrente de rafraîchissement du smoke.

Enfin, `init()` publie un `OnLogisticZoneUpdated` initial et logge le nombre de zones. Chaque
phase de découverte se protège par `if not self._troopZones[name]` / `_logisticZones[name]`,
donc l'ordre de priorité ci-dessus est ce qui fait que les définitions modernes l'emportent sur
les legacy.

Le perdant de cette course n'est pas toujours évident, car la clé est le nom **enregistré**, pas
le nom dans l'éditeur de mission : une zone `TRZ_` s'enregistre sous son nom analysé, donc
`TRZ_dropzone1_B_0_nil_0` occupe `dropzone1`, et une entrée `aiZones` portant sur une autre zone
réellement nommée `dropzone1` entre en collision avec elle. `_loadAIZonesFromConfig` signale ce cas
au rapport de démarrage sous la forme
`AIZ[i] ERROR '<nom>': name already taken by zone '<détenteur>' — entry ignored`, au point du skip
plutôt que dans `_validateZoneNames`, qui s'exécute avant la découverte et devrait donc prédire ce
que celle-ci va réclamer.

### Détails du fallback legacy { #legacy-fallback-details }

- Les entrées `troopZones` prennent en charge à la fois les zones de trigger DCS et les **noms
  d'unités de navire** — si `trigger.misc.getZone` échoue, le loader se rabat sur `Unit.getByName`
  et passe le navire comme `linkedUnit` de la zone, avec le rayon de **200 m** codé en dur en v1.
  La zone suit le navire : son centre est résolu à chaque `getCenter()`, et le point capturé à
  l'init n'est que la dernière position connue, utilisée une fois le navire disparu. Les troop
  zones legacy dérivent automatiquement un `stockFlagName` de la forme `<zoneName>_count`,
  reflétant `pickCurrentStock` vers ce flag DCS.
- Les entrées `logisticUnits` sont résolues via `StaticObject.getByName` ou `Unit.getByName` et
  deviennent des logistic zones **dynamiques** liées à cet objet (rayon issu de
  `maximumDistanceLogistic`, défaut 200 m). Une entrée qui ne résout rien produit un WARN — elle
  désigne un objet précis, donc son absence est une erreur. `logisticUnitTypes` en est le pendant
  par type et reste silencieux pour un type que la mission ne contient pas.

## `CTLDTroopZone`

Construite à partir d'une table `data`. Requis : `dcsName`, `zoneName`, `coalition`, `center`
(vec3), `radius`. Optionnels : `verticies`, `pickMaxStock`, `objectiveFlag`, `objectiveTarget`,
`stockFlagName`, `smoke` (une valeur `trigger.smokeColor.*` ou `-1`), `active`, les flags de
rôle `isWaypoint` / `isDropoff` / `isAIPickup` / `isAIDropoff`, et les champs IA `aiDropMode`,
`aiCargoType`, `troopTemplates`, `vehicleTypes`, `_aiTroopStock`, `_aiVehicleStock`.

### Prédicats de rôle { #role-predicates }

| Méthode | Vrai quand |
| --- | --- |
| `zone:hasPickup()` | `pickMaxStock ~= nil` |
| `zone:hasExtract()` | `objectiveFlag ~= nil` |
| `zone:hasWaypoint()` | `isWaypoint == true` |
| `zone:hasDropoff()` | `isDropoff == true` (auto-drop legacy IAZ) |
| `zone:hasAIPickup()` | `isAIPickup == true` (rôle P d'AIZ) |
| `zone:hasAIDropoff()` | `isAIDropoff == true` (rôle D d'AIZ) |

### Géométrie { #geometry }

`zone:isInZone(point)` teste les zones polygonales (`verticies` avec ≥3 sommets) via un
ray-cast de Jordan sur le static privé `CTLDTroopZone._raycast`, sinon se rabat sur un test de
rayon circulaire. À noter que `verticies[i].x/.y` sont des coordonnées de fichier de mission où
le `Y` de mission égale le `Z` monde. `zone:getCenter()` résout le centre live dans le même ordre
que `CTLDLogisticZone` : `linkedUnit` (zone portée par un navire) → `trigger.misc.getZone(dcsName)`
(Moving Zone) → le `center` stocké.

### Gestion du stock { #stock-management }

```lua
zone:consumeStock(n)   -- décrémente pickCurrentStock de n ; true en cas de succès, illimité toujours true
zone:restoreStock(n)   -- restaure jusqu'à pickMaxStock ; no-op pour les zones illimitées ou sans pickup
```

Les deux appellent `_syncStockFlag()`, qui écrit `pickCurrentStock` dans `stockFlagName` via
`trigger.action.setUserFlag` lorsque ce flag est défini. Un stock illimité (`pickMaxStock == 0`)
signifie que `consumeStock` réussit toujours et que `restoreStock` est un no-op.

### Stock IA par template / par type (Feature T) { #ai-per-template-per-type-stock-feature-t }

Les zones AIZ peuvent porter un stock granulaire au lieu d'un simple compteur. `_aiTroopStock`
et `_aiVehicleStock` sont des tables de la forme
`{ isAll = bool, init = {name=N}, current = {name=N} }`, où `N = -1` signifie illimité. La clé
de config spéciale `"All"` positionne `isAll = true` (chaque template/type, illimité).

```lua
zone:aiPickTroopTemplate(teams, typeName, unitName, tm)  -- meilleur template éligible, ou nil
zone:aiConsumeTroopStock(templateName)                   -- décrémente une unité de troop
zone:aiRestoreTroopStock(templateName, n)                -- restaure n (défaut 1), plafonné à init
zone:aiPickVehicleEntry()                                -- { type, isScene, isAASystem } ou nil
zone:aiConsumeVehicleStock(typeName)                     -- décrémente un véhicule
zone:aiRestoreVehicleStock(typeName)                     -- restaure un, plafonné à init
```

`aiPickTroopTemplate` filtre les templates qui sont en stock **et** qui rentrent dans la
capacité du transport (`tm:_canEmbark`), puis privilégie le stock courant le plus élevé,
choisissant au hasard en cas d'égalité. `aiPickVehicleEntry` résout le provider de chaque type
par ordre de priorité `CTLDSceneManager` (scene) > `CTLDCrateAssemblyManager` (AA system) > DCS
natif, retournant `nil` lorsque `isAll` est positionné (l'appelant utilise alors le chemin
legacy de scan physique).

### Objectif { #objective }

```lua
zone:incrementObjective(soldierCount)  -- → incremented(bool), valueBefore, valueAfter
```

Ajoute `soldierCount` à `objectiveFlag` (mode : **+N par soldat**, pas par groupe ni par
opération) et logge une ligne `INFO` lorsque `objectiveTarget` est atteint. CTLD ne fait que
incrémenter le flag ; il remet `objectiveFlag` à 0 une seule fois à la découverte, et le mission
maker définit la condition de victoire dans l'éditeur DCS avec un trigger tel que
`if flag >= target → victory`.

`zone:activate()` / `zone:deactivate()` basculent le flag `active`.

## `CTLDLogisticZone`

Construite à partir de `data`. Requis : `name`, `coalition`, `center`, `radius` (défaut 200).
Optionnels : `linkedUnit` (la zone suit alors cette unité/static DCS), `active`, et une table
`services` qui vaut par défaut `{ cratesPickup = true, cratesDropoff = true, vehicleSpawn = true }`.

| Méthode | Comportement |
| --- | --- |
| `zone:getCenter()` | Point live de l'unité liée si elle existe encore, sinon le center stocké |
| `zone:isDynamic()` | Vrai si ancrée à une unité DCS mobile (`_linkedUnit ~= nil`) |
| `zone:isAlive()` | Vrai sauf si l'unité liée n'existe plus (toujours vrai pour une static) |
| `zone:isInZone(point)` | Test de rayon circulaire uniquement — les logistic zones sont toujours circulaires |
| `zone:activate()` / `zone:deactivate()` | Bascule `active` |

## Scheduler de smoke { #smoke-scheduler }

`_scheduleSmoke()` se réarme toutes les `smokeRefreshInterval` secondes (défaut 300). Lorsque
`disableAllSmoke` est positionné, il se re-planifie sans rien faire. Sinon, il fume chaque troop
zone active dont `smoke >= 0` et chaque logistic zone active qui a une couleur dans
`logisticZoneSmokeColor[coalition]`, puis publie `OnZoneSmokeRefreshed` avec un instantané des
deux ensembles de zones (positions, stock, progression d'objectif, couleurs).

## Événements { #events }

Publiés via `EventDispatcher` (voir [Architecture](../architecture.md)) :

| Événement | Publié quand |
| --- | --- |
| `OnZoneSmokeRefreshed` | Toutes les `smokeRefreshInterval` secondes par la boucle de smoke |
| `OnLogisticZoneUpdated` | À l'init, à la mort d'une unité dynamique, et lors d'un register / unregister / (dé)activation de FOB / logistique |

Le manager enregistre `onDead` pour `S_EVENT_DEAD` via `CTLDDCSEventBridge` : lorsque l'unité
liée d'une logistic zone dynamique meurt, la zone est retirée et un `OnLogisticZoneUpdated` est
publié avec le retrait.

## API de requête — troop zones { #query-api-troop-zones }

```lua
zm:getTroopZone(zoneName)                     -- → CTLDTroopZone | nil
zm:getTroopZonesForCoalition(coalition)       -- zones actives pour la coalition (0 = les deux)
zm:getTroopZoneAtPoint(point, coalition)      -- zone contenante ; exclut les pickup zones réservées à l'IA
zm:getTroopZoneForUnit(unitName)              -- zone sous la position d'une unité live
zm:getWaypointZoneAt(point, coalition)        -- WPZ active contenant point
zm:getNearestWaypointZone(point, coalition)   -- WPZ la plus proche (point n'a pas besoin d'être à l'intérieur)
zm:getDropoffZoneAt(point, coalition)         -- zone d'auto-drop legacy IAZ active au point
zm:getAIPickupZoneAt(point, coalition)        -- zone AIZ P active au point (le plus petit rayon l'emporte)
zm:getAIDropoffZoneAt(point, coalition)       -- zone AIZ D active au point (le plus petit rayon l'emporte)
```

Le filtrage par coalition suit partout la même règle : une zone correspond quand
`coalition == 0` (l'appelant accepte tout), ou `zone.coalition == 0` (la zone sert tout le
monde), ou les deux camps sont égaux. `getNearestWaypointZone` sous-tend la Feature I
(`gotoNearestWPZ`), et les getters de pickup/dropoff IA sous-tendent la boucle de transport IA
(`_checkAIStatus`).

## API de requête — logistic zones { #query-api-logistic-zones }

```lua
zm:getLogisticZone(name)                             -- → CTLDLogisticZone | nil
zm:getLogisticZonesForCoalition(coalition)           -- zones actives + vivantes pour la coalition
zm:getLogisticZoneAtPoint(point, coalition)          -- première zone contenante
zm:getLogisticZoneForUnit(unitName)                  -- zone sous une unité / static
zm:getLogisticZonesAtPoint(point, coalition, key)    -- TOUTES les zones contenantes ; filtre services optionnel
```

`getLogisticZonesAtPoint` retourne chaque zone correspondante (pas seulement la première). Le
`serviceKey` optionnel (par ex. `"cratesPickup"`) ne conserve que les zones où
`zone.services[key]` n'est pas `false`.

## Enregistrement à l'exécution et API rétrocompatible { #runtime-registration-and-legacy-compatible-api }

```lua
zm:registerFOBAsLogistic(fobName, point, radius, coalitionId)  -- ajoute un FOB construit comme LGZ
zm:unregisterLogistic(name)                                     -- retire une LGZ dynamique (FOB détruit)
zm:registerFOBAsTroopZone(fobName, point, radius, coalitionId)  -- ajoute un FOB construit comme TRZ à stock illimité
zm:unregisterTroopZone(name)                                    -- retire une TRZ dynamique (FOB détruit)
zm:deactivateLogisticZone(name)                                 -- désactivation réversible (capture / perte)
zm:activateLogisticZone(name)                                   -- réactive
zm:setTroopZoneActive(zoneName, active)                         -- active / désactive une TRZ

-- Rétrocompatible (appelé par les wrappers de l'API legacy) :
zm:isUnitInZone(unitName, zoneType)     -- zoneType : "extract" | "pickup" | nil (toute zone active)
zm:createExtractZone(zoneName, flag, smoke)   -- EXZ à l'exécution depuis une zone de trigger DCS
zm:removeExtractZone(zoneName, flag)          -- flag accepté mais ignoré
zm:createTroopZoneAtObject(objectName, trzName)  -- TRZ pickup à l'exécution sur tout objet nommé
zm:parseTRZ(name)                             -- parse un nom TRZ_ sans rien enregistrer
zm:activateWaypointZone(zoneName)             -- délègue à setTroopZoneActive(…, true)
zm:deactivateWaypointZone(zoneName)           -- délègue à setTroopZoneActive(…, false)
zm:changeRemainingGroups(zoneName, amount)    -- ajuste pickCurrentStock de ±amount (plancher à 0)
```

Les logistic zones désactivées sont ignorées par chaque getter jusqu'à réactivation, ce qui
permet à une mission de simuler un point de ravitaillement capturé ou temporairement perdu sans
le détruire.

`createTroopZoneAtObject` résout `objectName` en essayant, dans l'ordre, une zone de trigger DCS,
une unité, un statique, un groupe, ou un airbase/FARP — et ancre la zone à cet objet quand il peut
bouger (`dcsName` pour une zone de trigger qui est une Moving Zone, `linkedUnit` pour une
unité/statique/groupe) ; un airbase/FARP reste fixe. Le rayon propre de la zone de trigger est
utilisé ; tout autre objet reçoit un rayon par défaut de 200 m. Par exemple, pour ajouter une zone
pickup sur un FARP placé dans l'éditeur de mission :

```lua
zm:createTroopZoneAtObject("FARP Alpha", "TRZ_farpAlpha_B_999_nil_0")
```

`parseTRZ` est ce que cette méthode et la découverte TRZ à l'init utilisent toutes les deux pour
transformer un nom `TRZ_…` en `{zoneName, coalition, pickMaxStock, objectiveFlag,
objectiveTarget}` (ou `nil` + une raison) — voir la
[convention de nommage TRZ](#trz-naming-convention) plus haut.

## Priorité de déchargement : extract avant RTB { #unload-priority-extract-before-rtb }

Lorsqu'un joueur décharge des troops, la zone contenante est évaluée dans cet ordre (géré par le
sous-système troop, pas par le zone manager lui-même) :

1. TRZ avec `objectiveFlag` → **extract** (déploie les troops, incrémente le flag).
2. TRZ avec pickup seulement → **RTB** (les troops rentrent, stock restauré).
3. Sinon → **combat deploy** (troops déployées, pas de flag, pas de changement de stock).

Cet ordre garantit qu'une zone mixte déclenche son objectif lorsqu'elle est utilisée comme point
d'extract plutôt que de simplement renvoyer les troops au stock.

## Comportement du menu F10 { #f10-menu-behaviour }

Le menu de commande des troops est reconstruit sur `S_EVENT_LAND` / `S_EVENT_TAKEOFF` à partir
de la position courante du joueur et de l'état de sa cargaison :

- En vol : le sous-menu « Troop Commands » est vide.
- Au sol dans une pickup TRZ : une option « Load from `<zoneName>` » apparaît.
- Au sol avec des troops à bord : une option « Unload / Extract » apparaît.
- Au sol hors de toute TRZ : aucune option de chargement.

## Validation des noms de zone { #zone-name-validation }

`_validateZoneNames()` s'exécute en premier dans `init()` et produit un unique rapport groupé
(`trigger.action.outText` + log DCS + `env.warning`). Il couvre :

- **TRZ / WPZ / LGZ** : toute zone de trigger portant le préfixe qui échoue à son parser est
  reportée comme une erreur.
- **Config AIZ (Features S/T)** : des vérifications par entrée accumulent erreurs et
  avertissements, indexées par `dcsZoneName` afin que seules les entrées invalides soient
  ignorées dans `_loadAIZonesFromConfig`.

| Règle | Sévérité | Condition |
| --- | --- | --- |
| — | error | `dcsZoneName` manquant, `dcsZoneName` en double, zone absente de l'éditeur de mission, ou `coalition` manquante/invalide |
| G1 | error | ni `isPickup` ni `isDropoff` — la zone ne ferait rien |
| G5 | error | `cargoType` véhicule (`V`/`TV`) sur une pickup zone mais aucun aéronef n'a `canTransportWholeVehicle` |
| — | warn | `cargoType` invalide (défaut à `T`) ou `aiDropMode` invalide (défaut à `GP`) |
| G3 | warn | pickup + cargo troop mais `troopStock` indéfini — pickup de troop désactivé |
| G6 | warn | pickup + cargo véhicule mais `vehicleStock` indéfini — pickup de véhicule désactivé |
| G2 | warn | chaque entrée de `troopTemplates` est inconnue (des avertissements par nom sont aussi émis) |
| G4 | warn | chaque entrée de `vehicleTypes` est inconnue dans les listes de véhicules chargeables |
| — | warn | une pickup zone chevauche une dropoff zone de la même coalition — risque de boucle instantanée pickup/dropoff |

Lorsqu'il n'y a aucune anomalie, il logge `CTLDZoneManager: zone config valid` à la place.
