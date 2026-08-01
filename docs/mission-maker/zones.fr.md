# Configuration des zones { #zone-setup }

Les zones CTLD sont déclarées directement dans l'**éditeur de mission de DCS** en nommant vos
trigger zones selon une convention structurée. Pour la plupart des zones, aucun script n'est
nécessaire : CTLD lit le nom de chaque trigger zone au démarrage de la mission, analyse celles
qui correspondent à un préfixe connu, et les enregistre automatiquement. Les zones de transport
IA constituent la seule exception — elles sont déclarées dans votre configuration CTLD (voir
[Zones de transport IA](#ai-transport-zones-aiz) ci-dessous).

Pour savoir comment les pilotes *utilisent* concrètement ces zones depuis le cockpit, consultez
le [Guide du pilote](../pilot/index.md).

## Convention de nommage { #naming-convention }

Le nom d'une zone encode son type et tous ses paramètres, séparés par `_` :

```
TYPE_name_param1_param2_..._paramN
```

> **Règle :** `_` est le séparateur de champ. Il est **interdit à l'intérieur de toute valeur de
> champ** (nom de zone, nom de flag, etc.). Utilisez `farmmain`, et non `farp_main`.

## Vue d'ensemble des types de zones { #zone-types-at-a-glance }

Trois préfixes sont auto-découverts à partir des noms de trigger zones de DCS :

| Préfixe | Type de zone | Schéma |
| --- | --- | --- |
| `TRZ` | Zone de troupes — objectif de pickup et/ou d'extract joueur | `TRZ_<name>_<A\|R\|B\|N>_<stock>_<flag>_<target>` — **les 5 champs sont requis** |
| `WPZ` | Zone de waypoint — les troupes déployées à l'intérieur marchent vers le centre de la zone | `WPZ_<name>_[R\|B\|N]` |
| `LGZ` | Zone logistique — services de crate et de véhicules | `LGZ_<name>_[R\|B\|N]` |

Un quatrième type — les **zones de transport IA (AIZ)** — n'est pas découvert par le nom. Il est
déclaré entièrement en configuration ; voir [Zones de transport IA](#ai-transport-zones-aiz).

> Il n'existe pas de préfixe `EXZ` distinct. Les objectifs d'extract sont une **fonction d'une
> TRZ** (une zone de troupes avec `stock = 0` et un flag d'objectif), décrite sous
> [Zones de troupes](#troop-zones-trz).

**Paramètre de coalition :**

| Valeur | Coalition |
| --- | --- |
| `A` | Toutes les coalitions (TRZ uniquement) |
| `R` | RED uniquement |
| `B` | BLUE uniquement |
| `N` | Neutre |
| *(omis)* | Toutes les coalitions (WPZ / LGZ uniquement — une TRZ requiert un `A` explicite) |

> **Unicité :** deux zones du même préfixe ne peuvent pas partager le même `name`. Un nom de zone
> déjà enregistré n'est jamais écrasé par un suivant.

---

## Zones de troupes (TRZ) { #troop-zones-trz }

Une zone de troupes fournit un **pickup joueur** et/ou un **objectif d'extract**.

**Schéma :** `TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>`

**Les 5 champs sont requis.** Le parser rejette tout nom de TRZ comportant un champ manquant ou
invalide — un avertissement est écrit dans `CTLD.log` et la zone est ignorée.

| Champ | Position | Valeurs | Signification |
| --- | --- | --- | --- |
| `name` | 2 | quelconque (sans underscore, ni mot réservé) | Identifiant de zone utilisé dans les logs et les menus F10 |
| `coalition` | 3 | `A` `R` `B` `N` | Qui peut interagir : **A**=toutes, **R**=RED, **B**=BLUE, **N**=NEUTRAL |
| `stock` | 4 | entier 0–999 | `0`=pas de pickup · `1–998`=limité · `999`=illimité |
| `flag` | 5 | nom de flag DCS ou `nil` | Flag incrémenté du nombre de soldats à l'extract ; `nil` = pas d'objectif |
| `target` | 6 | entier ≥0 | `0`=pas de seuil · `N≥1`=objectif de nombre de soldats pour un trigger de victoire DCS |

> **Mots réservés** — interdits comme `name` ou `flag` : `nil`, `A`, `R`, `B`, `N`.

### Valeurs de stock { #stock-values }

| `stock` | Capacité de pickup | Ce que voit le pilote |
| --- | --- | --- |
| `0` | **Aucune** — pas de pickup | Pas d'entrée « Load from » dans le menu F10 |
| `1–998` | Limité — décrémente à chaque chargement | « Load from `<name>` (N remaining) » |
| `999` | **Illimité** — jamais épuisé | « Load from `<name>` » |

> Utilisez `999` pour un pickup illimité — **pas** `0`. `0` signifie *aucune capacité de pickup*.

### Valeurs de flag et de target { #flag-and-target-values }

| `flag` | `target` | Comportement |
| --- | --- | --- |
| `nil` | quelconque | La zone n'a pas d'objectif. Les troupes déployées ici apparaissent comme un ground group DCS. |
| un nom de flag | `0` | Objectif actif, sans seuil. CTLD incrémente le flag du nombre de soldats à chaque déploiement de troupes à l'intérieur. |
| un nom de flag | `N≥1` | Objectif avec seuil. CTLD incrémente le flag ; **c'est vous** qui écrivez le trigger de victoire DCS `flag >= N`. CTLD initialise le flag à `0` au démarrage de la mission et ne termine jamais la mission de lui-même. |

### Exemples { #examples }

| Nom de zone | Coalition | Stock | Flag | Target | Comportement |
| --- | --- | --- | --- | --- | --- |
| `TRZ_base_B_50_nil_0` | BLUE | 50 (limité) | — | — | **Pickup** — 50 soldats, réapprovisionnement au RTB |
| `TRZ_depot_A_999_nil_0` | Toutes | illimité | — | — | **Pickup** — illimité, toutes coalitions |
| `TRZ_exfil_B_0_rescue_0` | BLUE | pas de pickup | `rescue` | aucun | **Extract uniquement** — déployer des troupes ici incrémente le flag `rescue` |
| `TRZ_lz_R_0_secure_100` | RED | pas de pickup | `secure` | 100 | **Extract avec condition de victoire** — objectif RED à 100 soldats |
| `TRZ_fob_N_20_defend_50` | Neutre | 20 (limité) | `defend` | 50 | **Mixte** — pickup (20) + objectif d'extract |
| `TRZ_marker_B_0_nil_0` | BLUE | pas de pickup | — | — | **Inerte** — marqueur nommé, sans fonction |

Annoté :

```
TRZ  _  fob  _  N   _  20     _  defend  _  50
 │      │       │      │          │          │
 │      │       │      │          │          └─ target : 50 soldats complètent l'objectif
 │      │       │      │          └──────────── flag   : "defend" (nom de flag DCS)
 │      │       │      └─────────────────────── stock  : 20 troupes max (pickup limité)
 │      │       └────────────────────────────── coalition: NEUTRAL
 │      └────────────────────────────────────── name   : "fob"
 └───────────────────────────────────────────── préfixe TRZ
```

> **Zone extract uniquement** (`stock = 0`) : aucune entrée « Load from » n'apparaît dans le menu
> F10. La zone sert uniquement de trigger d'objectif quand des troupes y sont déployées.
>
> **Zone mixte** (`stock > 0` et `flag ≠ nil`) : gère à la fois l'embarquement et le décompte
> d'objectif. Quand un pilote se pose à l'intérieur avec des troupes à bord, **l'objectif est
> prioritaire** — le flag est incrémenté et **aucun** groupe DCS n'est spawné. Le
> réapprovisionnement du stock au RTB n'a lieu que dans les zones de pickup uniquement.
>
> **Fumigène :** la couleur du fumigène des zones de troupes est définie globalement par
> coalition via le paramètre `troopZoneSmokeColor` (voir [Configuration](configuration.md)), et
> non par nom de zone.

Voir [Transport de troupes](../pilot/troop-transport.md) pour le workflow côté pilote
(embarquement, déploiement, extraction).

### Points d'embarquement sur les navires { #pickup-points-on-ships }

Un point d'embarquement peut se trouver sur un **navire** plutôt que sur une trigger zone. La zone
suit le bâtiment : les troupes embarquent donc encore après que le porte-avions a fait route. Deux
paramètres, dans [Configuration](configuration.md) :

| Paramètre | Ce qu'il nomme | À utiliser quand |
| --- | --- | --- |
| `troopZones` | un **nom d'unité**, quand aucune trigger zone ne porte ce nom | vous voulez *ce* navire, avec vos propres réglages de stock et de fumigène |
| `troopZoneShipTypes` | des noms de **type** DCS | vous voulez que *chaque* porte-avions soit un point d'embarquement, sans les nommer |

```yaml
  # Chaque porte-avions de classe Nimitz et Stennis et chaque Tarawa de la mission
  # devient un point d'embarquement illimité — aucun nom d'unité nulle part.
  troopZoneShipTypes:
  - CVN_71
  - Stennis
  - LHA_Tarawa
```

Une zone portée par un navire utilise toujours un rayon de **200 m**, quel que soit le paramètre
qui l'a créée. Les zones découvertes ont un stock **illimité** et pas de fumigène ; s'il vous faut
une limite, une couleur de fumigène ou une coalition à vous, nommez ce navire dans `troopZones` —
une zone explicitement configurée du même nom l'emporte toujours. Un type listé auquel aucun navire
ne correspond n'est pas une erreur : c'est un catalogue de types, réutilisable d'une mission à
l'autre.

!!! tip "Utilisez le nom de type, pas le nom affiché dans l'éditeur"
    Les deux paramètres comparent l'**identifiant de type** DCS, qui n'est pas toujours ce
    qu'affiche l'éditeur de mission. `ctld-tools validate` rejette un nom qui ne correspond à aucun
    type DCS connu : une faute de frappe est donc détectée avant même que la mission tourne.

---

## Zones de waypoint (WPZ) { #waypoint-zones-wpz }

Quand des troupes sont déployées (fast-rope ou dépose au sol) en un point qui tombe **à
l'intérieur** d'une WPZ active, elles marchent automatiquement vers le **centre** de cette zone au
lieu de chercher l'ennemi le plus proche.

**Schéma :** `WPZ_<name>_[R|B|N]`

| Exemple de nom | Signification |
| --- | --- |
| `WPZ_hill47_B` | Zone de waypoint BLUE « hill47 » |
| `WPZ_bridge` | Zone de waypoint toutes coalitions |

Le rayon de la zone est repris de l'éditeur de trigger zone de DCS.

> Les zones WPZ **n'apparaissent pas** dans le menu F10 — elles agissent silencieusement au moment
> du déploiement.

---

## Zones logistiques (LGZ) { #logistic-zones-lgz }

Une zone logistique définit une base où les pilotes peuvent spawner et packer des crates et des
véhicules depuis le menu F10. Un pilote doit se trouver à l'intérieur d'une zone logistique pour
utiliser ces services.

**Schéma :** `LGZ_<name>_[R|B|N]`

| Exemple de nom | Signification |
| --- | --- |
| `LGZ_depot1_B` | Zone logistique « depot1 », BLUE uniquement |
| `LGZ_farmmain_R` | Zone logistique « farmmain », RED uniquement |
| `LGZ_shared` | Zone logistique ouverte à toutes les coalitions |

> **Rayon :** une zone `LGZ_` est un **cercle** centré sur la trigger zone, avec un rayon repris
> du paramètre `dynamicZoneRadius` (défaut **200 m**). Le rayon propre de la trigger zone dans
> l'éditeur n'est **pas** utilisé pour les LGZ. Réglez `dynamicZoneRadius` dans
> [Configuration](configuration.md) pour le modifier globalement.

Voir [Catalogue des crates](crates-catalogue.md) pour ce qui peut être spawné, et
[Crates](../pilot/crates.md) pour le workflow du pilote.

### Zones logistiques portées par une unité ou un statique { #logistic-zones-carried-by-a-unit-or-a-static }

Une zone logistique peut aussi être attachée à un **objet** de la mission plutôt qu'à une trigger
zone. La zone suit l'objet — un porte-avions conserve donc son point logistique en route — et
disparaît quand l'objet est détruit. Deux paramètres le permettent, dans
[Configuration](configuration.md) :

| Paramètre | Ce qu'il nomme | À utiliser quand |
| --- | --- | --- |
| `logisticUnits` | des **noms** d'unité / de statique placés dans le ME | vous voulez que *cet* objet précis soit un point logistique |
| `logisticUnitTypes` | des noms de **type** DCS | vous voulez que *chaque* porte-avions, ou *chaque* dépôt de munitions, en soit un, sans les nommer |

```yaml
  # Chaque porte-avions de classe Stennis et chaque dépôt de munitions FARP
  # de la mission devient un point logistique — aucun nom d'unité nulle part.
  logisticUnitTypes:
  - Stennis
  - CVN_71
  - FARP Ammo Dump Coating
```

Un type listé ici auquel aucun objet de la mission ne correspond n'est **pas** une erreur : c'est
un catalogue de types, réutilisable d'une mission à l'autre, pas la liste des unités que contient
une mission donnée. Un nom dans `logisticUnits` fonctionne à l'inverse — il désigne un objet
précis, donc son absence est signalée par un avertissement.

Les deux utilisent le rayon `maximumDistanceLogistic` (défaut 200 m). Quand une zone existe déjà
sous le nom de cet objet — via une trigger zone `LGZ_` ou via `logisticUnits` — elle est conservée
telle quelle : la découverte par type n'écrase jamais.

!!! tip "Utilisez le nom de type, pas le nom affiché dans l'éditeur"
    `logisticUnitTypes` compare l'**identifiant de type** DCS, qui n'est pas toujours ce
    qu'affiche l'éditeur de mission. Le dépôt de munitions FARP est le piège classique :
    l'éditeur l'appelle *FARP Ammo Storage*, mais son identifiant de type est
    `FARP Ammo Dump Coating`. `ctld-tools validate` rejette un nom qui ne correspond à aucun type
    DCS connu : une faute de frappe est donc détectée avant même que la mission tourne.

### Zones logistiques créées à l'exécution { #logistic-zones-created-at-runtime }

La seule façon d'ajouter une nouvelle zone logistique pendant une mission en cours est de
**déployer une FOB**. Quand la construction de la FOB est terminée, CTLD enregistre
automatiquement une zone logistique circulaire centrée sur le site de la FOB (rayon =
`fobLogisticZoneRadius`, défaut 150 m, sous le nom de la FOB). Aucune trigger zone `LGZ_` ni entrée
de config n'est requise. Voir [Scenes & FOB](scenes-fob.md) pour le cycle de vie complet de la
FOB, y compris comment une FOB détruite retire sa zone logistique.

### Désactivation et réactivation d'une zone logistique { #deactivating-and-reactivating-a-logistic-zone }

Utilisez l'API `CTLDZoneManager` depuis un trigger **DO SCRIPT** pour simuler une capture de zone
ou une perte temporaire. Cela fonctionne à la fois pour les trigger zones `LGZ_` et pour les zones
basées sur `logisticUnits` :

```lua
-- Deactivate — zone is ignored by all pilots until reactivated
CTLDZoneManager.getInstance():deactivateLogisticZone("depot1")

-- Reactivate — zone becomes available again
CTLDZoneManager.getInstance():activateLogisticZone("depot1")
```

La zone reste enregistrée et peut être basculée autant de fois que souhaité.

---

## Zones de transport IA (AIZ) { #ai-transport-zones-aiz }

Les zones AIZ contrôlent le comportement automatique des **transports IA** (unités listées dans
`transportPilotNames`). Les joueurs humains ne sont jamais affectés par elles.

> **Les zones AIZ n'ont pas de convention de nommage.** N'importe quelle trigger zone de DCS peut
> être une zone AIZ — vous la référencez par son nom dans le tableau de config `aiZones`. Le
> pickup comme le drop-off se déclenchent à l'atterrissage (`S_EVENT_LAND`) : l'unité IA doit
> physiquement se poser à l'intérieur du rayon de la zone.

### Rôles

| Rôle | Déclencheur | Comportement |
| --- | --- | --- |
| **Pickup** | Le transport IA se pose à l'intérieur de la zone | Charge des troupes et/ou un véhicule entier |
| **Drop-off** | Le transport IA se pose à l'intérieur de la zone | Déploie des troupes et/ou décharge un véhicule entier |

Une zone peut être pickup uniquement, drop-off uniquement, ou les deux.

### Déclaration en config { #config-declaration }

`aiZones` est une liste d'entrées dans votre configuration. `ctld-tools` lui donne un éditeur dédié
dans la famille **Zones** ; dans un instantané écrit à la main, elle vit sous `mm_facing` :

```yaml
mm_facing:
  aiZones:
  # Troops-only pickup: two templates with per-template stock
  - dcsZoneName: my_base
    coalition: BLUE
    isPickup: true
    cargoType: T
    troopStock:
      Standard Group: 5
      Anti Tank: 2

  # Troops-only pickup: every compatible template, unlimited
  - dcsZoneName: depot_alpha
    coalition: BLUE
    isPickup: true
    cargoType: T
    troopStock:
      All: -1

  # Vehicle-only pickup (vehicles must be physically in the zone)
  - dcsZoneName: armor_depot
    coalition: BLUE
    isPickup: true
    cargoType: V
    vehicleStock:
      Hummer: 3
      M1045 HMMWV TOW: -1

  # Troops + vehicle pickup
  - dcsZoneName: hub_tv
    coalition: BLUE
    isPickup: true
    cargoType: TV
    troopStock:
      All: -1
    vehicleStock:
      Hummer: 5

  # Ground-only drop-off
  - dcsZoneName: lz_front
    coalition: BLUE
    isDropoff: true
    aiDropMode: G

  # Ground + parachute drop-off (default)
  - dcsZoneName: lz_rear
    coalition: BLUE
    isDropoff: true
```

!!! warning "Ici, `coalition` est un mot, pas un nombre"
    Tous les autres champs de coalition de la configuration CTLD sont le `side` numérique (`1` = RED,
    `2` = BLUE). Dans une entrée `aiZones`, c'est la chaîne `RED`, `BLUE` ou `NEUTRAL`. Y écrire un
    nombre signifie « n'importe quelle coalition », silencieusement.

### Paramètres { #parameters }

| Paramètre | Type | Requis | Description |
| --- | --- | --- | --- |
| `dcsZoneName` | string | ✅ | Nom exact de la trigger zone DCS |
| `coalition` | `"RED"` / `"BLUE"` / `"NEUTRAL"` | ✅ | Quels transports IA utilisent cette zone |
| `isPickup` | `true` | l'un des deux | Marque la zone comme zone de pickup |
| `isDropoff` | `true` | l'un des deux | Marque la zone comme zone de drop-off |
| `cargoType` | `"T"` / `"V"` / `"TV"` | pickup uniquement | Troupes, véhicule entier, ou les deux. Défaut `"T"` |
| `troopStock` | table `{ [name] = N }` | pickup + troupes | Stock par template. `N = -1` illimité, `N > 0` limité. Clé spéciale `All` = tous les templates compatibles. **Doit être présent pour activer le pickup de troupes.** |
| `vehicleStock` | table `{ [type] = N }` | pickup + véhicules | Stock par type, mêmes règles `-1` / `N` / `All`. **Doit être présent pour activer le pickup de véhicules.** |
| `aiDropMode` | `"G"` / `"P"` / `"GP"` | drop-off | `G` sol, `P` parachute, `GP` l'un ou l'autre. Défaut `"GP"` |
| `troopTemplates` | `{ "Name1", ... }` | optionnel | Liste blanche des templates de troupes éligibles à cette zone |
| `vehicleTypes` | `{ "TypeName", ... }` | optionnel | Liste blanche des noms de type de véhicule DCS éligibles au chargement |

> `troopStock` et `vehicleStock` sont des **tables**, pas de simples entiers. Le stock par template
> / par type a remplacé l'ancienne forme à entier unique.

### Configuration du transport IA { #ai-transport-setup }

1. Créez des trigger zones dans le ME (nom quelconque, rayon adapté à l'atterrissage).
2. Déclarez-les dans `aiZones` (ci-dessus).
3. Ajoutez le **nom d'unité DCS exact** de chaque unité IA à `transportPilotNames`, qui est une
   **simple liste** de noms :

   ```yaml
   mm_facing:
     transportPilotNames:
     - heliai_supply
     - heliai_medevac
   ```

4. Routez l'unité IA pour qu'elle se pose à l'intérieur des zones (waypoints avec une tâche
   « Landing »).

> Un véhicule entier n'est chargé que si son poids n'excède pas le `maxVehicleWeight` du transport
> et qu'au moins un aéronef a `canTransportWholeVehicle = true`. Voir
> [Configuration](configuration.md) pour les poids et les capacités.

### Rapport de validation { #validation-report }

Au démarrage de la mission, CTLD valide chaque entrée `aiZones` et, s'il y a quoi que ce soit à
signaler, affiche à l'écran (30 s) et dans `CTLD.log` une liste groupée d'erreurs et
d'avertissements, dans la langue de la mission. Si tout est valide, une seule ligne `INFO` est
loggée et rien n'apparaît.

Une entrée est **ignorée** (erreur) quand elle n'a pas de `dcsZoneName`, un `dcsZoneName` en
double, une zone absente de l'éditeur de mission, une `coalition` manquante ou invalide (doit être
`RED` / `BLUE` / `NEUTRAL`), ni `isPickup` ni `isDropoff`, ou un cargo véhicule (`V` / `TV`) alors
qu'aucun aéronef ne peut transporter un véhicule entier. Les **avertissements** courants (la zone
est tout de même créée) : un `cargoType` invalide retombe sur `"T"`, un `aiDropMode` invalide
retombe sur `"GP"`, une zone de pickup à laquelle manque le `troopStock` / `vehicleStock`
correspondant a ce pickup désactivé, des noms de `troopTemplates` / `vehicleTypes` inconnus, et une
zone de pickup chevauchant une zone de drop-off de la même coalition (risque de boucle instantanée
pickup+drop-off).

---

## Configuration de zone héritée (legacy) { #legacy-zone-configuration }

Les missions construites à la manière classique de CTLD v1 — noms de zones listés dans des tables
de config plutôt qu'analysés depuis les noms de trigger — restent supportées. Le caractère `_`
**est** autorisé dans les noms ici, car il s'agit de simples noms de trigger (ou d'unité) DCS, et
non de schémas analysés.

Ce sont des réglages de configuration ordinaires, et leurs entrées sont des **tableaux
positionnels** : le sens d'une valeur vient de sa place dans la liste. `ctld-tools` les édite comme
des champs nommés dans la famille **Zones**, ce qui est la façon la plus sûre d'y toucher ; écrits à
la main, ils ressemblent à ceci :

```yaml
mm_facing:
  # Zones de pickup de troupes — la v1 appelait cela pickupZones.
  # [ nom de zone DCS, couleur de fumée, limite, actif, side ]
  #   couleur de fumée : none | green | red | white | orange | blue
  #   limite           : -1 = illimité, ou tout entier >= 1
  #   actif            : yes | no
  #   side             : 0 = les deux, 1 = RED, 2 = BLUE
  troopZones:
  - - pickzone1
    - blue
    - -1
    - yes
    - 0
  - - USS Tarawa      # un nom d'unité de navire est aussi accepté — la zone suit le navire
    - blue
    - 10
    - yes
    - 2

  # Zones de waypoint (les troupes déployées marchent vers le centre)
  # [ nom de zone DCS, couleur de fumée, actif, side ]
  wpZones:
  - - wpzone1
    - green
    - yes
    - 2

  # Unités logistiques : noms d'unité ou de statique placés dans le ME.
  # Si l'objet nommé est détruit, sa zone logistique est retirée automatiquement.
  logisticUnits:
  - logistic1
  - logistic2
```

!!! warning "`dropOffZones` n'est pas lu par CTLD 2.x"
    La table `dropOffZones` de la v1 (points de déploiement automatique de l'IA) n'a pas de réglage
    équivalent dans CTLD 2. Le drop-off IA se configure avec les
    [zones de transport IA](#ai-transport-zones-aiz) — une entrée `aiZones` avec `isDropoff: true`.
    Une config v1 portant `dropOffZones` verra cette table ignorée — CTLD le signale une fois au
    démarrage de la mission, dans le rapport de démarrage. La couleur de fumigène de la v1 n'a pas
    d'équivalent : une zone IA n'est délibérément pas marquée. Voir
    [Migration v1 → v2](../developer/migration-v1-v2.fr.md#dropoffzones-is-gone-use-an-aizones-entry)
    pour l'exemple avant/après et la façon de marquer quand même l'endroit.

> Les zones héritées et les zones auto-découvertes (TRZ / WPZ / LGZ) coexistent sans conflit : une
> zone déjà enregistrée via la découverte par nom de trigger n'est jamais écrasée par la config
> héritée.

Pour la surface de compatibilité v1 `ctld.*` complète, voir [API héritée](legacy-api.md).
