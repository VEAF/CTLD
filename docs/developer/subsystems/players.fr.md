# Suivi des joueurs { #player-tracking }

CTLD suit les joueurs humains connectés **sans MIST**, dans un singleton unique :

| Singleton | Source | Responsabilité |
| --- | --- | --- |
| `CTLDPlayerManager` | `src/CTLD_player.lua` | État par joueur (entités `CTLDPlayer`), menu F10, suivi du cargo |

Il suit l'idiome `X = class()` + `getInstance()` décrit dans
[Architecture](../architecture.md) et consomme les événements de slot DCS via l'unique
gestionnaire `CTLDDCSEventBridge` plutôt qu'en s'enregistrant directement auprès de `world`.

## `CTLDPlayer` — entité par joueur { #ctldplayer-per-player-entity }

`CTLDPlayer = class()` est un instantané d'identité assorti d'un état de cargo mutable, construit
par `CTLDPlayerManager` lorsqu'un humain entre dans un slot. Ses champs, renseignés dans
`CTLDPlayer:init(data)` :

```lua
{
    unitName         = "UH-1H-1",   -- DCS unit name (the map key in CTLDPlayerManager)
    groupId          = 9901,        -- group:getID()  (used for F10 menu ops)
    groupName        = "Grp_1",     -- group:getName()
    coalition        = 2,           -- coalition.side.BLUE
    typeName         = "UH-1H",     -- unit:getTypeName()
    isTransport      = true,        -- detected capability (see below)
    canCarryVehicles = false,       -- detected capability (see below)
    loadedTroops     = {},          -- list
    loadedCrates     = {},          -- list of CTLDCrate
    loadedVehicles   = {},          -- list of CTLDVehicle
}
```

Les listes de cargo sont modifiées par des helpers de l'entité fonctionnant par correspondance
d'identité :

- `addLoadedCrate(crate)` / `removeLoadedCrate(crate)`
- `addLoadedVehicle(vehicle)` / `removeLoadedVehicle(vehicle)`

`loadedTroops` est initialisé mais non maintenu par ces helpers — les troops en transit sont gérés
par `CTLDTroopManager` et interrogés via `getInTransit(unitName)` (voir la commande « Check Cargo »
ci-dessous).

### Détection des capacités { #capability-detection }

`CTLDPlayerManager:_detectCapabilities(unit)` dérive les deux drapeaux de capacité de
`ctld.gs("capabilitiesByType")` indexé par `unit:getTypeName()` :

- `isTransport` — `true` lorsque le type possède une entrée dans `capabilitiesByType`.
- `canCarryVehicles` — `true` lorsque cette entrée définit `canTransportWholeVehicle == true`.

## `CTLDPlayerManager` — cycle de vie et propriétaire du menu { #ctldplayermanager-lifecycle-menu-owner }

Le manager tient sa propre map, distincte de l'index d'identité du tracker :

```lua
self._players = {}   -- unitName → CTLDPlayer
```

### Cycle de vie { #lifecycle }

| Événement DCS | Gestionnaire | Action |
| --- | --- | --- |
| `S_EVENT_PLAYER_ENTER_UNIT` | `onPlayerEnterUnit(event)` | Ignore l'IA (pas de `getPlayerName()`), applique le filtre de nom de pilote, construit un `CTLDPlayer`, le stocke, appelle `buildMenu(playerObj)` |
| `S_EVENT_BIRTH` | `onBirth(event)` | Filet de sécurité — enregistre un humain que CTLD ne connaît pas encore, en déléguant à `onPlayerEnterUnit`. Sort immédiatement pour une unité IA ou un joueur déjà suivi |
| `S_EVENT_PLAYER_LEAVE_UNIT` | `onPlayerLeaveUnit(event)` | Retire les entrées de menu DCS du joueur et le supprime de `_players` |
| `S_EVENT_TAKEOFF` | `onTakeoff(event)` | Positionne `_isFlying = true`, rafraîchit les sections de menu dépendantes du vol |
| `S_EVENT_LAND` | `onLand(event)` | Efface `_isFlying`, rafraîchit les sections de menu après un délai de stabilisation de 1 s |

`getPlayer(unitName)` retourne le `CTLDPlayer` suivi, ou `nil`.

`_scanExistingPlayers()` est un filet de sécurité multijoueur : il s'exécute une fois à la fin de
`ctld.initialize()` et se reprogramme toutes les 30 s pendant toute la mission, synthétisant un
`onPlayerEnterUnit` pour tout slot occupé pas encore présent dans `_players` (changements de slot,
prise de contrôle par l'IA, arrivants tardifs) et oubliant les joueurs dont le slot a disparu.

**Filtre de nom de pilote :** lorsque `ctld.gs("addPlayerAircraftByType") == false`, seuls les noms
d'unité listés dans `ctld.gs("transportPilotNames")` peuvent utiliser les fonctions de
**transport**. Tous les autres humains restent suivis et reçoivent un menu CTLD, construit avec
`isTransport = false` et `canCarryVehicles = false` **quel que soit leur type d'appareil** — un type
de transport absent de la liste ne récupère pas les menus de transport par la détection de
capacités, sans quoi le réglage ne voudrait rien dire.

Ce que voit un tel pilote est décidé par les sections elles-mêmes, qui respectent déjà
`isTransport` : reconnaissance, fumigènes, `List Beacons`, `JTAC Status` et `List active FOBs` sont
construites pour lui ; troupes, caisses, véhicules, pose de balises, demandes d'équipement JTAC et
`Check Cargo` ne le sont pas. Avant la 2.0.0-rc11, le filtre sortait avant d'enregistrer le joueur :
il n'avait aucun menu CTLD, donc aucune reconnaissance, alors que n'importe quel pilote est censé
pouvoir s'en servir.

### Sondage de l'état de vol { #flight-state-poller }

Comme `S_EVENT_TAKEOFF` / `S_EVENT_LAND` se déclenchent avec un retard de 3 à 5 s pour les
hélicoptères, `init()` démarre également un sondage `timer.scheduleFunction` toutes les 0,5 s. Il lit
`ctld.utils.inAir(unit)` pour chaque joueur suivi et, une fois qu'un nouvel état se maintient sur deux
ticks consécutifs (`DEBOUNCE_TICKS`, ~1 s), le valide dans `playerObj._isFlying` et exécute la même
chaîne de rafraîchissement de menu. Les gestionnaires `onTakeoff` / `onLand` se déclenchent toujours,
mais à ce moment-là `_isFlying` correspond déjà et le rafraîchissement est un no-op rapide.

### État du cargo via le bus d'événements { #cargo-state-via-the-event-bus }

Le manager s'abonne à `EventDispatcher` (voir [Events](../events.md)) pour maintenir à jour les listes
de cargo de chaque `CTLDPlayer`, puis rafraîchit les menus concernés :

| Événement souscrit | Effet |
| --- | --- |
| `OnVehicleLoaded` | `addLoadedVehicle`, puis `refreshForUnit` |
| `OnVehicleUnloaded` | `removeLoadedVehicle`, puis `refreshForUnit` |
| `OnCrateLoaded` | `addLoadedCrate`, `refreshForUnit`, et rafraîchit la section Unpack du crate |
| `OnFOBDeployed` | Rafraîchit les sections Request Equipment / JTAC pour chaque joueur au sol |

`CTLDPlayerManager` **ne publie aucun événement**.

### Menu F10 { #f10-menu }

`CTLDPlayerManager` est propriétaire du menu F10 de CTLD. Les managers contribuent des sections via
`registerMenuSection(sectionDef)` (idempotent par `key`) ; les fichiers de scène chargés avant que le
singleton n'existe peuvent pré-mettre en file des sections avec `deferMenuSection(sectionDef)`, vidées
pendant `init()`.

`buildMenu(playerObj)` efface et reconstruit le menu de façon atomique via `ctld.MenuManager`. Il
ajoute toujours une commande **Check Cargo** qui totalise la charge courante du transport — crates
(regroupés par descripteur), troops en transit (`CTLDTroopManager:getInTransit`), et véhicules entiers
(`CTLDVehicleSpawner:findLoadedVehicles`, pondérés depuis `ctld.gs("groundVehicleWeights")`, par défaut
2500 kg) — et rapporte une ventilation par type ainsi qu'un total en kilogrammes. Les sections
enregistrées sont ensuite rendues par `order` croissant, chacune conditionnée par son `configKey`
optionnel (`ctld.gs(configKey) == true`).

`refreshForUnit(unitName)` et `refreshAll()` demandent un rafraîchissement de menu différé via
`ctld.MenuManager` pour un ou tous les joueurs suivis. Le poids du cargo est uniquement **affiché** — il
n'y a ni plafond de poids par transport ni rejet de chargement dans ce sous-système.
