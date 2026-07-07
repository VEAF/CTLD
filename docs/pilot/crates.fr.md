# Crates

Les crates sont le pilier de la logistique CTLD. Vous demandez une crate dans une zone
logistique amie, vous la transportez là où elle est nécessaire, puis vous l'unpackez en un
véhicule, un système de défense anti-aérienne ou une structure FARP/FOB. Cette page couvre les
actions sur les crates que vous pilotez depuis le cockpit : loading, drop, unpack, listing et
packing.

Tout se trouve sous **F10 → CTLD → Crate Commands**. Ce que vous pouvez ramasser, spawner et
assembler provient du crate catalogue configuré par votre mission maker — voir
[Crate catalogue](../mission-maker/crates-catalogue.md).

## Visibilité du menu — au sol ou en vol

Le sous-menu **Crate Commands** est contextuel : les entrées apparaissent ou disparaissent
automatiquement selon que vous êtes au sol ou en vol, et selon les capacités de votre
aéronef. Vous ne voyez jamais une action que vous ne pouvez pas utiliser sur le moment.

| État | Entrées visibles |
| --- | --- |
| **Au sol** | Load Crate · Drop Crate(s) · Unpack Crate · List Nearby Crates · Pack Equipt |
| **En vol** | Parachute Crates · Release Slingload · Cut Slingload |

- **Load Crate** n'apparaît que si votre mission utilise le loading par menu. Si votre mission
  s'appuie plutôt sur le ramassage en vol stationnaire, vous chargez en survolant en hover —
  voir [Sling-load](slingload.md).
- **Pack Equipt** n'apparaît que lorsqu'un véhicule packable ou une scène FARP se trouve à
  proximité.
- **Parachute Crates** n'apparaît que lorsque votre aéronef peut effectuer un air-drop et que
  vous avez effectivement des crates CTLD à bord — voir [Parachute](parachute.md).
- **Release Slingload** et **Cut Slingload** n'apparaissent que lorsque votre aéronef peut
  faire du sling-load et qu'un sling-load virtuel est actif — voir [Sling-load](slingload.md).

## Load Crate

**Utilité :** Attache une crate proche à votre transport pour que vous puissiez la porter.

**Fonctionnement :** Posez-vous à côté de la crate. Crate Commands liste tous les types de
crates dans un rayon de 50 m, regroupés par catégorie avec un compteur (par ex.
`M1043 HMMWV Armament (2)`). Choisissez un type et la crate correspondante la plus proche est
chargée, dans la limite de la capacité `maxCratesOnboard` de votre aéronef. Si rien n'est à
portée, vous voyez `No crates within 50m` ; si vous êtes en vol, on vous demande de vous poser
d'abord.

**Activation :** F10 → CTLD → Crate Commands → Load Crate → *[type de crate]*

> Le loading par menu est l'une des deux méthodes de ramassage. L'autre est le ramassage en
> hover (maintenir un vol stationnaire stable au-dessus de la crate), décrit dans
> [Sling-load](slingload.md).

## Drop Crate(s)

**Utilité :** Repose au sol toutes les crates CTLD que vous transportez.

**Fonctionnement :** Au sol, cette action décharge d'un coup toutes les crates gérées par CTLD
présentes à bord, réparties devant l'aéronef. On vous indique combien ont été déposées et à
quelle position horaire. Si vous êtes en vol, on vous demande de vous poser d'abord ; si vous
ne transportez rien, on vous indique qu'il n'y a rien à déposer.

**Activation :** F10 → CTLD → Crate Commands → Drop Crate(s)

## Unpack Crate

**Utilité :** Consomme un ensemble complet de crates et déploie son contenu : un véhicule, un
système de défense anti-aérienne ou une structure FARP/FOB.

**Fonctionnement :** Au sol, Crate Commands liste chaque crate set dans un rayon de 300 m
disposant d'assez de crates pour être assemblé, en affichant la progression sous la forme
`count/required` (par ex. `2/3`). Sélectionner une entrée détruit les crates et spawn le
véhicule à faible distance. Certaines catégories nécessitent plusieurs crates du même type
(`cratesRequired`) ; tant que vous n'en avez pas rassemblé assez, l'ensemble apparaît comme
incomplet et ne peut pas être unpacké. Si aucun ensemble n'est complet, vous voyez
`No complete crate sets nearby`.

**Activation :** F10 → CTLD → Crate Commands → Unpack Crate → *[crate set]*

**Conditions :** Au sol, avec le nombre requis de crates correspondantes dans un rayon de
300 m.

## List Nearby Crates

**Utilité :** Affiche un relevé de toutes les crates dans un rayon de 300 m sans rien toucher.

**Fonctionnement :** Les crates sont regroupées par type et affichées sous la forme
`count/required`, marquées `READY` lorsqu'un ensemble est complet ou `incomplete` sinon — un
moyen rapide de vérifier ce que vous pouvez unpacker avant de vous engager. S'il n'y a rien à
portée, vous voyez `No crates within 300m`.

**Activation :** F10 → CTLD → Crate Commands → List Nearby Crates

## Pack Equipt

**Utilité :** Transforme un véhicule déployé ou une scène FARP en crates que vous pouvez
emporter.

**Fonctionnement :** Au sol, Pack Equipt liste les véhicules packables et les scènes FARP
proches de vous ; en choisir un le reconvertit dans le bon nombre de crates au sol. Le
sous-menu est masqué lorsque rien de packable n'est à proximité.

**Activation :** F10 → CTLD → Crate Commands → Pack Equipt → *[véhicule ou FARP]*

> Le packing a sa propre page couvrant en détail les véhicules et les scènes FARP/FOB — voir
> [Pack](pack.md). La demande et le loading de véhicules entiers sont sur
> [Vehicles](vehicles.md).

## Actions en vol

Celles-ci apparaissent une fois que vous volez, et uniquement si votre aéronef les prend en
charge :

- **Parachute Crates** — air-drop de toutes les crates CTLD à bord par parachute virtuel. Voir
  [Parachute](parachute.md).
- **Release Slingload** / **Cut Slingload** — déposer ou larguer une crate ramassée en hover.
  Voir [Sling-load](slingload.md).
