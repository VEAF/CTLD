# Parachute

Parfois vous ne pouvez pas — ou ne voulez pas — vous poser. La zone est chaude, le terrain est
mauvais, ou vous allez tout simplement trop vite pour vous embêter à atterrir. Le largage par
parachute vous permet de livrer des crates, des troops et des vehicles tout en restant en l'air :
survolez le point de largage, actionnez la bonne entrée F10, et CTLD fait descendre le cargo en
douceur à votre place.

## Utilité { #utility }

Un largage par parachute est une **livraison en survol**. Tout ce que vous transportez — crates
CTLD, troops embarquées ou vehicle chargé — quitte l'aéronef à l'instant où vous déclenchez le
largage et se pose au sol quelques secondes plus tard, décalé en avant de votre trajectoire et
autour d'elle. Utilisez-le pour ravitailler une position contestée, insérer de l'infanterie sans
exposer l'hélicoptère à un vol stationnaire, ou disséminer de l'équipement sur une zone depuis
l'altitude.

La livraison est *virtuelle* : pour les hélicoptères, CTLD calcule où le cargo se pose et l'y
place après une courte descente, si bien que vous ne verrez pas de voilure 3D sous l'aéronef.
(Certains transports à voilure fixe utilisent le parachute natif de DCS à la place, avec une vraie
voilure animée — voir [Comment ça marche](#how-it-works).)

## Comment ça marche { #how-it-works }

Lorsque vous déclenchez un largage, chaque élément est retiré de l'aéronef immédiatement et
programmé pour toucher le sol après une descente simulée. Le point d'atterrissage n'est pas
directement sous vous :

- **L'inertie** emporte le cargo vers l'avant le long de votre trajectoire de vol — plus vous
  volez vite, plus il se pose loin devant.
- **La dérive latérale** disperse chaque élément d'une distance et dans une direction aléatoires,
  de sorte qu'un escadron de 8 hommes se pose réparti autour de la drop zone plutôt qu'empilé sur
  un seul point.

Plus haut et plus rapide signifie une chute plus longue et plus dispersée ; bas et lent resserre
le groupement. Planifiez votre passage pour que l'empreinte calculée tombe où vous le souhaitez.

Deux choses méritent d'être connues avant de larguer :

- **Seuil d'altitude.** Chaque type de charge a une hauteur minimale au-dessus du sol. Si vous
  déclenchez un largage en dessous, l'action est refusée et vous recevez un message à l'écran
  (`Altitude too low for parachute drop. Minimum: <n>m AGL (current: <n>m AGL)`) ; le cargo reste
  à bord. Montez et réessayez. Les minima exacts sont définis par le mission maker — voir le
  [Mission Maker guide](../mission-maker/index.md).
- **Les crates s'assemblent automatiquement à l'atterrissage.** Lorsque plusieurs crates du même
  vehicle se posent proches les unes des autres, CTLD les déballe automatiquement en le vehicle
  fini au centre du groupe — sans ground crew et sans étape de unpack F10. Larguez l'ensemble
  complet des crates au-dessus du même point et le vehicle se construit tout seul là où elles se
  posent.

Pour les transports à voilure fixe tels que le C-130, l'Il-76 et le Hercules, les crates utilisent
le **parachute natif de DCS** à la place : chargez-les, montez à l'altitude de largage, et
utilisez la fonction parachute DCS propre à l'aéronef (pas le menu CTLD). DCS anime une vraie
voilure et CTLD revendique les crates lorsqu'elles touchent le sol. Quels aéronefs se comportent
de quelle manière est un réglage du mission maker.

> **Le cargo natif DCS ne peut pas être parachuté depuis le menu CTLD.** Les crates chargées via
> l'interface cargo standard de DCS (plutôt que via le menu CTLD **Load Crate**) sont exclues de
> **Parachute Crates**. Il s'agit d'une limitation de DCS — il n'existe aucun moyen de libérer un
> emplacement de cargo d'un aéronef en vol. Si vous comptez parachuter des crates, chargez-les via
> le menu F10 de CTLD. Voir [Crates](crates.md).

## Activation

Les entrées de parachute vivent sous le menu **F10 → CTLD** et n'apparaissent que lorsque trois
conditions sont réunies simultanément :

1. votre type d'aéronef est autorisé pour les largages par parachute (un réglage du mission maker),
2. vous êtes **en vol** (elles disparaissent au sol), et
3. vous avez effectivement le cargo correspondant à bord.

Lorsque ces conditions sont remplies, jusqu'à trois entrées deviennent disponibles :

| Menu path | Largue |
| --- | --- |
| **F10 → CTLD → Crate Commands → Parachute Crates** | Toutes les crates chargées par CTLD (les crates dans un sling-load virtuel actif sont exclues) |
| **F10 → CTLD → Troop Commands → Parachute Troops** | Vos troops embarquées |
| **F10 → CTLD → Vehicle Commands → Parachute Vehicle** | Le vehicle chargé |

**Plusieurs troop groups à bord.** Si vous transportez plus d'un troop group, **Parachute Troops**
devient un sous-menu :

- **Parachute All** — largue tous les groupes en une seule passe.
- **[1] <group>**, **[2] <group>**, … — largue un groupe nommé à la fois.

Chaque groupe se pose toujours avec sa propre inertie et sa propre dispersion.

Opérations de cockpit associées : [Troop transport](troop-transport.md) ·
[Crates](crates.md) · [Vehicles](vehicles.md) · [Sling-load](slingload.md). Pour les seuils
d'altitude, les taux de descente, le réglage de la dérive et l'activation par aéronef, voir le
[Mission Maker guide](../mission-maker/index.md).
