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

## ctld-tools — Harmoniser la convention de nommage des paramètres CTLD

Contexte (émergé de la discussion UX-CTLD-TOOLS-V2, 2026-07-23) : les noms de settings CTLD
sont incohérents — certains ont un préfixe fonctionnel (`JTAC_lock`, `recon*`, `fob*`), d'autres
non (`enableCrates`, `slingLoad`, `numberOfTroops`). L'affectation aux familles dans ctld-tools
est donc forcément un mapping statique déclaratif (`group:` dans le schéma YAML).

Objectif : chaque paramètre CTLD doit débuter par un préfixe représentant son périmètre
fonctionnel (`JTAC_`, `RECON_`, `FOB_`, `BEACON_`, `SMOKE_`, `CRATE_`, `TROOP_`, `AA_`,
`PARACHUTE_`…). Une fois uniformisés, l'affectation aux familles de ctld-tools pourrait être
dérivée automatiquement du préfixe.

Attention : renommer des settings CTLD est un **breaking change** pour les missions existantes
(`CTLD_userConfig.lua` générés ou écrits à la main). Nécessite un plan de migration (aliases,
période de transition, changelog clair).
