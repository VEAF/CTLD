# Système de véhicules { #vehicle-system }

Le système de véhicules transporte des **unités terrestres entières** par voie aérienne : un
transport récupère un véhicule pilotable dans une zone logistique, le convoie, et le repose sur
le terrain — sans jamais le décomposer en crates. C'est le pendant du pipeline de crates (voir
[crates](crates.md)), et il sous-tend également le spawn des JTAC terrestres (voir
[Cycle de vie Troop + JTAC](troops-jtac.md)).

**Source :** `src/CTLD_vehicle.lua`
**Entité :** `CTLDVehicle`
**Singleton :** `CTLDVehicleSpawner`

`CTLDVehicleSpawner` suit l'idiome de manager standard (`X = class()` + `getInstance()` — voir
[Architecture](../architecture.md)) : une unique `_instance`, allouée paresseusement au premier
appel de `CTLDVehicleSpawner.getInstance()`. `CTLDVehicle` est une simple entité créée avec
`:new(data)`.

```lua
CTLDVehicle        = class()
CTLDVehicleSpawner = class()
CTLDVehicleSpawner._instance = nil

function CTLDVehicleSpawner.getInstance()
    if not CTLDVehicleSpawner._instance then
        local o = setmetatable({}, CTLDVehicleSpawner)
        o:init()
        CTLDVehicleSpawner._instance = o
    end
    return CTLDVehicleSpawner._instance
end
```

À l'`init()`, le singleton enregistre sa section du menu F10 (`order = 30`), s'abonne au pont DCS
`S_EVENT_DEAD`, s'abonne à plusieurs événements du bus, et démarre trois timers périodiques
(détection de chargement natif, rafraîchissement de l'atterrissage pour packing, indice de vol
stationnaire).

## Machine à états { #state-machine }

`CTLDVehicle.STATE` déclare quatre états :

| État | Signification |
| --- | --- |
| `WAITING` | Au sol, suivi, prêt à être chargé |
| `LOADED` | Transporté par un transport (unité DCS détruite pour `menu_ctld`, ou physiquement liée pour `dcs_native`) |
| `FALLING` | Libéré en vol par le système cargo natif DCS : l'unité reste vivante et tombe sous son parachute DCS ; retour à `WAITING` une fois posé |
| `DELIVERED` | Déclaré mais **actuellement non assigné** — réservé à un futur état de livraison dédié |

Les transitions réellement effectuées par le code actuel sont :

```
        spawn / register              loadVehicle
   (none) ───────────────► WAITING ──────────────► LOADED
                              ▲                        │
                              │      unloadVehicle     │
                              └────────────────────────┘
                              │   parachuteVehicle
                              └─── (drop, then respawn) ─► WAITING
```

`unloadVehicle` comme `parachuteVehicle` ramènent le véhicule à `WAITING` (et non `DELIVERED`)
afin qu'il puisse être rechargé une fois de retour au sol. `setState(newState)` n'effectue aucune
validation — la correction incombe aux appelants.

## Méthodes de chargement et déchargement { #load-and-unload-methods }

Le chargement et le déchargement portent chacun une chaîne `method` :

| Sens | Méthode | Déclencheur |
| --- | --- | --- |
| Load | `menu_ctld` | Le joueur choisit un véhicule dans le sous-menu F10 **Load / Extract Vehicles** ; l'unité DCS est détruite au chargement |
| Load | `dcs_native` | L'entrée compagnon `CRG:<nom d'unité>` du véhicule apparaît dans la liste de cargo à bord d'un appareil joueur (`unit:getCargosOnBoard()`) ; DCS garde l'unité physiquement liée |
| Unload | `menu_ctld` | Le joueur choisit un véhicule dans **Unload Vehicles** ; l'unité est respawnée près du transport |
| Unload | `dcs_native` | L'entrée quitte la liste, transport au sol ; DCS a déjà posé l'unité, CTLD récupère la référence vivante (jamais respawnée) |
| Unload | `parachute` | Largage en vol : **Parachute Vehicle** virtuel de CTLD (l'unité est respawnée à sa position d'atterrissage), ou véhicule en carry natif dont l'entrée quitte la liste en vol (l'unité n'est **pas** respawnée ; état `FALLING` jusqu'à l'atterrissage) |

La règle derrière les deux modes de carry est qu'un objet cargo est **déchargé de la façon dont il a été
chargé** : les entrées F10 de déchargement et de parachutage (`findVirtualCarryVehicles`) ne listent que les
véhicules en carry virtuel, et un véhicule en carry natif est libéré par DCS.

## D'où vient un véhicule `WAITING` { #where-a-waiting-vehicle-comes-from }

Un `CTLDVehicle` chargeable en état `WAITING` est enregistré par l'un de ces chemins :

| Source | Mécanisme |
| --- | --- |
| Véhicule pré-placé par le MM | INIT-D `scanMMVehicles()` scanne les groupes `Group.Category.GROUND` des deux coalitions et appelle `_registerMMVehicleUnit(unit)` pour chaque unité **vivante** dont le type possède un descripteur de crate CTLD (`findDescriptorByUnitType`) |
| Activation retardée | `S_EVENT_BIRTH` → `onBirth` diffère d'une frame → `_onBirthDeferred` → `_registerMMVehicleUnit` (ou rattache une référence d'unité vivante à un véhicule existant après un déchargement) |
| Spawn programmatique | `spawnVehicleForTransport(vehicleType, spawner, logisticZone)` spawne une unité neuve près d'un transport et l'enregistre `WAITING` |
| Unpack de crate | `spawnVehicleAt(spawnData, position)` / `registerJTACVehicle(...)` enregistrent une unité produite par le flux d'unpack de crate/JTAC |

`_registerMMVehicleUnit` est idempotent : il ignore une unité déjà présente dans la table de
recherche inverse `_unitToVehicle`.

### `spawnVehicleForTransport`

Spawne une unité pilotable dans le **secteur avant** du transport via `ctld.utils.dynAdd`, crée le
`CTLDVehicle` en `WAITING`, et publie `OnVehicleSpawnedForTransport`. Les noms de groupe et d'unité
sont attribués sous la forme `CTLD_VEH_<type>_<id>` (les espaces et slashes étant remplacés par
`_`), et conservés dans `spawnData` afin que l'unité réapparaisse sous le même nom après tout
déchargement ultérieur. Le chemin JTAC terrestre (`spawnJTACFromDescriptor`) appelle cette méthode,
puis `CTLDJTACManager:startLase(...)`.

> La branche Feature-Q « Request Equipment spawns a whole vehicle » existe dans
> `CTLDCrateManager:refreshRequestEquipmentSection` mais est actuellement inerte : le constructeur
> de menu fixe `spawnAsVehicle = false` pour chaque entrée, de sorte que **Request Equipment
> (order 25) ne spawne jamais que des crates**. Le chargement de véhicules entiers est piloté par
> le menu Vehicle Commands dédié, à l'encontre de véhicules déjà `WAITING`.

## Pipeline de chargement — `loadVehicle(vehicle, transport, player, method)` { #load-pipeline-loadvehiclevehicle-transport-player-method }

1. Rejeter sauf si le véhicule est `WAITING`.
2. Garde-fou de capacité `menu_ctld` : lire `caps.maxWholeVehiclesOnboard` (défaut `1`) depuis
   l'entrée `capabilitiesByType` du transport, compter `findLoadedVehicles(transport)`, et refuser
   avec un message au joueur si la soute est pleine. (La capacité `dcs_native` est laissée à DCS.)
3. Si le véhicule est un JTAC enregistré, suspendre le lasing (`setJTACInTransit`).
4. `menu_ctld` : détruire l'unité DCS, publier `OnGroundUnitRemoved` (`reason = "loaded"`), et
   vider la recherche inverse. `dcs_native` : garder l'unité vivante mais la retirer de la recherche
   inverse afin qu'un `S_EVENT_DEAD` obsolète ne se déclenche pas à tort.
5. Enregistrer `loadMethod`, `loadTransportName`, `loadTime` ; passer à l'état `LOADED`.
6. `menu_ctld` uniquement : recalculer le poids de cargo interne du transport (`_updateVehicleCargo`)
   et envoyer un message de confirmation.
7. Publier `OnVehicleLoaded`.

La distance de ramassage maximale n'est **pas** appliquée dans `loadVehicle` ; elle l'est en amont
dans `findLoadableVehicles` (≤ `maximumDistancePackableUnitsSearch`, défaut 200 m).

## Pipeline de déchargement — `unloadVehicle(vehicle, transport, player, method, rearSector)` { #unload-pipeline-unloadvehiclevehicle-transport-player-method-rearsector }

1. Rejeter sauf si le véhicule est `LOADED`.
2. Calculer une position de spawn avec `_computeSpawnPosition(transport, rearSector)`.
3. Un véhicule en carry virtuel (`loadMethod ~= "dcs_native"`) est respawné près du transport avec
   `ctld.utils.dynAdd`, en réutilisant `spawnData.groupName` / `spawnData.unitName`, quel que soit le
   `method` publié. Un véhicule en carry natif (`loadMethod == "dcs_native"`) n'est **jamais** respawné :
   l'unité vivante que DCS a gardée est récupérée via `Group.getByName(spawnData.groupName)`. Le mécanisme
   découle de la façon dont le véhicule a été chargé, pas du motif publié.
4. Repasser à l'état `WAITING` (`FALLING` pour un véhicule en carry natif libéré avec `method = "parachute"`) ;
   ré-enregistrer la recherche inverse.
5. Carry virtuel : recalculer le poids de cargo (le poids d'un carry natif est laissé à DCS). Reprendre le
   lasing JTAC le cas échéant (un véhicule en chute le reprend à l'atterrissage).
6. `menu_ctld` uniquement : envoyer un message de confirmation.
7. Publier `OnVehicleUnloaded` ; pour un véhicule libéré en vol, démarrer le suivi d'atterrissage
   (`_scheduleNativeLandingPoll`).

> Le brouillon du guide développeur décrivait le déchargement comme un respawn via
> `CTLDObjectRegistry.spawnObject` ; le code actuel respawne via `ctld.utils.dynAdd` et n'utilise
> pas l'object registry ici.

## Positionnement au spawn { #spawn-positioning }

`_computeSpawnPosition(transport, rearSector)` (wrapper public `computeSafeDropPos`) place l'unité
dans un secteur de ±45° par rapport au cap du transport — le secteur **avant** par défaut, ou le
secteur **arrière** (`hdg + π`) quand `rearSector` vaut vrai, ce qui dégage le drop de la
trajectoire de décollage d'un hélicoptère IA. Le décalage radial provient de `_secureOffset`, la
diagonale de la bounding box `sqrt(halfLen² + halfWid²) × 2 + 10` m, avec un repli à 60 m lorsque
`getDesc().box` est indisponible.

## Chargement et libération de véhicule entier natif DCS — `_checkNativeLoading` (tick 1 s) { #dcs-native-whole-vehicle-loading-_checknativeloading-1-s-tick }

Un véhicule en carry natif est lu dans la liste que DCS déclare à bord de l'appareil, pas par géométrie
(ADR 0022). À chaque tick :

- Collecter les véhicules `WAITING` avec unités vivantes, et les véhicules `LOADED` dont
  `loadMethod == "dcs_native"`. S'il n'y en a aucun, le tick retourne avant de lire une liste.
- Les candidats sont les unités **joueur** (`CTLDPlayerManager._players` ; un appareil piloté par l'IA n'est
  jamais scanné), de toute catégorie, dont l'entrée `capabilitiesByType` fixe `useNativeDcsCargoSystem` et
  `canTransportWholeVehicle`. Leur liste est lue par `ctld.utils.getOnBoardCargo(unit)`. Si elle est
  illisible, un seul avertissement est journalisé pour le type et le type n'est plus surveillé
  (`_unreadableCargoTypes`) ; il n'y a aucun repli géométrique.
- **Entrée :** un véhicule entier apparaît comme une entrée compagnon nommée `CRG:<nom d'unité>`. Si elle
  correspond à un véhicule `WAITING`, appeler `loadVehicle(veh, transport, nil, "dcs_native")`. Aucun test de
  position, de sol, de vitesse ou de coalition : DCS décide de ce qu'il accepte. Une entrée qui n'est pas un
  véhicule en attente (cargo créé par la tablette de loadmaster, caisse d'éditeur inconnue) est ignorée avec
  une seule trace debug (`_ignoredCargoNames`).
- **Libération :** un véhicule en carry natif dont l'entrée a quitté la liste de son transport est libéré par
  `unloadVehicle` : `method = "dcs_native"` transport au sol (`WAITING` de nouveau aussitôt), ou
  `method = "parachute"` si `ctld.utils.inAir(transport)` (état `FALLING`). `_scheduleNativeLandingPoll` suit
  ensuite l'unité (vivante pendant toute la chute) jusqu'à ce que `ctld.utils.hasLanded` la dise au sol
  (critère des caisses parachutées), puis reprend son JTAC. Une unité disparue est abandonnée comme tout
  véhicule perdu (`_dropLostVehicle` : JTAC désenregistré, `OnVehicleDead`).
- **Transport disparu** (changement de slot, despawn : pas d'événement de mort) : un véhicule en carry natif
  dont le transport enregistré n'existe plus subit le même `_dropLostVehicle` qu'un transport détruit, une fois.
  Un transport dont la liste n'a pas été lue à ce tick ne libère rien. Un véhicule déjà `FALLING` n'est pas
  affecté.

Un véhicule libéré ne peut pas être rechargé par CTLD : il n'est rechargé qu'en réapparaissant dans la liste.

## Filtrage des chargeables — `findLoadableVehicles` / `_isTypeLoadable` { #loadable-filtering-findloadablevehicles-_istypeloadable }

`findLoadableVehicles(transport)` retourne les véhicules `WAITING` qu'un transport donné peut
charger, en appliquant trois filtres par-dessus la porte de capacité :

- L'entrée `capabilitiesByType` du transport doit fixer `canTransportWholeVehicle`, sinon `{}`.
- **Coalition (GAP-Q1) :** `veh.spawnData.coalitionId` doit être égal à la coalition du transport.
- **Type (GAP-Q2) :** `_isTypeLoadable` exige que `veh.vehicleType` figure dans la liste
  `loadableVehiclesRED` (coalition 1) ou `loadableVehiclesBLUE` (coalition 2) du transport.
- **Distance :** ≤ `maximumDistancePackableUnitsSearch`.

Les références d'unité des véhicules sont résolues paresseusement dans la boucle (`Group.getByName`
peut avoir une frame de retard sur `coalition.addGroup`).

## Capacités de transport { #transport-capabilities }

Le comportement des véhicules entiers est piloté par l'entrée `capabilitiesByType` du transport
(`ctld.gs("capabilitiesByType")`), plus le flag par joueur `canCarryVehicles` :

| Champ | Effet |
| --- | --- |
| `canTransportWholeVehicle` | Active le chargement/déchargement de véhicule entier pour ce type |
| `maxWholeVehiclesOnboard` | Capacité simultanée en véhicules entiers (`0` = aucune) |
| `loadableVehiclesRED` / `loadableVehiclesBLUE` | Noms de type DCS que cet appareil peut charger, par coalition |
| `canParachuteDrop` | Active l'entrée **Parachute Vehicle** |
| `useNativeDcsCargoSystem` | Marque le type comme porteur à cargo natif |

## Packing d'un véhicule en crates — `packVehicle` { #packing-a-vehicle-back-into-crates-packvehicle }

`findPackableVehicles(transport)` liste les véhicules `WAITING` gérés par CTLD situés à moins de
`maximumDistancePackableUnitsSearch` (uniquement les véhicules suivis — jamais des props de scène
arbitraires). `packVehicle(transportUnitName, packableUnitName, playerObj)` :

1. Résoudre le descripteur pour le type d'unité (`findDescriptorByUnitType`) ; refuser s'il n'y en
   a aucun.
2. Désenregistrer silencieusement tout JTAC sur l'unité, puis la `destroy()` et publier
   `OnGroundUnitRemoved` (`reason = "packed"`).
3. Spawner `descriptor.cratesRequired` crates via `CTLDCrateManager:spawnCratesAligned(...)` avec
   `CTLDCrate.SPAWN_METHOD.VEHICLE_PACK`, dans le secteur avant (hélicoptère) ou le secteur arrière
   (appareil à cargo natif).
4. Publier `OnVehiclePacked`, puis reconstruire le menu du joueur une frame plus tard (pour éviter
   la frame de retard de `coalition.getGroups()` après `destroy()`).

Le rafraîchissement du menu de pack déclenché à l'atterrissage (`_checkPackingLanding`, tick 3 s)
est conditionné à `ctld.gs("enablePackingVehicles")`.

## Largage en parachute — `parachuteVehicle` { #parachute-drop-parachutevehicle }

Requiert `caps.canParachuteDrop`. Vérifie l'AGL par rapport à `parachuteMinAltitudeVehicles`
(défaut 30 m) et refuse si trop bas. Résout le véhicule (id explicite, sinon le premier véhicule
chargé sur ce transport), calcule le point d'atterrissage avec `ctld.utils.calcDropPosition` en
utilisant `parachuteDescentRateVehicles` (défaut 8 m/s), repasse le véhicule à `WAITING`, publie
`OnVehicleParachuting`, et après le délai de descente le respawne à la position d'atterrissage et
publie `OnVehicleParachuteLanded` (en reprenant le lasing JTAC le cas échéant).

## Poids de cargo { #cargo-weight }

`getLoadedVehicleWeight(transportUnitName)` somme `ctld.gs("groundVehicleWeights")` pour les
véhicules `LOADED` en `menu_ctld` uniquement (défaut 2500 kg par type inconnu) ; le poids
`dcs_native` est laissé à DCS. `_updateVehicleCargo` délègue à `ctld.utils.updateTransportWeight`,
qui agrège troops, crates et véhicules en un unique appel `setUnitInternalCargo`.

## Menu F10 — `buildMenuSection` { #f10-menu-buildmenusection }

Ajouté uniquement lorsque l'unité du joueur possède `canCarryVehicles`. Il crée **Vehicle Commands**
(`order = 30`) avec trois branches dynamiques :

- **Load / Extract Vehicles** — reconstruit par `refreshLoadSection` ; désactivé en vol ; liste le
  résultat de `findLoadableVehicles`. Sélectionner une entrée appelle
  `loadVehicle(..., "menu_ctld")`.
- **Unload Vehicles** — reconstruit par `refreshUnloadSection` ; masqué quand rien n'est chargé,
  affiche « Land to unload vehicles » en vol, sinon liste les véhicules chargés.
- **Parachute Vehicle** — présent uniquement quand `caps.canParachuteDrop` ; activé uniquement en
  vol avec un véhicule chargé.

Les rafraîchissements sont pilotés par le détecteur d'atterrissage (`_checkPackingLanding`), les
événements de bus de spawn/retrait d'unité terrestre (`OnGroundUnitSpawned` / `OnGroundUnitRemoved`),
et les événements de load/unload eux-mêmes. Un timer d'indice de vol stationnaire
(`_checkVehicleHoverHint`, tick 5 s, cooldown de 30 s par joueur) incite un porteur en vol
stationnaire à se poser au-dessus d'un véhicule `WAITING` voisin.

## Gestion des événements DCS { #dcs-event-handling }

- **`onDead` (`S_EVENT_DEAD`)** — si l'unité morte est un véhicule suivi, la retirer et publier
  `OnVehicleDead` + `OnGroundUnitRemoved`. Sinon, s'il s'agit d'un transport qui portait des
  véhicules `LOADED`, chaque véhicule transporté est considéré perdu : son JTAC est désenregistré et
  `OnVehicleDead` est publié pour lui.
- **`onBirth` (`S_EVENT_BIRTH`)** — voir la source d'activation retardée ci-dessus.

## Événements publiés { #events-published }

| Événement | Quand |
| --- | --- |
| `OnVehicleSpawnedForTransport` | `spawnVehicleForTransport` a créé un véhicule `WAITING` |
| `OnVehicleLoaded` | Véhicule chargé dans un transport |
| `OnVehicleUnloaded` | Véhicule déchargé / largué d'un transport |
| `OnVehicleDead` | Véhicule suivi détruit, ou perdu avec son transport |
| `OnVehiclePacked` | Véhicule packé en crates |
| `OnVehicleParachuting` | Largage en parachute démarré |
| `OnVehicleParachuteLanded` | Véhicule parachuté arrivé au sol |
| `OnGroundUnitSpawned` / `OnGroundUnitRemoved` | Une unité terrestre suivie est apparue / a disparu (pilote le rafraîchissement du menu) |

Voir [Events](../events.md) pour le catalogue complet du bus et la forme des payloads.
