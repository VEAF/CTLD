# Fat Cow

Une Fat Cow est un CH-47 qui se pose sur le terrain et devient un point de ravitaillement et de réarmement avancé pour les autres hélicoptères.
L'US Army la décrit comme une FARP déployée en un instant : le Chinook emporte son carburant dans des réservoirs en soute et le distribue au sol.

DCS ne sait pas faire passer du carburant d'un appareil à l'autre, alors CTLD installe une petite FARP à côté de la cow : un héliport invisible, un dépôt de carburant derrière la rampe, quelques caisses et trois soldats.
Le stock de la FARP est exactement ce que la cow transporte.
Une fois épuisé, il n'y en a plus.

Il y a deux façons d'avoir une cow : la piloter soi-même, ou en demander une IA à CTLD.
Tout se trouve dans **F10 → CTLD → Fat Cow**.

## Piloter une cow (CH-47F)

1. Posez-vous dans une zone logistique.
2. Chargez ce que vous voulez emporter :
    - **Charger**, puis un lot : les caisses vont directement en soute.
      Chaque lot emporte deux réservoirs de 800 gal (4 800 kg de carburant jet) et des armes :

      | Menu | Lots |
      |---|---|
      | **Charger** (Apache) | 40 Hellfire (25 laser, 15 radar) et 2 400 obus de 30 mm ; 60 Hellfire (38 laser, 22 radar) et 1 200 obus ; 40 Hellfire laser et 2 400 obus ; 60 Hellfire laser et 1 200 obus |
      | **Charger → Russes** | Ka-50 : 40 Vikhr et 920 obus de 2A42 (moitié explosifs, moitié perforants), ou 60 Vikhr et 460 obus ; Mi-24P : 32 Ataka ou 32 Shturm, avec 500 obus de GSh-30 |
      | **Charger → Mixtes** | 20 Hellfire (12 laser, 8 radar), 20 Vikhr, 1 200 obus de 30 mm et 460 de 2A42 ; 20 Hellfire laser, 16 Ataka, 1 200 obus de 30 mm et 500 de GSh-30 |

      Cela fait de 6 400 à 8 200 kg en 5 à 8 caisses, ce qu'emporte un CH-47F avec 80 % de son carburant interne : inutile de faire le plein.
    - ou une caisse à la fois, **Demander une caisse** : un réservoir (2 400 kg), 20 Hellfire laser ou 20 radar, 1 200 obus de 30 mm, 20 Vikhr, 16 Ataka, 16 Shturm, 460 obus de 2A42 explosifs ou perforants, 500 obus de GSh-30, puis chargez-la comme n'importe quelle caisse CTLD.

    **Décharger les caisses Fat Cow** vide la soute, pour composer un autre lot.
3. Volez jusqu'aux hélicoptères d'attaque qui ont besoin de vous, et posez-vous.
4. **Déployer la FARP Fat Cow.**
   La FARP ouvre quelques secondes plus tard et on vous annonce ce qu'elle contient.
   Les caisses restent dans votre soute : le carburant ne quitte jamais le Chinook.
5. Les autres hélicoptères se posent à côté de vous et se ravitaillent par le menu de leur équipe au sol, comme sur n'importe quelle FARP.
6. **Replier la FARP Fat Cow**, ou décollez simplement : la FARP est repliée pour vous.
   Ce qui n'a pas servi retourne dans vos caisses, la soute s'allège, et une caisse vidée disparaît.

**Stock de la Fat Cow** vous dit ce qu'il vous reste, au sol comme en vol.
Si vous quittez votre slot pendant que la FARP est ouverte, la FARP reste, avec ce qu'elle contient encore, jusqu'à ce qu'un pilote reprenne ce slot : elle se ferme alors, vidée, et le nouveau pilote repart soute vide.

!!! note "Quand le stock s'épuise"
    Un hélicoptère qui demande plus que ce qui reste reçoit ce qui reste, et son équipe au sol répond « Unable to comply ».
    Une demande sur une FARP vide reçoit « We don't have this in stock ».

## Demander une cow IA

Tout joueur dont l'appareil n'est pas une cow peut **Demander une Fat Cow**, au sol comme en vol, et choisir son lot.
Un CH-47 décolle de la zone logistique amie la plus proche de vous, et on vous annonce d'où il vient, à quelle distance il est et quand il devrait vous rejoindre.

La cow fait ensuite ce que votre patrouille lui dit, et rien d'elle-même :

| Commande | Ce que fait la cow |
|---|---|
| **Atterris ici** | se pose à environ 120 m à votre gauche et ouvre sa FARP une minute après avoir touché le sol |
| **Redécolle** | replie sa FARP, décolle et tourne sur place |
| **Reste ici en orbite** | replie sa FARP si besoin et tourne au-dessus de votre position |
| **Rejoins-nous** | replie sa FARP si besoin et suit votre patrouille |
| **Rentre à la base** | replie sa FARP et rentre à la base, où elle disparaît |
| **Libérer la Fat Cow** | quitte votre patrouille et reste où elle est, pour qu'une autre patrouille la reprenne : au sol sa FARP reste ouverte, en vol elle tourne sur place |

Vous pouvez donc redécoller pour vous déplacer en stationnaire jusqu'à sa FARP, ou vous repositionner, sans que la cow parte.

**Statut Fat Cow** dit où est la cow de votre patrouille (phase, distance et relèvement), quand elle devrait vous rejoindre, et ce qu'elle contient encore, y compris avant qu'elle se soit posée.

**Demander une Fat Cow** ouvre la liste des lots, les mêmes que ceux d'une cow pilotée (Apache en tête, **Russes** et **Mixtes** un niveau plus bas) : choisissez ce dont votre patrouille a besoin.
C'est toujours un CH-47, quel que soit votre appareil.
Une cow par patrouille.

### Reprendre une cow libre

Si la patrouille qu'une cow sert est abattue, ou si son dernier joueur quitte son slot, la cow replie sa FARP et rentre à la base.
Chaque patrouille d'hélicoptères de sa coalition qui n'a pas de cow est prévenue : où elle est par rapport à vous, où elle rentre et ce qu'elle transporte.

Tant qu'une cow rentre, pour cette raison ou après un **Rentre à la base**, vide ou non, ou a été libérée par sa patrouille (**Libérer la Fat Cow**, qui prévient aussi ces patrouilles), elles la trouvent dans **Fat Cow → Reprendre une Fat Cow** : une entrée par cow, la plus proche en tête, avec sa distance par rapport à vous (mise à jour toutes les 30 s).
La cow choisie rejoint votre patrouille et obéit à ses commandes comme si vous l'aviez demandée.
Une cow libérée au sol replie sa FARP avant de vous rejoindre.
Une entrée disparaît dès que sa cow est reprise, posée à sa base ou abattue.

!!! tip "Posez-vous à découvert"
    Choisissez un terrain dégagé pour **Atterris ici** : un hélicoptère envoyé se poser en lisière de forêt y reste en stationnaire sans jamais toucher le sol.

## Ce que contient encore une FARP

**Statut FARP**, dans le même menu, dit ce que contient encore la FARP Fat Cow où vous êtes (la plus proche à moins de 2 km), à qui qu'elle appartienne.
