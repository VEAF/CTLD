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

## Zones dynamiques — aucun rafraîchissement du menu F10 des joueurs déjà sur place

Constaté en testant en direct `createTroopZoneAtObject` (`FEAT-TROOP-ZONE-SCRIPTED-API`,
2026-08-26) : un joueur déjà posé pile à l'endroit où une `TRZ_` vient d'être créée par script ne
voit **rien** dans son menu F10 tant qu'il ne redécolle/ratterrit pas — `CTLDTroopManager` ne
reconstruit la branche "Troop Commands" que sur `S_EVENT_LAND`/`S_EVENT_TAKEOFF`
(`CTLD_troop.lua:1854-1857`), jamais en continu ni sur un événement de création de zone.

Ce n'est pas propre aux zones de troupes : `CTLDZoneManager:registerFOBAsLogistic` (zones
logistiques sur FOB) publie bien un événement `OnLogisticZoneUpdated`
(`CTLD_zone.lua:1157`), mais **rien dans tout `src/` ne s'y abonne** (grep confirmé) — aucun menu
de joueur n'est rafraîchi en réaction. Le même vide existe donc pour `createExtractZone`,
`registerFOBAsLogistic` et `createTroopZoneAtObject` : les trois créent la zone et s'arrêtent là,
sans jamais toucher au menu d'un joueur déjà présent.

Dans le cas d'usage principal (un MM construit un FOB/FARP puis un joueur y atterrit *après*),
ça ne se voit pas : l'atterrissage qui suit déclenche naturellement le rafraîchissement. Le trou
ne touche que le cas où un joueur est **déjà posé** au moment où la zone apparaît.

Idée de lot (portée transverse, pas spécifique à un seul type de zone) : que la création/
suppression dynamique d'une zone (troupe ou logistique) déclenche un rafraîchissement ciblé du
menu de tout joueur actuellement à portée — probablement en s'abonnant enfin à
`OnLogisticZoneUpdated` côté `CTLDCrateManager`, et en publiant/écoutant un événement équivalent
pour les zones de troupes, plutôt qu'en ajoutant des appels de rafraîchissement au cas par cas
dans chaque fonction de création. Reste à trancher **au to-prd/to-issues** : un seul mécanisme
générique pour les deux familles de zones, ou deux événements distincts (troupe/logistique)
comme aujourd'hui pour la création elle-même ?

## luacheck n'est en réalité vérifié nulle part (ni local, ni CI)

Constaté en vérifiant l'état de `develop` après le merge de `FEAT-TROOP-ZONE-SCRIPTED-API` (PR
#129, 2026-08-26) : `CLAUDE.md` affirme "`luacheck --config .luacheckrc src/` must be clean (rely
on CI if not installed locally)", mais **aucun job CI n'exécute luacheck** (grep confirmé sur
`.github/workflows/` — zéro occurrence). Le job `Lua 5.1 Syntax Check` ne fait qu'un `luac5.1 -p`
(compilation/syntaxe), pas d'analyse statique (variables inutilisées, globals implicites, etc.).

Côté local, le hook `tools/hooks/luacheck-on-edit.sh` (PostToolUse sur Edit/Write d'un fichier
`src/*.lua`) est un **no-op silencieux** quand `luacheck` n'est pas installé (`command -v
luacheck` échoue) — le cas sur cette machine Windows (absent du PATH et de
`luarocks/rocks/bin`). Résultat : le code fusionné dans cette même PR (`src/CTLD_zone.lua`) n'a
jamais été passé au luacheck réel, ni pendant la session (hook muet), ni en CI (job absent) — la
garantie de qualité annoncée dans `CLAUDE.md` est un filet vide depuis on ne sait combien de temps.

Idée de lot : soit ajouter un vrai job CI luacheck (le plus simple — `luacheck` s'installe via
`luarocks` sur le runner ubuntu déjà utilisé par `busted Tests`), soit rendre le hook local
bloquant/visible plutôt que silencieux quand le binaire manque, soit les deux. Reste à trancher
**au to-prd/to-issues** : faire de ce nouveau job un gate bloquant dès le départ, ou l'ajouter en
mode rapport seul le temps de nettoyer une éventuelle dette luacheck déjà accumulée dans `src/`.

**Mise à jour (2026-08-26)** : luacheck installé en local (résolu deux `luarocks` en conflit sur
cette machine — celui bundlé dans `lua-for-windows`, cassé pour compiler des extensions C, shadowait
celui de scoop ; supprimé ses shims, gardé `lua-for-windows` pour son runtime Lua 5.1) et lancé sur
`src/` pour de vrai la première fois. Résultat : **0 erreur**, 206 warnings dans 33 fichiers.
**117 (57 %) étaient des faux positifs de config**, corrigés dans la foulée (`.luacheckrc`) :
`class`/`AI`/`Spot`/`STTS`/`ctld_config_user` sont des globals réels (DCS ou legacy) absents de
`read_globals`/`globals` (47 warnings), et les 70 restants étaient des lignes de traduction i18n
dépassant `max_line_length=200` — limite sans objet sur du texte traduit, désormais exemptée pour
`CTLD_i18n_{en,fr,es,ko}.lua`. Total ramené à **89 warnings, 0 erreur**, dette réelle et déjà
quantifiée (donc le "reste à trancher" ci-dessus n'est plus une inconnue) :
variables inutilisées et shadowing éparpillés sur ~8 fichiers, 2 branches `if` vides dans
`CTLD_vehicle.lua`, une négation simplifiable dans `CTLD_jtac.lua`, et surtout **58 occurrences dans
`legacy_api.lua`** où un paramètre nommé `_préfixé` (convention "volontairement inutilisé") est en
fait utilisé — la convention de nommage elle-même est trompeuse à corriger, pas le code qui
l'entoure. Chacune de ces ~89 lignes demande un vrai jugement au cas par cas, pas un simple réglage
de config — candidat pour un futur lot de nettoyage dédié, hors scope de celui-ci.

## TRZ_ automatique — création liée au spawn d'un objet (FOB, FARP, etc.)

Demandé le 2026-08-26. `CTLDZoneManager:createTroopZoneAtObject(objectName, trzName)`
(`FEAT-TROOP-ZONE-SCRIPTED-API`, PR #129) permet déjà de créer une `TRZ_` sur n'importe quel objet
DCS nommé après coup, mais uniquement via un appel scripté explicite — un MM ou une intégration
externe (ex. VMCT) doit le déclencher lui-même, objet par objet.

Idée : un réglage de config qui automatise cet appel — dès qu'un objet correspondant à un critère
donné (type, ex. FOB/FARP, ou convention de nommage) apparaît en mission, CTLD crée automatiquement
une `TRZ_` dessus, sans script dédié côté MM.

Non tranché (à instruire en grill-with-docs avant to-prd) :
- **Déclencheur** : quel événement DCS marque un objet comme « spawné » selon son type (FOB/FARP
  vs. unité/statique/groupe classique) — à vérifier contre le mécanisme de détection déjà utilisé
  par `createTroopZoneAtObject` et par les zones dynamiques existantes.
- **Critère de sélection** : liste explicite de types, convention de nommage (à la `TRZ_`/`EXTR_`/
  `SVNT_`), ou les deux — voir l'entrée roadmap `extractableGroups` ci-dessus pour un précédent de
  décision sur ce même choix.
- **Nommage de la `TRZ_` générée** : quels champs (coalition/stock/flag/target) par défaut quand
  rien n'est fourni par le MM, et est-ce que le `trzName` reste dérivable du nom de l'objet source.
- **Portée** : lié au rafraîchissement menu F10 pour un joueur déjà sur place, voir l'entrée
  roadmap « Zones dynamiques — aucun rafraîchissement... » ci-dessus (même trou probable).

<!-- Volet FOB formalisé/livré via FIX-FOB-TROOP-PICKUP (PR #136) ; volet FARP formalisé en lot
     `.backlog/FEAT-FARP-TROOP-PICKUP/` (grill-with-docs, 2026-08-26). Les deux couvrent l'idée
     d'origine (FOB, FARP) sans le réglage générique imaginé au départ — chaque cas réutilise le
     réglage/mécanisme le plus proche déjà existant plutôt qu'un système de sélection par
     type/convention. -->

## Lien générique zone ↔ objet de référence (owner-triggered)

Constaté en grillant le fix `troopPickupAtFOB` (2026-08-26, voir aussi le lot
`FIX-FOB-TROOP-PICKUP` qui corrige le bug lui-même sans attendre cette généralisation) : la
plomberie d'ancrage est **dupliquée, pas partagée**, entre `CTLDTroopZone` et `CTLDLogisticZone`
(`CTLD_zone.lua:40` et `:372`) — `_linkedUnit`, `_anchorUnitName`, `getCenter()`, `isDynamic()`,
`isAlive()` existent en code quasi identique dans les deux classes. Et l'enregistrement/nettoyage
d'une zone liée à un FOB est ad hoc par type : `registerFOBAsLogistic` + `unregisterLogistic`
existent pour la logistique ; le fix `FIX-FOB-TROOP-PICKUP` ajoute leur symétrique
(`registerFOBAsTroopZone` + `unregisterTroopZone`) pour les troupes, appelé explicitement depuis
`CTLDFOBManager:_destroyFOB`. Un troisième type de zone lié à un FOB demain exigerait un troisième
couple register/unregister et un troisième appel dans `_destroyFOB` à ne pas oublier.

Constat important qui écarte une généralisation naïve de l'ancrage existant : il y a en réalité
**deux mécanismes de cycle de vie**, pas un — l'ancrage par sondage (`_linkedUnit:isExist()`,
marche pour un objet DCS unique) et la notification par le propriétaire (le FOB n'utilise pas
`_linkedUnit` ; sa mort est un jugement composite — seuil d'intégrité sur plusieurs
`sceneObjects` — que rien ne peut déduire en sondant un seul objet).

<!-- Correction (vérification roadmap, 2026-08-26, FEAT-FARP-TROOP-PICKUP) : le FARP ne suit PAS
     le schéma composite du FOB, contrairement à ce que cette entrée supposait initialement. Un
     FARP s'enregistre comme un vrai Airbase DCS (statique catégorie Heliports), donc sa
     destruction est binaire et native (Airbase:isExist()) — pas de seuil d'intégrité multi-objets
     nécessaire. Le lot a réutilisé CTLDStaticWatcher (sondage générique déjà existant, déjà
     éprouvé par le Recon pour ce même type d'objet) plutôt qu'un troisième mécanisme de cycle de
     vie. Voir aussi l'entrée ci-dessous (camion de transport) : un troisième cas concret,
     lui aussi purement poll-based (_linkedUnit), déjà couvert par le mécanisme existant. -->

Idée : un registre de liens orthogonal aux tables de zones existantes —
`CTLDZoneManager:linkZonesToOwner(ownerId, { {type="logistic", key=...}, {type="troop", key=...},
... })` côté création, et un seul `CTLDZoneManager:unlinkOwner(ownerId)` côté suppression, qui sait
par type dans quelle table `nil`-er et quel événement `OnXxxZoneUpdated` publier. `_destroyFOB`
(et demain le teardown FARP, et tout futur propriétaire composite) n'aurait plus qu'un seul appel
à faire, quel que soit le nombre de types de zones liés. Referme aussi, comme effet de bord,
l'entrée roadmap « Zones dynamiques — aucun rafraîchissement du menu F10 » ci-dessus : un point
d'entrée unique de création/suppression est le bon endroit pour garantir ce rafraîchissement,
au lieu de compter sur chaque fonction de création pour y penser séparément.

Non tranché (à instruire en grill-with-docs dédié avant to-prd) : le générique doit-il aussi
absorber l'ancrage par sondage (`_linkedUnit`) existant, ou rester un mécanisme séparé pour les
propriétaires composites uniquement ; forme exacte de `ownerId` et de la table d'entrées ; est-ce
que `createTroopZoneAtObject`/`createExtractZone` (aujourd'hui sans notion de propriétaire ni
d'événement publié) migrent vers ce registre ou restent à part.

### Cas d'usage additionnel — pickup zone mobile sur un camion de transport

Demandé le 2026-08-26. Idée : associer une TRZ_ à un camion de transport pour simuler des troupes
transportées au sol, qu'un appareil viendrait embarquer en se posant à proximité du camion — la
zone doit suivre le camion, pas rester figée à sa position de spawn.

Constat en explorant le code existant : **la moitié "suivi de position" de cette idée est déjà
livrée, sans code nouveau.** `createTroopZoneAtObject` résout déjà un `objectName` quelconque —
zone éditeur, **unité ou statique**, groupe, ou airbase (`_resolveTroopZoneObject`,
`CTLD_zone.lua:1615`) — et pour une unité/statique/groupe, pose `linkedUnit` sur la
`CTLDTroopZone` créée, exactement le même mécanisme déjà utilisé pour une TRZ_ ancrée sur un
navire (`FIX-SHIP-ZONE-ANCHOR-PARITY`). Rien n'y limite le type d'unité à un navire — un camion
DCS ordinaire (`Unit`) fonctionne déjà de la même façon. Concrètement : un MM peut probablement
déjà appeler `CTLDZoneManager:createTroopZoneAtObject("MonCamion", "TRZ_...")` aujourd'hui et
obtenir une zone de pickup qui suit le camion — **à vérifier en test live avant de considérer que
c'est un vrai gap**, mais rien dans le code lu ne l'empêche.

Ce qui resterait potentiellement à trancher, si la vérification ci-dessus confirme que le suivi de
position marche déjà tel quel :
- **Automatisation** : le MM doit-il appeler `createTroopZoneAtObject` lui-même à chaque camion
  (ce qui marche déjà), ou faut-il une détection automatique par convention de nommage/type de
  véhicule — même famille de question que l'entrée « TRZ_ automatique » ci-dessus (FOB/FARP),
  cette fois pour un véhicule ordinaire plutôt qu'une scène.
- **Destruction du camion** : aujourd'hui, une zone ancrée par `linkedUnit` ne se retire jamais
  toute seule quand son ancre meurt — elle se fige à sa dernière position connue
  (`isAlive()`/`getCenter()`, comportement déjà prouvé pour un navire coulé). Pour un camion,
  est-ce le comportement voulu (les troupes restent récupérables à l'épave) ou faut-il un
  retrait explicite à la destruction — la même question de nettoyage déterministe que
  `FEAT-FARP-TROOP-PICKUP` a dû trancher pour le pack de FARP.
- Un troisième cas concret et purement poll-based (aucune sémantique composite comme le FOB) —
  utile comme référence si/quand le système générique ci-dessus est instruit : il confirmerait
  que l'ancrage par sondage doit bien être absorbé par le générique, pas laissé de côté.
