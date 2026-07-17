# Moteur de scènes

**Source :** `src/CTLD_sceneManager.lua`, `src/scenes/*.lua`
**Classes :** `CtldScene` (une instance en cours d'exécution), `CTLDSceneManager` (registre singleton + moteur)

`CTLDSceneManager` exécute des déploiements séquencés dans le temps de statiques DCS et de groupes
terrestres à partir d'un **modèle** déclaratif. C'est le backend de tout déploiement de FARP, de FOB
et de champ de mines : un modèle de scène liste des *étapes* ordonnées, et le moteur fait spawn des
objets de chaque étape relativement à un instantané de position, en attendant un délai configurable
entre chacune.

Les modèles de scène vivent à raison d'un par fichier sous `src/scenes/` et s'auto-enregistrent au
chargement via `CTLDSceneManager.getInstance():registerSceneModel(model)`.
`CTLDSceneManager:_registerBuiltins()` est intentionnellement vide — il n'y a pas de liste de
modèles codée en dur.

## Modèle de données interne

```
CtldScene (une instance par déploiement actif)
  ├── _name        : "<modelName>#<counter>"  (unique par déploiement)
  ├── _modelName   : original model name (used for registry / pack lookups)
  ├── _unit        : trigger DCS Unit (or a mock unit for playSceneAtPos)
  ├── _steps       : model.steps (shared reference)
  ├── _stepIndex   : current step pointer (0 before the first step)
  ├── _timeMarker  : absolute timer.getTime() target for the next step
  ├── _spawnedObjs : { DCSObject, … }  (every object spawned so far)
  ├── _params      : runtime bag forwarded to step funcs (e.g. farpName, repackData)
  ├── _onComplete  : callback fired after the last step (or model.onComplete)
  ├── _aborted     : true once abort() is called
  ├── _coalitionId / _countryId       : snapshot at init
  └── _refX / _refZ / _refAlt / _refHdgRad / _magDecDeg : position + heading snapshot

CTLDSceneManager (singleton, via getInstance())
  ├── _models[modelName] : registered model tables
  └── _active[sceneName] : CtldScene instances currently deployed
```

`_models` est indexé par le nom du modèle ; `_active` est indexé par le `_name` propre à chaque
déploiement (`"<modelName>#<counter>"`), de sorte que plusieurs instances du même modèle peuvent
être actives simultanément. Les deux tables ne vivent qu'en mémoire — `_active` ne survit pas à un
redémarrage de mission ni à une réinjection complète de CTLD pendant le développement.

La position et le cap de référence sont capturés **une seule fois** dans `CtldScene:init()` depuis
l'unité de déclenchement (`unit:getPoint()` et `ctld.utils.getHeadingInRadians`). Chaque étape
ultérieure est positionnée relativement à cet instantané, si bien que la scène se déploie de manière
cohérente même si l'unité bouge ou quitte les lieux. La `func` d'une étape peut écraser `_refX` /
`_refZ` / `_refAlt` sur `ctx.scene` avant l'exécution des étapes de spawn suivantes.

## Exécution des étapes

La machine à étapes est pilotée par `timer.scheduleFunction`. `CtldScene:_execute()` planifie la
première étape après `steps[1].delayAfterPreviousStep` secondes ; `_runNextStep()` exécute alors
l'étape courante et planifie la suivante. Chaque étape prend l'une des trois formes suivantes :

| Type d'étape | Champs clés | Comportement |
| --- | --- | --- |
| **polar** | `polar = { distance, angle }`, `relativeHeadingInDegrees`, `relativeAltitudeInMeters`, `registryKey` | Position monde déterministe dérivée de l'instantané via `ctld.utils.getRelativeCoords`. |
| **axis** | `axis = { count, safeDistance, spacing }`, `registryKey` | Un axe aléatoire autour de l'unité ; `count` objets répartis le long de celui-ci via `ctld.utils.getSpawnObjectPositions`. |
| **func** | `func = function(ctx) … end` | Aucun spawn — exécute seulement le callback (hook post-spawn / placement personnalisé). |

Chaque étape porte aussi `delayAfterPreviousStep` (secondes) : après l'exécution de l'étape *N*, le
moteur attend ce nombre de secondes avant l'étape *N+1*. Le même champ sur l'étape 1 correspond au
délai initial depuis le déclenchement.

Pour une étape de spawn (`registryKey` présent, spawn non ignoré), `_runNextStep()` :

1. Exécute la **`preFunc(ctx)`** optionnelle avec `ctx = { unit, step, scene }`. Renvoyer `false`
   ignore le spawn de cette étape (la scène continue) ; appeler `ctx.scene:abort(reason)` arrête
   entièrement la scène.
2. Récupère le descripteur avec `CTLDObjectRegistry.get(step.registryKey)` et injecte
   automatiquement `circleRadius` lorsque le descripteur utilise une formation `circle`.
3. Fait spawn via **`CTLDObjectRegistry.spawnObject(registryKey, coalitionId, countryId, x, z, hdg, overrides)`**
   — le moteur n'appelle jamais `coalition.addStaticObject` / `coalition.addGroup` directement (une
   étape de type `func` uniquement le peut, comme le fait la FARP de campagne pour ses pneus de
   délimitation).
4. Ajoute chaque objet spawné à `_spawnedObjs`.
5. Si `step.critical` est défini et que rien n'a été spawné, appelle `abort()` plutôt que de
   continuer avec une scène partielle cassée.
6. Exécute la **`func(ctx)`** optionnelle avec `ctx = { unit, spawnedObj, step, scene }`, où
   `spawnedObj` est le dernier objet spawné durant cette étape (`nil` pour une étape ignorée ou de
   type `func` uniquement).

Les deux hooks sont enveloppés dans un `pcall` ; une erreur est journalisée (`ERROR`) et la scène se
poursuit. Lorsque la dernière étape se termine, `_onComplete(scene)` se déclenche (également sous
`pcall`). Un modèle peut définir `model.onComplete` ; un callback fourni par l'appelant à
`playScene` le remplace.

### Points d'entrée

| Méthode | Usage |
| --- | --- |
| `playScene(unit, modelName, params, onComplete)` | Démarre une scène depuis une unité de déclenchement vivante. Rejette une unité nil/morte, un modèle inconnu, ou un modèle `_disabled`. |
| `playSceneAtPos(modelName, pos, coalitionId, countryId, params)` | Démarre une scène sans unité vivante (p. ex. auto-unpack par parachute). Construit une unité factice minimale à `pos` orientée au nord et délègue à `playScene`. |

Les deux enregistrent la nouvelle `CtldScene` dans `_active` avant l'exécution.

## Flux de pack de FARP

Le pack démonte une scène de FARP déployée pour la remettre en crates tout en préservant l'état de
son entrepôt (warehouse). Le flux est réparti entre le gestionnaire de scènes et
[`CTLDCrateManager`](crates.md) :

```
Player selects "Pack Equipt → Pack <scene>"
  └── CTLDCrateManager:refreshPackEquiptSection(playerObj)
        └── CTLDSceneManager:findNearbyRepackableScenes(transport:getPoint(), 300)
              └── returns _active scenes within radius whose model defines onRepack
        └── on click, per scene:
              1. sc = CTLDSceneManager._active[sceneName]
              2. repackData = CTLDSceneManager:packScene(sc)
                    ├── model.onRepack(sc, repackData)   ← snapshot warehouse into repackData
                    ├── destroy every obj in sc._spawnedObjs
                    └── _active[sc._name] = nil
              3. spawn cratesRequired crates via CTLDCrateManager:spawnCrate(...)
                    └── crate.metadata.warehouseSnapshot = repackData.warehouseSnapshot

On crate unpack at a new site (auto-unpack path in CTLDCrateManager):
  └── sm:getModel(desc.unit) resolves the scene model
        └── CTLDSceneManager:playSceneAtPos(desc.unit, centroid, coa, cId, { repackData = … })
              └── warehouse step reads ctx.scene._params.repackData.warehouseSnapshot to restore fuel/inventory
```

`packScene(scene)` ne prend que l'instance de scène ; `onRepack(scene, repackData)` est l'endroit où
un modèle écrit son `repackData.warehouseSnapshot`. L'instantané voyage sur le crate via
`crate.metadata.warehouseSnapshot` et est réinjecté dans le `_params.repackData` de la nouvelle
scène, afin que l'étape d'approvisionnement de l'entrepôt puisse restaurer les liquides et
l'inventaire au lieu de les remettre à zéro.

Les identifiants concernés (`onRepack`, `findNearbyRepackableScenes`, `packScene`, `repackData`,
`warehouseSnapshot`) conservent leur orthographe dans le code ; le libellé F10 est
`ctld.tr("Pack %1", …)`.

## Ajouter une nouvelle scène (checklist dev)

1. Créer `src/scenes/CTLD_myScene.lua` : une table de modèle locale avec `name` et `steps`, se
   terminant par `CTLDSceneManager.getInstance():registerSceneModel(myScene)`.
2. Déclarer le crate sur le modèle lui-même — `myScene.crate = { weight, i18nKey, deployKey,
   cratesRequired, side, … }`. Il est auto-injecté dans le menu Request Equipment par
   `CTLDCrateManager:_processSpawnableCrates` / `_injectSceneCrate` ; il n'y a pas d'entrée
   `unit = "…"` à ajouter dans `CTLD_userConfig.lua`.
3. Enregistrer tout objet DCS référencé par les étapes avec `CTLDObjectRegistry.registerIfAbsent(key,
   descriptor)` et pointer le `registryKey` de chaque étape dessus.
4. Ajouter le fichier à `tools/build/listToMerge.txt` (les scènes sont listées **après** tous les
   managers pour que l'auto-injection des crates soit résolue) et ajouter la ligne `dofile`
   correspondante à `tests/helpers/loader.lua`.
5. Si la scène déploie une FARP basée sur un mod de type helipad avec un entrepôt, ajouter une étape
   finale de type `func` uniquement qui l'approvisionne via `w:setLiquidAmount(fuelType, qty)`
   (types de carburant `0`–`3` : jet fuel, aviation gasoline, MW50, diesel). Lire les niveaux avec
   `w:getLiquidAmount(fuelType)`, jamais `getLiquid`. Les aérodromes de type Invisible FARP renvoient
   `nil` depuis `getWarehouse()`, il faut donc s'en prémunir.
6. Pour la prise en charge du pack, implémenter `myScene.onRepack(scene, repackData)` qui lit
   `w:getLiquidAmount(...)` et `w:getInventory()` dans `repackData.warehouseSnapshot`.
7. Pour rendre la scène déployable en tant que FOB, définir `fobCompatible = true` **à l'intérieur
   de la table `crate`** (`myScene.crate.fobCompatible`). Une scène FOB fournit aussi typiquement un
   `crate.unpack = function(unit, unitName, sceneName) … end` personnalisé qui délègue à
   `CTLDFOBManager`.
8. Si la scène spawn un type **mod** (hors-stock), le lister dans `myScene.modTypes = { "Type_Name" }`
   (le gate d'assets design-time l'accepte tout en restant strict sur tous les autres types) et
   définir `myScene.requiresMod = "<libellé lisible>"` pour le catalogue. Optionnellement, définir
   `myScene.requiresCtld = "X.Y.Z"` pour avertir si CTLD est incompatible.

`src/scenes/CTLD_countrysideFarpScene.lua` est l'implémentation de référence (Invisible FARP +
approvisionnement d'entrepôt + `onRepack`) ; `src/scenes/CTLD_fobScene.lua` illustre la variante FOB.

## Scènes plugin (indépendantes de la position de chargement)

Le source d'une scène est **indépendant de sa position de chargement** : le même fichier fonctionne
qu'il soit mergé dans `CTLD.lua` (intégré) ou chargé depuis un déclencheur au démarrage de la mission
**après** CTLD (un plugin, distribué par
[`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins)). Les scènes dépendantes d'un mod ou de
niche sont livrées en plugins : une mission ne les embarque que si elle le décide.

Cela fonctionne parce que chaque point d'extension tolère d'être invoqué après l'init de CTLD :

- `registerSceneModel` injecte la caisse immédiatement si `CTLDCrateManager` est déjà initialisé ;
- les affectations i18n sont de simples écritures de table (indépendantes de l'ordre) ;
- `CTLDPlayerManager.deferMenuSection` route vers le manager vivant (`registerMenuSection`) lorsqu'il
  est appelé post-init, au lieu de remplir la file pré-init déjà vidée.

Contrat d'une scène plugin : charger **au démarrage de la mission uniquement** (avant slot-in des
joueurs), déclarer `requiresCtld`, et déclarer les types mod dans `modTypes`. La scène de référence
`_template` dans CTLD_plugins exerce tous les points d'extension (y compris un sous-menu radio).

## Validation des assets (design-time)

Les types DCS des scènes sont validés au **dev/CI**, pas au runtime (ADR 0007). Le hard-gate busted
`tests/ci/unit/scene_asset_gate_spec.lua` collecte les types spawnés par chaque scène (STATIC
`desc.type`, GROUND `desc.units[].type`) et échoue sur tout type absent du jeu datamine vendorisé
(`tests/data/dcs_types.lua`) ∪ l'union des `modTypes` de chaque scène. `modTypes` est additif : une
faute de frappe dans un type stock reste détectée même dans un descripteur qui utilise aussi un type
mod whitelisté.

L'ancien audit runtime (`_auditAfterModValidator`, `model._disabled`, `_purgeDisabledScenes`) a été
retiré ; la sonde runtime `CTLD_modValidator` a également été retirée pour les crates/troops (ASSET-VALIDATION-REVAMP) — la validation est au design-time (`CTLDTypeCollector` + gates) plus le compagnon dev-time optionnel. `isSceneEnabled(name)` indique désormais
simplement si le modèle est enregistré.
