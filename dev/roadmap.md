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

## ctld-tools — dépréciation du companion asset-check

Contexte (émergé du grill TUI). Deux points liés à l'origine ; le premier est réglé :
1. ~~`ctld-tools validate` ne vérifie un `unit` que contre le **datamine stock**, ignorant les
   `modTypes` déclarés par le MM~~ — **fait**, livré par `FIX-VALIDATE-MODTYPES` (PR #87) :
   `validate.py` résout désormais `datamine ∪ modTypes` (constaté le 2026-08-10, vérification
   roadmap).
2. Le **companion asset-check** (`tools/companion/asset_check.lua`) fait exactement la même
   validation (même datamine stock + `modTypes`), mais **dans DCS après coup** → largement
   **redondant** avec `ctld-tools`, maintenant que (1) est fait. À déprécier/retirer. Résidu
   couvert : les types **injectés au runtime** (scènes de plugins) que le design-time ne voit pas —
   marginal, et rattrapé par le test-en-DCS. `logDefaults` reste (debug power-user). Décision David
   (2026-07-20) : pas maintenant, à faire en lot séparé.

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

<!-- FEAT-MOVING-ZONE — déjà livré, PR #49 (archive/FEAT-MOVING-ZONE.md). Cette entrée dupliquait
     un lot déjà mergé et est retirée (constaté le 2026-08-10, vérification roadmap :
     trigger.misc.getZone() bien utilisé dans src/CTLD_zone.lua et ailleurs). -->

---

<!-- STARTUP-REPORT-UNIFIED — formalisé en lot `.backlog/STARTUP-REPORT-UNIFIED/` (grill-with-docs, 2026-07-21). -->

<!-- FIX-I18N-DICT-SYNC — formalisé en lot `.backlog/FIX-I18N-DICT-SYNC/` (grill-with-docs, 2026-07-22). Livré PR #57. -->
<!-- ctld-tools — i18n FR de l'interface web : livré (lot CTLD-TOOLS-MM-UX, ticket 11). -->

---

<!-- ctld-tools — unit:/group: manquants dans le schéma : apparemment déjà livré (constaté le
     2026-08-10, vérification roadmap — pas de lot dédié identifié dans .backlog/README.md, donc
     probablement fait en marge d'un autre lot sans mise à jour de cette entrée).
     `src/CTLD_config_schema.yaml` porte désormais un champ `unit:` explicite (67 réglages) et
     `web/src/lib/labels.ts` le lit en priorité avant l'extraction depuis la `description` ; `web/
     src/lib/families.ts`'s `familyOf()` dérive une famille par nom de clé avec `OTHER_FAMILY`
     comme résidu irréductible (confirmé par families.test.ts) — exactement le mécanisme
     initialement proposé ici. Résiduel non couvert : les descriptions des ~44 réglages non
     documentés (les inventer serait contraire à la règle zéro-supposition) — pas un candidat de
     lot en soi, juste une dette de documentation qui traînera tant que personne ne les écrit. -->

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

<!-- TOOLING — i18n_dict_utils.py ne distingue pas une entrée -- STALE: d'une entrée live —
     formalisé en lot `.backlog/FIX-I18N-STALE-COMMENT-PARSING/` (grill-with-docs, 2026-08-10).
     Pas d'ADR (bug factuel, pas de trade-off de conception). -->
