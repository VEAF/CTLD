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
<!-- ctld-tools — i18n FR de l'interface web : livré (lot CTLD-TOOLS-MM-UX, ticket 11). -->

---

## ctld-tools — `label:` et `unit:` par réglage dans le schéma

Le lot CTLD-TOOLS-MM-UX a mis les **familles** dans `src/CTLD_config_schema.yaml` (section
`families:` : `label` + `description` bilingues + `order`). Restent deux métadonnées dérivées côté
frontend, faute de source :

- le **libellé** d'un réglage, dérivé du nom de la clé (`humanize` + petite table d'overrides) — donc
  **toujours en anglais**, même quand l'UI est en français. C'est la principale limite de l'i18n
  livrée : un MM francophone voit un nom anglais, une description française, et la clé brute ;
- l'**unité**, extraite du texte de la `description` (`(m)`, `(kg)`, `(seconds)`) — fiable mais
  indirect ; un champ `unit:` serait explicite.
- la **famille** des ~44 réglages sans `group:`, dérivée du nom de la clé (`familyOf`). Ça réduit la
  famille fourre-tout `Other` de ~44 à 7, donc le gain restant est surtout cosmétique.

Le lot candidat : ajouter `label:` (bilingue) et `unit:` par réglage, + les `group:` manquants, puis
faire consommer ça par l'UI et retirer les heuristiques. Converge avec « générer les tableaux de
config de la doc depuis le schéma » : mêmes métadonnées, même source.

Attention au volume : ~136 libellés bilingues à **écrire** (les inventer serait contraire à la règle
zéro-supposition). C'est un vrai lot d'écriture, pas un coup de sed.
