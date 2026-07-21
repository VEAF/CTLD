# Balises (beacons) { #beacons }

Les radio beacons sont des aides à la navigation déployables que vous larguez depuis votre
appareil. Chaque beacon émet sur trois fréquences à la fois — une sur laquelle vous pouvez
vous rallier avec votre aiguille ADF, plus un canal UHF et un canal FM — de sorte que
n'importe quel appareil de la coalition peut retrouver l'endroit que vous avez marqué : une
zone d'atterrissage, un point de rendez-vous, un site avancé, tout ce que vous voulez
indiquer.

Chaque beacon fonctionne sur batterie. Une fois celle-ci à plat, le beacon s'éteint de
lui-même et disparaît, ce qui vous évite d'avoir à surveiller de vieux beacons qui
encombreraient l'espace aérien.

## Déployer un beacon { #deploying-a-beacon }

**Utilité :** Marque votre position actuelle avec un beacon de navigation que toute la
coalition peut accorder et sur lequel elle peut se rallier.

**Fonctionnement :** CTLD fait spawn le beacon à hauteur de votre appareil et lui choisit
trois fréquences libres — un canal VHF (ADF), un canal UHF et un canal FM, toutes uniques de
sorte qu'aucun beacon actif n'entre en collision avec un autre. L'émission démarre environ
une seconde après le largage. La coalition reçoit un message texte avec les fréquences
attribuées, par exemple :

```
Navigation beacon deployed - 245.00 kHz - 350.50 / 45.20 MHz
```

Au sol, le beacon est placé quelques mètres derrière votre appareil pour que l'unité au sol
ne fasse pas spawn à l'intérieur de vous ; en vol, il est largué à votre position.

**Activation :** F10 → CTLD → Radio Beacons → Drop Beacon

## Retirer un beacon { #removing-a-beacon }

**Utilité :** Retire un beacon dont vous n'avez plus besoin.

**Fonctionnement :** CTLD retire le beacon ami le plus proche dans un rayon de **500 m**
autour de votre appareil — il arrête les émissions et supprime le beacon. Volez près de
celui que vous voulez éliminer avant de lancer la commande. Si aucun beacon ami n'est à
portée, vous obtenez *"No Radio Beacons within 500m."*

**Activation :** F10 → CTLD → Radio Beacons → Remove Closest Beacon

## Lister les beacons { #listing-beacons }

**Utilité :** Affiche tous les beacons actifs de votre coalition, avec leur nom et leurs
fréquences, de sorte que vous puissiez relire un canal sans avoir à rechercher le message de
largage d'origine.

**Activation :** F10 → CTLD → Radio Beacons → List Beacons

## Les fréquences { #the-frequencies }

Chaque beacon émet simultanément sur trois canaux :

| Channel | Band | Notes |
| --- | --- | --- |
| VHF | basse fréquence, indiquée en **kHz** | Le canal ADF (NDB) — orientez votre aiguille de radiogoniométrie automatique dessus pour vous rallier. |
| UHF | indiquée en **MHz** | Porteuse silencieuse (aucune tonalité audio), destinée aux appareils de type FC3. |
| FM | indiquée en **MHz** | Tonalité audible ; prend en charge le ralliement FM sur les appareils qui en disposent. |

La chaîne de fréquences se lit toujours `VHF kHz - UHF / FM MHz` (par exemple `245.00 kHz -
350.50 / 45.20 MHz`). Les fréquences sont attribuées automatiquement — vous ne pouvez pas les
choisir depuis le cockpit.

!!! note "L'audio nécessite des fichiers son embarqués"
    Les tonalités du beacon ne se jouent que si la mission a embarqué les fichiers son du
    beacon. Si vous n'entendez rien sur les canaux VHF et FM, c'est une question de
    configuration de la mission, pas un défaut de votre côté — voir le [guide Mission
    Maker](../mission-maker/index.md). L'aiguille ADF peut toujours réagir au beacon même
    lorsqu'aucune tonalité n'est entendue.

## Autonomie de la batterie { #battery-life }

Un beacon largué dure le temps de sa batterie — **30 minutes** par défaut. Lorsque la
batterie s'épuise (ou que les unités du beacon sont détruites), CTLD arrête automatiquement
les émissions et le retire ; ses fréquences sont libérées pour être réutilisées. Le mission
maker peut modifier la durée de la batterie — voir le [guide Mission
Maker](../mission-maker/index.md).

## Le calque de carte des beacons { #the-beacon-map-layer }

Lorsque la mission a activé le beacon map layer, les beacons actifs sont dessinés sur la
**carte F10** sous forme d'icônes de cercle coloré, chacune étiquetée avec le nom du beacon
et ses coordonnées MGRS. Le layer se tient à jour de lui-même : les nouveaux largages sont
ajoutés, et les icônes des beacons expirés ou retirés sont effacées automatiquement.
L'activation du layer, ainsi que ses couleurs et sa fréquence de rafraîchissement, sont
définies par la mission — voir le [guide Mission Maker](../mission-maker/index.md).

Pour révéler et marquer des *unités détectées* (plutôt que vos propres beacons) sur la carte
F10, voir [Recon](recon.md).
