# Système de balises (beacons) { #beacon-system }

**Source :** `src/CTLD_beacon.lua` · **Singleton :** `CTLDBeaconManager` · **Entité :** `CTLDBeacon`

Le système de beacons permet à un équipage de transport de larguer un beacon de navigation à sa
position courante (ou à un mission maker d'en placer un sur une trigger zone). Chaque beacon est un
**triple émetteur radio** — un groupe DCS par bande (VHF, UHF, FM) — qui diffuse une tonalité de
ralliement audible pour la navigation ADF/radiocompas. Les beacons fonctionnent sur batterie, sont
rafraîchis selon une cadence fixe et peuvent être dessinés sur la carte F10 sous forme de calque
activable/désactivable par joueur.

Il n'existe **aucun « type de beacon » distinct** (pas de chemin TACAN ou de beacon IR séparé dans
le code actuel) : chaque beacon est le même montage à trois groupes `TACAN_beacon` décrit ci-dessous.

## Les deux classes { #the-two-classes }

`CTLD_beacon.lua` définit une entité et un manager, suivant l'idiome de classe décrit dans
[Architecture](../architecture.md) :

```lua
CTLDBeacon = class()                 -- one deployed beacon (three DCS groups)
CTLDBeaconManager = class()          -- singleton owning all beacons + frequency pools
CTLDBeaconManager._instance = nil
CTLDBeaconManager.getInstance()      -- factory, builds freq pools on first access
```

`CTLDBeaconManager:init()` construit les pools de fréquences, planifie la boucle de rafraîchissement
(uniquement si `ctld.gs("enabledRadioBeaconDrop")` est vrai) et enregistre sa section de menu F10
auprès de `CTLDPlayerManager` sous la clé `"beacons"` à `order = 60`.

### Champs de `CTLDBeacon` { #ctldbeacon-fields }

Une instance de beacon porte les trois noms de groupes, les trois fréquences assignées (en Hz) et
son état de batterie/cycle de vie :

| Champ | Signification |
| --- | --- |
| `beaconName` | Clé unique — égale à `vhfGroupName` |
| `name` | Nom d'affichage, p. ex. `"Beacon #3"` |
| `coalitionId` | Coalition propriétaire |
| `position` | Position monde `{x, y, z}` |
| `vhfGroupName` / `uhfGroupName` / `fmGroupName` | Les trois noms de groupes DCS |
| `vhf` / `uhf` / `fm` | Fréquences assignées en Hz |
| `batteryEndTime` | Échéance `timer.getTime()`, ou `-1` pour infinie |
| `spawnTime` | `timer.getAbsTime()` au largage |
| `isFOB` | Les beacons FOB sont infinis (`batteryEndTime == -1`) |

Méthodes utilitaires : `isBatteryAlive()`, `countAliveUnits()` (0–3), `batteryRemaining()`
(`math.huge` lorsqu'infinie), `freqText()` (`"245.00 kHz - 350.50 / 45.20 MHz"`) et
`mgrsCoords()`.

## Transmission radio { #radio-transmission }

Chacun des trois groupes est une unité DCS `TACAN_beacon` unique spawnée via `ctld.utils.dynAdd`.
`_startTransmissions()` fixe la ROE de chaque groupe à `WEAPON_HOLD` et appelle
`trigger.action.radioTransmission` avec des réglages propres à la bande :

| Bande | Mode | Son |
| --- | --- | --- |
| VHF | `0` (AM) | `ctld.gs("radioSound")` (défaut `beacon.ogg`) |
| UHF | `0` (AM) | `ctld.gs("radioSoundFC3")` (défaut `beaconsilent.ogg`) — silencieux pour les appareils FC3 |
| FM | `1` (FM) | `ctld.gs("radioSound")` |

Les transmissions démarrent **1 seconde après le spawn** via `timer.scheduleFunction` : DCS laisse
les unités d'un groupe fraîchement ajouté non initialisées pendant environ une seconde, donc appeler
`radioTransmission` immédiatement diffuserait depuis une position périmée ou nulle.

## Pools de fréquences { #frequency-pools }

Trois paires de pools libre/utilisé sont construites une fois dans `_buildFreqPools()` :

| Pool | Plage | Pas |
| --- | --- | --- |
| VHF | 200–840 kHz, puis 850–1250 kHz | 10 kHz en dessous de 850, 50 kHz au-dessus |
| UHF | 220 MHz jusqu'à (non inclus) 399 MHz | 0,5 MHz |
| FM | bande 30–76 MHz | `(100*f + 10*s + t) * 100 kHz` pour `f=3..7`, `s=0..5`, `t=0..9` |

Les fréquences sont stockées en Hz. Le pool VHF saute un ensemble codé en dur de fréquences NDB
réelles (`CTLDBeaconManager._ndbSkip`) qui existent déjà sur les cartes DCS, pour éviter les
interférences.

`_assignFrequencies(granted)` tire une fréquence par bande avec `_pickFreq(free, used)`, qui choisit
une entrée aléatoire et la confie à `_takeFreq(free, used, index)` — le seul endroit où une fréquence
quitte le pool libre. Lorsqu'un pool tombe à **3 entrées libres ou moins**, il recycle l'intégralité
du pool utilisé vers le pool libre avant de tirer. `_freeFrequencies(beacon)` rend les trois
fréquences à leurs pools libres lorsqu'un beacon est retiré ou détruit.

Un appelant peut demander une fréquence précise au lieu de subir le tirage, via `opts.frequencies` sur
`createAtPoint` (voir
[Demander des fréquences précises](../api-reference.md#beacon-requested-frequencies) pour l'API).
`CTLDBeaconManager._bands` énonce pour chaque bande sa clé d'option, son unité, son multiplicateur
vers les Hz et sa plage, et `_resolveFreqRequest(request)` valide toute la demande contre les pools
**sans les modifier**, en retournant les demandes accordées sous la forme
`{ [bande] = { freq = Hz, index } }` ou `nil, raison`. Ainsi un refus sur la troisième bande ne peut
pas laisser les deux premières consommées, et un appel refusé ne fait rien spawner.

La règle : une demande n'est accordée que si la fréquence est actuellement **libre dans le pool de sa
bande** ; tout le reste fait échouer l'appel entier au lieu de substituer un tirage aléatoire. Deux
raisons, une de chaque nature. Côté comportement, un beacon qui répond ailleurs que sur la fréquence
annoncée est invisible pour le mission maker et inaudible pour le pilote qui a affiché la fréquence
annoncée — un refus est au moins quelque chose auquel l'appelant peut réagir. Côté mécanique, le pool
*est* la comptabilité : `_freeFrequencies` remet inconditionnellement les trois fréquences d'un beacon
dans les pools libres, donc une fréquence accordée hors du pool y serait *ajoutée* au retrait puis
tirée au hasard plus tard, et une fréquence accordée deux fois serait libérée alors que le second
beacon émet encore dessus.

## Cycle de vie { #lifecycle }

```
dropped   → 3 TACAN_beacon groups spawned, transmissions start after 1s
active    → _refreshAll() runs every beaconRefreshInterval seconds
destroyed → battery depleted OR fewer than 3 units alive → cleanup + free frequencies
removed   → manual removal by a player within 500m
```

**Chemins de création.** Les trois passent par **`createAtPoint(point, coalitionId, countryId, opts)`**,
qui porte le spawn, l'attribution des fréquences, la batterie et les couches de carte — et rien de ce
qui s'adresse à un pilote. `opts` transporte `name`, `batteryMinutes` (`-1` = n'expire jamais),
`isFOB` et `frequencies` (voir [Pools de fréquences](#frequency-pools)). Il retourne le `CTLDBeacon`,
dont les champs `vhf` / `uhf` / `fm` sont ce qu'un script relit — ou `nil` et une chaîne de raison si
la demande de fréquence est refusée ou si le spawn échoue. Sur ce chemin d'échec de spawn, les trois
fréquences déjà tirées sont rendues à leurs pools, pour qu'un appelant qui retente la même demande ne
s'entende pas dire que sa propre fréquence est prise par un beacon qui n'existe pas.

- `dropBeacon(transport, player, isFOB, overridePosition)` — le chemin de transport : lorsque
  l'appareil est au sol, il décale le point de spawn derrière l'appareil (cap + π, en utilisant la
  largeur de la bounding-box plus 5 m, avec repli sur 20 m) afin que l'unité au sol ne soit pas
  spawnée à l'intérieur de la boîte de collision de l'appareil ; en vol, il spawne à la position de
  l'appareil. Il annonce ensuite à la coalition et publie `OnBeaconDropped`.
- `createAtZone(zoneName, coalitionStr, batteryLife, name)` — le chemin mission-maker : il résout
  une trigger zone DCS, mappe `"red"`/`"blue"` vers une coalition et un pays (`RUSSIA`/`USA`), et
  annonce / publie comme un largage par `"MissionMaker"`.
- `createAtPoint` lui-même — le chemin scripté, pour un appelant qui n'est **pas un pilote dans un
  cockpit** : un script qui construit une FARP ou une FOB n'a ni transport ni joueur. Il est
  silencieux par conception (aucun message de coalition, aucun `OnBeaconDropped` — le champ `player`
  de cette charge utile n'aurait aucun sens), et il ne respecte **pas** `enabledRadioBeaconDrop`, qui
  ne gouverne que l'action F10 du pilote. La boucle de rafraîchissement, normalement démarrée par
  `init()` quand ce réglage est actif, est démarrée à la demande ici pour qu'un beacon scripté
  émette et expire quand même.

**Retrait manuel.** `removeClosestBeacon(transport, player)` trouve le beacon de même coalition le
plus proche dans un rayon de `BEACON_REMOVAL_RADIUS` (500 m) ; si aucun n'est à portée, il rapporte
`"No Radio Beacons within 500m."`. **`removeBeacon(name)`** en est le pendant scripté — nom affiché
ou clé interne, sans distance ni message — et retourne `true` quand il en a retiré un.

**Listage.** `listBeacons(transport)` affiche les beacons actifs de la coalition (nom + `freqText()`)
au groupe demandeur.

### Batterie et rafraîchissement { #battery-and-refresh }

L'autonomie de la batterie est en **minutes**, lue depuis `ctld.gs("deployedBeaconBattery")`
(défaut `30`). Au largage, le `batteryEndTime` d'un beacon normal est fixé à
`timer.getTime() + minutes * 60` ; les beacons FOB (`isFOB = true`) reçoivent `-1`, ce qui signifie
infini.

La boucle de rafraîchissement, planifiée par `_scheduleRefresh()`, exécute `_refreshAll()` toutes les
`ctld.gs("beaconRefreshInterval")` secondes (défaut `60`). Pour chaque beacon, elle vérifie
`countAliveUnits() == 3` **et** `isBatteryAlive()` :

- Les deux vrais → réexécution de `_startTransmissions()` (maintient la tonalité en vie à travers
  les timeouts de transmission de DCS).
- Sinon → détruire les groupes du beacon, libérer ses fréquences, le retirer des calques de carte,
  le supprimer de `_beacons`, et publier `OnBeaconDestroyed` avec `reason` = `"battery_depleted"` ou
  `"unit_destroyed"`.

La boucle de rafraîchissement utilise une garde de singleton : si `CTLDBeaconManager._instance` n'est
plus l'instance qui l'a planifiée, la fonction planifiée renvoie `nil` et s'arrête, empêchant une
boucle zombie après une réinitialisation. L'id du planificateur est enregistré sous
`"beacon_refresh"` via `ctld.scheduler.register`.

## Calque de dessin sur la carte { #map-draw-layer }

Le calque de dessin est un **toggle par joueur** conditionné par `ctld.gs("beaconLayerEnabled")`.
`toggleLayer(player, transport)` bascule `_layerState[player].enabled` ; lorsqu'il est activé, il
dessine tous les beacons de même coalition, lorsqu'il est désactivé, il retire les marques du joueur.

Chaque icône de beacon est composée de trois primitives dessinées par
`_drawBeaconIcon(beacon, markId)` :

- un cercle extérieur (`beaconIconRadius`, défaut `25` ; `beaconIconColor`, défaut orange
  `{1.0, 0.5, 0.0, 1.0}`),
- un cercle plein intérieur à mi-rayon,
- une étiquette de texte (`beaconName` + coordonnées MGRS, taille `beaconTextSize`, défaut `12`).

### Allocation des Mark ID { #mark-id-allocation }

Les Mark ID proviennent du **compteur monotone applicatif global**, pas d'un schéma local au
beacon :

```lua
ctld.utils.getNextMarkId()   -- ctld._markIdCounter starts at 10000, increments and returns
```

Chaque icône de beacon consomme **un** id de `getNextMarkId()` (encapsulé localement en
`_nextMark()`), puis en dérive ses trois mark ids DCS : `markId*10 + 1` (cercle extérieur),
`markId*10 + 2` (cercle intérieur), `markId*10 + 3` (texte). `_removeMarkId(markId)` appelle
`trigger.action.removeMark` sur les trois. Le même compteur `getNextMarkId()` est partagé avec le
calque recon et `ctld.utils.drawQuad()` (voir [Système recon](recon.md)) ; les ids ne sont jamais
réutilisés.

Lorsque `ctld.gs("beaconAutoRefreshLayer")` est vrai, `_addBeaconToLayers()` pousse un beacon
fraîchement largué dans chaque calque actuellement activé, et `_removeBeaconFromLayers()` retire ses
marques lorsqu'il est retiré ou détruit.

## Événements { #events }

Le manager de beacons publie sur le bus d'événements interne (voir [Événements](../events.md)) :

| Événement | Quand |
| --- | --- |
| `OnBeaconDropped` | Un beacon est largué ou créé sur une zone |
| `OnBeaconRemoved` | Un joueur retire manuellement le beacon le plus proche (`reason = "manual"`) |
| `OnBeaconDestroyed` | Le rafraîchissement détecte la batterie épuisée ou moins de 3 unités en vie |
| `OnBeaconRefreshed` | Un tick de rafraîchissement a touché au moins un beacon (les ticks sans effet sont silencieux) |
| `OnBeaconLayerToggled` | Un joueur bascule le calque de carte |

## Menu F10 { #f10-menu }

`buildMenuSection(playerObj, menu)` construit le sous-menu **Radio Beacons** (order 60) sous la racine
CTLD. Il retourne immédiatement sauf si `playerObj.isTransport`, et toute la section est conditionnée
par la clé de config `enabledRadioBeaconDrop` (le `configKey` passé à `registerMenuSection`).
Commandes :

- **Drop Beacon** → `dropBeacon(transport, nil, false)`
- **Remove Closest Beacon** → `removeClosestBeacon(transport, nil)`
- **List Beacons** → `listBeacons(transport)`

## API de requête { #query-api }

| Méthode | Renvoie |
| --- | --- |
| `getBeaconsForCoalition(coalitionId)` | Tableau de `CTLDBeacon` pour la coalition |
| `getBeacon(beaconName)` | Le `CTLDBeacon` pour un nom, ou `nil` |
