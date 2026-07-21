# Scènes & FOB { #scenes-fob }

Cette page couvre deux outils liés que vous configurez en tant que mission maker : les **scenes**
(déploiements séquencés tels qu'une FARP ou un champ de mines qui se matérialisent lorsqu'un pilote
déballe une crate) et le **FOB** (une base avancée que les pilotes assemblent à partir de crates et
qui devient une logistics zone opérationnelle).

Les deux sont *déployés* par les pilotes depuis le cockpit. Pour les actions côté pilote — spawn,
transport et unpack des crates, ainsi que le pack d'une FARP — voir [Crates](../pilot/crates.md) et
[Pack](../pilot/pack.md).

---

## Scenes

Une **scene** est un déploiement séquencé et temporisé de plusieurs objets DCS (statics et/ou ground
groups) qui se joue automatiquement lorsqu'un pilote déballe une crate désignée. Elle permet de
mettre en scène une construction réaliste — une FARP qui se matérialise pièce par pièce, un champ de
mines qui se déploie — sans scripting spécifique à chaque mission : vous utilisez soit une scene
intégrée, soit vous déclarez un modèle de scene une seule fois.

### Scenes intégrées

Celles-ci sont livrées avec CTLD et sont prêtes à être proposées aux pilotes. Chacune déclare
elle-même sa crate, elle apparaît donc automatiquement dans le menu **Request Equipment** une fois
CTLD chargé (aucune config supplémentaire).

| Nom de scene | Crates | Ce qu'elle déploie |
| --- | --- | --- |
| `FARP Alpha` | 1 | FARP complète : helipad, tente, dépôt de munitions, camions de carburant + réparation, escouade de sécurité, décor. Warehouse approvisionné avec 10 000 L de chaque type de carburant. |
| `Countryside FARP` | 3 | Heliport Invisible-FARP discret + tente, camions, équipe de garde, lumières, manche à air. Warehouse mis à zéro par défaut (FARP visuelle, pas de service carburant). Supporte le pack de FARP. |
| `mineField` | 1 | Dispose une grille configurable de mines terrestres devant l'hélicoptère, marquée sur la carte F10. Voir [Champ de mines](minefield.md). |
| `FOB` | 3 | Forward Operating Base : une construction animée qui se termine en logistics zone. Voir [FOB](#fob-forward-operating-base) ci-dessous. |

### Scènes plugin

Certaines scènes ne sont pas embarquées dans `CTLD.lua` — généralement parce qu'elles dépendent d'un
**mod** DCS. Elles vivent dans le dépôt séparé
[`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) et se chargent à la demande : une mission
ne les embarque que si elle le décide.

Pour ajouter une scène plugin à votre mission :

1. Téléchargez le `.lua` du plugin depuis le
   [catalogue des plugins](https://veaf.github.io/CTLD_plugins/).
2. Dans l'éditeur de mission, ajoutez un déclencheur `DO SCRIPT FILE` au **démarrage de la mission**,
   **après** le déclencheur qui charge `CTLD.lua`. La scène s'enregistre et sa caisse apparaît dans
   **Request Equipment**.
3. Si le plugin requiert un mod DCS, assurez-vous que **tous** les clients l'ont installé (la page du
   plugin liste les prérequis). Le plugin prévient en jeu si votre version de CTLD est trop ancienne.

> **`Metal FARP`** est désormais un plugin (il nécessite le mod `Farp_FG_Petit_Helipad`). Il était
> auparavant intégré ; les missions qui l'utilisaient doivent maintenant charger le plugin Metal
> FARP comme ci-dessus.

### Comment une scene est construite

Un modèle de scene est une table avec un `name`, une `crate` auto-déclarée optionnelle et une liste
ordonnée de `steps`. Chaque step est d'un des trois types.

**Polar step — position déterministe.** L'objet spawn à une distance et un angle fixes relatifs à la
position et au cap de l'hélicoptère (capturés au moment de l'unpack).

| Champ | Type | Description |
|---|---|---|
| `registryKey` | string | Clé de l'objet à spawn (voir [Objects](#objects-le-registry)) |
| `polar` | table | `{ distance=N, angle=N }` — distance en mètres, angle en degrés dans le sens horaire depuis le cap de l'appareil (`0` = midi) |
| `relativeHeadingInDegrees` | number | Cap de l'objet spawné relatif au cap de l'appareil |
| `relativeAltitudeInMeters` | number | Décalage d'altitude par rapport à l'altitude de l'hélicoptère |
| `delayAfterPreviousStep` | number | Secondes à attendre *avant* l'exécution de ce step |

**Axis step — position sur axe aléatoire.** Un ou plusieurs objets spawnent le long d'un axe choisi
aléatoirement rayonnant depuis l'hélicoptère — un placement d'aspect naturel sans relèvement codé en
dur.

| Champ | Type | Description |
|---|---|---|
| `registryKey` | string | Clé de l'objet à spawn |
| `axis` | table | `{ count=N, safeDistance=N, spacing=N }` — nombre d'objets, distance jusqu'au premier objet (m), espacement entre objets (m) |
| `delayAfterPreviousStep` | number | Secondes à attendre avant l'exécution de ce step |

**Func-only step — pas de spawn.** Aucun objet n'est spawné ; seul un callback s'exécute. Utilisez-le
pour les messages de fin, l'approvisionnement du warehouse ou l'enregistrement post-construction.

| Champ | Type | Description |
|---|---|---|
| `delayAfterPreviousStep` | number | Secondes à attendre avant l'exécution de ce step |
| `func` | function | Callback `function(ctx)` (voir ci-dessous) |

La coalition (BLUE/RED) et le pays sont résolus automatiquement à partir du pilote qui a déballé la
crate.

### Step hooks

Tout spawn step peut également porter des hooks de script et un flag de criticité :

| Champ | Type | Description |
|---|---|---|
| `preFunc` | function | `function(ctx)` exécuté **avant** le spawn. Retourne `false` pour ignorer le spawn de ce step (la scene continue) ; appelle `ctx.scene:abort(reason)` pour arrêter toute la scene. |
| `func` | function | `function(ctx)` exécuté **après** le spawn (ou après un spawn ignoré). |
| `critical` | boolean | Si `true` et que le spawn ne produit aucun objet, la scene s'interrompt plutôt que de continuer avec une construction partielle défectueuse. |

Chaque hook reçoit une unique table de contexte `ctx` :

| Champ `ctx` | Description |
|---|---|
| `ctx.unit` | L'unité déclencheuse (l'appareil du pilote) |
| `ctx.spawnedObj` | Le dernier objet DCS spawné dans ce step (`nil` pour les func-only ou les steps ignorés) |
| `ctx.step` | La table du step courant |
| `ctx.scene` | L'instance de scene — lecture/écriture de `_refX` / `_refZ` / `_refAlt` (point de référence), `_params`, etc. |

Un modèle de scene peut aussi définir `model.onComplete = function(scene) ... end`, appelé une fois
le dernier step terminé.

### Objects : le registry

Les steps de scene référencent les objets par un `registryKey` qui se résout via
**`CTLDObjectRegistry`** — un catalogue de descripteurs DCS enrichis (fréquence de helipad,
`shape_name` de static, formations de ground groups multi-unités, types d'unités selon la coalition).
Ceci remplace toute liste d'objets figée : vous enregistrez au chargement les clés dont votre scene a
besoin, et les clés partagées peuvent être déclarées sans risque depuis plusieurs scenes.

```lua
CTLDObjectRegistry.registerIfAbsent("FARP_Tent", {
    groupType  = "STATIC",
    namePrefix = "FARP_Tent",
    type       = "FARP Tent",
    category   = "Fortifications",
})
```

`registerIfAbsent` est un no-op lorsque la clé existe déjà, les scenes peuvent donc co-déclarer des
objets communs (`SINGLE_HELIPAD`, `Fuel_Truck`, `FARP_Tent`, `ammo_cargo`, `Windsock`,
`NF-2_LightOn`…) sans conflit. Vérifiez tout `type` DCS par rapport au dataset datamine avant de vous
y fier.

### Déclarer une scene personnalisée

**Étape 1 — enregistrez les objets** que vos steps utilisent (comme ci-dessus), s'ils ne sont pas
déjà dans le registry.

**Étape 2 — déclarez le modèle de scene** dans un script de mission chargé après CTLD. Déclarez
vous-même une table `crate` pour que la scene soit proposée automatiquement dans le menu Request
Equipment :

```lua
local myScene = {
    name = "My FARP",

    -- Auto-injected into the Request Equipment menu — no spawnableCrates entry needed.
    crate = {
        weight         = 1050.00,
        i18nKey        = "My FARP Crate",   -- display name (translation key)
        deployKey      = "Deploy My FARP",  -- menu label (translation key)
        cratesRequired = 1,
        side           = nil,               -- nil = both coalitions
    },

    steps = {
        -- polar step: helipad 100 m ahead, facing south relative to the helicopter
        { registryKey = "SINGLE_HELIPAD", polar = { distance = 100, angle = 0 },
          relativeHeadingInDegrees = 180, relativeAltitudeInMeters = 0, delayAfterPreviousStep = 0 },
        -- polar step: tent 130 m ahead-right, 3 s later
        { registryKey = "FARP_Tent", polar = { distance = 130, angle = 5 },
          relativeHeadingInDegrees = 90, relativeAltitudeInMeters = 0, delayAfterPreviousStep = 3 },
        -- axis step: scatter 3 ammo crates along a random axis
        { registryKey = "ammo_cargo", axis = { count = 3, safeDistance = 30, spacing = 8 },
          delayAfterPreviousStep = 5 },
        -- func-only step: completion message
        { delayAfterPreviousStep = 0,
          func = function(ctx)
              trigger.action.outText("FARP ready at " .. ctx.unit:getName(), 10)
              return true
          end },
    },
}

CTLDSceneManager.getInstance():registerSceneModel(myScene)
```

C'est tout ce qui est requis : les pilotes chargent la crate dans une logistics zone, volent jusqu'à
la cible et font l'unpack — la scene se joue automatiquement.

> **Note de migration.** Les versions antérieures utilisaient un champ `objectsDescDbKey` et une
> signature `func(unit, spawnedObj, step)`, et requéraient une entrée `spawnableCrates`
> correspondante avec `unit = "<scene name>"`. L'API actuelle utilise **`registryKey`**, une unique
> table de contexte **`func(ctx)`** et une **table `crate` auto-déclarée** sur le modèle. Mettez à
> jour les anciens scripts de scene en conséquence.

### Pack de FARP

Lorsque `enableFARPRepack = true` (par défaut), un pilote au sol à moins de **300 m** d'une scene de
FARP déployée qui supporte le pack obtient une entrée **Pack Equipt → Pack `<scene name>`** sous
**Crate Commands**. La packer :

1. Capture l'état du warehouse de la FARP (carburant, et le cas échéant armes/appareils) via le hook
   `onRepack` de la scene.
2. Détruit les objets de la scene déployée.
3. Spawn les crates requises près de l'hélicoptère, portant le snapshot du warehouse.

Lorsque ces crates sont déballées à un nouvel emplacement, le warehouse est restauré aux niveaux
capturés au lieu des valeurs par défaut.

```lua
cfg.settings["enableFARPRepack"] = false  -- default: true
```

**Scenes qui supportent le pack :** `Countryside FARP` (et le plugin `Metal FARP`).

Pour rendre une scene **personnalisée** packable, ajoutez un hook `onRepack(scene, repackData)` qui
enregistre ce qui doit être restauré, et faites en sorte que votre warehouse step vérifie
`ctx.scene._params.repackData` pour choisir entre restaurer le snapshot et appliquer les valeurs par
défaut :

```lua
myScene.onRepack = function(scene, repackData)
    local farpName = scene._params and scene._params.farpName
    if not farpName then return end
    local ab = Airbase.getByName(farpName)
    if not ab then return end
    local w = ab:getWarehouse()
    if not w then return end
    repackData.warehouseSnapshot = {
        liquid = { [0] = w:getLiquidAmount(0), [1] = w:getLiquidAmount(1),
                   [2] = w:getLiquidAmount(2), [3] = w:getLiquidAmount(3) },
    }
end
```

> La clé de config `enableFARPRepack` et le hook de modèle `onRepack` conservent leurs noms
> hérités, mais l'action en jeu est **pack** partout — le menu affiche « Pack Equipt ».

---

## FOB — Forward Operating Base

Un FOB est une base avancée déployable construite à partir de crates. Une fois construit, il
s'enregistre automatiquement comme logistics zone (les pilotes peuvent y spawn des crates et des
véhicules) et, optionnellement, comme troop pickup zone.

> **Les FOB sont le seul moyen de créer une nouvelle logistics zone à l'exécution.** Si votre mission
> a besoin de logistique à une position décidée en cours de jeu, déployez un FOB plutôt que de
> pré-placer une trigger zone `LGZ_`. Voir [Configuration des zones](zones.md).

Le FOB est livré comme la scene intégrée **`FOB`** : une construction animée d'environ 120 s qui se
termine en enregistrant la base. Il nécessite **3 crates de FOB** par défaut (défini sur la table
`crate` de la scene, pas dans un réglage global).

### Déroulé de la construction (côté pilote)

1. Le pilote charge les crates de FOB requises et vole jusqu'à la zone cible.
2. L'unpack est déclenché depuis le menu F10 (**Crate Commands → Unpack Crate(s)** avec des crates de
   FOB à proximité). CTLD vérifie que toutes les crates requises sont à moins de **750 m** les unes
   des autres et que le site est en dehors de toute logistics zone active et à au moins
   `fobMinDistanceFromZones` des zones existantes.
3. La scene de FOB se joue ; les structures spawnent en séquence.
4. À la fin : une [balise](../pilot/beacons.md) radio est déposée au centre du FOB, la zone
   s'enregistre comme logistics zone et — si `troopPickupAtFOB = true` — comme troop pickup zone.

Les pilotes peuvent lister les FOB actifs via **CTLD → FOBs List → List active FOBs**.

### Destruction d'un FOB

Si une action ennemie détruit suffisamment de structures de FOB pour que la fraction survivante passe
sous `(1 - fobDestructionThreshold)`, le FOB est considéré comme détruit : sa logistics zone est
désenregistrée immédiatement, sa balise est retirée et l'événement `OnFOBDestroyed` se déclenche.

| `fobDestructionThreshold` | Structures devant survivre | FOB perdu lorsque |
| --- | --- | --- |
| `0.5` (par défaut) | > 50 % | ≥ 50 % détruites |
| `0.75` | > 25 % | ≥ 75 % détruites |
| `1.0` | > 0 % (au moins une survivante) | toutes les structures détruites |

> Une fois détruit, la logistics zone du FOB est perdue pour le reste de la mission — il n'y a pas de
> reconstruction automatique. Les pilotes doivent déployer de nouvelles crates de FOB ailleurs pour
> rétablir la logistique dans cette zone.

### Configuration

| Paramètre | Défaut | Description |
|---|---|---|
| `enabledFOBBuilding` | `true` | Active la construction de FOB et le menu FOB |
| `troopPickupAtFOB` | `true` | Enregistre un FOB déployé comme troop pickup zone |
| `fobMinDistanceFromZones` | `500` | Distance minimale (m) par rapport aux logistics zones existantes pour autoriser le déploiement |
| `fobLogisticZoneRadius` | `150` | Rayon (m) de la logistics zone créée autour du FOB |
| `fobDestructionThreshold` | `0.5` | Fraction des objets de scene détruits avant que le FOB ne soit perdu (0.0–1.0) |
| `fobTroopPickupRadius` | `150` | Rayon (m) à l'intérieur duquel les troupes peuvent être récupérées à un FOB |

```lua
cfg.settings["enabledFOBBuilding"]      = true
cfg.settings["troopPickupAtFOB"]        = true
cfg.settings["fobMinDistanceFromZones"] = 500
cfg.settings["fobLogisticZoneRadius"]   = 150
cfg.settings["fobDestructionThreshold"] = 0.5
cfg.settings["fobTroopPickupRadius"]    = 150
```

> Le nombre de crates dont un FOB a besoin n'est **pas** un réglage global — il vit sur le champ
> `crate.cratesRequired` de la scene `FOB` (3 par défaut), et la construction est auto-temporisée par
> la scene. Les anciennes docs référençaient `cratesRequiredForFOB` et `buildTimeFOB` ; ces réglages
> n'existent plus.

### Événements

| Événement | Déclenché quand |
|---|---|
| `OnFOBDeployed` | Construction du FOB terminée et base pleinement active |
| `OnFOBDestroyed` | FOB détruit par une action ennemie |
