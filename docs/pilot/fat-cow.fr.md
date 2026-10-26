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
    - **Charger : Plein carburant** (3 réservoirs, 7 200 kg), **Charger : 4 Hellfire + carburant max** ou **Charger : Armement max + carburant max** (3 réservoirs, 12 Hellfire, 300 obus de 30 mm, environ 8 100 kg) : les caisses vont directement en soute ;
    - ou une caisse à la fois, **Demander Réservoir Fat Cow (800 gal)** (2 400 kg de carburant jet, et 2 400 kg dans votre soute), **Demander Hellfire Fat Cow (x4)**, **Demander Fat Cow 30 mm (x300)**, puis chargez-les comme n'importe quelle caisse CTLD.

    **Décharger les caisses Fat Cow** vide la soute, pour composer un autre lot.
3. Volez jusqu'aux hélicoptères d'attaque qui ont besoin de vous, et posez-vous.
4. **Déployer la FARP Fat Cow.**
   La FARP ouvre quelques secondes plus tard et on vous annonce ce qu'elle contient.
   Les caisses restent dans votre soute : le carburant ne quitte jamais le Chinook.
5. Les autres hélicoptères se posent à côté de vous et se ravitaillent par le menu de leur équipe au sol, comme sur n'importe quelle FARP.
6. **Replier la FARP Fat Cow**, ou décollez simplement : la FARP est repliée pour vous.
   Ce qui n'a pas servi retourne dans vos caisses, la soute s'allège, et une caisse vidée disparaît.

**Stock de la Fat Cow** vous dit ce qu'il vous reste, au sol comme en vol.
Si vous quittez votre slot pendant que la FARP est ouverte, la FARP reste, avec ce qu'elle contient encore.

!!! note "Quand le stock s'épuise"
    Un hélicoptère qui demande plus que ce qui reste reçoit ce qui reste, et son équipe au sol répond « Unable to comply ».
    Une demande sur une FARP vide reçoit « We don't have this in stock ».

## Demander une cow IA

Tout joueur dont l'appareil n'est pas une cow peut **Demander une Fat Cow**, au sol comme en vol.
Un CH-47 décolle de la zone logistique amie la plus proche de vous, et on vous annonce d'où il vient, à quelle distance il est et quand il devrait vous rejoindre.

La cow fait ensuite ce que votre patrouille lui dit, et rien d'elle-même :

| Commande | Ce que fait la cow |
|---|---|
| **Atterris ici** | se pose à environ 120 m à votre gauche et ouvre sa FARP une minute après avoir touché le sol |
| **Redécolle** | replie sa FARP, décolle et tourne sur place |
| **Reste ici en orbite** | replie sa FARP si besoin et tourne au-dessus de votre position |
| **Rejoins-nous** | replie sa FARP si besoin et suit votre patrouille |
| **Libérer la Fat Cow** | replie sa FARP et rentre, où elle disparaît |

Vous pouvez donc redécoller pour vous déplacer en stationnaire jusqu'à sa FARP, ou vous repositionner, sans que la cow parte.

**Statut Fat Cow** dit où est la cow de votre patrouille (phase, distance et relèvement), quand elle devrait vous rejoindre, et ce qu'elle contient encore, y compris avant qu'elle se soit posée.

Par défaut, une cow IA emporte 7 200 kg de carburant (trois réservoirs de 800 gal) et 6 Hellfire.
Une cow par patrouille.

!!! tip "Posez-vous à découvert"
    Choisissez un terrain dégagé pour **Atterris ici** : un hélicoptère envoyé se poser en lisière de forêt y reste en stationnaire sans jamais toucher le sol.

## Ce que contient encore une FARP

**Statut FARP**, dans le même menu, dit ce que contient encore la FARP Fat Cow où vous êtes (la plus proche à moins de 2 km), à qui qu'elle appartienne.
