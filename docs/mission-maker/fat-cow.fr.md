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

L'entrepôt de la FARP reçoit le stock de la cow et rien d'autre : du carburant jet, et chaque munition que la cow transporte.
DCS le distribue jusqu'à épuisement.
Quand un joueur rejoint le serveur, CTLD réécrit l'entrepôt de chaque cow ouverte avec les quantités que le serveur détient : on n'a pas mesuré si DCS partage avec les clients un entrepôt modifié par script.

## Réglages

Tous dans la famille `fob` de la configuration.

| Réglage | Défaut | Rôle |
|---|---|---|
| `fatCowEnabled` | `true` | Le menu F10 **Fat Cow** et les caisses cow. |
| `fatCowTypes` | `[CH-47Fbl1]` | Types qu'un joueur peut piloter en cow. Chacun doit aussi être un transport dans `capabilitiesByType`. |
| `fatCowCrates` | réservoir, Hellfire, 30 mm | Ce qu'une cow pilotée peut charger (voir plus bas). |
| `fatCowLoadouts` | plein carburant ; 4 Hellfire + carburant max ; armement max + carburant max | Ce qu'une cow pilotée peut charger d'un coup, directement en soute (voir plus bas). |
| `fatCowDeployDelay` | `60` | Secondes qu'une cow IA passe au sol avant que sa FARP ouvre. |
| `fatCowAIType` | `CH-47Fbl1` | Type de l'hélicoptère amené quand une patrouille demande une cow. Vide, **Demander une Fat Cow** disparaît. |
| `fatCowAIFuelKg` | `7200` | Carburant jet emporté par une cow IA (trois réservoirs ERFS de 800 gal). |
| `fatCowAIItems` | 6 × `weapons.missiles.AGM_114K` | Munitions emportées par une cow IA. |
| `fatCowAICows` | `[]` | Cows placées dans la mission (voir plus bas). |

### Caisses cow

Chaque entrée de `fatCowCrates` est une caisse qu'une cow pilotée peut demander :

```yaml
fatCowCrates:
- desc: Fat Cow fuel tank (800 gal)
  weight: 2400            # kg en soute ; aussi la clé de la caisse dans le catalogue
  fuelKg: 2400            # carburant jet contenu
- desc: Fat Cow Hellfires (x4)
  weight: 250
  item: weapons.missiles.AGM_114K   # nom d'article d'entrepôt DCS
  count: 4
```

Une entrée a soit `fuelKg`, soit `item` et `count`.
`item` est le nom que DCS donne à l'arme dans un entrepôt : `weapons.missiles.AGM_114K` a été vérifié en jeu pour le Hellfire.
L'entrée 30 mm (`weapons.shells.M230_HEDP M789`) est le nom que DCS donne aux obus de l'Apache, pas encore vérifié comme article d'entrepôt.

Les caisses cow n'apparaissent ni dans **Request Equipment** ni dans **Unpack Crate** : on les demande depuis le menu Fat Cow, et on les déploie depuis la soute.

### Lots de chargement

Chaque entrée de `fatCowLoadouts` est une commande **Charger : <desc>** : ses caisses, désignées par leur desc dans `fatCowCrates`, vont directement en soute, dans une zone logistique.

```yaml
fatCowLoadouts:
- desc: 4 Hellfires + max fuel
  crates:
  - crate: Fat Cow fuel tank (800 gal)
    count: 3
  - crate: Fat Cow Hellfires (x4)
    count: 1
```

Un lot qui dépasserait le `maxCratesOnboard` de l'appareil (8 pour le CH-47F) est refusé.
Le lot par défaut « Armement max + carburant max » pèse environ 8 100 kg : ce qu'un CH-47F plein de carburant interne peut emporter (22 680 kg au plus, 11 400 kg à vide, 3 054 kg de carburant, d'après la base d'unités de DCS).

## Placer une cow IA dans une mission

Un joueur peut demander une cow IA de n'importe où, au sol comme en vol : elle arrive en vol depuis la zone logistique amie à terre la plus proche du demandeur, et y retourne pour disparaître.
La patrouille la commande ensuite depuis le F10 (Atterris ici, Redécolle, Reste ici en orbite, Rejoins-nous, Libérer) : la cow d'une patrouille de joueurs ne bouge jamais d'elle-même.
Pour donner sa cow à une patrouille dès le départ, placez la cow dans l'éditeur de mission et déclarez-la :

1. Placez un groupe **CH-47F**, avec **activation différée** cochée, là où la cow doit démarrer (en général la base de la patrouille).
   Son premier waypoint est un décollage depuis le sol ; il n'en faut pas d'autre.
2. Déclarez-le, avec le groupe qu'il escorte :

```yaml
fatCowAICows:
- group: Fat Cow Gunfighter      # le groupe CH-47, nom exact
  escort: Gunfighter             # la patrouille escortée, nom de groupe exact
```

CTLD active la cow dès que le groupe escorté est en jeu : au démarrage de la mission pour une patrouille IA, ou quand le premier joueur prend un slot d'une patrouille de clients.
Si la patrouille escortée est une patrouille IA, la cow se pose à côté du leader quand il se pose, se déploie après `fatCowDeployDelay`, se replie et suit quand le leader décolle, et rentre à son point de départ une fois vide : une patrouille IA ne peut pas utiliser le menu.
Si c'est une patrouille de clients, ses joueurs commandent la cow depuis le F10, comme une cow demandée.

Au démarrage, CTLD note dans le log ce que DCS renvoie pour l'entrepôt des FARP de la mission (`FARP warehouse '<nom>': jet fuel …`) : une mesure, avant que **Statut FARP** couvre toutes les FARP et pas seulement celles des Fat Cow.

Cette déclaration est le contrat sur lequel s'appuient les VEAF Mission Creation Tools pour ajouter une cow qui escorte une patrouille nommée : un groupe d'hélicoptère en activation différée, et une entrée `fatCowAICows` `{ group, escort }`.
CTLD ne reconnaît jamais une cow à son nom.
