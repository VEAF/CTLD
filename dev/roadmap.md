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

## Parachutage — garde générale d'activation, prioritaire sur `canParachuteDrop`

Constaté en répondant à une question sur `ctld-tools.exe` : le groupe de settings **Parachute**
(`CTLD_config_schema.yaml`) ne couvre que la *physique* du parachutage (vitesse de descente, dérive,
altitude d'ouverture, rayon de déballage auto). Il n'existe aucune garde globale pour activer/
désactiver la fonctionnalité elle-même — seul `canParachuteDrop` (`capabilitiesByType`, par type
d'appareil) conditionne l'apparition des entrées F10 « Parachute », appareil par appareil.

Idée : ajouter un réglage global `enableParachuteDrop` (pseudo-grill du 2026-08-11 — décisions ci-dessous,
pas encore formalisées en lot) qui fait office de garde de premier rang. `canParachuteDrop` ne serait
évalué qu'en second rang, seulement si la garde générale vaut `true` ; si elle vaut `false`, le
parachutage est désactivé pour tous les appareils sans avoir à repasser `canParachuteDrop: false` un
par un dans `capabilitiesByType`.

Décisions retenues (alignées sur les gardes globales existantes du même genre) :
- **Nom** : `enableParachuteDrop` — suit la convention `enable<Feature>` déjà en place
  (`enableCrates`, `enableSmokeDrop`, `enableFastRopeInsertion`, `enableHoverSlingload`,
  `enableFARPRepack`), plutôt qu'un suffixe `*Enabled` (seul `reconEnabled` fait exception aujourd'hui).
- **Comportement** : masque entièrement les entrées F10 « Parachute » quand `false`, même si
  `canParachuteDrop=true` pour l'appareil — comme `enableCrates`/`enableSmokeDrop` qui gatent
  l'enregistrement de toute la section de menu (`CTLD_crate.lua:281-282`) et `enableFastRopeInsertion`
  qui conditionne à la fois la logique et l'apparition de l'entrée menu (`CTLD_troop.lua:1316`,
  `CTLD_troop.lua:2024`). Pas de message d'erreur à l'action : le garde retire l'entrée, il ne la
  laisse pas visible pour échouer ensuite.
- **Emplacement schéma** : nouveau champ dans le groupe `parachute` existant de
  `CTLD_config_schema.yaml`, à côté des réglages de physique — reste dans la famille ctld-tools
  « Parachute ».

Reste à trancher **au to-prd/to-issues** (implémentation, pas conception) : quels points d'appel côté
menu (troops/vehicles/crates parachute — sections distinctes ou un seul gate ?) doivent lire
`enableParachuteDrop`, et l'impact sur les tests busted existants du groupe parachute.

## extractableGroups — détection automatique par convention de nommage

Constaté en expliquant `extractableGroups` : aujourd'hui, rendre un groupe pré-placé dans le Mission
Editor extractible au F10 exige que le MM ajoute son nom à la table de config `extractableGroups`
(`INIT-E`, `CTLDCoreManager:_initExtractableGroups`, `CTLD_core.lua:520`) — une étape manuelle,
séparée du placement du groupe lui-même, à la manière de `logisticUnits` avant l'introduction de
`logisticUnitTypes`.

Idée : offrir au MM le choix entre la liste explicite existante et une **convention de nommage**
détectée automatiquement à l'init, sans toucher à la config — le MM place son groupe et le nomme
directement dans l'éditeur, comme il le fait déjà pour les zones `TRZ_…`. Les deux mécanismes
coexistent (union, dédoublonnée) : un groupe listé dans `extractableGroups` *et* nommé selon la
convention ne compte qu'une fois.

Décisions retenues (pseudo-grill du 2026-08-11, alignées sur les conventions de nommage déjà
présentes dans `src/`) :
- **Style** : préfixe strict `EXTR_<nom>`, sur le modèle de `SVNT_` (`_isServantUnitName`,
  `^SVNT`, `CTLD_troop.lua:37`) plutôt que la sous-chaîne libre de `_isJTACGroup` (`"jtac"` n'importe
  où dans le nom, insensible à la casse, `CTLD_core.lua:549`) — un préfixe ancré évite les faux
  positifs sur un nom de groupe qui contiendrait le mot par coïncidence.
- **Mot-clé** : `EXTR` — court, cohérent avec les préfixes existants (`SVNT_`, `TRZ_`), distinct de
  `JTAC`/`SVNT`.
- **Périmètre coalition du scan** : RED + BLUE + NEUTRAL. Plus large que le seul autre scan par nom
  existant (`_initMMJTACs` ne couvre que RED/BLUE, `CTLD_core.lua:488`), choisi pour rester cohérent
  avec la liste explicite `extractableGroups` — celle-ci accepte déjà n'importe quelle coalition
  puisqu'elle lit `group:getCoalition()` sur le groupe résolu, sans restriction dans
  `_initExtractableGroups`. Inclure NEUTRAL sert notamment le cas des **civils** (par nature neutres)
  — un groupe de civils à évacuer/extraire, par exemple — que le périmètre RED/BLUE seul de
  `_initMMJTACs` ne couvrirait pas.
- **Mécanisme** : étendre `INIT-E` pour scanner `coalition.getGroups(side)` sur les trois côtés (comme
  `_initMMJTACs` le fait pour RED/BLUE) et tester le préfixe `^EXTR` sur chaque nom, en plus de la
  résolution des noms listés dans `extractableGroups` — même passage d'init, résultat fusionné dans
  `CTLDTroopManager._droppedGroups[coalition]`.

Reste à trancher **au to-prd/to-issues** (implémentation, pas conception) : convention exacte du nom
après le préfixe (`EXTR_<name>` libre, ou faut-il aussi extraire des métadonnées du nom comme `TRZ_`
le fait pour ses 5 champs ?) et mise à jour de la doc mission-maker (`configuration.md` /
`.fr.md`) pour documenter les deux voies côte à côte.

<!-- FOB — API scriptée pour zone de troupes : généralisée et formalisée en lot
     `.backlog/FEAT-TROOP-ZONE-SCRIPTED-API/` (grill-with-docs, 2026-08-26) — le grilling a élargi
     le périmètre de "FOB uniquement" à "n'importe quel objet DCS nommé" (zone ME, unité, statique,
     groupe, ou FARP/airbase), d'où `createTroopZoneAtObject(objectName, trzName)` plutôt que
     `registerFOBAsTroopZone(fobName, trzName)`. Entrée conservée ci-dessous pour l'historique. -->

## FOB — API scriptée pour ajouter une zone de troupes (pickup) par-dessus un FOB

Constaté en répondant à une question MM (2026-08-25) : comment ajouter, via un script lancé après
l'init, une capacité d'embarquement de troupes sur un FOB déjà construit. Aujourd'hui, seul
`CTLDZoneManager:registerFOBAsLogistic(fobName, point, radius, coalitionId)` existe pour ce cas de
figure (`CTLD_zone.lua:1187-1198`), et il n'est même pas pensé pour un appel MM : il est déclenché
**automatiquement** par `CTLDFOBManager` à la construction du FOB (`CTLD_fob.lua:319`). Aucun
équivalent troupes n'existe : `createExtractZone(zoneName, flagNumber, smoke)` (`CTLD_zone.lua:
1481-1507`) ne fixe jamais `pickMaxStock`, donc `hasPickup()` reste `false` (`:107-109`) — elle ne
peut compter qu'une extraction, jamais servir de zone de pickup.

Solution de contournement donnée en attendant (non officielle) : reconstruire soi-même une
`CTLDTroopZone` à partir de la zone logistique déjà enregistrée du FOB
(`CTLDZoneManager:getLogisticZone(fobName)`) et l'insérer directement dans la table privée
`self._troopZones`, en réutilisant au passage le parseur privé `CTLDZoneManager:_parseTRZ(name)`
(`:591-650`) pour que le MM garde le contrôle de la coalition/stock/flag/target via un nom `TRZ_…`
classique. Fonctionne (le menu F10 se reconstruit en direct depuis `_troopZones`,
`CTLD_troop.lua:1937`), mais dépend de deux champs/méthodes privés — pas garanti dans le temps.

Idée de lot : ajouter `CTLDZoneManager:registerFOBAsTroopZone(fobName, trzName)` /
`removeFOBTroopZone(fobName)`, sur le modèle du **scripted API** déjà livré pour les balises
(`FEAT-VMCT-INTEGRATION` ticket 03, `CTLDBeaconManager:createAtPoint()` / `removeBeacon()`) — une
paire créer/retirer publique, documentée, testée (busted + scénario `tests/dcs`), qui accepte un
nom `TRZ_…` complet (réutilisant `_parseTRZ` en interne, promu public ou dupliqué proprement) et
résout la position/rayon du FOB via sa zone logistique existante, sans que l'appelant ait besoin de
toucher à un champ privé.

Reste à trancher **au to-prd/to-issues** (implémentation, pas conception) : `registerFOBAsTroopZone`
doit-il exiger que le FOB soit déjà logistique (comme le contournement), ou doit-il accepter un
point/rayon explicites pour couvrir un FOB sans zone logistique ? Faut-il aussi un
`getFOBTroopZone(fobName)` symétrique à `getLogisticZone` ?
