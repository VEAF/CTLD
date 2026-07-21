# Champ de mines { #minefield }

CTLD embarque une scene **minefield** intégrée. Lorsqu'elle est déployée, CTLD spawn de
vrais statics de mines terrestres DCS selon un motif en quinconce devant l'unité de
transport et, en option, trace un quadrilatère englobant sur la carte F10 pour montrer
l'étendue du champ.

Cette page explique comment le minefield est mis à disposition dans une mission et comment
régler son comportement. Les actions en cockpit — le unpack de la crate pour poser un champ,
et l'utilisation du menu **Clear Mine Field** pour en retirer un — sont des opérations pilote,
décrites dans le [guide Pilote](../pilot/index.md).

## Mise à disposition { #making-it-available }

Le minefield est une scene auto-enregistrée : dès que `CTLD.lua` est chargé, elle apparaît
automatiquement comme **Mine Field Crate** dans le menu F10 **Request Equipment**, pour les
deux coalitions, en ne demandant qu'une seule crate. Vous n'avez **pas** besoin de la déclarer
dans `spawnableCrates`. Voir le [catalogue des crates](crates-catalogue.md) pour savoir comment
les crates sont listées et demandées de manière générale.

Les pilotes demandent alors la crate, la transportent et l'unpack au sol ; le champ est posé
devant l'aéronef, dans l'axe de son cap. Voir le [guide Pilote](../pilot/index.md).

### Disposition par défaut { #default-layout }

La crate pose toujours le même champ fixe : une grille en quinconce calculée à partir de
5 mines par rangée complète × 15 rangées, commençant 20 m devant l'unité, avec 6 m entre les
mines adjacentes et 12 m entre les rangées. Les rangées impaires portent 5 mines, les rangées
paires en portent 4, décalées latéralement d'une demi-distance de colonne, pour un total de
68 mines :

```text
x    x    x    x    x        <- odd row  (5 mines)
   x    x    x    x          <- even row (4 mines, shifted right)
x    x    x    x    x        <- odd row
   x    x    x    x          <- even row
```

## Configuration

Les réglages sont lus via `ctld.gs("paramName")` à l'exécution ; vous les définissez dans
`CTLD_userConfig.lua` sous `_cfg.settings[...]`.

| Réglage | Défaut | Description |
| --- | --- | --- |
| `showMinefieldOnF10Map` | `true` | Trace un quadrilatère englobant sur la carte F10 lorsqu'un minefield est déployé. Mettre à `false` pour garder le champ caché. |
| `demineRadius` | `150` | Distance maximale en mètres entre un joueur posé et le centre d'un minefield pour que l'entrée **Clear Mine Field** de ce champ apparaisse dans le menu F10. |

```lua
_cfg.settings["showMinefieldOnF10Map"] = true
_cfg.settings["demineRadius"]          = 150
```

## Avancé : poser un minefield depuis un script { #advanced-laying-a-minefield-from-a-script }

Si vous voulez placer des minefields depuis votre propre logique de mission (plutôt qu'en
faisant unpack une crate par un pilote), récupérez le modèle de la scene et appelez l'une de
ses deux fonctions de disposition. Les deux prennent un objet DCS Unit, qui définit l'origine
et le cap du champ, et les deux renvoient un indicateur de succès plus le tableau des static
objects spawnés.

Récupérez le modèle une fois :

```lua
local mineField = CTLDSceneManager.getInstance():getModel("mineField")
```

### `setLandMineAuto` — par surface et nombre { #setlandmineauto-by-area-and-count }

Fournissez les dimensions cibles et un nombre de mines souhaité ; CTLD calcule
automatiquement la meilleure disposition colonnes/rangées.

```lua
local ok, result = mineField.setLandMineAuto(
    transport,   -- DCS Unit object (origin and heading)
    30,          -- distance (m) from the unit to the first mine row
    50,          -- width (m) — lateral extent of the field
    80,          -- length (m) — forward extent of the field
    40           -- desired number of mines
)
-- The actual count may differ slightly from the request due to quinconce rounding.
-- Use #result for the exact number of mines spawned.
```

### `setLandMine` — grille explicite { #setlandmine-explicit-grid }

Pour un contrôle total sur le nombre de colonnes, le nombre de rangées et les deux distances :

```lua
local ok, result = mineField.setLandMine(
    transport,   -- DCS Unit object
    20,          -- distance (m) from the unit to the first mine row
    5,           -- mines per odd (full) row
    15,          -- number of rows
    6,           -- lateral spacing between adjacent mines (m)
    12           -- forward spacing between rows (m)
)
-- Quinconce total: 8 odd rows x 5 + 7 even rows x 4 = 68 mines
```

### Cas limites de disposition { #layout-edge-cases }

| Condition | Comportement |
| --- | --- |
| 1 mine au total | Une seule mine avec un petit marqueur carré sur la F10. |
| 1 mine par rangée | Une colonne rectiligne vers l'avant, sans décalage. |
| 2 mines ou plus par rangée | Disposition en quinconce (décalée) complète. |
