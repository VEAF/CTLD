# Roadmap — CTLD

Registre d'idées futures non encore formalisées en lots backlog. Format minimal : titre + contexte.
Avant toute création de lot, vérifier si l'idée est déjà ici et formaliser depuis l'entrée existante.
Chemin vers la formalisation : `grill-with-docs` → `to-prd` → `to-issues`.

---

<!-- ctld-tools — aiZones : troopStock/vehicleStock absents : formalisé en lot
     `.backlog/FIX-CTLD-TOOLS-AIZ-STOCK-GAP/`, mergé (PR #180, 4 tickets) — défaut troopStock
     asymétrique, validation WARNING dans validate.py, indicateur ⚠/ⓘ inline dans l'éditeur. -->

<!-- ctld-tools — mode « configuration seule » à l'installation : formalisé en lot
     `.backlog/FEAT-CTLD-TOOLS-CONFIG-ONLY-INSTALL/`, mergé (PR #174). -->

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

<!-- Parachutage — garde générale d'activation `enableParachuteDrop` : formalisé en lot
     `.backlog/FEAT-PARACHUTE-DROP-GATE/` (grill-with-docs, 2026-09-27, ADR 0019). Le point resté
     ouvert ici (quels points d'appel menu) est résolu : 5 sites inline (2 CTLD_crate.lua,
     1 CTLD_troop.lua, 2 CTLD_vehicle.lua), pas de mécanisme centralisé ni de helper partagé —
     voir l'ADR pour le raisonnement complet. -->

<!-- extractableGroups — détection automatique par convention de nommage EXTR_ : formalisé en lot
     `.backlog/FEAT-EXTR-GROUP-NAMING-CONVENTION/` (grill-with-docs, 2026-09-27). Le point resté
     ouvert ici (métadonnée dans le nom) est résolu : aucune, `EXTR_<name>` reste un préfixe nu —
     rien à configurer, la coalition est déjà lue en direct sur l'objet DCS. Nouveau terme
     CONTEXT.md "Auto-discovered group", sibling de "Auto-discovered zone". -->

<!-- Zones dynamiques — aucun rafraîchissement du menu F10 des joueurs déjà sur place : grillé le
     2026-09-28 avec "TRZ_ automatique" ci-dessous (couplés : toute TRZ_ auto-créée en cours de
     mission touche ce trou plus souvent qu'aujourd'hui), formalisé en lot
     `.backlog/FEAT-TRZ-DYNAMIC-OBJECT-AUTODISCOVERY/`. Conclusion : pas de calcul de portée
     géométrique — toute création/suppression dynamique de zone (troupe ou logistique) rafraîchit
     CTLDTroopManager:refreshMenuSection/CTLDCrateManager:refreshCrateFlightSection pour tous les
     joueurs transport au sol trackés, chaque fonction filtrant déjà elle-même par appartenance de
     zone. Un bug d'asymétrie trouvé en creusant la destruction d'ancre (bunker/convoi/navire) dans
     le même gril : une zone logistique linkedUnit est déjà réellement supprimée à la mort de son
     ancre, une zone de troupe équivalente (navire, camion) ne l'était jamais — unifié sur la
     suppression réelle pour les deux familles, voir ADR 0021. -->

<!-- luacheck n'est en réalité vérifié nulle part (ni local, ni CI) : formalisé en lot
     `.backlog/TOOLING-LUACHECK-CI-RATCHET/` (grill-with-docs, 2026-09-27). Résolu : nouveau job
     CI dédié avec un ratchet inversé (LUACHECK_WARNING_CEILING, démarre à 89, ne peut que baisser
     — miroir de COVERAGE_FLOOR), 0 erreur toujours bloquant. Hook local rendu visible (message
     une fois, marqueur simple dans .git/, jamais réinitialisé). Le nettoyage des 89 warnings
     eux-mêmes reste hors scope, candidat de lot séparé (détail de la dette toujours ci-dessous
     pour référence future — variables inutilisées/shadowing sur ~8 fichiers, 2 `if` vides dans
     CTLD_vehicle.lua, une négation simplifiable dans CTLD_jtac.lua, et le gros du volume dans
     legacy_api.lua où un paramètre `_préfixé` est en fait utilisé). -->

<!-- luacheck cleanup, Lot A — legacy_api.lua : formalisé en lot
     `.backlog/FIX-LEGACY-API-PARAM-PREFIX/`, mergé — 58 des 89 warnings corrigés (préfixe `_`
     retiré sur les 58 paramètres, tous réellement utilisés), plafond CI abaissé à 31. -->

## Native-cargo bbox-exit detection is unimplemented (`CTLDVehicleSpawner`)

Constaté en nettoyant les warnings `luacheck` restants (2026-09-27) : dans la boucle de détection
bbox (`CTLD_vehicle.lua`, autour de la ligne 733), la branche qui devrait détecter la **sortie**
d'un véhicule chargé nativement (`dcs_native`) de la zone de chargement est **entièrement
composée de commentaires** décrivant le mécanisme prévu — aucun code réel. L'entrée bbox (chargement)
fonctionne ; la sortie (déchargement natif détecté automatiquement) ne l'a jamais été.

Portée du gap, telle que décrite par les commentaires en place : un véhicule chargé en mode
`dcs_native` reste en état `LOADED` indéfiniment tant que rien ne détecte sa sortie — pas de
transition automatique vers un état de déchargement, contrairement au chemin `menu_ctld`
(chargement/déchargement explicites via le menu F10). Le commentaire suggère une piste : détecter
la réapparition de l'unité spawnée (un nouvel `isExist()` vrai) au tick suivant comme signal de
sortie (parachute ou débarquement au sol), mais rien de tout ça n'est implémenté ni vérifié.

Marqué `-- luacheck: ignore 542` sur place (pas de lot de nettoyage lint qui supprimerait
silencieusement l'intention documentée) — reste candidat de lot séparé si le besoin réel (un
véhicule `dcs_native` qui ne sort jamais formellement de l'état `LOADED`) est confirmé en jeu.

<!-- luacheck cleanup, Lot B — le reste (30 des 31 restants après le gap ci-dessus, ~9 fichiers) :
     formalisé en lot `.backlog/FIX-LUACHECK-REMAINING-WARNINGS/`, mergé — plafond CI abaissé à 0.
     Le nettoyage luacheck complet (89 → 0) est terminé ; le seul résidu (bbox-exit ci-dessus) est
     un gap de fonctionnalité documenté, pas une dette de lint. -->

<!-- TRZ_ automatique — création liée au spawn d'un objet (FOB, FARP, etc.) : demandé le 2026-08-26,
     grillé le 2026-09-28 avec "Zones dynamiques" ci-dessus, formalisé en lot
     `.backlog/FEAT-TRZ-DYNAMIC-OBJECT-AUTODISCOVERY/`. FOB/FARP hors périmètre final (mécanisme
     dédié déjà existant, troopPickupAtFOB/troopPickupAtFARP) ; le vrai besoin, confirmé par un cas
     concret (RV avec un convoi, un navire, ou un bunker/fortification statique pour embarquer/
     déposer des troupes) : auto-détection TRZ_<name>_<coalition>_<stock>_<flag>_<target> — syntaxe
     inchangée — sur un static, unit ou group quelconque, détection continue (init +
     S_EVENT_BIRTH, déjà prouvé fiable pour les trois types d'objets dans ce code), même chemin de
     résolution/construction que createTroopZoneAtObject, aucun réglage global (le nommage est déjà
     l'opt-in, cohérent avec EXTR_). Voir CONTEXT.md ("Auto-discovered zone", "Anchor") et ADR 0021
     pour le détail des décisions couplées. -->

<!-- Volet FOB formalisé/livré via FIX-FOB-TROOP-PICKUP (PR #136) ; volet FARP formalisé en lot
     `.backlog/FEAT-FARP-TROOP-PICKUP/` (grill-with-docs, 2026-08-26). Les deux couvrent l'idée
     d'origine (FOB, FARP) sans le réglage générique imaginé au départ — chaque cas réutilise le
     réglage/mécanisme le plus proche déjà existant plutôt qu'un système de sélection par
     type/convention. -->

<!-- Lien générique zone ↔ objet de référence (owner-triggered) — le volet "duplication d'ancrage
     entre CTLDTroopZone/CTLDLogisticZone" est formalisé en lot
     `.backlog/FIX-ZONE-ANCHOR-DUPLICATION/` (lancé directement en to-prd le 2026-09-27, sans grill
     dédié, sur instruction explicite). Le registre générique linkZonesToOwner/unlinkOwner que
     cette entrée proposait n'est PAS construit : FEAT-FARP-TROOP-PICKUP a confirmé que le FARP
     (le seul second candidat "propriétaire composite" envisagé) n'en a pas besoin (Airbase
     binaire, pas un jugement composite comme le FOB) — il ne reste qu'un seul consommateur réel
     (le FOB), ce qui rend le registre générique prématuré (CLAUDE.md, pas d'abstraction
     spéculative). À reconsidérer si un vrai deuxième propriétaire composite apparaît un jour. -->

<!-- Pickup zone mobile sur un camion de transport : demandé le 2026-08-26, formalisé en lot
     `.backlog/FEAT-TRUCK-MOBILE-PICKUP-ZONE/` (verification-first, pas de grill dédié). Confirmé
     live en DCS le 2026-09-28 (`tests/dcs/noPlayer/scenario_truck_anchor.lua`, PASS 4/4) :
     `createTroopZoneAtObject`/`linkedUnit` ancrent déjà correctement une TRZ_ sur un véhicule
     terrestre en mouvement — suivi de position, `isDynamic()`, et gel à la dernière position
     connue à la destruction, tout identique au cas navire déjà prouvé. Aucun changement de code.
     Les deux questions ouvertes (automatisation par convention de nommage, comportement souhaité
     à la destruction du camion) restent non tranchées — pas de nouvelle information les motivant,
     reportées tant qu'un besoin concret ne les fait pas remonter. -->

<!-- AIZ_ — pourquoi une config explicite : grillé le 2026-09-23, formalisé en lot
     `.backlog/FEAT-EXZ-AUTODISCOVERY/` (aiZones injectée pour Test_CTLDNEXT_01.miz via le
     mécanisme ctld-tools réel + auto-détection EXZ_ + doc mission-maker EXZ_). Conclusion : le
     modèle config-only d'AIZ_ n'était pas le problème (docs/mission-maker/zones.md + l'éditeur
     ctld-tools le servent déjà bien) — la mission de dev contournait le pipeline ctld-tools. -->

<!-- Piège du nom court pour une zone auto-détectée par convention de nommage : formalisé en lot
     `.backlog/FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY/` (grill-with-docs, 2026-09-27, ADR 0020).
     Vérifié pendant le grill : LGZ_/WPZ_ ont exactement le même piège que TRZ_ (la roadmap en
     doutait) et `createTroopZoneAtObject` (API scriptée) aussi — 4 sites corrigés, pas 1. Décision :
     nom complet uniquement, aucune rétrocompatibilité sur le nom court (projet encore en RC, non
     diffusé) — voir l'ADR pour le raisonnement et sa limite de validité dans le temps. Le code de
     détection de FIX-AIZONE-NAME-COLLISION (PR #88) reste en place, désormais un filet inatteignable
     en pratique plutôt que du code prouvé mort. -->

<!-- Rappel — donner les paramètres ctld-tools pour configurer Test_CTLDNEXT_01.miz : résolu
     2026-09-24 — table des 15 zones donnée à a.lingo, saisie via ctld-tools, config persistée et
     vérifiée en live DCS (F-176, MT-07/08/08B/09/10/11/12/13/14 tous PASS), lot
     `FEAT-EXZ-AUTODISCOVERY` ticket 01, PR #181. -->

<!-- ctld-tools — lire les zones du .miz pour peupler et synchroniser l'éditeur AIZ_ : formalisé
     en lot `.backlog/FEAT-CTLD-TOOLS-AIZ-SYNC/`, mergé (PR #169) — datalist dcsZoneName +
     réconciliation ajout/suppression des zones AIZ_, convention `AIZ_<name>_<coalition>_<P|D>_
     <cargoType-ou-aiDropMode>` côté outil uniquement (ADR dédié dans dev/adr/). -->
