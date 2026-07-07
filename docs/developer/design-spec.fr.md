# Design spec

Cette page constitue la **justification de conception** de CTLD v2 — le *pourquoi* derrière
l'architecture, non le *comment*. Elle consigne les objectifs que la réécriture s'est fixés et les
décisions prises pour les atteindre. Pour la forme concrète du code — organisation du dépôt, l'idiome
manager/singleton, la séquence d'initialisation et les bibliothèques internes — voir
[Architecture](architecture.md) ; pour la surface publique de chaque manager, voir la
[référence de l'API](api-reference.md).

Lorsqu'une décision ci-dessous est formellement consignée sous forme d'Architecture Decision Record,
le numéro d'ADR est cité afin que le raisonnement durable et ses alternatives puissent être retracés
dans `dev/adr/`.

## D'où vient CTLD v2

Le CTLD original (Combat Troop and Logistics Drop) est un unique fichier Lua procédural d'environ
12 000 lignes. Il fonctionne, et il constitue la **référence fonctionnelle** de la réécriture — le
monolithe est conservé en lecture seule sous `migration/source/` et toute modification v2 doit
préserver un comportement en jeu identique, sauf si une déviation est explicitement demandée.

Mais en tant qu'espace de noms unique et plat, il est difficile à appréhender, difficile à tester de
façon isolée, et difficile à étendre sans risquer des régressions ailleurs. CTLD v2 est une réécriture
modulaire et testable qui conserve ce comportement tout en donnant à chaque domaine fonctionnel sa
propre frontière.

## Objectifs de conception

| Objectif | Ce que cela signifie | Comment il est atteint |
| --- | --- | --- |
| **Legacy parity** | Reproduire chaque fonctionnalité v1 ; comportement en jeu identique par défaut | `migration/source/` est la référence immuable ; les déviations se font sur option |
| **Modularity** | Un domaine fonctionnel par classe, avec des dépendances explicites | Pattern Manager + Entity, une classe par fichier sous `src/` |
| **Maintainability** | Du code qui reste lisible à mesure qu'il grandit | Budgets de taille : `CTLDCoreManager` sous ~500 lignes, chaque classe sous ~800 |
| **Testability** | Une logique qui peut être exercée sans mission en cours d'exécution | Modules Lua 5.1 purs chargés sous busted avec des stubs DCS |
| **Reproducible deliverable** | Un seul fichier à livrer, construit de la même manière à chaque fois | Fusion PowerShell de `src/` en un unique `CTLD.lua` |
| **Room to grow** | Du contenu nouveau sans éditer les fichiers du cœur | Moteur de scènes piloté par les données, scènes auto-enregistrées, menus dynamiques |

Ces objectifs contraignent l'exécution : tout doit tourner à l'intérieur du DCS Scripting Engine en
**Lua 5.1**, en utilisant uniquement l'API de scripting officielle du simulateur.

## Décisions de conception fondamentales

### Source modulaire, livrable unique (ADR 0001)

CTLD est livré comme un seul fichier parce que c'est ce qu'un mission maker charge. Développer dans un
seul fichier est précisément le problème que la réécriture entend résoudre. La conception sépare les
deux préoccupations : la rédaction se fait dans `src/` (une classe par fichier, les fondations dans
`src/core/`, les données de scènes dans `src/scenes/`, les shims v1 dépréciés dans `src/legacy/`) ;
un build PowerShell sous `tools/build/` concatène ces fichiers dans un ordre de dépendances fixe pour
produire `CTLD.lua`.

L'ordre de build fait autorité — les fondations d'abord, puis les domain managers, puis les scènes,
puis l'orchestrateur `CTLD_core.lua`, puis les legacy shims, la configuration utilisateur étant fusionnée
en dernier afin qu'elle puisse tout surcharger. `CTLD.lua` est un artefact généré et n'est jamais
édité à la main. Voir [Architecture](architecture.md) pour l'organisation et
[Building & testing](building-and-testing.md) pour le pipeline.

### Objets Manager + Entity (ADR 0002)

Chaque domaine est modélisé comme une paire : une classe **Entity** décrivant une chose unique
(`CTLDCrate`, `CTLDTroopGroup`, `CTLDVehicle`, `CTLDBeacon`, `CTLDJTAC`, `CTLDPlayer`,
`CTLDTroopZone`, `CTLDLogisticZone`, `CtldScene`) et un **Manager** singleton qui détient le registre
et la logique du domaine (`CTLDCrateManager`, `CTLDTroopManager`, …). Les entities sont instanciées
N fois ; les managers existent une seule fois et sont atteints via `getInstance()`.

Cette séparation garde l'état là où il doit être — les données par chose sur l'entity, la politique
transversale sur le manager — et rend chaque manager testable indépendamment. Le système de classes
lui-même est un micro-framework minimal à héritage simple (`X = class()`) ; l'idiome et la factory de
singleton sont décrits dans [Architecture](architecture.md). La gestion des
coalition est unifiée entre les managers plutôt que réinventée par domaine.

### Une couche utilitaire maison plutôt que MIST (ADR 0003)

Le script v1 s'appuyait sur MIST pour le spawn, la géométrie et les helpers. La v2 abandonne cette
dépendance au profit d'une petite couche utilitaire maison (`ctld.utils.*`, adossée à
`src/CTLD_utils.lua`). La motivation est le contrôle et l'empreinte : CTLD a besoin d'une poignée bien
définie de helpers (`dynAddStatic`, `dynAddGroup`, géométrie, allocation d'identifiants uniques, dessin
F10), et les posséder évite de livrer et de suivre en version une grande bibliothèque externe à
l'intérieur du livrable unique. Des appels tels que l'ancien `mist.dynAddStatic()` dans la scène du
champ de mines sont remplacés par `CTLDUtils.dynAddStatic()`.

### Une couche de compatibilité legacy (ADR 0004)

Les missions v1 existantes appellent l'ancienne API procédurale. Pour laisser ces missions tourner sur
la v2 sans être réécrites, de fins shims délégants vivent dans `src/legacy/legacy_api.lua` et
transfèrent aux nouveaux managers. Ils sont dépréciés par conception — une aide à la migration, non une
surface supportée. Le chemin de migration et un exemple travaillé sont dans
[Migration v1 → v2](migration-v1-v2.md).

### Un seul verbe de packing : « pack » (ADR 0005)

La v1 utilisait deux verbes différents pour la même opération vehicle-to-crate, ce qui prêtait à
confusion tant pour les utilisateurs que pour le code. La v2 unifie autour d'un seul verbe, **pack**,
de manière cohérente à travers les clés de config, les libellés du menu F10, les noms de méthodes et les
commentaires. C'est une convention à l'échelle du projet, non le simple renommage d'une fonction.

## Dépendances en couches

Les managers forment un empilement de couches de dépendances plutôt qu'un maillage : les fondations
sans dépendances (config, i18n, le registre d'objets) tout en bas, les domain managers au milieu, et
`CTLDCoreManager` comme orchestrateur au sommet. `CTLDPlayerManager` se situe juste sous le cœur car il
se déploie vers chaque manager fonctionnel lorsqu'il construit les menus d'un joueur.

Le but de cet empilement est de garder l'ordre d'initialisation bien défini et de prévenir les
dépendances circulaires : un manager peut dépendre de ceux en dessous de lui, jamais de ceux au-dessus.
L'ordonnancement concret et la séquence d'init par phases sont documentés dans
[Architecture](architecture.md) ; cette page n'énonce que le principe qui
la sous-tend.

## Le moteur de scènes

Les constructions physiques — FARPs, FOBs, champs de mines, systèmes AA multi-crate — constituent la
partie de CTLD la plus susceptible de grandir. La conception isole cette croissance derrière un
**moteur de scènes piloté par les données** de sorte qu'ajouter du contenu nouveau ne signifie jamais
éditer la logique du cœur.

- Une **scène** est un fichier de données sous `src/scenes/` : un modèle nommant les objets à spawn,
  leurs positions relatives (offsets polaires depuis l'unité déclencheuse), les délais par étape et
  d'éventuels callbacks post-spawn. `CTLDSceneManager` est le registre des modèles ; `CtldScene` est
  une instance de déploiement en cours d'exécution.
- Les descripteurs de spawn d'objets sont détenus dans `CTLDObjectRegistry`
  (`src/core/CTLD_objectRegistry.lua`), qui stocke des **descripteurs, non des instances**. Les scènes
  enregistrent leurs composants au moment du chargement via un appel register-if-absent, de sorte que
  plusieurs scènes peuvent partager sans risque le même descripteur.
- **Self-registration** : un fichier de scène s'enregistre auprès de `CTLDSceneManager` à sa dernière
  ligne, si bien que le simple ajout du fichier au build rend la scène disponible — aucune table
  centrale à éditer.
- **Auto-injection** : `CTLDCrateManager` parcourt les modèles de scènes enregistrés et injecte
  automatiquement le crate de chaque scène dans le menu des crate. Une nouvelle scène apparaît comme un
  crate requérable sans entrée dans la configuration.

Les systèmes AA multi-crate (HAWK, Patriot, NASAMS, BUK, KUB, S-300) suivent le même principe : leur
assemblage physique est délégué au moteur de scènes, tandis que `CTLDCrateAssemblyManager` détient le
registre à l'exécution des systèmes assemblés, la logique de rearm/repair et les limites par coalition.
Les templates de systèmes AA sont portés **inline** dans `src/CTLD_aasystem.lua` plutôt que comme des
fichiers de scène séparés. Le workflow de rédaction de scènes est couvert dans
[Scene engine](subsystems/scenes.md).

## Zones : séparation des préoccupations

La v1 avait un concept de zone générique unique assurant plusieurs tâches sans lien entre elles. La v2
le scinde selon ses responsabilités réelles :

| Préfixe | Entité | Rôle |
| --- | --- | --- |
| `TRZ_` | `CTLDTroopZone` | Objectif de pickup + extraction de troops (remplace les zones pickup/extract de la v1) |
| `WPZ_` | `CTLDTroopZone` | Zone de waypoint — les troops déployées marchent vers son centre |
| `LGZ_` | `CTLDLogisticZone` | Point logistique pour les requêtes de crate et le spawn de véhicules |

Deux décisions déterminent cette forme :

- **Une logistic zone est une DCS trigger zone**, non une ancre liée à un objet statique comme en v1.
  Cela fait des zones des entités de plein droit de l'éditeur de mission et permet à un FOB de
  s'enregistrer lui-même comme logistic zone dynamique à l'exécution.
- **L'unpack est autorisé partout.** La restriction v1 « suffisamment loin d'une logistic zone » est
  supprimée ; un crate peut être unpack là où il est déposé. Cela simplifie le modèle mental pour les
  pilotes et supprime une catégorie de refus déroutants.

Les préfixes de zone hérités sont toujours reconnus pour les missions non migrées mais sont dépréciés.
Le schéma de nommage complet, les champs et les validations vivent dans la documentation mission-maker.

## Refonte du transport de véhicules (EVO-09)

Le changement de conception comportemental le plus significatif est la manière dont les véhicules se
déplacent. La v1 offrait un chargement *virtuel* de véhicule depuis une pickup zone — un contournement
d'une époque où DCS n'avait pas de load/unload de cargo natif et où CTLD n'avait pas de fonctionnalité
pack. Ces deux éléments existent désormais, donc le contournement est retiré.

Le redesign trace une ligne nette :

- **Les pickup zones portent uniquement des troops.** Les variables et fonctions génératrices du
  transport virtuel de véhicules sont supprimées.
- **Les véhicules sont pré-placés sur la carte** par le mission maker comme des unités DCS ordinaires.
  Ce qui est placé est ce qui est disponible — le mission maker contrôle directement la quantité, ce qui
  est plus réaliste qu'un pool synthétique.

Deux workflows de transport remplacent l'ancien :

```
Workflow A — direct load  (aircraft with native dynamic cargo, e.g. C-130)
  vehicle on map → native DCS load → native DCS unload

Workflow B — pack / unpack  (vehicle too heavy or bulky for direct load)
  vehicle on map → pack (object destroyed, N crates spawned)
                 → load  (native DCS or CTLD menu)
                 → unload (native DCS or CTLD menu)
                 → unpack (crates destroyed, vehicle respawned)
```

`CTLDVehicleSpawner` détient exclusivement le Workflow B ; le Workflow A est géré nativement par DCS
sans aucune intervention de CTLD. Scinder un véhicule en N crates est délibéré — cela permet à
plusieurs aircraft de coopérer, chacun portant une partie de la charge.

## Menus dynamiques construits selon le contexte

Chaque classe fonctionnelle construit son propre bloc de menu F10 via une méthode `buildMenu(player)`
plutôt qu'un constructeur de menu central assemblant l'ensemble. Le player manager crée le menu racine
CTLD et délègue chaque bloc au manager qui le détient, conditionné par la config de ce domaine et par
les capacités de l'aircraft (transport ou non, capacité à porter des véhicules). Garder la construction
du menu à côté de la logique qu'il expose signifie que le menu d'un domaine ne peut jamais dériver hors
synchronisation avec ce que le domaine supporte réellement.

Les menus sont aussi construits **à la demande** là où les options disponibles sont contextuelles. La
commande statique « Unpack Crate » de la v1 est remplacée par **Unpack Any Crate**, un sous-menu
reconstruit au moment du clic à partir des crate réellement proches de l'aircraft (EVO-01). Les seuils
de pagination des menus et l'arbre F10 complet sont détaillés dans
[F10 menu system](subsystems/menu.md).

## Accès à la config et à l'i18n

Deux conventions maintiennent l'accès transversal uniforme et en lecture seule :

| Raccourci | Se développe en | Usage |
| --- | --- | --- |
| `ctld.gs("param")` | `CTLDConfig.getInstance():getSetting("param")` | Lire une valeur de configuration |
| `ctld.tr("key", ...)` | `CTLDi18n.getInstance():translate("key", ...)` | Traduire une chaîne d'affichage |

La configuration est **en lecture seule à l'exécution** et toujours atteinte via `ctld.gs(...)` ; les
managers n'appellent jamais `config:getSetting()` directement et ne mutent jamais la config. Chaque
chaîne visible par l'utilisateur passe par `ctld.tr(...)` afin que les quatre langues livrées restent
alignées. Le modèle d'internationalisation est décrit dans [Internationalisation](i18n.md).

## Pour aller plus loin

- [Architecture](architecture.md) — organisation, idiome manager/singleton, séquence d'init, bibliothèques internes
- [Subsystems](subsystems/index.md) — scènes, crate, zones, menus et le reste du détail des domaines
- [API reference](api-reference.md) — les méthodes publiques de chaque manager
- [Migration v1 → v2](migration-v1-v2.md) — la couche de compatibilité legacy en pratique
