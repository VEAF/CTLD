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

<!-- ctld-tools — injection .miz automatique : livré (lot CTLD-TOOLS-MIZ-INJECT, PR #NN). -->

## ctld-tools — mode TUI interactif

Contexte: surcouche d'ergonomie pour créer/éditer le `user-config.yaml` sans écrire de YAML brut,
pour les MM non-développeurs. Le premier périmètre livre à la place `gen-user --scaffold` (YAML
commenté) + `validate` (rapport clair). À prioriser après la V1 **si** l'usage réel montre que le
YAML brut rebute. Sorti du premier périmètre (grill-with-docs, 2026-07-20).

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

## STARTUP-REPORT-UNIFIED — Rapport de démarrage unifié

Contexte : les warnings/erreurs de config CTLD au démarrage sont produits par plusieurs domaines
indépendants (zones, crates, userSetup…), chacun avec son propre `trigger.action.outText`. Un MM
voit plusieurs popups successifs sans vue d'ensemble.

Solution : un rapport agrégé unique en fin d'init, produit par un collecteur centralisé alimenté
par chaque manager pendant sa phase d'init. Un seul `outText` résumant erreurs + warnings.
**Priorité haute — à traiter immédiatement après `FEAT-USERCONFIG-API`.**
