# Roadmap — CTLD

Registre d'idées futures non encore formalisées en lots backlog. Format minimal : titre + contexte.
Avant toute création de lot, vérifier si l'idée est déjà ici et formaliser depuis l'entrée existante.
Chemin vers la formalisation : `grill-with-docs` → `to-prd` → `to-issues`.

---

## AA System → Scenes — Remplacer CTLDCrateAssemblyManager par des scènes

Contexte: analyser si la mécanique AA system (`CTLD_aasystem.lua` / `CTLDCrateAssemblyManager`)
peut être remplacée par des scènes pilotées par `CTLDSceneManager`. Les scènes gèrent déjà le
spawn ; la question porte sur la mécanique d'*assembly* (construction progressive depuis des
caisses) : absorbable par les scènes, ou couche séparée inévitable ?

<!-- ctld-tools — injection .miz automatique : livré (lot CTLD-TOOLS-MIZ-INJECT, PR #50). -->

## ctld-tools — validation `modTypes` + dépréciation du companion asset-check

Contexte (émergé du grill TUI) : deux points liés.
1. `ctld-tools validate` ne vérifie un `unit` que contre le **datamine stock** — il ignore les
   `modTypes` déclarés par le MM, donc un type de **mod légitime** est signalé « unknown » à tort.
   À corriger : valider `unit ∈ datamine ∪ (modTypes du user-config)`.
2. Le **companion asset-check** (`dist/CTLD_asset_check.lua`, `tools/companion/`) fait exactement la
   même validation (même datamine stock + `modTypes`), mais **dans DCS après coup** → largement
   **redondant** avec `ctld-tools`. Une fois (1) fait, le déprécier/retirer. Résidu couvert : les
   types **injectés au runtime** (scènes de plugins) que le design-time ne voit pas — marginal, et
   rattrapé par le test-en-DCS. `logDefaults` reste (debug power-user). Décision David (2026-07-20) :
   pas maintenant, à faire en lot séparé.

<!-- ctld-tools — mode TUI interactif : livré (lot CTLD-TOOLS-TUI, PR #52). -->

## ctld-tools — générer les tableaux de config de la doc depuis le schéma

Les **descriptions** des settings (EN+FR) vivent désormais dans `src/CTLD_config_schema.yaml`
(seedées depuis `configuration(.fr).md`, lot CTLD-TOOLS-TUI-POLISH) et sont affichées + cherchables
dans la TUI. Il reste une **duplication** : les tableaux de settings de `docs/mission-maker/
configuration.md` / `.fr.md` répètent ces descriptions. Candidat lot : **générer** ces tableaux depuis
le schéma (le schéma est la source de vérité) pour supprimer la double maintenance.

<!-- DEV-LOCAL-MIZ — formalisé en lot `.backlog/DEV-LOCAL-MIZ/` (grill-with-docs, 2026-07-19). -->

_(Note post-formalisation : le constat « chemins absolus… `dcs-bridge.lua` » était partiellement
inexact — `dcs-bridge.lua` est embarqué dans le miz, pas chargé par chemin ; seul `CTLD.lua` était
un chemin machine. Détail dans le PRD.)_

---

## FEAT-MOVING-ZONE — Zones logistiques ancrées sur une Moving Zone DCS

Contexte : DCS permet d'attacher une trigger zone à une unité (Moving Zone, configurée dans le ME).
La zone suit l'unité en jeu ; `trigger.misc.getZone(name)` retourne sa position courante.

CTLD ne tire pas parti de ce mécanisme : `_discoverLGZ()` lit la position depuis
`env.mission.triggers.zones` (snapshot statique du `.miz` au load) et ne la rafraîchit jamais.
Une LGZ_ attachée à un véhicule dans le ME se comporterait donc comme une zone fixe.

Solution identifiée : stocker le nom DCS de la zone dans `CTLDLogisticZone` au lieu de
snapshoter `_center`, et interroger `trigger.misc.getZone(name)` dans `getCenter()` à chaque
appel. Le mécanisme `linkedUnit` (logisticUnits legacy) resterait inchangé et coexisterait.

Bénéfice MM : une LGZ_ attachée à un camion logistique ou un navire dans le ME suffit — sans
passer par la config `logisticUnits`. La zone logistique suit le véhicule en mouvement.

---

<!-- STARTUP-REPORT-UNIFIED — formalisé en lot `.backlog/STARTUP-REPORT-UNIFIED/` (grill-with-docs, 2026-07-21). -->

<!-- FIX-I18N-DICT-SYNC — formalisé en lot `.backlog/FIX-I18N-DICT-SYNC/` (grill-with-docs, 2026-07-22). Livré PR #57. -->
## ctld-tools — i18n FR de l'interface web

Le backend a déjà une couche i18n EN+FR (`ctld_tools/i18n.py`, catalogues JSON, `--lang` /
`CTLD_LANG`) utilisée par les messages de validation. L'**interface web**, elle, est en anglais
seulement. Pour un MM francophone peu technique, c'est la dernière marche.

Préparé par le lot CTLD-TOOLS-MM-UX : toutes les chaînes visibles sont centralisées dans
`tools/ctld-tools/web/src/lib/strings.ts` (objet `UI`), et les libellés de réglages sont dérivés dans
`labels.ts`. La bascule est donc mécanique : exposer la langue courante via `/api/schema` (ou un
`/api/lang`), servir `UI` depuis un catalogue, et prendre `description.fr` au lieu de `description.en`.

---

## ctld-tools — enrichir `CTLD_config_schema.yaml` (group / label / unit)

Le lot CTLD-TOOLS-MM-UX place deux métadonnées de présentation **dans le frontend**, faute de mieux :

- le **libellé** lisible d'un réglage, dérivé du nom de la clé (`humanize` + table d'overrides) ;
- la **famille** des ~44 réglages pour lesquels le schéma n'a pas de `group:`, dérivée du nom de la
  clé (`familyOf`), ce qui réduit la famille fourre-tout `Other` de ~44 à 7 réglages.

C'est un contournement assumé : la vraie source de vérité est `src/CTLD_config_schema.yaml`. Le lot
candidat consiste à y ajouter les `group:` manquants + de vrais champs `label:` et `unit:` (bilingues),
puis à faire consommer ça par l'UI et à supprimer les heuristiques. Ça converge avec l'entrée
« générer les tableaux de config de la doc depuis le schéma » : mêmes métadonnées, même source.

Attention : cela demande d'**écrire** les descriptions/libellés des 44 réglages non couverts (les
inventer serait contraire à la règle zéro-supposition) — donc un vrai lot, pas un coup de sed.
