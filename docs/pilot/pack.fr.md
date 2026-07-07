# Pack

Le pack est l'inverse du dépaquetage : il prend quelque chose que vous avez déjà posé au sol —
un vehicle déployé ou une scène FARP entière — et le retransforme **en crates** pour que vous
puissiez les charger et transporter l'ensemble ailleurs. Vous avez posé la mauvaise FARP dans la
mauvaise vallée, ou vous devez relocaliser un SAM déployé il y a une heure ? Packez-le,
transportez-le, dépaquetez-le sur le nouveau site.

Tout se trouve au même endroit : **F10 → CTLD → Crate Commands → Pack Equipt**. Ce sous-menu est
construit pour vous à la volée et n'apparaît que lorsque le pack est réellement possible.

!!! note "Quand Pack Equipt apparaît-il ?"
    Le sous-menu est **au sol uniquement** — il est absent tant que vous êtes en vol. Au sol, il
    n'apparaît que lorsque vous pilotez un transport aircraft capable de porter des crates **et**
    qu'il y a au moins un élément packable à portée. Si vous vous posez et ne voyez aucune entrée
    **Pack Equipt**, c'est qu'il n'y a rien à packer à proximité (ou que votre mission a désactivé
    les deux options de pack).

## Packer un vehicle

Tout ground vehicle que vous avez déployé via CTLD — depuis un dépaquetage de crate ou depuis
**Request Equipment** — peut être replié en crates.

1. **Posez-vous près du vehicle.** Vous devez être au sol et à moins de
   `maximumDistancePackableUnitsSearch` — **200 m** par défaut — du vehicle.
2. Ouvrez **F10 → CTLD → Crate Commands → Pack Equipt**. Chaque vehicle packable à portée est
   listé par son nom (par ex. la description de crate du vehicle).
3. **Sélectionnez le vehicle.** Il est retiré de la carte et ses crates apparaissent à côté de
   vous — devant un helicopter, ou derrière un C-130 / Il-76 qui utilise le cargo natif.
4. Chargez les crates et transportez-les vers le nouveau site, puis dépaquetez comme d'habitude.

Le nombre de crates qui apparaissent correspond au nombre dont ce vehicle a besoin
(`cratesRequired`) — une unité lourde revient sous forme de plusieurs crates, tout comme il en a
fallu plusieurs pour la construire. Vous recevez un message de confirmation :
*"… packed into N crate(s)."*

!!! tip "Seuls les vehicles propres à CTLD se packent"
    Pack Equipt ne liste que les vehicles que CTLD a spawn et qu'il suit, et seulement tant
    qu'ils sont inactifs (non taskés). Les unités arbitraires de la carte, les décors et les
    gardes n'apparaissent jamais — le menu reste ainsi épuré.

## Packer une FARP

Une scène FARP déployée peut être packée de la même manière, et CTLD **mémorise son carburant**
pendant le trajet.

1. **Posez-vous à moins de 300 m** de la FARP déployée.
2. Ouvrez **Pack Equipt**. Une FARP packable apparaît sous la forme **Pack [FARP name]**.
3. **Sélectionnez-la.** CTLD prend un instantané des niveaux de carburant de l'entrepôt de la
   FARP, retire la scène et fait apparaître ses crates à côté de vous. Vous recevez
   *"FARP packed successfully!"*.
4. Transportez les crates vers le nouvel emplacement et dépaquetez. La FARP se redéploie **avec
   son carburant restauré** aux quantités capturées.

!!! note "Restez au sol"
    Si vous déclenchez un pack de FARP en vol, CTLD refuse et vous indique d'être d'abord au sol.
    Seuls les types de FARP que la mission a configurés comme packables peuvent être packés —
    voir le guide Mission Maker ci-dessous.

## Désactiver la fonction

Les deux moitiés de Pack Equipt sont activées par défaut et contrôlées indépendamment par la
mission :

| Paramètre | Défaut | Contrôle |
| --- | --- | --- |
| `enablePackingVehicles` | `true` | Si les vehicles peuvent être packés en crates |
| `enableFARPRepack` | `true` | Si les scènes FARP déployées peuvent être packées |
| `maximumDistancePackableUnitsSearch` | `200` | À quelle distance (m) vous devez être d'un vehicle pour le packer |

Si `enablePackingVehicles` et `enableFARPRepack` sont toutes deux désactivées, le sous-menu
**Pack Equipt** n'apparaît jamais.

## Voir aussi

- [Crates](crates.md) — faire apparaître, charger, larguer et dépaqueter les crates que vous
  récupérez.
- [Vehicles](vehicles.md) — demander et déployer les vehicles que vous pourrez packer ensuite.
- [Configuration](../mission-maker/configuration.md) — activer le pack et régler la distance de
  recherche.
- [Scenes & FOBs](../mission-maker/scenes-fob.md) — rendre une FARP packable et comment le
  carburant est capturé et restauré.
