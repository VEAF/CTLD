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
| `fatCowCrates` | réservoir, 20 Hellfire laser, 20 Hellfire radar, 1 200 obus de 30 mm | Les caisses dans lesquelles une cow pilotée emporte son stock (voir plus bas). |
| `fatCowLoadouts` | quatre lots Hellfire et 30 mm, chacun avec 4 800 kg de carburant | Ce qu'emporte une cow : chargé par une cow pilotée, choisi par une patrouille qui demande une cow IA (voir plus bas). |
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
Les quatre lots par défaut emportent tous deux réservoirs de 800 gal (4 800 kg), avec 40 Hellfire (25 laser, 15 radar) et 2 400 obus, 60 Hellfire (38 laser, 22 radar) et 1 200 obus, 40 Hellfire laser et 2 400 obus, ou 60 Hellfire laser et 1 200 obus.
Ils pèsent de 7 800 à 8 200 kg, sous les 8 837 kg qu'emporte un CH-47F avec 80 % de son carburant interne (22 680 kg au plus, 11 400 kg à vide, 2 444 kg de carburant, d'après la base d'unités de DCS) ; une cow IA reçoit ces 80 %.

`item` est le nom que DCS donne à l'arme dans un entrepôt.
`weapons.missiles.AGM_114K` a été vérifié en jeu pour le Hellfire laser.
`weapons.missiles.AGM_114` (l'AGM-114L, d'après le data mine DCS) et `weapons.shells.M230_HEDP M789` (les obus de l'Apache) ne sont pas encore vérifiés comme articles d'entrepôt.

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
Par défaut : un réservoir de 800 gal (2 400 kg), 20 Hellfire laser (906 kg), 20 Hellfire radar (980 kg) et 1 200 obus de 30 mm (600 kg, 0,5 kg par obus emballage compris : une estimation).
Chaque lot par défaut tient en 6 ou 7 caisses ; un lot qui dépasserait le `maxCratesOnboard` de l'appareil (8 pour le CH-47F) est refusé, tout comme un lot qui emporte un article qu'aucune caisse ne porte.
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

Au démarrage, CTLD note dans le log ce que DCS renvoie pour l'entrepôt des FARP de la mission (`FARP warehouse '<nom>': jet fuel …`) : une mesure, avant que **Statut FARP** couvre toutes les FARP et pas seulement celles des Fat Cow.

Cette déclaration est le contrat sur lequel s'appuient les VEAF Mission Creation Tools pour ajouter une cow qui escorte une patrouille nommée : un groupe d'hélicoptère en activation différée, et une entrée `fatCowAICows` `{ group, escort, loadout }` (`loadout` facultatif).
CTLD ne reconnaît jamais une cow à son nom.
