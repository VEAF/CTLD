# Architecture

## Structure du dépôt

```
src/                    Source modules (pure Lua 5.1, one class per file)
  core/                 Foundations: class.lua, CTLD_objectRegistry, CTLD_modValidator,
                        CTLDParachuteEffect
  scenes/               Scene data files (auto-registered at load time)
  legacy/               Legacy v1 API wrappers (thin delegates, deprecated)
  CTLD_*.lua            Domain managers (config, i18n, utils, menu, zone, troop, crate,
                        vehicle, fob, aasystem, beacon, recon, jtac, player, core…)
  CTLD_userConfig.lua   User configuration (merged last)
tools/
  build/                Build tooling: merge_CTLD.ps1, listToMerge.txt, generate_i18n_dicts.ps1
tests/
  ci/                   busted tests (no DCS required)
    helpers/            DCS stubs + module loader (init.lua, loader.lua)
    unit/               *_spec.lua unit tests
    functional/         *_spec.lua functional tests
  dcs/                  DCS integration-test scenarios (require a live mission)
docs/                   Published documentation (this site)
assets/                 Runtime audio (beacon.ogg)
missions/               Demo and test .miz files
migration/
  source/               Reference — original monolithic v1 CTLD.lua (read-only, immutable)
CTLD.lua                Generated deliverable — never hand-edit (rebuilt from src/)
```

## Idiome Manager / singleton

Les classes sont construites avec le micro-framework OOP minimal de `src/core/class.lua` :

```lua
MyClass = class()            -- create a class
Child   = class(MyClass)     -- subclass (single inheritance)

function MyClass:init(...) end   -- constructor, called by :new()
local obj = MyClass:new(...)     -- allocate instance + run init()
```

`class(base)` définit la table de classe comme son propre `__index`, de sorte que la résolution
des méthodes d'instance retombe sur la classe ; passer un `base` chaîne `__index` vers le parent.

Les managers de domaine sont des **singletons**. Ils déclarent `_instance` et exposent une
fabrique `getInstance()` qui contourne `:new()` et appelle `init()` au premier accès :

```lua
CTLDZoneManager = class()
CTLDZoneManager._instance = nil

function CTLDZoneManager.getInstance()
    if not CTLDZoneManager._instance then
        local o = setmetatable({}, CTLDZoneManager)
        o:init()
        CTLDZoneManager._instance = o
    end
    return CTLDZoneManager._instance
end
```

La configuration est en lecture seule via `ctld.gs("paramName")` — jamais `config:getSetting()`.

## Séquence d'init de `CTLDCoreManager`

`CTLDCoreManager:init()` s'exécute une seule fois au démarrage de la mission et déroule ces phases
dans l'ordre :

| Phase | Méthode | Description |
| --- | --- | --- |
| INIT-B | `_initMMCrates()` | Scanne les statics de la coalition à la recherche des objets de cargo placés par le MM |
| INIT-C | `_initMMJTACs()` | Scanne les groupes de la coalition à la recherche des groupes JTAC placés par le MM |
| INIT-D | `CTLDVehicleSpawner:scanMMVehicles()` | Scanne les groupes terrestres de la coalition à la recherche des vehicles placés par le MM |
| INIT-E | `_initExtractableGroups()` | Enregistre les noms de `extractableGroups` dans `CTLDTroopManager._droppedGroups` |
| INIT-A | `_initAITransports()` | Construit les listes d'équipes IA et démarre la boucle d'auto-pickup/dropoff |

**Détail INIT-E :** lit `ctld.gs("extractableGroups")`, appelle `Group.getByName()` pour chaque
entrée, et insère le nom du groupe dans `CTLDTroopManager._droppedGroups[coalition]`. Les groupes
introuvables sont journalisés en `WARN` et ignorés. Il n'y a pas d'activation tardive (iso-legacy)
ni d'entrée `_droppedTemplates` — `embarkFromField` utilise un repli à 130 kg/unité.

## Ajouter un nouveau module

1. Créer `src/CTLD_mymodule.lua` en utilisant l'idiome class/singleton ci-dessus (`CTLDMyManager = class()`,
   `_instance`, `getInstance()`).
2. Ajouter le nom de fichier à `tools/build/listToMerge.txt` dans l'ordre des dépendances (les
   fondations d'abord, puis les managers de domaine, puis les scenes, puis `CTLD_core.lua`, puis
   `legacy/`, `CTLD_userConfig.lua` en dernier).
3. Ajouter la même entrée `dofile` à `tests/ci/helpers/loader.lua`.
4. Écrire des specs busted dans `tests/ci/unit/mymodule_spec.lua` (test-first — voir
   [Build et tests](building-and-testing.md)).

L'ordre de merge dans `listToMerge.txt` fait foi : les scenes sont listées après tous les managers
pour que l'auto-injection de `model.crate` se résolve, et `CTLD_core.lua` (l'orchestrateur) vient
après les scenes qu'il instancie.

## Bibliothèques internes

### `core/class.lua` — base OOP

Le système de classes à héritage simple utilisé partout dans CTLD (voir l'idiome ci-dessus).
`class()` crée une classe dont le `__index` est elle-même ; `class(base)` chaîne vers un parent.

### `core/CTLD_objectRegistry.lua` — magasin de descripteurs de spawn

`CTLDObjectRegistry` est un registre statique qui associe des clés de template à des descripteurs de
spawn de group/unit DCS. Il gère des **descripteurs**, pas des instances.

```lua
CTLDObjectRegistry.register(key, descriptor)    -- add a template
CTLDObjectRegistry.spawnObject(key, coa, country, x, z, hdg, opts)
    -- → DCS Group object | nil
```

Les scenes enregistrent les descripteurs de leurs composants au moment du dofile ; les templates de
troops et de vehicles sont enregistrés par leurs managers à l'init.

### `core/CTLD_modValidator.lua` — sonde de présence de mods

`CTLDModValidator` teste si des mods DCS optionnels (HAWK, Patriot, NASAMS…) sont présents en tentant
un `coalition.addStaticObject` avec le type d'unit du mod puis en le détruisant immédiatement.

```lua
CTLDModValidator.getInstance():isPresent("AAA_HAWK_SR")  -- → bool (cached after first probe)
```

Les résultats sont mis en cache dans `_cache[typeName]`. La sonde est différée à la première
utilisation afin de ne pas impacter le temps de chargement de la mission.

#### `probeSkip` — les objets de type heliport ne peuvent pas être sondés

La technique de sonde fonctionne pour les objets `STATIC` et `GROUND`. Elle ne fonctionne **pas**
pour les objets enregistrés avec `category = "Heliports"` (spawnés via l'API airbase plutôt que via
l'API static object).

**Cause racine (vérifiée par diagnostic DCS en direct) :** quand un static de type heliport est
spawné via `coalition.addStaticObject`, DCS l'enregistre comme une entrée `Airbase`, que le mod soit
installé ou non. Tous les champs de l'API — `getTypeName()`, `getCategory()`, `getCategoryEx()`,
`getCallsign()`, `getDesc().life`, `getDesc().displayName` — renvoient des valeurs identiques que le
mod soit présent ou absent. Il n'existe aucun signal dans l'API de scripting Lua pour distinguer les
deux états.

**Conséquence :** si une entrée de registre heliport ne définit pas `probeSkip = true`,
`CTLDModValidator` la signale toujours comme présente — un faux positif « mod trouvé » même lorsque
le mod est absent.

**Règle :** toute entrée de registre avec `category = "Heliports"` **doit** définir
`probeSkip = true`.

```lua
CTLDObjectRegistry.registerIfAbsent("Farp_FG_Petit_Helipad", {
    groupType = "STATIC",
    category  = "Heliports",
    -- probeSkip suppresses the ModValidator probe: DCS returns life=0 and identical
    -- API data regardless of mod installation state — no reliable detection is possible.
    probeSkip = true,
    -- …
})
```

**Scenes utilisant des types mod :** une scene déclare les types hors-stock qu'elle spawn dans
`model.modTypes`. Le hard-gate d'assets au design-time (`tests/ci/unit/scene_asset_gate_spec.lua`)
valide tous les autres types contre le jeu datamine tout en acceptant les types mod déclarés — une
faute de frappe reste donc détectée. L'audit runtime des scenes a été retiré (ADR 0007) ; une scene
dépendante d'un mod comme Metal FARP est désormais un plugin optionnel dans
[`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) plutôt que d'avertir à chaque mission.

```lua
someModScene.modTypes    = { "Some_Mod_Type" }   -- whitelist design-time (reste strict sur le reste)
someModScene.requiresMod = "Some Mod Name"       -- libellé lisible pour le catalogue
someModScene.requiresCtld = "2.0.0"              -- optionnel : avertit si CTLD est plus ancien
```

### `core/CTLDParachuteEffect.lua`

Helper d'effet visuel de parachute utilisé lors du largage de crates/troops depuis l'altitude.

### `CTLD_utils.lua` — fonctions utilitaires

Fonctions clés disponibles sous `ctld.utils.*` :

| Fonction | Rôle |
| --- | --- |
| `log(level, fmt, ...)` | Écrit dans `CTLD.log` (niveaux : DEBUG, INFO, WARN, ERROR) |
| `getDistance(caller, p1, p2)` | Distance 2D au sol entre deux points `{x,z}` |
| `getHeadingInRadians(caller, unit, magnetic)` | Cap de l'unit en radians |
| `inAir(unit)` | Vrai si l'unit est en vol (garde-fou AGL + vélocité) |
| `getNextMarkId()` | Alloue le prochain mark ID DCS unique depuis `ctld._markIdCounter` |
| `getNextUniqId()` | Alloue le prochain ID d'entité unique depuis `ctld.utils.UniqIdCounter` |
| `drawQuad(coalitionId, pts, msg)` | Dessine un polygone à 4 points sur la carte F10 |
| `buildWP(caller, pt, type, speed)` | Construit une table de waypoint DCS |
| `getSecureDistanceFromUnit(unitName)` | Rayon minimal de dégagement de spawn depuis la bbox d'une unit |
| `dynAddStatic(coalitionId, data)` | Wrapper de `coalition.addStaticObject` avec résolution du pays |
