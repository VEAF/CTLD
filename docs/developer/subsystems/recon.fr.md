# Système de reconnaissance (recon) { #recon-system }

Le système de recon permet aux joueurs de révéler les unités **ennemies** qu'une unité alliée peut
réellement voir. Sa portée est délibérément restreinte : RECON n'affiche que les moyens ennemis
détectés par ligne de visée (LOS) depuis une unité alliée. Il ne doit jamais servir à montrer des
moyens amis (FOB, zones, beacons) — ceux-ci relèvent des menus de leurs propres managers.

Le code source se trouve dans `src/CTLD_recon.lua`, qui définit deux collaborateurs :

- `CTLDReconRenderer` — une **table statique** (sans instance) qui dessine les icônes sur la carte
  F10.
- `CTLDReconManager` — le **singleton** du domaine (`CTLDReconManager = class()`, obtenu via
  `CTLDReconManager.getInstance()`) qui détient l'état par joueur, le pipeline de scan et le
  sous-menu F10 RECON.

Voir [Architecture](../architecture.md) pour l'idiome manager/singleton et
[Événements](../events.md) pour les événements listés ci-dessous.

## Pipeline scan → mark

Une session de recon pour un joueur exécute la boucle suivante :

1. Le joueur active un ou plusieurs **layers** depuis le sous-menu RECON (tous les layers démarrent
   désactivés).
2. Le joueur lance RECON. `scan()` exécute une vérification LOS via `ctld.utils.getUnitsLOS()` et
   dessine une icône Draw-API par cible détectée, mise en forme selon le layer de la cible.
3. Le rafraîchissement automatique est toujours activé au démarrage. Toutes les
   `reconRefreshInterval` secondes, un tick de rafraîchissement re-scanne et réconcilie les cibles
   nouvelles / déplacées / perdues.
4. Arrêter RECON supprime toutes les marks et annule le timer.

### `scan(playerUnit, player)` — démarrage / re-scan

`scan()` est l'action F10 « RECON [Start] » et il est aussi appelé en interne lors du toggle d'un
layer pendant qu'un scan est actif (un re-scan avec l'ensemble de layers mis à jour). Il :

- Se conditionne à `ctld.gs("reconF10Menu")` — la même clé que la section de menu. Si RECON est
  visible, le scan fonctionne sans configuration supplémentaire.
- Impose une altitude AGL minimale de `ctld.gs("reconMinAltitude")` (valeur de repli `50` m),
  calculée à partir de `land.getHeight()` sous l'unité.
- Annule tout scan précédent (supprime son timer et ses marks) avant de reconstruire.
- Appelle `_scanLOS()` avec la liste **complète** des layers du joueur (pas seulement ceux activés),
  afin que `_matchLayer()` puisse appliquer correctement la priorité des layers (voir ci-dessous),
  puis crée les icônes pour les cibles retournées et les compte par layer.
- Enregistre la session dans `self._activeScans[player]`.
- Synchronise les marks FARP/FOB via `_syncFarpMarks()`.
- Publie `OnReconScan`, puis appelle `enableAutoRefresh(..., true)` et reconstruit la branche RECON.

RECON démarre même quand aucun layer n'est activé : le joueur peut activer des layers depuis le menu
ensuite, sans redémarrer. Lors d'un démarrage à neuf sans layer, un message d'information est
affiché ; lors d'un re-scan par toggle de layer, il est supprimé.

### `_scanLOS(playerUnit, enabledLayers, searchRadius)` — cœur LOS

`_scanLOS()` construit la liste des noms d'unités ennemies (`_getEnemyUnitNames()` couvre `GROUND`,
`AIRPLANE`, `HELICOPTER`, `SHIP` pour la coalition adverse), puis appelle
`ctld.utils.getUnitsLOS()` avec un `altoffset` de `180` (identique au legacy). Pour chaque unité
visible, il résout le meilleur layer via `_matchLayer()` et, si ce layer est activé, produit un
enregistrement de cible portant `unit`, `unitName`, `unitType`, `coalition`, `playerCoalition`,
`position`, `distance` et `layer`.

### Rafraîchissement automatique : `_doRefresh(playerName, unitName, _t)`

Le callback du timer réexécute `_scanLOS()`, indexe les cibles précédentes par `unitName`, et
classifie les cibles courantes :

- **new** — aucune entrée précédente : alloue une mark, dessine l'icône, tague `status = "new"`.
- **moved** — même unité déplacée de plus de `5` m : supprime l'ancienne icône, alloue un **nouvel**
  identifiant de mark, redessine, tague `status = "moved"`. Les identifiants de mark DCS ne sont
  jamais réutilisés, donc une cible déplacée reçoit toujours un nouvel identifiant.
- **existing** — déplacement ≤ `5` m : reporte le `markId` précédent inchangé.
- **lost** — restant dans l'index précédent : supprime l'icône ; la raison est `"dead"` si l'unité
  n'existe plus, sinon `"out_of_los"`.

Le tick met à jour `scan.targets`, re-synchronise les marks FARP/FOB, se re-planifie lui-même, et
publie `OnReconScanRefresh` avec le détail complet new/moved/lost.

### Arrêt et toggle

- `stopScan()` (F10 « RECON [Stop] ») annule le timer, supprime toutes les marks de cibles et les
  marks FARP/FOB, efface `_activeScans[player]`, et publie `OnReconHideTargets`. Les états
  activé/désactivé des layers sont **préservés** pour le prochain démarrage.
- `enableAutoRefresh()` / `disableAutoRefresh()` activent/désactivent le timer de rafraîchissement et
  publient `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled`. Désactiver fige les marks
  courantes sur place.
- `toggleLayer()` bascule le flag `enabled` d'un layer, l'indique au joueur, et — si un scan est
  actif — re-scanne immédiatement pour que le nouvel ensemble de layers prenne effet. Il publie
  `OnReconLayerToggled`.

## Layers

Les layers sont définis une seule fois dans `CTLDReconManager._defaultLayers` et **copiés par
joueur** par `_getPlayerLayers()` (initialisé paresseusement), de sorte que chaque joueur porte un
état activé/désactivé indépendant. Chaque objet layer possède un `layerId`, un `name` d'affichage,
un flag `enabled`, une `color`, un `filterAttrib` (un nom d'attribut d'unité DCS) et une clé
`iconRenderer`.

| `layerId` | Nom | `filterAttrib` | `iconRenderer` |
| --- | --- | --- | --- |
| `infantry` | Infantry | `Infantry` | `infantry` |
| `air_defense` | Air Defense (AA) | `Air Defence` | `aa` |
| `ground_vehicles` | Ground Vehicles | `Vehicles` | `vehicle` |
| `helicopters` | Helicopters | `Helicopters` | `helicopter` |
| `aircraft` | Aircraft | `Planes` | `aircraft` |
| `ships` | Ships | `Ships` | `ship` |
| `farp_fob` | FARP / FOB | `nil` | `farp` |

**L'ordre des layers est significatif.** `_matchLayer()` parcourt la liste ordonnée complète et
retourne le premier layer dont l'unité possède le `filterAttrib`. Les attributs plus spécifiques
doivent précéder les plus généraux : `Air Defence ⊂ Vehicles`, donc `air_defense` vient avant
`ground_vehicles` ; `Helicopters ⊂ Planes`, donc `helicopters` vient avant `aircraft`. Point
crucial, `_matchLayer()` s'exécute contre la liste complète même lors d'un scan, puis ne retourne le
layer trouvé que s'il est actuellement activé — cela empêche une unité de « retomber » vers un layer
de priorité inférieure lorsque son layer de meilleure correspondance est désactivé (un hélicoptère
ne doit pas apparaître comme Aircraft quand le layer Helicopters est désactivé ; un ZU-23 ne doit pas
apparaître comme Vehicle quand AA est désactivé).

Le layer `farp_fob` a `filterAttrib = nil` à dessein : `_matchLayer()` ignore les layers sans
`filterAttrib`, car la détection FARP/FOB utilise un pipeline dédié plutôt qu'une correspondance par
attribut d'unité.

## Cycle de vie du layer FARP/FOB

Les marks FARP/FOB ne suivent pas le cycle de vie des enregistrements de cible. Elles sont gérées par
`_syncFarpMarks()` et suivies dans `self._farpMarks[player]` (indexé par object id → mark id). La
détection puise dans deux sources, chacune conditionnée par `reconSearchRadius` (valeur de repli
`5000` m) et une vérification LOS `land.isVisible()` à +180 m :

- **Source A** — `coalition.getAirbases()` pour le camp ennemi, filtré aux objets dont
  `getDesc().attributes.Helipad` est défini.
- **Source B** — les FOB ennemis issus de `CTLDFOBManager` (`_fobs` correspondant à la coalition
  ennemie et vivants).

Les nouvelles détections dessinent une icône, enregistrent un `CTLDStaticWatcher` sous la clé
`"recon_farp_<player>_<id>"`, et publient `ReconFarpDetected`. Quand l'objet surveillé meurt, le
watcher supprime l'icône, efface l'entrée, et publie `ReconFarpLost`. Les marks sont
**persistantes** : un objet déjà marqué est ignoré lors des syncs suivants (pas de scintillement),
et les marks survivent jusqu'à la mort de l'objet ou l'effacement du layer/scan. `_clearFarpMarks()`
supprime toutes les marks FARP/FOB d'un joueur et annule ses watchers.

## Rendu des icônes

`CTLDReconRenderer.createIcon(target, markId)` dispatche sur `target.layer.iconRenderer` vers la
fonction de dessin correspondante (`drawInfantryIcon`, `drawVehicleIcon`, `drawAAIcon`,
`drawAircraftIcon`, `drawHelicopterIcon`, `drawShipIcon`, `drawFarpIcon`), avec un repli sur un simple
cercle pour une clé inconnue. Chaque cible consomme jusqu'à trois éléments Draw-API aux identifiants
`markId*10+1 .. markId*10+3` ; `removeIcon(markId)` supprime les trois.

La **forme** de l'icône encode le type de layer, et la **couleur** de l'icône encode la coalition de
l'unité détectée (RED → rouge, BLUE → bleu, NEUTRAL → gris), de sorte que les deux dimensions
n'entrent jamais en collision. La taille de l'icône est mise à l'échelle avec
`ctld.gs("reconIconScale")` (valeur de repli `1.0`). Les marks ne sont dessinées que pour la
coalition du joueur, et tous les identifiants de mark proviennent du compteur monotone applicatif
global `ctld.utils.getNextMarkId()` via `_nextMark()`.

## Menu F10

`CTLDReconManager` enregistre une section de menu lors de l'`init()` via
`CTLDPlayerManager.getInstance():registerMenuSection({ key = "recon", ..., configKey =
"reconF10Menu", order = 70 })`, conditionnée à `reconF10Menu`. `buildMenuSection()` ajoute le
sous-menu `RECON` sous `CTLD` et délègue à `_addReconCommands()`, qui met en place :

- un unique toggle **RECON [Start]** / **RECON [Stop]** reflétant l'état du scan actif ;
- une commande par layer, dont le libellé indique la **prochaine action** — `[activate]` quand le
  layer est désactivé, `[deactivate]` quand il est activé. Un suffixe ` (X)` est ajouté tant que
  RECON est au repos (aucun scan actif).

Après tout changement d'état (démarrage, arrêt, toggle de layer), `_rebuildReconBranch()` efface la
branche RECON et ré-ajoute les commandes avec des libellés à jour, puis rafraîchit le menu.

## API de requête

- `getActiveScan(player)` — l'état du scan courant (`playerUnit`, `coalition`, `targets`, `layers`,
  `autoRefresh`, `refreshTimer`) ou `nil`.
- `getPlayerLayers(player)` — le tableau de layers du joueur (initialisé paresseusement).

## Événements émis

| Événement | Quand |
| --- | --- |
| `OnReconScan` | Un scan démarre (ou re-scanne) |
| `OnReconScanRefresh` | Un tick de rafraîchissement automatique se termine |
| `OnReconHideTargets` | RECON est arrêté |
| `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled` | Rafraîchissement automatique basculé |
| `OnReconLayerToggled` | Un layer est activé/désactivé |
| `ReconFarpDetected` / `ReconFarpLost` | Une mark FARP/FOB est ajoutée / son objet meurt |

## Clés de configuration

| Clé | Valeur de repli | Rôle |
| --- | --- | --- |
| `reconF10Menu` | — | Condition d'accès au sous-menu RECON et à `scan()` |
| `reconSearchRadius` | `5000` | Rayon de scan LOS (m) |
| `reconMinAltitude` | `50` | AGL minimale pour scanner (m) |
| `reconRefreshInterval` | `10` | Période de rafraîchissement automatique (s) |
| `reconIconScale` | `1.0` | Multiplicateur de taille d'icône |

Toute la configuration est en lecture seule via `ctld.gs("...")` — jamais `config:getSetting()`.
