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

## ctld-tools — injection `.miz` automatique

Contexte: commodité au-dessus de `ctld-tools` — au lieu que le MM colle le `user-config.lua` généré
dans un trigger de l'ME, l'outil pose/met à jour lui-même un trigger CTLD dédié (nom conventionnel,
idempotent, placé avant le trigger CTLD conformément au setup 2-triggers d'ADR 0008). Brique maison
surgicale (zipfile + parse/serialize de la table Lua `mission`, patch de la seule sous-section
triggers, pas de fidélité byte) — pas de dépendance aux outils VEAF ni à une lib qui reconstruit
toute la mission. Sorti du premier périmètre (grill-with-docs, 2026-07-20).

## ctld-tools — mode TUI interactif

Contexte: surcouche d'ergonomie pour créer/éditer le `user-config.yaml` sans écrire de YAML brut,
pour les MM non-développeurs. Le premier périmètre livre à la place `gen-user --scaffold` (YAML
commenté) + `validate` (rapport clair). À prioriser après la V1 **si** l'usage réel montre que le
YAML brut rebute. Sorti du premier périmètre (grill-with-docs, 2026-07-20).

<!-- DEV-LOCAL-MIZ — formalisé en lot `.backlog/DEV-LOCAL-MIZ/` (grill-with-docs, 2026-07-19). -->

_(Note post-formalisation : le constat « chemins absolus… `dcs-bridge.lua` » était partiellement
inexact — `dcs-bridge.lua` est embarqué dans le miz, pas chargé par chemin ; seul `CTLD.lua` était
un chemin machine. Détail dans le PRD.)_
