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

## ctld-tools — `unit:` et `group:` manquants dans le schéma

Le lot CTLD-TOOLS-MM-UX a mis dans `src/CTLD_config_schema.yaml` les **familles** (section
`families:` : `label` + `description` bilingues + `order`) et un **`label:` bilingue par réglage**
(137 entrées). Restent deux métadonnées dérivées côté frontend :

- l'**unité**, extraite du texte de la `description` (`(m)`, `(kg)`, `(seconds)`) — fiable mais
  indirect, et muette pour les réglages sans description. Un champ `unit:` serait explicite ;
- la **famille** des ~44 réglages sans `group:`, dérivée du nom de la clé (`familyOf`). Ça réduit la
  famille fourre-tout `Other` de ~44 à 7, donc le gain restant est surtout cosmétique.

Converge avec « générer les tableaux de config de la doc depuis le schéma » : mêmes métadonnées, même
source. Le vrai reste-à-faire coûteux, ce sont les **descriptions** des ~44 réglages non documentés
(les inventer serait contraire à la règle zéro-supposition).

## CHANGELOG — réorganiser `[Unreleased]` avant la 2.0.0 stable

Soulevé par Zip le 2026-08-09 en constatant qu'aucune release candidate n'a de section à elle.
C'est **voulu** et documenté (`docs/developer/workflow.md` : une rc laisse `[Unreleased]` ouverte,
seule une stable la gèle en `## [x.y.z] — date`), et ça reste le bon modèle : une rc est une étape
vers la 2.0.0, pas une version livrée, et découper en `[2.0.0-rc1]`…`[2.0.0-rcN]` obligerait un
lecteur à recoller sept sections pour savoir ce que la 2.0.0 apporte. Les notes de chaque rc, elles,
vivent déjà sur sa page GitHub.

L'effet de bord, lui, est réel : `[Unreleased]` a dépassé **1450 lignes**, tout ce qui s'est
accumulé depuis la 2.0.0 du 6 juillet, empilé par lot dans l'ordre d'arrivée. Le jour du tag stable,
ce bloc se fige tel quel et devient la section de référence de la version — donc le moment de le
réorganiser est **avant** le tag, pas après.

Pistes à instruire (aucune tranchée) : regrouper par thème plutôt que par ordre d'arrivée
(Added / Changed / Fixed à la « Keep a Changelog », ou par domaine CTLD : troupes, caisses, JTAC,
outil…) ; fusionner les entrées qui se corrigent l'une l'autre entre deux rc, un lecteur de la
2.0.0 n'ayant que faire d'un bug introduit puis corrigé avant publication ; décider si le détail
d'implémentation (noms de fonctions, numéros de PR) a sa place dans un fichier lu par des mission
makers, ou s'il redescend d'un cran.

À faire pendant la préparation de la release stable, pas avant : chaque lot mergé d'ici là y ajoute
des lignes.

<!-- TOOLING-I18N-CLAUDE-CODE-TRANSLATE — formalisé en lot `.backlog/TOOLING-I18N-CLAUDE-CODE-TRANSLATE/` (grill-with-docs, 2026-08-10, ADR 0014). -->

## TOOLING — `i18n_dict_utils.py` ne distingue pas une entrée `-- STALE:` d'une entrée live

Contexte (trouvé pendant `FIX-I18N-DEBT-REPAYMENT`, 2026-08-10) : le regex de
`tools/build/i18n_dict_utils.py`'s `parse_dict`/`_ENTRY_RE` matche `ctld.i18n["lang"]["key"] =
"..."` peu importe si la ligne est commentée par un préfixe `-- STALE: ` (marqueur de
`generate_i18n_dicts.ps1 -Apply` pour une clé qui n'est plus référencée dans `src/`). Conséquence
vécue : sur les 93 stubs KO / 78 ES comptés au merge de `FIX-I18N-DICT-GUARD`, 23 / 8 étaient en
réalité des clés `-- STALE:` dans `CTLD_i18n_en.lua` — `translate_i18n.py` les aurait traduites
(appels API gaspillés) et écrites dans des lignes déjà mortes (`_apply_translations`'s regex ne
distingue pas non plus). `check_i18n_diff.py` hérite du même gap via le même parseur partagé.

Piste : `parse_dict`/`parse_keep_en` (et tout appelant) devraient ignorer les lignes dont la version
strippée commence par `--`. Repéré aussi : `CTLD_i18n_ko.lua`/`_es.lua` ont des clés vides que
`CTLD_i18n_en.lua` marque déjà `-- STALE:` mais que `ko`/`es` eux-mêmes n'ont pas encore marquées
ainsi (dérive entre dictionnaires).

**À traiter dans ce lot, pas seulement le symptôme parseur** : remonter à la cause de cette dérive
avant de corriger uniquement `parse_dict` — sans quoi le patch du parseur masque le problème plutôt
que de le résoudre. Hypothèse à vérifier en premier : `generate_i18n_dicts.ps1`'s marquage `STALE`
scanne-t-il et applique-t-il le préfixe aux 4 dictionnaires (en/fr/es/ko) dans la même passe, ou
traite-t-il chaque fichier indépendamment avec un risque de désynchronisation (ex. un seul fichier
mis à jour lors d'un run partiel, ou un ordre de traitement qui laisse certains fichiers en
retard) ? Si le marquage est censé être atomique/uniforme et ne l'est pas, c'est un bug dans le
script à corriger en même temps que le parseur — pas seulement documenter le symptôme.
