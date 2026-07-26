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
<!-- ctld-tools — i18n FR de l'interface web : livré (lot CTLD-TOOLS-MM-UX, ticket 11). -->

---

## ctld-tools — `unit:` et `group:` manquants dans le schéma

Le lot CTLD-TOOLS-MM-UX a mis dans `src/CTLD_config_schema.yaml` les **familles** (section
`families:` : `label` + `description` bilingues + `order`) et un **`label:` bilingue par réglage**
(137 entrées). Restent deux métadonnées dérivées côté frontend :

- l'**unité**, extraite du texte de la `description` (`(m)`, `(kg)`, `(seconds)`) — fiable mais
  indirect, et muette pour les réglages sans description. Un champ `unit:` serait explicite ;
- la **famille** des ~44 réglages sans `group:`, dérivée du nom de la clé (`familyOf`). Ça réduit la
  famille fourre-tout `Other` de ~44 à 7, donc le gain restant est surtout cosmétique.

Converge avec « générer les tableaux de config de la doc depuis le schéma » : mêmes métadonnées, même
source. Le vrai reste-à-faire coûteux, ce sont les **descriptions** des ~44 réglages non documentés
(les inventer serait contraire à la règle zéro-supposition).

---

## Runtime — anomalies relevées en traçant les unités (lot CTLD-TOOLS-MM-UX, ticket 14)

Quatre balayages de `src/` pour établir l'unité de chaque réglage numérique ont mis au jour des
points qui n'ont **rien à voir avec l'UI** et n'ont donc pas été touchés. Chacun est étayé par le
code ; à trier avant d'en faire des tickets.

**1. `maxSlingloadSpeed` : défaut probablement faux.** Le code compare la valeur à la norme de
`Unit:getVelocity()`, donc en **m/s** (`CTLD_crate.lua:1100-1102`, aucun facteur de conversion dans
tout `src/`). Le défaut de 50 vaut donc **180 km/h**, ce qui est très permissif pour une limite de
sling-load. Le seuil frère de `CTLD_troop.lua:1266` (`speed < 2.2`) suggère que 50 a peut-être été
écrit en pensant km/h. À trancher par quelqu'un qui connaît l'intention.

**2. Défauts du code divergents du catalogue YAML.** Les fallbacks `or <valeur>` dans le Lua ne
correspondent pas à `src/CTLD_config.yaml` :

| Réglage | YAML | Fallback Lua | Où |
|---|---|---|---|
| `maximumSearchDistance` | 3000 | 10000 | `CTLD_troop.lua:1521` |
| `maximumDistanceLogistic` | 200 | 500 | `CTLD_zone.lua:897` |

Sans effet tant que le catalogue est chargé (il l'est toujours), mais deux sources de vérité pour la
même valeur par défaut.

**3. Trois réglages sans fallback → erreur arithmétique si la clé manque.** `ctld.gs()` renvoie `nil`
et la valeur part directement dans une comparaison ou une addition :
`JTAC_laseIntervalSeconds` / `JTAC_searchIntervalSeconds` (`CTLD_jtac.lua:905-906`, puis
`t + interval`) et `slingCutDestroyHeight` (`CTLD_crate.lua:1503`). Une config utilisateur amputée de
ces clés planterait au lieu de retomber sur un défaut.

**4. `CTLDCrateManager:dropCrate` semble mort.** Aucun appelant dans `src/` — uniquement
`tests/ci/unit/crate_lifecycle_spec.lua`. Donc `maxDropHeight` (`CTLD_crate.lua:2135`) ne sert
qu'en test. À confirmer avant de supprimer : peut-être un point d'entrée d'API pour les plugins.

**5. `minimumHoverHeight` / `maximumHoverHeight` : référentiel incohérent selon l'appelant.** Hauteur
au-dessus de l'objet visé à `CTLD_crate.lua:1152` et `CTLD_vehicle.lua:1193`
(`transportPos.y - cratePos.y`), mais vrai AGL terrain à `CTLD_crate.lua:1463`
(`pos.y - land.getHeight(...)`). Sur terrain en pente, ou pour une caisse posée en hauteur, les deux
ne donnent pas la même chose — le pilote peut satisfaire un test et pas l'autre.
