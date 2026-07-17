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

## DEV-LOCAL-MIZ — Chargement dynamique des fichiers locaux de développement

Contexte: `Test_CTLDNEXT_01.miz` contient des chemins absolus vers les fichiers locaux de chaque
développeur (`CTLD.lua`, `dcs-bridge.lua`). Chaque dev doit modifier le `.miz` pour ses chemins,
ce qui génère du bruit git et risque de laisser un chemin de machine personnelle dans master.
L'objectif est un mécanisme de trigger dynamique permettant à chaque dev de charger ses fichiers
locaux sans modifier le `.miz` partagé.
