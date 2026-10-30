# Fat Cow

Une Fat Cow est un CH-47 qui se pose sur le terrain et ouvre une FARP approvisionnée avec ce qu'il transporte.
Le côté pilote est décrit dans [Fat Cow (pilotes)](../pilot/fat-cow.md) ; cette page couvre les réglages et la façon de placer une cow dans une mission.

## Ce que CTLD installe

Quand une cow se déploie, CTLD joue la scène **Fat Cow FARP** à la cow :

| Objet | Où | Rôle |
|---|---|---|
| FARP invisible | à la cow | l'aérodrome dont l'entrepôt contient le stock de la cow |
| FARP Fuel Depot | 25 m derrière la rampe | le fournisseur dont les équipes au sol ont besoin |
| 2 caisses de munitions, 1 lot de fûts | 20 m derrière, à droite | décor, jamais chargeables |
| 3 soldats | 25 m derrière, à gauche | en attente |

Pas de véhicule, pas de tente, pas de dépôt de munitions.
C'est mesuré dans DCS 2.9.30.28738 : une FARP créée en cours de mission sert un joueur déjà en jeu, mais seulement avec un fournisseur à portée, et le FARP Fuel Depot suffit à lui seul pour le carburant et les armes (camions citernes, camions de munitions et dépôt de munitions sont inutiles ; caisses et fûts ne fournissent rien).

Chaque cow a sa propre FARP, nommée `CTLD_FatCow_FARP_<n>`.
Le repli retire le dépôt, le décor et l'équipe et vide l'entrepôt de la FARP, mais laisse la FARP elle-même : un héliport détruit en cours de mission reste sur la carte F10, et une cow IA posée sur sa FARP a explosé quand la FARP a été détruite sous elle.
Le déploiement suivant ajoute de nouveau la FARP sous le même nom, là où se trouve la cow.
Il reste donc une FARP vide sur la carte là où chaque cow s'est déployée en dernier ; sans fournisseur à côté, elle ne sert rien.

L'entrepôt de la FARP reçoit le stock de la cow et rien d'autre : du carburant jet, et chaque munition que la cow transporte.
DCS le distribue jusqu'à épuisement.
Quand un joueur rejoint le serveur, CTLD réécrit l'entrepôt de chaque cow ouverte, tout de suite puis deux secondes plus tard, avec les quantités que le serveur détient : on n'a pas mesuré si DCS partage avec les clients un entrepôt modifié par script.
CTLD les relit et les réécrit aussi toutes les 10 secondes.
Une quantité qui a augmenté a été remplie par un autre script (les VEAF Mission Creation Tools remplissent toutes les FARP quand un joueur arrive) : CTLD garde le compte de la cow et le remet, et retire toute arme que la cow ne transporte pas.
Ce qui a été pris dans les quelques secondes avant un tel remplissage peut revenir, et les munitions qu'un hélicoptère rend en se réarmant ne s'ajoutent pas au stock de la cow.
Une FARP de cow qui n'est pas ouverte est vidée aux mêmes moments.
La FARP d'une cow IA rentrée à la base sert à la suivante : la carte ne gagne pas une FARP vide à chaque cow demandée.

## Réglages

Tous dans la famille `fob` de la configuration.

| Réglage | Défaut | Rôle |
|---|---|---|
| `fatCowEnabled` | `true` | Le menu F10 **Fat Cow** et les caisses cow. |
| `fatCowTypes` | `[CH-47Fbl1]` | Types qu'un joueur peut piloter en cow. Chacun doit aussi être un transport dans `capabilitiesByType`. |
| `fatCowCrates` | réservoir ; Hellfire et 30 mm (Apache) ; Vikhr et obus de 2A42 (Ka-50) ; Ataka, Shturm et obus de GSh-30 (Mi-24P) | Les caisses dans lesquelles une cow pilotée emporte son stock (voir plus bas). |
| `fatCowLoadouts` | quatre lots Apache, quatre russes et deux mixtes, chacun avec 4 800 kg de carburant | Ce qu'emporte une cow : chargé par une cow pilotée, choisi par une patrouille qui demande une cow IA (voir plus bas). |
| `fatCowDeployDelay` | `60` | Secondes qu'une cow IA passe au sol avant que sa FARP ouvre. |
| `fatCowAIType` | `CH-47Fbl1` | Type de l'hélicoptère amené quand une patrouille demande une cow. Vide, **Demander une Fat Cow** disparaît. |
| `fatCowAICows` | `[]` | Cows placées dans la mission (voir plus bas). |

### Lots de chargement

Chaque entrée de `fatCowLoadouts` est ce qu'emporte une cow : du carburant jet en kg, et des articles d'entrepôt DCS avec leur nombre.

```yaml
fatCowLoadouts:
- desc: 40 Hellfires (25 laser, 15 radar), 2400 rounds
  fuelKg: 4800                          # deux réservoirs de 800 gal
  items:
  - item: weapons.missiles.AGM_114K     # Hellfire laser
    count: 25
  - item: weapons.missiles.AGM_114      # Hellfire radar (AGM-114L)
    count: 15
  - item: weapons.shells.M230_HEDP M789 # 30 mm
    count: 2400
```

Une cow pilotée les trouve sous **Charger**, dans une zone logistique ; une patrouille qui demande une cow IA en choisit un sous **Demander une Fat Cow**.
Un lot avec `menu: russian` ou `menu: mixed` apparaît dans le sous-menu **Russes** ou **Mixtes**, un lot sans `menu` en tête.
La cow est toujours un CH-47 (`fatCowAIType`), quel que soit le lot et quel que soit l'appareil du demandeur : c'est le module que les joueurs pilotent en cow.

Les lots par défaut emportent tous deux réservoirs de 800 gal (4 800 kg) :

| Menu | Lot | Armes | Total |
|---|---|---|---|
| en tête | Apache | 40 Hellfire (25 laser, 15 radar), 2 400 obus de 30 mm | 7 868 kg |
| en tête | Apache | 60 Hellfire (38 laser, 22 radar), 1 200 obus | 8 199 kg |
| en tête | Apache | 40 Hellfire laser, 2 400 obus | 7 812 kg |
| en tête | Apache | 60 Hellfire laser, 1 200 obus | 8 118 kg |
| Russes | Ka-50 | 40 Vikhr, 460 obus de 2A42 explosifs et 460 perforants | 7 382 kg |
| Russes | Ka-50 | 60 Vikhr, 230 obus de 2A42 explosifs et 230 perforants | 7 891 kg |
| Russes | Mi-24P | 32 Ataka, 500 obus de GSh-30 | 6 809 kg |
| Russes | Mi-24P | 32 Shturm, 500 obus de GSh-30 | 6 358 kg |
| Mixtes | Apache + Ka-50 | 20 Hellfire (12 laser, 8 radar), 20 Vikhr, 1 200 obus de 30 mm, 460 de 2A42 | 7 627 kg |
| Mixtes | Apache + Mi-24P | 20 Hellfire laser, 16 Ataka, 1 200 obus de 30 mm, 500 de GSh-30 | 7 523 kg |

Tous restent sous les 8 837 kg qu'emporte un CH-47F avec 80 % de son carburant interne (22 680 kg au plus, 11 400 kg à vide, 2 444 kg de carburant, d'après la base d'unités de DCS) ; une cow IA reçoit ces 80 %.
Les masses des missiles sont celles du data mine DCS (AGM-114K 45,3 kg, AGM-114L 49 kg, Vikhr 45 kg, Ataka 49,5 kg, Shturm 35,4 kg) ; les obus comptent 0,5 kg (30 mm de l'Apache) et 0,85 kg (30 × 165 russe) emballage compris, une estimation.

`item` est le nom que DCS donne à l'arme dans un entrepôt.
`weapons.missiles.AGM_114K` a été vérifié en jeu pour le Hellfire laser.
Les autres viennent du data mine DCS et ne sont pas encore vérifiés comme articles d'entrepôt : `weapons.missiles.AGM_114` (AGM-114L), `weapons.shells.M230_HEDP M789` (les obus de l'Apache), `weapons.missiles.Vikhr_M`, `weapons.missiles.Ataka_9M120`, `weapons.missiles.AT_6` (Shturm), `weapons.shells.2A42_30_HE` et `2A42_30_AP` (Ka-50), `weapons.shells.GSh_30_2K_HE` (Mi-24P).

### Caisses cow

Une cow pilotée emporte son lot dans des caisses : **Charger** le répartit dans les `fatCowCrates` qui portent chaque partie, toutes pleines sauf la dernière de chaque sorte.

```yaml
fatCowCrates:
- desc: Fat Cow fuel tank (800 gal)
  weight: 2400            # kg en soute quand elle est pleine ; aussi la clé de la caisse dans le catalogue
  fuelKg: 2400            # carburant jet d'une caisse pleine
- desc: Fat Cow laser Hellfires (x20)
  weight: 906             # 20 x 45,3 kg
  item: weapons.missiles.AGM_114K
  count: 20
```

Une entrée a soit `fuelKg`, soit `item` et `count` ; une caisse en partie pleine pèse sa part.
Par défaut : un réservoir de 800 gal (2 400 kg) ; 20 Hellfire laser (906 kg), 20 Hellfire radar (980 kg), 1 200 obus de 30 mm (600 kg) ; 20 Vikhr (900 kg), 460 obus de 2A42 explosifs ou perforants (391 kg chacun) ; 16 Ataka (792 kg), 16 Shturm (566 kg), 500 obus de GSh-30 (425 kg).
Chaque lot par défaut tient en 5 à 8 caisses ; un lot qui dépasserait le `maxCratesOnboard` de l'appareil (8 pour le CH-47F) est refusé, tout comme un lot qui emporte un article qu'aucune caisse ne porte.
**Demander une caisse** amène une caisse pleine à la fois.
Les caisses cow n'apparaissent ni dans **Request Equipment** ni dans **Unpack Crate**.

## Placer une cow IA dans une mission

Un joueur peut demander une cow IA de n'importe où, au sol comme en vol : elle arrive en vol depuis la zone logistique amie à terre la plus proche du demandeur, et y retourne pour disparaître.
La patrouille la commande ensuite depuis le F10 (Atterris ici, Redécolle, Reste ici en orbite, Rejoins-nous, Rentre à la base) : la cow d'une patrouille de joueurs ne bouge jamais d'elle-même.
Pour donner sa cow à une patrouille dès le départ, placez la cow dans l'éditeur de mission et déclarez-la :

1. Placez un groupe **CH-47F**, avec **activation différée** cochée, là où la cow doit démarrer (en général la base de la patrouille).
   Son premier waypoint est un décollage depuis le sol ; il n'en faut pas d'autre.
2. Déclarez-le, avec le groupe qu'il escorte :

```yaml
fatCowAICows:
- group: Fat Cow Gunfighter      # le groupe CH-47, nom exact
  escort: Gunfighter             # la patrouille escortée, nom de groupe exact
  loadout: 2                     # facultatif : le lot de fatCowLoadouts qu'elle emporte, 1 par défaut
```

CTLD active la cow dès que le groupe escorté est en jeu : au démarrage de la mission pour une patrouille IA, ou quand le premier joueur prend un slot d'une patrouille de clients.
Si la patrouille escortée est une patrouille IA, la cow se pose à côté du leader quand il se pose, se déploie après `fatCowDeployDelay`, se replie et suit quand le leader décolle, et rentre à son point de départ une fois vide : une patrouille IA ne peut pas utiliser le menu.
Si c'est une patrouille de clients, ses joueurs commandent la cow depuis le F10, comme une cow demandée.
Si la patrouille escortée est perdue, la cow rentre à son point de départ, et toute patrouille de joueurs de sa coalition sans cow peut la reprendre en chemin depuis le F10 (**Reprendre une Fat Cow**, voir le guide pilote).

Au démarrage, CTLD note dans le log ce que DCS renvoie pour l'entrepôt des FARP de la mission (`FARP warehouse '<nom>': jet fuel …`) : une mesure, avant que **Statut FARP** couvre toutes les FARP et pas seulement celles des Fat Cow.

Cette déclaration est le contrat sur lequel s'appuient les VEAF Mission Creation Tools pour ajouter une cow qui escorte une patrouille nommée : un groupe d'hélicoptère en activation différée, et une entrée `fatCowAICows` `{ group, escort, loadout }` (`loadout` facultatif).
CTLD ne reconnaît jamais une cow à son nom.
