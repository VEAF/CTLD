# Système de menu F10

Le menu radio F10 est l'interface principale de CTLD en mission : chaque action qu'un pilote de
transport effectue — charger des crates, embarquer des troops, demander de l'équipement, activer
ou désactiver la désignation laser du JTAC — est déclenchée depuis lui. Cette page documente le
moteur de menu à deux couches (`ctld.Menu` et `ctld.MenuManager`), la façon dont
`CTLDPlayerManager` assemble le menu par joueur à partir des sections contribuées par chaque
manager, la façon dont l'arbre est rafraîchi en fonction de l'état changeant du vol et de la
cargaison, ainsi que l'arbre de menu complet tel qu'il est rendu en jeu.

**Source :** `src/CTLD_menu.lua` (le moteur), `src/CTLD_player.lua` (propriété et orchestration
des sections).

## Architecture à deux couches

La conception sépare *ce que contient le menu* de *la façon dont DCS le rend*. L'API DCS
`missionCommands.*` est fragile — il n'y a aucun moyen d'interroger le menu courant, pas de mise
à jour partielle, et pas de pagination automatique — donc CTLD conserve un arbre de référence en
mémoire et traite chaque appel DCS comme un effet de bord de rendu de cet arbre.

| Couche | Classe | Responsabilité |
| --- | --- | --- |
| Modèle logique | `ctld.Menu` | Arbre en mémoire pour le menu d'un groupe. Profondeur illimitée ; la pagination est transparente pour les appelants. Un `ctld.Menu` par `groupId`. |
| Moteur de rendu DCS | `ctld.MenuManager` | Singleton propriétaire de tous les `ctld.Menu`. Efface et reconstruit atomiquement les entrées CTLD d'un groupe sur `refresh()` ; trie les frères et sœurs par `order` ; pagine. |
| Orchestrateur | `CTLDPlayerManager` | Propriétaire du cycle de vie du menu F10 : le construit à l'entrée d'un joueur, l'assemble à partir des sections enregistrées et déclenche les rafraîchissements lors des changements d'état de vol/cargaison. |

`CTLDPlayerManager` suit l'idiome de manager standard (`CTLDPlayerManager = class()` +
`getInstance()` ; voir [Architecture](../architecture.md)). Le moteur de menu n'utilise **pas**
`class()` : `ctld.MenuManager` est un singleton codé à la main (`ctld.MenuManager = ctld.MenuManager or {}`,
`_instance`, `getInstance()` appelant `self:_new()`), et les instances de `ctld.Menu` sont de
simples tables avec une métatable créée par `ctld.Menu:_new(groupId, manager)`.

```
CTLDPlayerManager                 ctld.MenuManager
  _menuSections[]           →       menus{}  (groupId → ctld.Menu)
  registerMenuSection()             refreshMenuForGroup() / deferredRefreshForGroup()
  buildMenu(playerObj)              _rebuildMenuNode() / _rebuildPagedChildren()
  refreshForUnit(unitName)          _sortByOrder()
                                  ctld.Menu
                                    addSubMenu / addCommand / clearBranch
                                    setBranchEnabled / removeMenuBranch
                                    _getNode(pathTable) / refresh()
```

## Le modèle de menu — `ctld.Menu`

Un `ctld.Menu` est un arbre de nœuds. Les appelants manipulent exclusivement cet arbre ; ils
n'appellent jamais `missionCommands.*` directement. Il existe deux types de nœuds, plus l'objet
menu racine lui-même.

```lua
-- Root menu (the ctld.Menu instance)
{
    groupId    = number,     -- DCS group ID this menu belongs to
    groupName  = "string",   -- resolved once at creation, for name-based lookup
    children   = { ... },    -- root-level nodes
    _lookup    = { ... },    -- "path.string" → node reference (fast access)
    manager    = reference,  -- back-reference to ctld.MenuManager
    nextItemId = number,     -- counter for unique node ids
}

-- Submenu node
{
    id       = "sub_123",
    name     = "string",
    type     = "submenu",
    children = { ... },
    order    = number|nil,   -- position among siblings (see Order convention)
    enabled  = boolean,      -- DCS visibility (see Enabled convention), default true
}

-- Command node
{
    id             = "cmd_456",
    name           = "string",
    type           = "command",
    functionToCall = function,
    anyArgument    = table,   -- passed as-is to the callback; defaults to {}
    order          = number|nil,
    enabled        = boolean, -- default true
}
```

### Convention d'ordre

Chaque nœud peut porter un champ `order` optionnel (un nombre). Avant le rendu, les frères et
sœurs sont triés par `order` **croissant**, indépendamment de l'ordre d'insertion ou de la
séquence d'initialisation des managers. Comme chaque manager enregistre sa section de manière
indépendante, sans `order` explicite la position visuelle d'un submenu dépendrait de l'ordre
fragile d'initialisation des managers. Un `order` explicite rend les positions déclaratives et
stables. L'espacement recommandé est des multiples de 10 (10, 20, 30…) pour laisser de la place
aux insertions futures. Les nœuds sans valeur `order` sont ajoutés en dernier (`math.huge`) ; à
égalité, l'ordre d'insertion est préservé (tri stable).

### Convention d'activation

Chaque nœud porte un champ `enabled` (booléen, `true` par défaut). Un nœud désactivé
(`enabled == false`) est invisible dans DCS mais **reste dans l'arbre en mémoire, préservant son
créneau `order`** — le réactiver le ramène exactement à la même position de touche F qu'il aurait
occupée s'il avait toujours été visible. On le bascule avec `setBranchEnabled(path, bool)` suivi de
`refresh()`. C'est ainsi que des fonctionnalités sont déverrouillées à l'exécution (p. ex. un
trigger de mission activant la construction de FOB en cours de mission) sans perturber les
créneaux voisins.

### Table `_lookup`

La table `_lookup` associe une chaîne de chemin pointée à une référence de nœud, offrant une
résolution de chemin en O(1) au lieu d'un parcours d'arbre en O(profondeur × frères) :

```lua
_lookup = {
    ["CTLD"]                          = <ref>,
    ["CTLD.Troop Commands"]           = <ref>,
    ["CTLD.Troop Commands.Infantry"]  = <ref>,
}
```

Elle est maintenue automatiquement par `addSubMenu` / `addCommand` et élaguée par `clearBranch`,
`removeMenuBranch`, et (indirectement) `buildMenu` lorsqu'il réinitialise le modèle.

## Rendu — `ctld.MenuManager`

### Rafraîchissement atomique

DCS n'offre aucune mise à jour par item, donc un rafraîchissement est tout ou rien : le manager
supprime les entrées de premier niveau courantes de CTLD, puis reconstruit l'arbre entier depuis
la mémoire. Point crucial, il ne supprime **que les entrées propres à CTLD** — il ne passe *pas*
`nil` à `missionCommands.removeItemForGroup` (ce qui détruirait aussi les entrées DCS standard
comme Ground Crew et ATC). Il suit le handle DCS opaque retourné par `addSubMenuForGroup` /
`addCommandForGroup` dans le champ `_dcsHandle` de chaque nœud de premier niveau et supprime
exactement ces handles. (Passer un tableau de chemin sous forme de chaîne à `removeItemForGroup`
est silencieusement ignoré par DCS, c'est pourquoi le handle opaque est requis.)

```
refreshMenuForGroup(groupId)
  1. Validate a menu exists in memory for groupId
  2. For each top-level child with a stored _dcsHandle:
        missionCommands.removeItemForGroup(groupId, handle); clear the handle
  3. Sort root children by order, then for each:
        _rebuildMenuNode(groupId, {}, child)   -- recursive, depth-first
  4. Return { success = true, refreshedCount = N }
```

`_rebuildMenuNode` ignore les nœuds désactivés (retourne 0), rend un submenu avec
`addSubMenuForGroup` (en capturant le nouveau `_dcsHandle`), rend une commande avec
`addCommandForGroup`, et descend récursivement dans les enfants du submenu via
`_rebuildPagedChildren`.

### Rafraîchissement débouncé

`ctld.Menu:refresh()` ne reconstruit pas immédiatement — il appelle
`ctld.MenuManager:deferredRefreshForGroup(groupId)`, qui fusionne toutes les demandes de
rafraîchissement d'un groupe dans une fenêtre de `DEBOUNCE_S = 0.15 s` en une seule reconstruction
DCS (planifiée via `timer.scheduleFunction`). Cela empêche les appelants à cadence rapide (le
poller d'état de vol qui oscille, la détection de cargaison, les événements d'atterrissage qui se
déclenchent ensemble) d'éjecter le joueur du menu F10 en pleine navigation. Le `buildMenu` initial
à l'entrée d'un joueur passe aussi par le debounce. `refreshMenuForGroup` reste disponible pour une
reconstruction directe, non débouncée.

### Pagination

DCS donne à chaque niveau de menu dix créneaux contrôlés par le programmeur (F1–F10 ; F11 est la
« Previous Page » de DCS, F12 est « Quit »). `_rebuildPagedChildren` applique cette règle à une
liste d'enfants pré-triée et limitée aux nœuds activés :

| Enfants visibles | Rendu |
| --- | --- |
| ≤ 10 | Tous rendus sur une page (pas de pagination). |
| > 10 | F1–F9 rendent les neuf premiers items ; F10 = un submenu `→ Next Page` ; le reste descend récursivement à l'intérieur. |

Le nœud `→ Next Page` existe **uniquement au moment du rendu** — il ne fait jamais partie du modèle
en mémoire — et son libellé est traduit via `ctld.tr("→ Next Page")`. La dernière page reçoit
toujours ≤ 10 items. Comme la pagination est recalculée à chaque rafraîchissement, il n'y a aucun
état de page en cache à invalider et la profondeur d'imbrication est illimitée.

**Exemple — un submenu de 15 véhicules :**

```
F10 → Vehicles → (page 1):
  F1  vehicle_1 … F9 vehicle_9    F10  → Next Page
F10 → Vehicles → → Next Page:
  F1  vehicle_10 … F6 vehicle_15
  (F11 Previous Page — provided by DCS)
```

### Enrobage du callback

Lorsqu'une commande est rendue, son callback utilisateur est enrobé dans une closure qui isole les
échecs avec `pcall`, de sorte qu'un callback défectueux ne peut pas faire planter tout le rendu du
menu :

```lua
local wrapped = function()
    local ok, err = pcall(node.functionToCall, node.anyArgument or {})
    if not ok then
        ctld.logError("ctld.MenuManager: callback failed for '%s': %s", node.name, tostring(err))
    end
end
missionCommands.addCommandForGroup(groupId, node.name, dcsPath, wrapped, {})
```

Le callback reçoit exactement la table `anyArgument` fournie au moment de `addCommand` (par défaut
`{}`) ; il n'est pas augmenté du group id. Les appelants qui ont besoin du groupe l'encodent
eux-mêmes dans `anyArgument`.

## API de `ctld.Menu`

Toutes les méthodes de mutation retournent une table de statut `{ success = bool, message = string, ... }`
plutôt que de lever des erreurs (Lua 5.1 n'a pas d'exceptions ; des retours explicites sont plus
robustes dans l'environnement mono-thread de DCS).

| Méthode | Objet |
| --- | --- |
| `addSubMenu(pathTable, menuName, opts)` | Ajoute un submenu à `pathTable` (`{}` = racine). `opts.order` / `opts.enabled` fixent la position et la visibilité initiale. **Idempotent** : si le submenu existe déjà, il est retourné inchangé (avec `order`/`enabled` mis à jour s'ils sont fournis). Retourne `{ success, message, subMenuId }`. |
| `addCommand(pathTable, commandName, functionToCall, anyArgument, opts)` | Ajoute une commande exécutable. `anyArgument` doit être une table (ou nil → `{}`). `opts.order` fixe la position. Retourne `{ success, message, commandId }`. |
| `clearBranch(pathTable)` | Vide les enfants d'un submenu **sans supprimer le conteneur**, de sorte que son créneau `order` ne bouge pas. L'idiome standard pour les listes dynamiques de proximité (crates à proximité, véhicules chargeables). |
| `setBranchEnabled(pathTable, enabled)` | Bascule la visibilité DCS d'une branche tout en la conservant (ainsi que son créneau `order`) en mémoire. À faire suivre de `refresh()`. |
| `removeMenuBranch(pathTable)` | Supprime définitivement une branche et ses descendants. Retourne `{ success, message, removedCount }`. Réservé aux suppressions vraiment permanentes — préférer `clearBranch` / `setBranchEnabled`. |
| `refresh()` | Raccourci pratique vers `manager:deferredRefreshForGroup(self.groupId)` — effacer + reconstruire (ordonné, paginé), débouncé. |

Messages d'échec courants : `"Path not found: …"` (créez d'abord le submenu parent),
`"Cannot add submenu/command under a command node"`, `"Invalid menu name"`,
`"Invalid function reference"`, `"Cannot remove root menu"`.

L'idiome de rafraîchissement dynamique, utilisé partout dans les managers crate/véhicule :

```lua
local menu = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
menu:clearBranch({ "CTLD Commands", "Pack Vehicles" })   -- keep the container, drop its contents
for _, v in ipairs(nearbyVehicles) do
    menu:addCommand({ "CTLD Commands", "Pack Vehicles" }, v.name, packFn, { unitName = v.name })
end
menu:refresh()   -- single atomic, debounced rebuild
```

## API de `ctld.MenuManager`

| Méthode | Objet |
| --- | --- |
| `getInstance()` | Retourne (crée au premier appel) le singleton. |
| `createMenuForGroup(groupId)` | Crée un `ctld.Menu` vide pour un `groupId` numérique. **Idempotent** : retourne le menu existant si un est déjà enregistré. Retourne le menu, ou `nil` sur un id invalide. |
| `refreshMenuForGroup(groupId)` | Effacement + reconstruction immédiat, non débouncé, des entrées CTLD du groupe. Retourne `{ success, message, refreshedCount }`. |
| `deferredRefreshForGroup(groupId)` | Planifie un rafraîchissement débouncé (0.15 s) ; fusionne les rafales. |
| `getMenuByGroupId(groupId)` | Menu pour un group id numérique, ou `nil`. |
| `getMenuByGroupName(groupName)` | Menu dont le nom de groupe correspond, ou `nil`. |
| `getMenuByUnitName(unitName)` | Menu du groupe contenant cette unité (`Unit.getByName` → group), ou `nil`. |
| `getMenuByUnitId(unitId)` | Menu du groupe contenant cette unité (`Unit.getByID` → group), ou `nil`. |

La résolution du nom de groupe (`_getGroupName`) itère sur les trois coalitions et fait
correspondre `group:getID()`, car `Group.getByID()` n'existe pas dans l'API de scripting DCS —
seul `Group.getByName()` est disponible.

## Enregistrement des sections — `CTLDPlayerManager`

Le submenu racine `CTLD` et la commande `Check Cargo` sont ajoutés directement par
`CTLDPlayerManager`. Toute autre section de premier niveau est contribuée par le manager qui la
possède. Chaque manager enregistre sa section une fois, au moment de son propre `getInstance()` :

```lua
-- e.g. from a crate/troop/jtac manager
CTLDPlayerManager.getInstance():registerMenuSection({
    key           = "crates",              -- unique id; duplicate keys are ignored (idempotent)
    manager       = _cmInstance,           -- the manager instance
    method        = "buildMenuSection",    -- called as manager:method(playerObj, menu)
    configKey     = "enableCrates",        -- ctld.gs(configKey) must be true; nil = always active
    order         = 40,                     -- lower = higher in the menu
    refreshMethod = "refreshMenuSection",  -- optional; called on land/takeoff (see below)
})
```

Un `sectionDef` porte : `key`, `manager`, `method`, `configKey` optionnel, `order` optionnel, et un
`refreshMethod` optionnel. L'enregistrement est idempotent par `key`.

**Enregistrement pré-init.** Les fichiers de scène peuvent être chargés avant l'exécution de
`CTLDPlayerManager.getInstance()`. Pour ce cas, `CTLDPlayerManager.deferMenuSection(sectionDef)`
met une section en file d'attente au niveau supérieur du module ; la file est vidée dans
`_menuSections` pendant `init()`. La scène de champ de mines (mine-field) utilise ce chemin.

### `buildMenu(playerObj)`

Appelé à l'entrée d'un joueur (et réexécutable). Il :

1. Récupère/crée le `ctld.Menu` du groupe via `ctld.MenuManager:getInstance()`.
2. Réinitialise le modèle en mémoire (`children`, `_lookup`, `nextItemId`) pour que les sections ne
   s'accumulent pas d'un appel à l'autre.
3. Ajoute le submenu racine `ctld.tr("CTLD")` à `order = 10`.
4. Ajoute la commande `Check Cargo` sous la racine — elle compte les crates chargées, les troops en
   transit, et les véhicules entiers du transport, puis `outTextForGroup`.
5. Itère sur les sections enregistrées **triées par `order`** ; pour chacune, si `configKey` est
   nil ou `ctld.gs(configKey) == true`, appelle `manager:method(playerObj, menu)` pour construire le
   sous-arbre de cette section.
6. Appelle `menu:refresh()` pour un rendu atomique unique.

**Contrôle des capacités.** Les capacités du joueur sont détectées dans `_detectCapabilities` à
partir de `ctld.gs("capabilitiesByType")[typeName]` : un transport est tout type ayant une entrée ;
`canCarryVehicles` est positionné lorsque le `canTransportWholeVehicle == true` de cette entrée.
Les managers utilisent ces indicateurs (et leurs propres contrôles config/proximité) pour décider
quels items rendre. Lorsque `addPlayerAircraftByType == false`, seules les unités dont le nom
figure dans `transportPilotNames` reçoivent un menu CTLD.

`refreshForUnit(unitName)` et `refreshAll()` déclenchent un rafraîchissement débouncé pour un / tous
les joueurs suivis.

## Rafraîchissement selon l'état de vol

Les items dont la disponibilité dépend d'être en vol ou au sol (p. ex. `Release Slingload`
uniquement en l'air, `Load Crate` uniquement au sol) sont basculés via `setBranchEnabled` / des
reconstructions de section plutôt que par le ré-enregistrement de commandes DCS (ce qui laisserait
fuir des items de menu orphelins). Deux mécanismes pilotent cela :

- **Poller d'état de vol (cadence de 0.5 s).** `S_EVENT_TAKEOFF` / `S_EVENT_LAND` se déclenchent
  avec un délai de 3 à 5 s pour les hélicoptères dans DCS. Un poller vérifie
  `ctld.utils.inAir(unit)` toutes les 0.5 s et, une fois qu'un nouvel état se maintient pendant
  `DEBOUNCE_TICKS = 2` polls consécutifs (~1 s), le valide et exécute la chaîne de rafraîchissement
  complète — de sorte que les menus basculent en ~1 s de la vraie transition. Les handlers
  `onTakeoff` / `onLand` s'exécutent tout de même lorsque les événements DCS finissent par se
  déclencher, mais d'ici là l'état correspond déjà et le rafraîchissement est un no-op rapide.
- **Rafraîchissements par événement/handler.** À l'atterrissage/décollage (et sur les événements de
  cargaison via l'[event bus](../events.md) — `OnVehicleLoaded`, `OnVehicleUnloaded`,
  `OnCrateLoaded`, `OnFOBDeployed`), `CTLDPlayerManager` appelle la méthode de rafraîchissement de
  chaque manager concerné (`refreshMenuSection`, `refreshRequestEquipmentSection`,
  `refreshCrateFlightSection`, `refreshLoadSection`, `refreshUnloadSection`,
  `refreshParachuteVehicleSection`, `refreshJtacEquipmentSection`, …). Les sections ayant enregistré
  un `refreshMethod` sont invoquées génériquement via `manager:refreshMethod(playerObj)`.

| Déclencheur | Managers/sections rafraîchis |
| --- | --- |
| `S_EVENT_LAND` / poller → sol | Troop, Crate (Request Equipment, Load Crate, Unpack, section de vol), Vehicle (load/unload/parachute), JTAC, plus le `refreshMethod` de chaque section |
| `S_EVENT_TAKEOFF` / poller → air | Même ensemble — bascule la visibilité de la branche SOL/AIR |
| Spawn/despawn de véhicule | Vehicle : section load + section pack |
| Load/unload de crate | Crate : section de vol ; section Unpack sur load |
| Embarquement/débarquement de troops | Troop : section de menu |
| Spawn/mort de JTAC | JTAC : branche de commande par JTAC, pour tous les joueurs de la coalition |

## L'arbre de menu F10

L'arbre ci-dessous est le menu CTLD complet tel qu'il est rendu en jeu. Les valeurs d'ordre de
premier niveau déterminent les positions des touches F ; la visibilité de chaque section dépend des
contrôles de config, des contrôles de capacité et de la proximité/l'état.

```
CTLD (root, order=10)
├── Check Cargo                     (command — added by CTLDPlayerManager)
├── Troop Commands                  (submenu, order=20)
├── Request Equipment               (submenu, order=25)
├── Vehicle Commands                (submenu, order=30)
├── Crate Commands                  (submenu, order=40)
├── FOB (List active FOBs)          (submenu, order=60)  ⚠ shares order with Radio Beacons
├── Radio Beacons                   (submenu, order=60)  ⚠ shares order with FOB
├── RECON                           (submenu, order=70)
├── Mine Field                      (submenu, order=75)  — conditional, ground only
├── Smoke                           (submenu, order=80)
└── JTAC                            (submenu, order=90)
```

> **Conflit `order=60`.** FOB (`CTLD_fob.lua`) et Radio Beacons (`CTLD_beacon.lua`) utilisent tous
> deux `order=60`, donc l'ordre de rendu entre les deux dépend de la séquence d'initialisation des
> managers. C'est une lacune connue — l'un devrait être renuméroté (p. ex. FOB → `order=55`).

### Table d'enregistrement des sections

| Section | Manager | Ordre | Contrôle config | Contrôle capacité / état |
| --- | --- | --- | --- | --- |
| Check Cargo | `CTLDPlayerManager` | — | — | — |
| Troop Commands | `CTLDTroopManager` | 20 | — | `troopsEnabled = true` |
| Request Equipment | `CTLDCrateManager` | 25 | — | `cratesEnabled = true` |
| Vehicle Commands | `CTLDVehicleSpawner` | 30 | — | `canCarryVehicles = true` |
| Crate Commands | `CTLDCrateManager` | 40 | — | `cratesEnabled = true` |
| FOB (List FOBs) | `CTLDFOBManager` | **60** ⚠ | `enabledFOBBuilding` | — |
| Radio Beacons | `CTLDBeaconManager` | **60** ⚠ | `enabledRadioBeaconDrop` | `isTransport = true` |
| RECON | `CTLDReconManager` | 70 | `reconF10Menu` | — |
| Mine Field | `mineFieldScene` | 75 | — | sol + champs de mines à proximité |
| Smoke | `CTLDCrateManager` | 80 | `enableSmokeDrop` | `isTransport = true` |
| JTAC | `CTLDJTACManager` | 90 | `JTAC_jtacStatusF10` | — |

### Troop Commands (order=20)

Manager `CTLDTroopManager` (`src/CTLD_troop.lua`). Les sous-items sont conditionnés selon que le
transport est au sol (SOL) ou en l'air (AIR), selon que des troops sont transportées, et selon des
conditions par template (un template n'est proposé que si `tmpl.total <= transportLimit`, si du
stock est disponible et si le camp correspond). `Embark / Extract` pagine à 10 items par page.

```
Troop Commands
├── Disembark Troops            [SOL — if hasTroops]
│   ├── (direct command if 1 group)
│   └── Disembark Troops (submenu if 2+ groups)
│       ├── Disembark All
│       ├── [1] TemplateNameA
│       └── [2] TemplateNameB
├── Embark / Extract Troops     [SOL — if TRZ zones or field groups nearby]
│   ├── Load from TRZ_ZoneName
│   │   ├── Load Template-Infantry
│   │   └── Load Template-Mixed
│   └── Extract from field      [if dropped troops nearby]
│       ├── GroupName1 (50m)
│       └── GroupName2 (120m)
├── Check Cargo                 [SOL]
└── Parachute Troops            [AIR — if canParachuteDrop + hasTroops]
    ├── (direct command if 1 group)
    └── Parachute Troops (submenu if 2+ groups)
        ├── Parachute All
        └── [1] TemplateNameA
```

### Request Equipment (order=25)

Manager `CTLDCrateManager` (`src/CTLD_crate.lua`). Affiché lorsque le transport a atterri **et**
qu'il se trouve dans une zone logistique (LGZ). Une branche par zone logistique à proximité ; les
catégories paginent à 10 par page.

```
Request Equipment
├── [Logistics Zone "Zone-Alpha"]
│   ├── Infantry
│   │   ├── Rifle Squad
│   │   └── Rifle Squad x3   (singleTypeSet, if enableAllCrates)
│   ├── Support
│   │   └── Machine Gunner Team
│   └── [→ Next Page]         (if > 10 categories)
└── [Logistics Zone "Zone-Beta"]
    └── [...]
```

Conditions des items : les items JTAC requièrent `JTAC_dropEnabled = true` ; un `descriptor.side`
doit correspondre à la coalition ; les items de véhicule entier (Feature Q) apparaissent lorsque
`canTransportWholeVehicle = true` et que le type figure dans
`loadableVehiclesRED`/`loadableVehiclesBLUE`, faisant spawn un véhicule WAITING directement plutôt
qu'une crate. Types de spawn : crate unique, `SingleTypeSet` (N crates d'un même type), `MixedSet`
(multi-type, nécessite `enableAllCrates`), et véhicule (Feature Q).

### Vehicle Commands (order=30)

Manager `CTLDVehicleSpawner` (`src/CTLD_vehicle.lua`). Affiché lorsque
`capabilitiesByType[typeName].canCarryVehicles = true`.

```
Vehicle Commands
├── Load / Extract Vehicles  (submenu)  [SOL — dynamic]
│   ├── M1A1 Abrams
│   ├── M113 APC
│   └── [... vehicles in range, coalition match, loadable type]
├── Unload Vehicles          (submenu)  [SOL — hidden if 0 loaded]
│   ├── Vehicle 1 (descriptor label)
│   └── Vehicle 2
└── Parachute Vehicle        (command)  [AIR — if canParachuteDrop + vehicle loaded]
```

Filtres de chargement : distance ≤ `maximumDistancePackableUnitsSearch` (~200 m), correspondance de
coalition, type dans `loadableVehiclesRED`/`loadableVehiclesBLUE`, et état `WAITING`. Rafraîchi à
l'atterrissage, au décollage, et au spawn/despawn de véhicule.

### Crate Commands (order=40)

Manager `CTLDCrateManager` (`src/CTLD_crate.lua`).

```
Crate Commands
├── Load Crate          (submenu, order=10) [SOL — if loadCrateFromMenu = true]
│   └── [dynamic: nearby crates < 300 m with assembly status]
├── Drop Crate(s)       (command, order=15) [SOL]
├── Unpack Crate        (submenu, order=20) [SOL]
│   ├── [Crate 1 - M1045 HMMWV TOW, 2500kg]
│   ├── [Crate 2 - Soldier]
│   └── [...]
├── List Nearby Crates  (command)           [SOL]
├── Pack Equipt         (submenu, order=25) [SOL — dynamic, rebuilt on land]
│   ├── Pack FARP-AlphaModel               [if enableFARPRepack + nearby FARP scenes]
│   ├── Pack FARP-BetaModel
│   ├── M1A1 Abrams                        [if enablePackingVehicles + packable vehicles nearby]
│   └── M113 APC
│   (submenu hidden entirely if no packable content found)
├── Parachute Crates    (command)           [AIR — if canParachuteDrop + crates onboard]
├── Release Slingload   (command)           [AIR — if canSlingload + slingload active]
└── Cut Slingload       (command)           [AIR — if canSlingload + slingload active]
```

Schémas de rafraîchissement : `refreshCrateFlightSection()` bascule la visibilité SOL/AIR à
l'atterrissage/décollage ; `refreshPackEquiptSection()` reconstruit « Pack Equipt » à
l'atterrissage ; `refreshRequestEquipmentSection()` reconstruit « Request Equipment » à l'entrée de
zone/à l'atterrissage.

### Radio Beacons (order=60)

Manager `CTLDBeaconManager` (`src/CTLD_beacon.lua`). Contrôle config `enabledRadioBeaconDrop = true`.

```
Radio Beacons
├── Drop Beacon              — spawns TACAN/ADF units + starts radio transmissions
├── Remove Closest Beacon    — removes a beacon within 500 m
└── List Beacons             — displays VHF/UHF/FM frequencies
```

### RECON (order=70)

Manager `CTLDReconManager` (`src/CTLD_recon.lua`). Contrôle config `reconF10Menu = true`.

```
RECON
├── RECON [Start] / RECON [Stop]     (toggle command)
├── Infantry        [activate/deactivate (X)]
├── Air Defense (AA) [activate/deactivate (X)]
├── Ground Vehicles [activate/deactivate (X)]
├── Helicopters     [activate/deactivate (X)]
├── Aircraft        [activate/deactivate (X)]
├── Ships           [activate/deactivate (X)]
└── FARP / FOB      [activate/deactivate (X)]
```

Logique des libellés : RECON actif + couche activée → `[deactivate]` ; RECON actif + couche
désactivée → `[activate]` ; RECON inactif + couche désactivée → `[activate] (X)`, où `(X)` signale
que le scan ne tourne pas. Les sept couches sont `infantry`, `air_defense`, `ground_vehicles`,
`helicopters`, `aircraft`, `ships`, `farp_fob`. Pipeline de scan : contrôle d'altitude
(AGL ≥ `reconMinAltitude`, 50 m par défaut) → ligne de vue (line-of-sight) par unité ennemie mise
en correspondance avec les couches activées → tracé d'une marque sur la carte F10 par cible (forme
selon la couche, couleur selon la coalition) → timer d'auto-rafraîchissement
(`reconRefreshInterval`, 10 s par défaut) détectant les cibles nouvelles/déplacées/perdues.

### Mine Field (order=75)

Manager `mineFieldScene` (`src/scenes/CTLD_mineFieldScene.lua`), enregistré via
`CTLDPlayerManager.deferMenuSection()`. Affiché uniquement lorsque le joueur est au sol et que des
champs de mines sont à moins de `demineRadius` (150 m par défaut) ; masqué entièrement sinon.
Rafraîchi à l'atterrissage/décollage et après chaque opération de déminage.

```
Mine Field
├── Clear Mine Field (N mines, ~Xm)    [one entry per nearby mine set]
└── [...]
```

### Smoke (order=80)

Manager `CTLDCrateManager` (`src/CTLD_crate.lua`). Contrôle config `enableSmokeDrop = true`.

```
Smoke
├── Drop Red Smoke
├── Drop Blue Smoke
├── Drop Orange Smoke
├── Drop Green Smoke
└── Smoke Auto-Resume [activate] / [deactivate]   (toggle command)
```

Avec `Smoke Auto-Resume` activé, les marqueurs de fumée sont redéployés automatiquement après leur
extinction.

### JTAC (order=90)

Manager `CTLDJTACManager` (`src/CTLD_jtac.lua`). Contrôle config `JTAC_jtacStatusF10 = true`.

```
JTAC
├── Request JTAC Equipment  (submenu)  [SOL — if JTAC_dropEnabled + in LGZ]
│   ├── Air JTAC Type1    (drone, spawnAs = "AIRPLANE")
│   ├── Ground JTAC Type2 (vehicle)
│   └── [...]
├── JTAC Status  (command)
├── [JTAC Name 1]  (submenu — per active JTAC, same coalition)
│   ├── Lasing [activate] / [deactivate]        [if JTAC_allowStandbyMode]
│   ├── Spot Corrections [activate/deactivate]  [if JTAC_laseSpotCorrections ≠ nil]
│   ├── Request Smoke on Target                 [if JTAC_allowSmokeRequest]
│   └── Request 9-Line                          [if JTAC_allow9Line]
└── [JTAC Name 2]
    └── [...]
```

Un submenu par JTAC est présent dans tous les états sauf `DEAD` (SPAWNED, IDLE, LASING, ORBITING,
IN_TRANSIT l'affichent tous ; DEAD le supprime). `toggleStandby()` / `toggleSpotCorrections()`
appellent `_rebuildJTACCommandBranch()`, effaçant et reconstruisant le submenu par JTAC pour tous
les joueurs de la coalition. Indicateurs de config affectant le menu :

| Indicateur | Effet sur le menu |
| --- | --- |
| `JTAC_dropEnabled` | Affiche/masque « Request JTAC Equipment » |
| `JTAC_allowStandbyMode` | Affiche/masque « Lasing [toggle] » |
| `JTAC_laseSpotCorrections` | Affiche/masque « Spot Corrections [toggle] » |
| `JTAC_allowSmokeRequest` | Affiche/masque « Request Smoke on Target » |
| `JTAC_allow9Line` | Affiche/masque « Request 9-Line » |

## Ajouter une section de menu à un nouveau module

1. Dans le `getInstance()` de votre manager (ou, pour une scène chargée tôt, au niveau supérieur du
   module via `CTLDPlayerManager.deferMenuSection`), appelez
   `CTLDPlayerManager.getInstance():registerMenuSection(sectionDef)` avec une `key` unique, votre
   instance `manager`, le nom de `method`, et un `order`. Ajoutez un `configKey` si la section est
   conditionnée par la config, et un `refreshMethod` si elle a besoin d'être rafraîchie à
   l'atterrissage/au décollage.
2. Implémentez `Manager:buildMenuSection(playerObj, menu)` — construisez votre sous-arbre avec
   `menu:addSubMenu` / `menu:addCommand`, en assignant `order` pour contrôler la position.
3. Implémentez `Manager:refreshMenuSection(playerObj)` (ou votre `refreshMethod` enregistré) —
   mettez à jour le contenu dynamique via `clearBranch` + ré-ajout, ou basculez la visibilité avec
   `setBranchEnabled`. Ne ré-enregistrez pas directement de commandes DCS.
4. Déclenchez `CTLDPlayerManager.getInstance():refreshForUnit(unitName)` sur tout changement d'état
   qui affecte la visibilité de votre section.

## Contraintes et limites de l'API DCS

- **Pas d'API de listing du menu** — DCS ne peut pas rapporter les items de menu existants ; l'arbre
  en mémoire est l'unique source de vérité, validé localement avant tout appel DCS.
- **Rafraîchissement tout ou rien** — pas de mise à jour par item ; accumulez les changements, puis
  appliquez un seul `refresh()`.
- **Pagination manuelle** — DCS ne pagine pas automatiquement ; `_rebuildPagedChildren` s'en charge.
- **Pas d'introspection des callbacks** — les signatures de fonctions Lua ne peuvent pas être
  validées à l'exécution ; la signature attendue est documentée et les échecs sont isolés avec
  `pcall`.
- **`Group.getByID()` est indisponible** — les group ids sont résolus en noms en itérant sur les
  coalitions.

| Limite | Valeur |
| --- | --- |
| Créneaux programmeur par niveau de menu | 10 (F1–F10 ; F11 = Previous Page, F12 = Quit, les deux DCS) |
| Enfants visibles avant pagination | 10 |
| Profondeur de menu | Illimitée (rester < 5 niveaux pour l'utilisabilité) |
| Menus simultanés | Illimité (un par groupe) |
| Fréquence de rafraîchissement | Débouncée à 0.15 s ; rester bien en dessous d'1 refresh/s par groupe |

## Décisions de conception

- **Arbre en mémoire avant application DCS** — permet des reconstructions atomiques, tout ou rien,
  et garde le modèle comme référence.
- **Pagination recalculée à chaque rafraîchissement** — aucun état de page en cache à invalider ;
  les mises à jour dynamiques restent simples.
- **`order` + `enabled` explicites** — les positions sont déclaratives et stables quel que soit
  l'ordre d'initialisation, et les fonctionnalités peuvent être masquées sans perdre leur créneau.
- **Rafraîchissement débouncé** — absorbe les rafales pour que les joueurs ne soient pas éjectés du
  menu en pleine navigation.
- **Tables de statut, pas d'exceptions** — Lua 5.1 n'a pas de gestion d'exceptions ; les retours
  `{ success, message }` sont plus robustes dans un moteur mono-thread.

## Différences avec la v1

| v1 (`old/CTLD_menus.lua`) | v2 |
| --- | --- |
| Un `addTransportF10MenuOptions()` monolithique | Chaque manager enregistre sa propre section via `registerMenuSection` |
| Fonctions globales (`ctld.checkTroopStatus`, `ctld.loadTroopsFromZone`, …) | Méthodes OOP sur des instances de manager |
| Menu statique construit une seule fois à l'entrée du joueur | Sections dynamiques reconstruites à l'atterrissage/décollage et sur les événements de cargaison |
| Aucun contrôle d'ordre | Champ `order` explicite par nœud |
| Nommage de zones PKZ / EXZ | Nommage de zones TRZ (voir la documentation des zones de troops) |
| Pas d'intégration menu du véhicule entier | Feature Q : véhicules entiers proposés dans Request Equipment |

## Sous-systèmes liés

- [Suivi des joueurs](players.md) — l'entité `CTLDPlayer` et le cycle de vie de `CTLDPlayerManager`
  qui possède ce menu.
- [Événements](../events.md) — les événements de cargaison/FOB qui pilotent les rafraîchissements du
  menu.
- [Architecture](../architecture.md) — l'idiome manager/singleton utilisé par `CTLDPlayerManager`.
