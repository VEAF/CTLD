# CTLD 2.0.0-rc2 — version candidate

CTLD 2.0 est une **réécriture complète** du script CTLD v1 : le code monolithique devient un
ensemble de modules Lua **testables** (architecture orientée objet Manager/Entité), couvert par une
intégration continue — build unique, plus de 1 100 tests unitaires et fonctionnels, plus des tests
d'intégration en DCS réel.

Cette **rc2** apporte le gros morceau attendu : un **outil de configuration graphique**, et avec lui
un **nouveau modèle de configuration**. Lisez la section « Changements importants » si vous avez déjà
configuré une mission pour la rc1.

## Nouveautés

- **`ctld-tools.exe` — configurez CTLD sans écrire une ligne de Lua.** Double-cliquez le fichier :
  l'outil s'ouvre dans votre navigateur, en local, sans installation ni connexion. Tous les réglages
  et tous les catalogues sont éditables — caisses, groupes de troupes, zones, capacités par appareil,
  zones IA, modèles de caisse — avec recherche, libellés en clair, unités (m / kg / s), marqueurs de
  valeur modifiée et retour au défaut en un clic. La validation tourne en continu et parle français.
  Puis **« Injecter dans la mission… »** écrit la configuration directement dans votre `.miz`
  (trigger MISSION START placé en premier). Interface FR / EN selon la langue de votre système.
- **Détection d'écart de version.** À l'ouverture d'une configuration écrite pour une version
  antérieure de CTLD, l'outil liste ce qui est apparu, ce qui a disparu et ce qui diffère du défaut,
  avant réinjection. Jamais de fusion silencieuse.
- **Zones ancrées à une unité (Moving Zones).** Une zone trigger attachée à une unité dans le
  Mission Editor suit désormais son unité en direct — zones logistiques et zones de troupes. Unité
  détruite = zone morte.
- **Rapport de démarrage unifié.** Un bloc `=== CTLD_STARTUP_REPORT ===` est écrit dans `DCS.log` à
  chaque démarrage, cherchable même quand tout va bien, et un **unique** message écran apparaît s'il
  y a un problème. Configuration saine = silence total.
- **Interface en français.** Menus F10 et messages pilotes traduits (FR complet, ES/KO partiels), y
  compris les sous-menus RECON et les messages du système AA qui restaient en anglais. Réglable par
  mission via `i18n_lang`, qui est devenu un vrai réglage — plus besoin d'éditer une source.
- **Douze constantes deviennent des réglages** — rayons de recherche et de collecte, distances de
  réarmement et d'assemblage AA, plage de codes laser JTAC, poids par défaut, rayon de zone par
  défaut. Mêmes valeurs qu'avant, désormais modifiables par mission.
- **Un réglage a maintenant exactement une valeur par défaut.** 114 valeurs de repli en double dans
  le code ont été supprimées ; cinq avaient déjà divergé du catalogue.

## Changements importants pour les concepteurs de mission

⚠️ **Le modèle de configuration change.** `CTLD_userConfig.lua` ne porte plus des surcharges mais
**toute** la configuration, sous forme d'instantané YAML dans `ctld.configUser`. Les anciennes
méthodes `ctld.yamlConfigDatas` (bloc de scalaires) et `ctld.userSetup` (callbacks `addCrate`,
`patchCrate`…) **n'existent plus**. Reprenez votre configuration rc1 avec `ctld-tools`, qui part des
défauts courants et valide avant export.

Rien n'est fusionné, mais l'omission n'est pas uniforme : un **réglage** que vous omettez retombe sur
la valeur par défaut de CTLD et est nommé dans le rapport de démarrage à l'écran, alors qu'une
**liste** omise (une section de caisses, un groupe de troupes, une zone) est réellement absente —
c'est ainsi qu'on en retire une.

⚠️ **`maxSlingloadSpeed` : défaut corrigé de 50 à 26.** La valeur est en **mètres par seconde** — 50
signifiait ~180 km/h, près du double de la limite d'un UH-1H, et ressemblait à une valeur saisie en
nœuds. 26 m/s ≈ 94 km/h. La caisse est donc larguée plus tôt qu'avant ; remontez le réglage si votre
appareil le justifie.

⚠️ **Orbite des drones JTAC.** `JTAC_droneRadius` est remplacé par `JTAC_droneRadiusNoLase` et
`JTAC_droneRadiusOnLase` (rayon de recherche et rayon plus serré en désignation), et
`JTAC_droneSpeed` apparaît. L'orbite est inchangée, mais le drone **apparaît** désormais à 3000 m et
150 km/h au lieu de 4000 m et ~194 km/h : il vole à une seule altitude et une seule vitesse du début
à la fin.

⚠️ **`specificParams` sur une caisse n'est plus lu.** Une configuration qui en porte encore affiche
un message NOTICE au démarrage nommant les caisses concernées et les réglages qui les remplacent.
(Sans rapport avec `specificParams.task` sur les modèles de troupes, qui reste actif.)

⚠️ **`AIZones` était une clé morte** — quatre zones IA par défaut sans aucun effet en jeu. Le moteur
lit `aiZones` (minuscule), dont les entrées sont des enregistrements nommés. La clé morte est
supprimée et `aiZones` a désormais un éditeur dédié dans l'outil.

⚠️ **`dropOffZones` de la v1 n'est pas lu par CTLD 2.** Le drop-off IA se configure avec une entrée
`aiZones` portant `isDropoff`.

L'ordre des triggers ne change pas : (1) `CTLD_userConfig.lua` (optionnel), (2) `CTLD.lua`, (3) les
éventuels plugins de scène après CTLD.

## Corrections visibles en jeu

- **Une configuration incomplète ne fait plus planter la mission.** Trois réglages étaient lus sans
  garde-fou et injectés directement dans un calcul — deux intervalles JTAC et
  `slingCutDestroyHeight` — ce qui produisait une erreur à chaque tick JTAC ou à chaque largage.
- **Un éditeur de groupes de troupes qui corrompait le fichier qu'il éditait** : `jtac` était traité
  comme une case à cocher alors que le catalogue porte un nombre.
- **Onze descriptions de réglages en français** étaient illisibles (double encodage UTF-8).
- **Pour les auteurs de plugins** : l'événement `OnCrateDestroyed` n'est plus émis du tout. Le seul
  chemin qui le publiait, `dropCrate`, était injoignable — aucun menu F10 ne l'appelait — et a été
  retiré. Le largage en vol est assuré par `parachuteCrates`.

## Documentation

Toute la documentation de configuration a été reprise pour ce nouveau modèle. Les pages qui
enseignaient encore les anciennes méthodes montrent désormais le YAML réel, et plusieurs erreurs de
fond ont été corrigées au passage — notamment un exemple de `transportPilotNames` écrit comme un
dictionnaire là où le moteur attend une simple liste, et l'ordre des triggers présenté à l'envers
dans les pages d'accueil.

## Contributeurs

**FullGas** (développeur principal), **Zip** (assistance technique) — VEAF.
