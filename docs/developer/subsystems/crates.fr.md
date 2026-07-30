# Pipeline de spawn des caisses (crates) { #crate-spawn-pipeline }

Les crates sont la monnaie physique de la logistique CTLD : un transport demande de
l'équipement sous forme de crate (ou d'un ensemble de crates), le transporte jusqu'à une
destination, le dépose ou le sling-load, puis le unpack en un véhicule, un JTAC ou une scène.
Tout le domaine réside dans `src/CTLD_crate.lua`, qui définit l'entité `CTLDCrate` et le
singleton `CTLDCrateManager`.

Cette page suit une crate de sa configuration jusqu'à ses contenus déployés. Pour les
signatures des méthodes publiques du manager, voir la [référence de l'API](../api-reference.md) ;
pour les événements qu'il publie, voir [Events](../events.md) ; pour les scènes et véhicules
qu'il alimente, voir [Scenes](scenes.md) et [Vehicles](vehicles.md).

## L'entité `CTLDCrate` { #the-ctldcrate-entity }

`CTLDCrate = class()` modélise un static de cargo et son cycle de vie. Une crate est créée avec
`CTLDCrate:new(data)` (jamais via les internes du `CTLDCrateManager` directement) et porte son
descripteur, sa position, sa coalition, sa méthode de spawn et le handle du `StaticObject` DCS.

Le cycle de vie est une petite machine à états conservée dans `crate.state`, tirée de
`CTLDCrate.STATE` :

| État | Signification |
| --- | --- |
| `spawned` | Au sol, fraîchement créée, jamais déplacée |
| `loaded` | À l'intérieur / attachée à un transport |
| `falling` | En l'air, en descente (drop ou parachute) |
| `landed` | Au sol après un cycle de transport |
| `unpacked` | Contenus déployés — état terminal |

Les transitions sont pilotées par des méthodes d'entité, dont chacune positionne `state` et les
champs pertinents : `load(transport)`, `unload(position)`, `drop(position)`,
`startParachute(altitude)`, `land(position)` et `unpack()`. `destroy()` supprime le static DCS
sous-jacent.

Deux prédicats conditionnent les actions de menu. `isOnGround()` renvoie vrai uniquement dans
l'état `spawned` ou `landed` **et** vérifie `dcsStatic:isExist()` lorsqu'un handle de static est
présent — cela protège contre les crates détruites au combat avant qu'un `S_EVENT_DEAD` n'ait pu
les désenregistrer. `canUnpack()` combine `isOnGround()` avec le flag `canBeUnpacked`.
`isLoadedByCTLD()` renvoie vrai dès que la crate est `loaded`, couvrant à la fois les loads via
le menu CTLD et les loads natifs DCS migrés dans CTLD ; utilisez `loadedByDCSNative` pour
distinguer les deux.

Chaque crate enregistre son origine dans `crate.spawnMethod`, l'une des valeurs de
`CTLDCrate.SPAWN_METHOD` :

| Valeur | Origine |
| --- | --- |
| `crate_spawn` | Spawnée depuis le menu F10 Request Equipment |
| `vehicle_pack` | Résultat du pack d'un véhicule |
| `mission_maker` | Pré-placée par le mission maker (détectée via INIT-B) |
| `menu_ctld` | Spawnée via une action de menu CTLD |

## Pré-traitement de la configuration : `_processSpawnableCrates` { #configuration-pre-processing-_processspawnablecrates }

`CTLDCrateManager.getInstance()` appelle `_processSpawnableCrates()` une seule fois au premier
accès. Elle lit la configuration brute `ctld.gs("spawnableCrates")` et la transforme en deux
structures internes sur lesquelles s'appuient le constructeur de menu et chaque lookup de
descripteur :

- `self._processedCrates[category] = { singleCrates = { {singleCrate, singleTypeSet?}, … }, mixedSets = { … } }`
- `self._weightIndex[weight] = descriptor` — un index O(1) utilisé par toutes les méthodes
  `findDescriptorBy*` (crates simples uniquement ; les mixed sets n'ont pas de champ `weight`).

Avant la boucle principale, `CTLDCrateAssemblyManager.injectAACrates(spawnableCrates)` injecte
les entrées de crates de pièces/réparation des systèmes AA afin qu'elles transitent par les
mêmes passes. La transformation exécute ensuite trois passes par catégorie :

1. **Séparation.** Chaque entrée avec un champ `weight` devient une crate simple (indexée dans un
   `catWeightIdx` propre à la catégorie et dans `self._weightIndex`) ; chaque entrée avec un champ
   `mixedSet` devient un mixed set. Les entrées avec ni l'un ni l'autre sont journalisées en
   warning et ignorées.
2. **Génération de `singleTypeSet`.** Pour chaque crate simple dont `cratesRequired > 1`, lorsque
   `enableAllCrates` n'est pas `false` et que le `showSets` de la crate n'est pas `false`, un
   `singleTypeSet` auto-généré est stocké à côté d'elle : `multiple` est le weight répété
   `cratesRequired` fois, et `desc` est la description de la crate plus un suffixe i18n-aware
   `" - " .. ctld.tr("All crates")`. Positionner `showSets = false` sur une crate supprime cette
   entrée même lorsque `enableAllCrates` est activé.
3. **Validation des mixed sets.** Chaque weight d'un `mixedSet` est vérifié par rapport à l'index
   de la catégorie. Tout weight non résolu invalide l'ensemble du set (exclu du menu) et met en
   file un warning mission-maker affiché via `trigger.action.outText` au démarrage. Les sets
   valides sont copiés avec `mixedSet` aliasé sur `multiple` pour la compatibilité de spawn.

Les scene crates enregistrées avant l'init sont fusionnées ensuite via `_injectSceneCrate` ; les
scènes enregistrées plus tard sont injectées de façon incrémentale par
`CTLDSceneManager:registerSceneModel`. Les collisions de weight lors de l'injection sont résolues
en avançant jusqu'au prochain slot libre dans la même plage `1001.xx` et en journalisant un
`WARN`. Les scènes désactivées par l'audit des mods sont purgées par `_purgeDisabledScenes`.

## Du menu au sol : `spawnCrate` { #from-menu-to-ground-spawncrate }

Une requête de spawn passe par `spawnCrate(descriptor, position, coalitionId, spawnedBy,
spawnMethod, countryId, modelKey)`. Elle délègue la création du static à `_spawnStatic`, qui :

- résout le modèle de crate depuis `ctld.gs("spawnableCratesModels")` par `modelKey`, avec un
  fallback sur `"load"` ;
- dérive le country de la coalition lorsque `countryId` est nil ;
- construit un nom unique assaini (`CTLD_<label>_<uid>` ou `CTLD_Crate_<uid>`) ; et
- appelle `ctld.utils.dynAddStatic` (jamais `coalition.addStaticObject` directement) à l'intérieur
  d'un `pcall`, renvoyant le nom et le handle du `StaticObject`.

`spawnCrate` enveloppe ensuite le static dans un `CTLDCrate`, l'enregistre, publie
`OnCrateSpawned` et planifie un `_refreshNearbyPlayers` quasi-immédiat afin que les transports
proches voient la nouvelle crate dans leur sous-menu Load Crate. `spawnCratesAligned` est le point
d'entrée par lot : il choisit un axe de spawn aléatoire (secteur avant pour les transports
standard, secteur arrière pour ceux capables de native-cargo), calcule des positions sans
chevauchement en évitant les bounding boxes des autres aéronefs à cargo dynamique, et appelle
`spawnCrate` pour chaque descripteur. La clé de modèle est choisie par `_crateModelKey` : `"sling"`
lorsque `slingLoad` est positionné, `"dynamic"` pour les transports capables de native-cargo,
sinon `"load"`.

## Transitions de cycle de vie sur le manager { #lifecycle-transitions-on-the-manager }

Le manager reflète les transitions de l'entité et détient la publication des événements :

| Méthode | Transition | Publie |
| --- | --- | --- |
| `loadCrate(crateName, transport)` | `spawned`/`landed` → `loaded` (détruit le static) | `OnCrateLoaded`, `OnCrateCleared` |
| `unloadCrate(crateName, position, method)` | `loaded` → `landed` (respawn le static) | `OnCrateUnloaded`, `OnCrateSpawned` |
| `unpackCrate(crateName, unpacker)` | `spawned`/`landed` → `unpacked` (détruit + désenregistre) | `OnCrateUnpacked`, `OnCrateCleared` |
| `destroyCrate(crateName)` | détruit + désenregistre | `OnCrateCleared` |

Le load et le unload appellent tous deux `ctld.utils.updateTransportWeight` pour que la masse du
transport reflète son cargo. Comme le static DCS est détruit au load, `unloadCrate` le recrée via
`_respawnStatic`, qui génère un nouveau nom unique et ré-indexe `self.crates` sous celui-ci.

## Le pipeline de unpack : `_spawnUnpacked` { #the-unpack-pipeline-_spawnunpacked }

Chaque issue de unpack — véhicule au sol, JTAC aérien ou static — est déployée via un unique
pipeline en trois étapes dans `_spawnUnpacked(desc, pos, coa, cId, playerName)` :

```
_spawnUnpacked(desc, pos, coa, cId, playerName)
  ├── spawnAs ≠ "GROUND"/"STATIC" (air) + JTAC_dropEnabled == false → skip
  ├── desc.isJTAC → CTLDJTACManager:_consumeJTACSlot(coa)   ← quota gate (définitif)
  │     └── limite atteinte → notifie le joueur + return (pas de spawn)
  ├── ctld.utils.buildGroupUnitDef(desc, pos, gname, gid, uid)
  │     ├── spawnAs == "GROUND"   → minimal {name, task, units[{x,y,heading}]}
  │     └── spawnAs == "AIRPLANE" → complet {groupId, units[{alt,speed}], route[orbit+EPLRS]}
  │           (orbit + EPLRS embarqués uniquement quand isJTAC = true)
  ├── ctld.utils.spawnFromDescriptor(desc, cId, unitDef)
  │     ├── spawnAs == "STATIC"   → coalition.addStaticObject
  │     └── sinon                 → coalition.addGroup(Group.Category[spawnAs])
  └── _dispatchPostSpawn(desc, gname)
        └── isJTAC = true → CTLDJTACManager:startLase(gname)
```

Les spawns au sol publient en plus `OnGroundUnitSpawned`. En cas de succès, lorsqu'un `playerName`
est fourni, les sous-menus load et pack du spawner de véhicules sont rafraîchis.

**Règles clés :**

- `coalition.addGroup` et `coalition.addStaticObject` ne doivent être atteints que via
  `ctld.utils.spawnFromDescriptor` — jamais appelés directement.
- `ctld.utils.buildGroupUnitDef` est le constructeur unique des définitions d'unités GROUND et AIR.
  Les objets STATIC utilisent un schéma séparé et vont directement à `addStaticObject`.
- L'activation de rôle post-spawn appartient exclusivement à `_dispatchPostSpawn`. Cette méthode
  démarre le lasing JTAC pour les descripteurs `isJTAC` et enregistre à la fois les JTAC et les
  véhicules au sol ordinaires auprès de `CTLDVehicleSpawner` afin que le menu Load/Unload puisse
  les suivre. N'ajoutez pas de logique de rôle ailleurs dans le chemin de unpack.
- Le quota JTAC (`JTAC_LIMIT_RED`/`JTAC_LIMIT_BLUE`) est consommé **avant** le spawn, ici comme
  dans le chemin Request Equipment (`spawnJTACFromDescriptor`). Le quota est définitif — il n'est
  jamais réapprovisionné lorsqu'un JTAC est tué. Les JTAC de mission-maker et les soldats JTAC
  d'infanterie ne le consomment pas.

## Champs de descripteur pilotant le pipeline { #descriptor-fields-driving-the-pipeline }

| Champ | Effet sur le pipeline |
| --- | --- |
| `spawnAs` (string, défaut `"GROUND"`) | Sélectionne la catégorie `addGroup` ou route vers `addStaticObject` |
| `isJTAC` (boolean) | **Source de vérité pour le rôle JTAC.** Ajoute la route d'orbit à une définition d'unité aérienne et déclenche `startLase` en post-spawn. Le nom de type d'unité (`unit`) n'est jamais utilisé pour la détection JTAC dans la stack OOP. |
| `specificParams` (table, air uniquement) | Réglage d'orbit passé à `startLase` / `deployAirJTAC` : `speed`, `alti`, `orbitRadiusNoLase`, `orbitRadiusOnLase` |
| `cratesRequired` (number) | Conditionne le unpack — le compte doit être atteint avant que le pipeline ne s'exécute |
| `showSets` (boolean, défaut `true`) | Lorsque `false`, supprime l'entrée `singleTypeSet` « All crates » auto-générée même si `enableAllCrates` est activé |

### Règles de détection JTAC (ne pas inverser) { #jtac-detection-rules-do-not-invert }

| Contexte | Règle |
| --- | --- |
| Peuplement du menu Request Equipment | `getJTACDescriptors(coalition)` itère `_processedCrates` et renvoie les entrées de crate simple avec `isJTAC = true` pour la coalition du joueur (ou `side = nil`) |
| Spawn Request Equipment | `CTLDVehicleSpawner:spawnJTACFromDescriptor(desc, spawner, zone)` — vérification du quota → sol : `spawnVehicleForTransport` + `startLase` ; air : `deployAirJTAC` |
| Activation post-unpack | `_dispatchPostSpawn` : `if desc.isJTAC → CTLDJTACManager:startLase()` |
| Détection de groupe MM pré-placé | Le nom du groupe contient `"jtac"` (insensible à la casse) — type d'unité non utilisé |
| Deploy de troops avec un soldat JTAC | `tmpl.hasJtac == true` (calculé depuis `jtac > 0`) → `startLase` après le deploy |

> N'ajoutez pas de nouveaux chemins de détection JTAC. Si un nouveau type d'unité a besoin du
> comportement JTAC, positionnez `isJTAC = true` sur son descripteur de crate — ne l'ajoutez
> jamais à une liste de noms de type. `JTAC_unitTypeNames` a été supprimé : le catalogue de crates
> est la source de vérité unique tant pour le menu de crates que pour le menu Request Equipment.

## Intégration au menu F10 { #f10-menu-integration }

`buildMenuSection(playerObj, menu)` construit le sous-menu **Request Equipment** (`order = 25`,
entre les commandes Troop et Vehicle) et le sous-menu **Crate Commands** (`order = 40`),
conditionnés par le `capabilitiesByType[typeName].cratesEnabled` du joueur. Les sous-menus
dynamiques sont reconstruits à la demande :

- `refreshRequestEquipmentSection` rend les `singleCrates` de chaque catégorie (chacune suivie
  immédiatement de son `singleTypeSet` lorsqu'il est visible) puis ses `mixedSets`, avec un
  filtrage coalition/JTAC par joueur et un compteur d'ordre stable.
- `refreshLoadCrateSection` regroupe les crates situées à moins de 50 m par type de descripteur
  avec un compte ; le load choisit la crate correspondante la plus proche et applique le
  `maxCratesOnboard` du transport.
- `refreshUnpackSection` liste les sets assemblables (compte ≥ `cratesRequired`) à moins de 300 m,
  en déléguant les sets AA à `CTLDCrateAssemblyManager:tryUnpackOrRepair`, les scene crates à
  `CTLDSceneManager:playScene` (ou au `crate.unpack` propre à un modèle), et les véhicules
  standard à `_spawnUnpacked`.
- `refreshPackEquiptSection` affiche le sous-menu unifié **Pack Equipt** (scènes FARP et véhicules
  packables) uniquement au sol, lorsque `enableFARPRepack` ou `enablePackingVehicles` est
  positionné.

Un poller de position au sol (10 s) rafraîchit Request Equipment uniquement lorsque l'ensemble des
logistic-zones du joueur change, évitant une reconstruction à cadence fixe qui éjecterait les
joueurs des sous-menus ouverts. Les événements de spawn et de clear de crate rafraîchissent les
sous-menus Load Crate et Unpack pour chaque transport à portée.
