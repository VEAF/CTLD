# Assemblage des systèmes AA { #aa-system-assembly }

`CTLDCrateAssemblyManager` (`src/CTLD_aasystem.lua`) transforme plusieurs crates déballés à
proximité les uns des autres en un système de défense antiaérienne complet. C'est un singleton
obtenu via `CTLDCrateAssemblyManager.getInstance()`, qui couvre trois opérations sur les
systèmes pris en charge — **HAWK, Patriot, NASAMS, BUK, KUB, S-300** :

- **assemblage** — spawn d'un système complet une fois que tous les crates de pièces requis sont packés ensemble ;
- **rearm** — ajout de launchers à un système complet existant ;
- **réparation** — respawn sur place d'un système endommagé.

Le manager conserve un unique champ, `_completeSystems` (`groupName → { details, template }`),
qui suit chaque système qu'il a spawné afin de pouvoir ensuite les compter, les rearm ou les
réparer.

## Templates

Les templates sont déclarés dans `CTLD_config.lua` (à l'intérieur de `CTLDConfig:load()`), qui
écrase le placeholder `CTLDCrateAssemblyManager.TEMPLATES = {}` avant l'exécution de toute init
de manager. Un mission maker peut surcharger `CTLDCrateAssemblyManager.TEMPLATES` avant l'init
si nécessaire. Chaque template décrit un système :

```lua
{
    name           = "HAWK AA System",   -- display name, used as the system identity
    count          = 5,                   -- unique part types required = "complete"
    side           = 2,                   -- coalition.side.* (1 = RED, 2 = BLUE)
    sectionName    = "SAM mid range",     -- spawnableCrates section to inject crate entries into
    allCratesLabel = "HAWK - All crates", -- i18n key for the auto-generated "All crates" mixedSet
    parts = {
        { DCSTypename = "Hawk ln",   desc = "HAWK Launcher",     launcher = true, weight = 1004.01 },
        { DCSTypename = "Hawk sr",   desc = "HAWK Search Radar", amount = 2,      weight = 1004.02 },
        { DCSTypename = "Hawk tr",   desc = "HAWK Track Radar",  amount = 2,      weight = 1004.03 },
        { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",          NoCrate = true,  weight = 1004.04 },
        { DCSTypename = "Hawk cwar", desc = "HAWK CWAR",         amount = 2, NoCrate = true, weight = 1004.05 },
    },
    repair = { desc = "HAWK Repair", weight = 1004.06 },
}
```

Champs d'une pièce :

| Champ | Signification |
| --- | --- |
| `DCSTypename` | Type name DCS de l'unité au sol spawnée à l'assemblage (le champ `unit` du descripteur de crate) |
| `desc` | Clé i18n utilisée à la fois pour l'entrée de menu du crate et pour les messages de pièce manquante |
| `weight` | Poids du crate ; une pièce **sans** `weight` n'a pas de crate autonome |
| `launcher` | `true` marque la pièce dont le crate déclenche la détection de rearm |
| `amount` | Unités spawnées par système (par défaut 1 ; les launchers utilisent par défaut `aaLaunchers`) |
| `NoCrate` | `true` = pièce toujours présente à l'assemblage, non comptée dans le `mixedSet` auto-généré |
| `cratesRequired` | Crates nécessaires pour cette pièce (lu depuis le descripteur de crate à l'assemblage, par défaut 1) |

`count` est le nombre de **types de pièces uniques** qui doivent être vivants pour que le système
soit considéré comme complet ; il est vérifié par `countComplete()` et `_rearm()`.

## Les crates AA dans `spawnableCrates` { #crate-injection-into-spawnablecrates }

Les crates AA déployables sont des **entrées de catalogue ordinaires** dans `src/CTLD_config.yaml`,
sous les sections `SAM mid range` et `SAM long range`. Elles ne sont plus générées à l'exécution :
l'ancienne étape `CTLDCrateAssemblyManager.injectAACrates(spawnableCrates)` a été supprimée et son
résultat déplié une fois dans le YAML (comparé au golden de l'ancienne injection). Les crates
transitent donc par les passes normales de `CTLDCrateManager._processSpawnableCrates()`, comme
n'importe quelle autre crate.

Chaque section contient donc, explicitement :

1. une entrée de crate par pièce qui porte un `weight` (les pièces `NoCrate` avec un poids obtiennent
   tout de même une entrée de menu mais ne sont pas comptées dans le set) ;
2. une entrée `mixedSet` **All crates** listant les poids des pièces non-`NoCrate` ;
3. l'entrée du crate de réparation, taguée avec le flag interne `_repairFor = <nom du template>`
   (ce n'est pas un type name DCS).

`CTLDCrateAssemblyManager.TEMPLATES` porte toujours les **règles d'assemblage** dont le runtime a
besoin — pièces, count, launcher — déclarées statiquement dans `CTLD_aasystem.lua`. Une section peut
contenir à la fois des entrées AA et des entrées de crate ordinaires ; ce qui change, c'est
seulement que plus rien n'injecte les entrées AA à votre insu.

## Assemblage, rearm et réparation { #assembly-rearm-and-repair }

Le contrôleur de menu M7 appelle le point d'entrée unique avant de retomber sur un unpack
standard :

```lua
local aam     = CTLDCrateAssemblyManager.getInstance()
local handled = aam:tryUnpackOrRepair(heli, crate, allCrates, radius)
-- if handled == false, the caller performs the standard unpack.
```

`tryUnpackOrRepair` résout le template à partir du descripteur du crate le plus proche
(`getTemplateForUnit(unit, _repairFor)`). Si le crate n'appartient à aucun template, elle renvoie
`false`. Sinon, elle aiguille :

- `_repairFor` défini → `_repair()` ;
- sinon → `_assemble()`.

**`_assemble`** tente d'abord la voie rearm lorsque le crate le plus proche est le launcher du
template (`_getLauncherUnit`) et qu'un système complet de ce template existe à moins de
`_REARM_DIST` (300 m). Sinon, elle collecte tous les crates au sol dont le type appartient au
template et qui se trouvent dans le rayon d'assemblage (`radius`, par défaut `_ASSEMBLY_DIST` =
500 m) de l'origine de référence, vérifie la complétude par pièce (`found >= required`) et — si la
limite de systèmes de la coalition l'autorise — détruit les crates consommés et spawn le groupe.
Les pièces manquantes produisent un message `Cannot build …` par groupe, listant chaque manque.

Lorsque `AASystemCrateStacking` est activé, les crates de launcher excédentaires multiplient le
nombre de launchers spawnés (`amountFactor = found - found % required`) ; les crates restants en
dessous d'un multiple complet sont conservés.

**`_rearm`** capture les positions, types et caps actuels du système complet existant, le détruit,
le respawn entièrement rearm dans la même disposition, puis détruit le crate de launcher.

**`_repair`** utilise les `details` persistés (positions/types/caps capturés au spawn) pour
respawner sur place un système endommagé, puis détruit le crate de réparation. Si aucun système
endommagé du template ne se trouve à moins de `_REARM_DIST`, elle signale `Cannot repair …`.

## Géométrie de spawn { #spawn-geometry }

Toutes les pièces sont placées relativement au **transport de déballage**, et non par rapport aux
positions dispersées des crates (même schéma que `CTLD_fob.lua`). `_computeOrigin(transport)`
renvoie un point de référence à 100 m à 12 heures du transport ; `_buildSpawnArrays()` dispose
ensuite les pièces sur un cercle de rayon `_SPAWN_RADIUS` (50 m) autour de cette origine, donnant à
chaque pièce du template un segment d'arc égal afin que les unités ne s'empilent pas. `_spawnGroup()`
construit un groupe `Group.Category.GROUND` via `ctld.utils.dynAdd` (en utilisant la convention
dynAdd `y == world Z`) et renvoie le `Group` DCS résultant.

## Limites de systèmes { #system-limits }

`countComplete(coalitionId)` compte les systèmes vivants dans `_completeSystems` qui contiennent
encore au moins `template.count` types de pièces uniques vivants. `getAllowedCount(coalitionId)`
renvoie le plafond par coalition défini dans la config :

| Clé de config | Rôle | Défaut |
| --- | --- | --- |
| `aaLaunchers` | launchers spawnés lorsqu'une pièce launcher n'a pas d'`amount` explicite | 3 |
| `AASystemLimitBLUE` | nombre max de systèmes complets pour BLUE | 20 |
| `AASystemLimitRED` | nombre max de systèmes complets pour RED | 20 |
| `AASystemCrateStacking` | les crates de launcher excédentaires ajoutent des launchers supplémentaires | `false` |

L'assemblage est refusé avec un message de rupture de pièces lorsque `active + 1 > allowed`.

## Livraison par zone IA (`isAASystem`) { #ai-zone-delivery-isaasystem }

Les transports IA peuvent livrer un système entier sans assemblage de crates. Un dropoff résout
le type livré via `CTLDZoneManager` (`getTypeAt`), qui tague les templates AA avec
`isAASystem = true` lorsque `getTemplateByName(typeName)` correspond ; un mission maker le demande
via le `vehicleStock` d'une zone :

```lua
vehicleStock = { ["HAWK AA System"] = 1 }
```

Dans `CTLDCoreManager:onAILand`, lorsque l'entrée sélectionnée porte `isAASystem`, la branche de
dropoff appelle :

```lua
CTLDCrateAssemblyManager.getInstance():spawnSystemAt(vEntry.type, pt, coa, u:getCountry())
```

`spawnSystemAt(templateName, point, coa, countryId)` résout le template par son display name,
applique la même limite de coalition, construit la disposition en cercle autour de `point`, spawn
le groupe, l'enregistre dans `_completeSystems` et publie `OnAASystemDeployed`.

## Événements { #events }

Le manager publie sur le [bus d'événements](../events.md) via
`EventDispatcher.getInstance():publish(...)` :

| Événement | Quand |
| --- | --- |
| `OnAASystemDeployed` | un système complet est assemblé (assemblage de crates ou livraison IA) |
| `OnAASystemRearmed` | des launchers sont ajoutés à un système complet existant |
| `OnAASystemRepaired` | un système endommagé est respawné sur place |

Chaque payload porte `systemName`, `groupName`, `coalition`, `timestamp` et (sauf pour le
déploiement IA) l'unité `heli` ; les payloads de déploiement incluent également `position`.

## Voir aussi { #related }

- [Crates](crates.md) — spawn/chargement/déchargement des crates et le menu unpack M7 qui pilote l'assemblage
- [Architecture](../architecture.md) — l'idiome manager/singleton et la séquence d'init
- [Événements](../events.md) — le bus d'événements et le catalogue complet
