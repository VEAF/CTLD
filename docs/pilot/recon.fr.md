# Reconnaissance (recon) { #recon }

Le recon transforme votre aéronef en capteur : survolez le terrain hostile, lancez un scan,
et chaque unité ennemie que votre ligne de visée atteint est dessinée sur la carte F10 —
façonnée par catégorie, colorée par camp. C'est un outil de **révélation et de marquage**
réservé aux contacts ennemis. Les actifs amis (FOB que vous possédez, zones logistiques,
[beacons](beacons.md) radio) ne sont jamais affichés ici ; ils vivent dans leurs propres
menus.

## Ce que le recon vous permet de faire

Vous choisissez quelles catégories de contact vous intéressent (infanterie, véhicules,
défense antiaérienne, avions, hélicoptères, navires, FARP/FOB ennemis), vous lancez un scan,
et CTLD peint des icônes sur la carte F10 pour tout ce qui se trouve actuellement dans votre
ligne de visée. Tant que le scan tourne, il se rafraîchit automatiquement sur une minuterie,
si bien que les contacts apparaissent, se déplacent et disparaissent de la carte à mesure que
la situation évolue. Les marques n'appartiennent qu'à vous — elles ne sont dessinées que pour
votre coalition.

## Comment ça marche

- **Ligne de visée.** Un scan ne révèle que les unités ennemies que votre aéronef peut
  réellement voir. Le relief, l'horizon et le rayon de scan limitent tous ce qui remonte —
  volez plus haut ou plus près pour voir davantage.
- **Altitude minimale.** Vous devez être au-dessus de l'altitude AGL minimale configurée pour
  scanner. Trop bas et CTLD refuse avec un message.
- **Rafraîchissement automatique.** Lancer un scan arme aussi une minuterie de
  rafraîchissement automatique. À chaque tick, CTLD re-scanne et met à jour la carte : les
  nouveaux contacts reçoivent une icône, les contacts qui ont bougé sont redessinés à leur
  nouvelle position, les contacts détruits ou sortis du champ de vision sont retirés.
- **Les layers pilotent l'image.** Seules les catégories dont le layer est actif produisent
  des marques. Vous pouvez basculer les layers avant ou pendant un scan ; basculer pendant un
  scan en cours relance un scan immédiatement, si bien que désactiver un layer efface ses
  marques aussitôt.

## Activation

Le menu Recon se trouve dans **F10 → CTLD → RECON**. Si vous ne le voyez pas, le recon n'est
pas activé pour la mission — c'est un réglage du mission-maker (voir le
[guide Mission Maker](../mission-maker/index.md)).

### RECON [Start] / RECON [Stop]

**Utilité :** un simple bascule. **RECON [Start]** lance immédiatement un scan de ligne de
visée autour de votre aéronef, marque chaque ennemi détecté dans vos layers actifs, et arme
le rafraîchissement automatique. Une fois lancé, la même entrée devient **RECON [Stop]**, qui
arrête le rafraîchissement et efface toutes vos marques de recon de la carte.

**Prérequis :** vous devez être à l'altitude AGL minimale ou au-dessus. Vous pouvez lancer un
scan sans aucun layer actif — CTLD vous invite à activer des layers pour voir des cibles —
puis activer des layers sans redémarrer.

**Activation :** F10 → CTLD → RECON → **RECON [Start]** (puis **RECON [Stop]** pour
terminer).

### Bascules de layers

**Utilité :** afficher ou masquer une catégorie de contact. Chaque layer a sa propre entrée
dont le libellé vous indique ce qu'un clic va faire — `[activate]` quand le layer est
désactivé, `[deactivate]` quand il est activé. Un **(X)** en fin de libellé signifie que le
recon est actuellement inactif (aucun scan en cours), si bien que la bascule ne fait
qu'enregistrer votre choix pour le prochain démarrage. Désactiver un layer pendant un scan en
cours retire ses marques immédiatement.

**Activation :** F10 → CTLD → RECON → *[nom du layer]* `[activate]` / `[deactivate]`

Layers disponibles, dans l'ordre du menu :

- Infantry
- Air Defense (AA)
- Ground Vehicles
- Helicopters
- Aircraft
- Ships
- FARP / FOB

## Layers et icônes

Chaque layer dessine une forme distincte pour que vous lisiez la catégorie d'un coup d'œil,
tandis que la **couleur de l'icône suit le camp de l'unité détectée** — rouge pour RED, bleu
pour BLUE, gris pour neutre.

| Layer | Icône |
|---|---|
| Infantry | Cercle avec une croix |
| Air Defense (AA) | Cercle plein avec un sommet (^) |
| Ground Vehicles | Rectangle avec une diagonale |
| Helicopters | Cercle avec deux barres verticales (H) |
| Aircraft | Croix avec un point central |
| Ships | Rectangle allongé avec une flèche de proue |
| FARP / FOB | T dans un carré |

!!! note "Les icônes s'échelonnent avec le zoom de la carte"
    Les icônes de recon sont dessinées dans l'espace monde (mètres au sol), donc elles
    grandissent et rétrécissent quand vous zoomez la carte F10 — c'est une limitation de DCS,
    il n'existe pas d'alternative fixée à l'écran. Le mission-maker peut définir un
    multiplicateur global de taille d'icône.

## Notes

- Les marques de recon sont propres à chaque joueur et visibles uniquement par votre
  coalition.
- Le rayon de scan, l'altitude minimale, l'intervalle de rafraîchissement et la taille des
  icônes relèvent tous de la configuration du mission-maker — voir le
  [guide Mission Maker](../mission-maker/index.md).
