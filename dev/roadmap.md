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

## ctld-tools — dépréciation du companion asset-check

Contexte (émergé du grill TUI). Le **companion asset-check** (`tools/companion/asset_check.lua`)
fait exactement la même validation que `ctld-tools validate` (même datamine stock + `modTypes`
déclarés par le MM, depuis `FIX-VALIDATE-MODTYPES`, PR #87), mais **dans DCS après coup** →
largement **redondant** avec `ctld-tools`. À déprécier/retirer. Résidu couvert : les types
**injectés au runtime** (scènes de plugins) que le design-time ne voit pas — marginal, et rattrapé
par le test-en-DCS. `logDefaults` reste (debug power-user). Décision David (2026-07-20) : pas
maintenant, à faire en lot séparé.

## ctld-tools — générer les tableaux de config de la doc depuis le schéma

Les **descriptions** des settings (EN+FR) vivent désormais dans `src/CTLD_config_schema.yaml`
(seedées depuis `configuration(.fr).md`, lot CTLD-TOOLS-TUI-POLISH) et sont affichées + cherchables
dans la TUI. Il reste une **duplication** : les tableaux de settings de `docs/mission-maker/
configuration.md` / `.fr.md` répètent ces descriptions. Candidat lot : **générer** ces tableaux depuis
le schéma (le schéma est la source de vérité) pour supprimer la double maintenance.

## ctld-tools — descriptions manquantes pour ~44 réglages

Constaté le 2026-08-10 : les descriptions des ~44 réglages non documentés ne sont pas écrites (les
inventer serait contraire à la règle zéro-supposition). Pas un candidat de lot en soi, juste une
dette de documentation qui traînera tant que personne ne les écrit.

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

## Lien générique zone ↔ objet de référence (owner-triggered)

Idée écartée comme prématurée, à reconsidérer : le registre générique `linkZonesToOwner` /
`unlinkOwner` n'est PAS construit. `FEAT-FARP-TROOP-PICKUP` a confirmé que le FARP (le seul second
candidat « propriétaire composite » envisagé) n'en a pas besoin (Airbase binaire, pas un jugement
composite comme le FOB) — il ne reste qu'un seul consommateur réel (le FOB), ce qui rend le registre
générique prématuré (CLAUDE.md, pas d'abstraction spéculative). À reconsidérer si un vrai deuxième
propriétaire composite apparaît un jour.

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

<!-- ctld-tools — lire les zones du .miz pour peupler et synchroniser l'éditeur AIZ_ : formalisé
     en lot `.backlog/FEAT-CTLD-TOOLS-AIZ-SYNC/`, mergé (PR #169) — datalist dcsZoneName +
     réconciliation ajout/suppression des zones AIZ_, convention `AIZ_<name>_<coalition>_<P|D>_
     <cargoType-ou-aiDropMode>` côté outil uniquement (ADR dédié dans dev/adr/). -->

## Cargo natif — adopter les objets que CTLD ne suit pas

Le lot `FIX-NATIVE-CARRY-DETECTION` ignore (trace debug) tout objet de la liste de cargo à bord qui n'est pas un
véhicule ou une caisse suivi : cargo créé par la tablette de loadmaster, caisses d'éditeur de type inconnu
(`ammo_cargo` posé dans l'éditeur). Idée : les adopter comme caisses génériques CTLD, pour qu'elles
bénéficient du suivi (déballage, menus). À cadrer : quel descripteur, quelle coalition, quel poids.

## Cargo natif — étendre `convertNativeLoadToCTLD` aux véhicules

La conversion d'un chargement natif en chargement CTLD (UH-1H, CH-47Fbl1 par défaut) ne s'applique qu'aux
caisses. Pour les types dont l'interface cargo DCS accepterait un véhicule entier, la même conversion
donnerait accès au parachute virtuel et aux menus de CTLD. Non applicable au Mi-8MT, dont l'interface cargo
DCS n'accepte que des caisses (constaté en jeu).

## Cargo natif — limite de poids des véhicules appliquée pour l'IA seulement

`maxVehicleWeight` n'est appliqué qu'au chargement automatique par l'IA ; un chargement natif par un joueur
n'est limité que par DCS. Idée : une limite manuelle configurable, si le besoin se confirme.

## Véhicule `WAITING` dont l'unité a disparu reste suivi

Constaté en jeu le 2026-10-01 : `veh_15`, demandé par Request Equipment, est resté en état `WAITING` dans
`CTLDVehicleSpawner` sans unité vivante (`isExist() == false`), sans événement `OnVehicleDead`. Cause non
établie (hors du lot natif : il n'a jamais été chargé). À reproduire et à traiter.

## Cargo natif — types non vérifiés en jeu

Le CH-47F et le Mi-24P n'ont pas été vérifiés en jeu (modules non possédés) : lecture de la liste de cargo
à bord, chargement et libération. Le défaut `canTransportWholeVehicle: true` du CH-47F n'est couvert que par
busted. Une libération de caisse native est détectée environ 5 s après la vidange de la liste, car la passe
de libération attend que le statique DCS de la caisse existe de nouveau : à surveiller sur un type où DCS
recréerait l'objet avec une nouvelle identité. Le lot `FEAT-NATIVE-CRATE-SPAWN-NEAR` y ajoute les valeurs
`crateSpawnDistance` du CH-47F (3,7 m) et du Mi-24P (5,1 m), déduites de leur coque de collision seule.

## Cargo natif — portée de chargement et point de mesure de DCS

Constaté en jeu le 2026-10-01 (lot `FEAT-NATIVE-CRATE-SPAWN-NEAR`) : une caisse à environ 8 m du Mi-8MT se charge
par l'interface cargo native, une à 23 m est refusée pour son éloignement. La limite exacte et le point depuis
lequel DCS mesure (centre de l'appareil ou coque) n'ont pas été établis ; la valeur déclarée étant la distance de
dégagement de coque, la plus proche possible, cette borne ne la change pas. Ce qui limite réellement un
chargement, c'est la capacité de la soute (Mi-8MT trois caisses, UH-1H une), pas le poids (DCS n'applique pas le
plafond affiché) ni la distance. À mesurer si un besoin d'éloigner les caisses apparaît.

## ctld-tools — la complétion ne couvre que les tables clé → entrée

Le lot `FEAT-CTLD-TOOLS-CONFIG-COMPLETION` (PR #222) complète les champs scalaires manquants des entrées d'une
table identifiée par clé (`capabilitiesByType`, `spawnableCratesModels`) quand la configuration est plus ancienne
que le catalogue. Les listes d'enregistrements (`loadableGroups`, `spawnableCrates`, `aiZones`…), dont les entrées
n'ont pas de clé stable, ne sont pas complétées : un champ ajouté à ces enregistrements ne serait pas propagé aux
configurations existantes. À cadrer le jour où le catalogue gagne un tel champ : quelle identité d'entrée (nom,
`unit`…).

## ctld-tools — « Configuration seule » oubliée sur une mission à moteur de dev

Constaté le 2026-10-01 : injecter dans `Test_CTLDNEXT_01.miz` sans cocher « Configuration seule » a embarqué le
moteur (1,2 Mo), les sons et deux déclencheurs en plus de la configuration, alors que cette mission charge déjà
le moteur du dépôt par son déclencheur `CTLD_DEV_ROOT`. Idée : détecter ce chargeur dans la mission et avertir
(ou proposer le mode configuration seule par défaut) avant d'écrire. À cadrer.

## ctld-tools — les tests lisent la copie de travail de la mission partagée

Quatre tests (`test_install`, `test_inject_into_miz`) échouent en local quand `missions/Test_CTLDNEXT_01.miz` a
été réexportée par ctld-tools (elle porte alors déjà un moteur et des sons, `replacedPrevious` vaut vrai), alors
qu'ils passent contre la version commitée utilisée par le CI. Idée : les faire partir d'une copie « pristine »
comme le fait déjà la fixture `pristine_miz`, ou d'une fixture minimale indépendante de la mission de dev.

## Fat Cow — Mi-8 piloté en « petite cow » (lot 3, optionnel)

Le Mi-8MTV2 pilotable comme cow : 13 000 kg max, 8 866 kg à vide, 1 929 kg de carburant, soit 2 591 kg de charge utile à 80 % de carburant.
Assez pour un ou deux hélicos (par exemple 1 400 kg de carburant et 20 Vikhr) : fidèle au réel, où le Mi-8 ravitailleur emporte des réservoirs de convoyage d'environ 900 L.
Demande un réservoir plus petit que celui de 800 gal du CH-47 et son entrée dans `fatCowTypes` / `capabilitiesByType`.

## Scènes — le bouton « Pack » est offert avant la fin de la pose de la FARP

**Le point à traiter.** Une scène est inscrite dans l'ensemble des scènes actives dès son premier tick, et
`findNearbyRepackableScenes` la propose donc aussitôt dans **Pack Equipt**. Or une FARP Countryside met environ
trente secondes à se poser : l'héliport et les repères au départ, les camions à +5 s, la tente, la caisse de
munitions à +15 s, les gardes à +20 s, les lumières, la manche à air et le marqueur à +25 s, et seulement à +30 s
l'étape qui remplit (ou restaure) l'entrepôt, suivie de l'enregistrement de la zone de ramassage de troupes. Pendant
cette demi-minute, le pilote peut cliquer sur Pack. La question : faut-il le lui permettre, et sinon comment le lui
dire ?

**Ce qui est déjà réglé** (lot `FIX-SCENE-PACK-WHILE-LAYING-OUT`, PR #304, vérifié en jeu le 2026-11-09). Packer en
cours de pose arrête maintenant la scène : ses étapes restantes ne tournent plus, il ne reste aucun objet orphelin
(six avaient été comptés pour un pack à +3 s ; zéro désormais). Le lot a volontairement laissé l'entrée visible : la
cacher est un choix d'interface, pas un correctif.

**Pourquoi il reste quelque chose à traiter.**

1. *Un stock perdu en silence.* L'instantané de l'entrepôt est pris au moment du pack. Sur une FARP **redéployée**
   depuis des caisses, l'entrepôt n'est restauré qu'à l'étape de +30 s. Un pack à +10 s lit donc un entrepôt encore
   vide : les caisses emportent un instantané vide, et le prochain déploiement remet la FARP à zéro. Le carburant
   et les armes de la FARP d'origine sont perdus, sans autre signe que le message de succès. *Déduit, pas mesuré* :
   il vient de l'ordre des étapes et de la mesure de `FEAT-FAT-COW` (un héliport invisible créé en cours de mission
   démarre avec un entrepôt vide) ; à confirmer en jeu avant d'en faire un lot.
2. *Un message qui ment un peu.* Le pilote lit « FARP packed successfully! » pour une FARP qui n'a jamais fini de se
   poser ; ce qu'il récupère (les caisses) est correct, ce que la FARP contenait ne l'est pas.
3. *Une incohérence avec la Fat Cow.* La FARP de la Fat Cow en cours de pose est déjà protégée (la cow arrête sa
   scène avant de la packer) ; celle d'une scène classique ne l'est que depuis la PR #304, et par un arrêt
   silencieux, pas par un refus expliqué au pilote.
4. *Aucune explication.* L'entrée est là, elle marche, et rien n'indique qu'il vaut mieux attendre.

**Pourquoi ce n'est pas un correctif.** Il y a au moins trois réponses valables, qui changent ce que voit le
pilote, et le choix ne se déduit pas du code :

- *Cacher l'entrée tant que la scène n'est pas terminée.* Le drapeau `_completed` existe depuis la PR #304. Mais le
  menu F10 ne se reconstruit que sur des événements : il faudrait rafraîchir la section Pack à la fin de la scène
  (son `onComplete`), sans quoi l'entrée n'apparaîtrait qu'au rafraîchissement suivant.
- *Garder l'entrée mais refuser avec un message* du type « FARP en cours de pose, patientez N s ». Plus simple
  (pas de rafraîchissement à ajouter), au prix d'une entrée qui ne fait rien pendant trente secondes.
- *Ne rien changer* : le pack arrête la scène, comme aujourd'hui. Reste alors le stock perdu du point 1, qu'il
  faudrait au moins signaler.

**Pourquoi c'est peu urgent.** La fenêtre dure une demi-minute, une fois par déploiement ; un pilote qui packe sa
FARP à peine posée est rare, et depuis la PR #304 plus rien ne traîne dans la mission. Le cas qui fait mal est le
point 1 : une FARP redéployée avec du stock, packée aussitôt. À reprendre si un équipage le rencontre, ou avec un
prochain lot sur les FARP.

**Où regarder.** `CTLDSceneManager:findNearbyRepackableScenes` (la liste), `CTLDCrateManager:refreshPackEquiptSection`
(l'entrée et son rappel), `_completed` et `onComplete` de `CtldScene`, l'étape 11 de la FARP Countryside (la
restauration de l'entrepôt). Seule la FARP Countryside déclare `onRepack` aujourd'hui.
