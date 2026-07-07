# JTAC

Un JTAC (Joint Terminal Attack Controller) est une unité au sol ou aéroportée qui repère les
cibles ennemies et les illumine pour vous et votre patrouille — en posant une tache laser et un
pointeur IR sur tout ce qu'elle voit. Une fois déployé, un JTAC CTLD travaille de manière
autonome : il balaie à la recherche de l'ennemi le plus proche en ligne de vue, allume le laser
et réacquiert une cible dès qu'une autre est détruite. Votre rôle de pilote consiste à en poser
un au sol (ou dans les airs) là où il peut voir le combat, puis à utiliser son menu F10 pour
gérer le lase et demander de la fumée ou une 9-line.

Tout ce qui suit se trouve sous **F10 → CTLD → JTAC**. Les entrées que vous voyez dépendent de
votre appareil (il doit être un transport), de votre position (posé dans une zone logistique) et
des JTAC actuellement actifs pour votre coalition.

## Request JTAC Equipment

**Utilité :** fait apparaître un véhicule ou un drone JTAC directement dans la zone logistique où
vous êtes stationné, prêt à être chargé et transporté. À utiliser lorsque vous voulez convoyer
vous-même un JTAC jusqu'à la ligne de front.

**Fonctionnement :** posez-vous dans une zone logistique active, puis ouvrez le sous-menu et
choisissez un type de JTAC. CTLD fait apparaître cette unité à côté de la zone ; à partir de là,
vous la chargez et la transportez comme n'importe quel autre cargo. Elle commence à laser
automatiquement une fois déchargée et installée à sa position.

**Activation :** F10 → CTLD → JTAC → Request JTAC Equipment → [type]

Le sous-menu **Request JTAC Equipment** est dynamique. Il ne liste des types que lorsque vous
êtes posé dans une zone logistique active ; si vous êtes en vol il affiche *Land near logistics
to request equipment*, et si vous êtes au sol mais hors de portée il affiche *No logistics in
range*. La liste se rafraîchit d'elle-même lorsque vous vous posez, décollez ou déployez une FOB.

Le sous-menu n'apparaît que lorsque les largages de JTAC sont activés (`JTAC_dropEnabled`), que
votre appareil est un transport et qu'au moins un type de JTAC est proposé à votre coalition. Les
types disponibles proviennent directement du catalogue de crates de la mission — voir
[JTAC crates](../mission-maker/crates-catalogue.md) pour la façon dont un mission maker les
configure.

## Déployer un JTAC depuis une crate

**Utilité :** livre un JTAC en transportant sa crate là où vous le souhaitez, puis en la
dépaquetant. À utiliser lorsque vous préférez élinguer ou transporter une crate plutôt que de
charger l'unité finie.

**Fonctionnement :** demandez la crate JTAC depuis une zone logistique de la même manière que
n'importe quelle crate, transportez-la jusqu'au point de largage, posez-la et dépaquetez-la.
L'unité JTAC apparaît à l'emplacement de dépaquetage et commence immédiatement à balayer à la
recherche de cibles.

**Activation :**

1. F10 → CTLD → Request Equipment → [zone logistique] → [catégorie] → [crate JTAC]
2. Transportez la crate jusqu'à la zone cible et larguez-la (F10 → CTLD → Crate Commands → Drop
   Crate(s)).
3. F10 → CTLD → Crate Commands → Unpack Crate

Les crates JTAC ne sont proposées ici que lorsque `JTAC_dropEnabled` est défini. Voir
[Crates](crates.md) pour le workflow complet des crates et
[JTAC crates](../mission-maker/crates-catalogue.md) pour les définitions de crates et de types.

## Piloter un JTAC déployé

**Utilité :** gérer chaque JTAC actif — vérifier son état, basculer son laser, affiner la tache,
demander de la fumée sur la cible ou demander une 9-line.

**Fonctionnement :** chaque JTAC actif de votre coalition obtient son propre sous-menu nommé
d'après son groupe, plus une commande partagée **JTAC Status** qui liste chaque JTAC, son état, sa
cible actuelle et son code laser. Les entrées propres à chaque JTAC sont contextuelles et
n'apparaissent que lorsque la fonctionnalité correspondante est activée dans la configuration de
la mission.

**Activation :**

- F10 → CTLD → JTAC → JTAC Status — liste tous les JTAC actifs, leurs cibles et leurs codes laser.
- F10 → CTLD → JTAC → [nom du groupe] → Lasing [deactivate] / Lasing [activate] — éteindre le
  laser (standby) ou le rallumer. Affiché lorsque `JTAC_allowStandbyMode` est activé.
- F10 → CTLD → JTAC → [nom du groupe] → Spot Corrections [activate] / Spot Corrections
  [deactivate] — basculer les corrections de tache laser. Affiché lorsque
  `JTAC_laseSpotCorrections` est défini.
- F10 → CTLD → JTAC → [nom du groupe] → Request Smoke on Target — marquer la cible lasée avec de
  la fumée pour un repérage visuel. Affiché lorsque `JTAC_allowSmokeRequest` est activé.
- F10 → CTLD → JTAC → [nom du groupe] → Request 9-Line — demander le briefing CAS 9-line. Affiché
  lorsque `JTAC_allow9Line` est activé.

Un JTAC déployé lase automatiquement sans aucune action de votre part : il accroche l'ennemi le
plus proche dans sa ligne de vue et sa portée de balayage, allume le laser et réacquiert la cible
suivante lorsque l'actuelle est détruite. Le libellé de l'entrée *Lasing* bascule pour refléter
l'état courant, de sorte que vous pouvez voir d'un coup d'œil si un JTAC est en train de laser
activement ou en standby.
