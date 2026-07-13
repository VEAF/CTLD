# CTLD Next — Procédure de test de version

Les tests sont organisés en six niveaux (L1 à L6).
L1 et L2 s'exécutent automatiquement via la CI GitHub Actions.
L3 à L5 nécessitent une session DCS active avec le pont Lua dcs-bridge injecté et `dcs-serve` démarré.
L6 est purement manuel (joueur + checklist).

Chaque scénario L3–L5 porte aussi un header `-- @tier:` (`auto` / `auto-check` / `human`) indiquant
s'il nécessite ou non un agent IA ou un humain dans la boucle. La majorité du L3 (`noPlayer/`)
est `auto` ou `auto-check` et peut être **pilotée sans intervention humaine** par
`tools/integration-runner/run_scenarios.py`, plutôt qu'en injectant chaque script à la main —
voir [Niveaux d'automatisation](#niveaux-dautomatisation) ci-dessous.

Pour la configuration de debug et la mise en place de CTLD.log, voir [Building & testing](developer/building-and-testing.md).

---

## Correspondance dossier / niveau

| Dossier | Niveau | Contexte d'exécution |
| --- | --- | --- |
| `tests/ci/unit/` | L1 | GitHub Actions — busted, sans DCS |
| `tests/ci/functional/` | L2 | GitHub Actions — busted, sans DCS |
| `tests/dcs/noPlayer/` | L3 | Développeur en local — DCS + dcs-bridge, sans slot joueur |
| `tests/dcs/pilotPassive/` | L4 | Développeur en local — DCS + joueur en cockpit, le script pilote |
| `tests/dcs/pilotActive/` | L5 | Développeur en local — DCS + le joueur exécute des actions F10 |
| `tests/manual_test_sequences.md` | L6 | Développeur en local — joueur, checklist pas à pas |

---

## Niveaux d'automatisation

Indépendamment du niveau L (le dossier où vit un scénario), chaque scénario porte un header
`-- @tier:` indiquant s'il nécessite un agent IA/humain :

| Tier | Signification | Peut tourner sans humain ? |
| --- | --- | --- |
| `auto` | Une seule injection retourne le verdict définitif (`PASS`/`FAIL`/`ABORT`). Aucun joueur, aucun polling, aucun jugement. | Oui |
| `auto-check` | Se résout automatiquement via un vrai timer/`waitFor` ou une machine à états ré-injectée, en quelques secondes — le scénario retourne `STARTED`/`RUNNING` et le runner interroge/ré-injecte `_SCN_<ID>_RESULT` jusqu'à résolution. Aucun jugement humain. | Oui (rapide) |
| `auto-slow` | Sans humain non plus, mais prend **plusieurs minutes** à se résoudre — un hélicoptère IA volant une route vers une zone pickup/dropoff, ou une longue chaîne de timers internes (ex. le drone JTAC ~13 min). Exclu du balayage rapide `--headless` ; à lancer explicitement avec `--tier auto-slow --poll-timeout 900`, joueur simplement garé dans un slot. | Oui (lent, à la demande) |
| `human` | Nécessite un humain : soit un joueur qui doit **piloter** (`human (fly)`), soit qui doit **cliquer un item F10 / faire un jugement visuel** que le code ne vérifie pas (`human (menu)`). Le pont dcs-bridge n'expose aucune API de pilotage. | Non |
| `disabled` | En quarantaine : le code **et** la mission sont corrects, mais le test ne peut pas aboutir pour une raison hors CTLD (p. ex. l'hélico IA de DCS ne se pose pas de façon fiable sur un emplacement donné). Jamais lancé par un sweep par défaut ; accessible uniquement via `--tier disabled`. La couverture logique est assurée par des tests rapides et déterministes. | Non (quarantaine) |

Les dossiers `pilotActive/`/`pilotPassive/` n'impliquent **pas** `human` — le tier reflète ce que le
code du scénario nécessite réellement, vérifié fichier par fichier, pas son dossier. Un audit
`CATCH-UP-PILOT-SCENARIOS` a montré que sur les ~34 scénarios jadis tagués `human` en bloc, seule une
poignée nécessite vraiment un humain (deux vérifs de menu `human (fly)`, plus un différé et un manuel
optionnel) ; la grande majorité pilotent des hélicoptères IA ou s'auto-vérifient et sont
`auto-check`/`auto-slow`. Voir la skill `integration-testing` pour la taxonomie complète et le
tier par défaut de chaque template.

### Comment lancer chaque tier — commande + ce qu'on attend de toi

Deux runners Python sans dépendance pilotent les scénarios via l'API REST de `dcs-serve` et lisent
le verdict (aucune installation ; tous deux lisent `dcs-client.yaml`). Prérequis commun :
`dcs-serve` lancé et la mission chargée avec `dcs-bridge.lua` injecté (voir le haut de cette page).

| Tier | Commande | Ce que TU fais |
|---|---|---|
| `auto` | `python tools/integration-runner/run_scenarios.py --headless` | **Rien.** Entièrement headless. (Aucun slot requis.) |
| `auto-check` | même balayage `--headless` (couvre `auto` + `auto-check`) | **Être garé dans un slot BLUE** (UH-1H) — certains lisent la position/le groupe de ton unité. Pas de vol, pas de clic. |
| `auto-slow` | `python tools/integration-runner/run_scenarios.py --tier auto-slow --poll-timeout 900` | **Être garé dans un slot BLUE**, puis attendre — chacun nécessite plusieurs minutes de vol d'hélico IA. Exclu de `--headless` volontairement. Optionnel (logique aussi couverte par les tests `noPlayer` `aiTransport_featureT/U`). |
| `human (fly)` | `python tools/integration-runner/run_manual_scenario.py --scenario <nom>` | **Piloter l'appareil** selon les instructions du terminal (décoller, atterrir, repositionner). Le runner recopie les instructions in-game de chaque étape dans ton terminal. |
| `human (menu)` | `python tools/integration-runner/run_manual_scenario.py --scenario <nom>` | **Cliquer des items F10 / faire une vérif visuelle** selon les instructions (pas de vol). |

Notes :
- Un **balayage headless complet** (recommandé avant une release) :
  `python tools/integration-runner/run_scenarios.py --headless --inject-ctld --reset-before-each`
  — le `--reset-before-each` remet à zéro l'état CTLD partagé entre scénarios (voir plus bas) pour
  que des runs enchaînés ne se contaminent pas. Écrit un rapport JUnit (`test-results.xml`).
- Cibler un sous-ensemble avec `--scenario <sous-chaîne>` (ex. `--scenario F-178`) ou `--dir noPlayer`.
- `run_manual_scenario.py` récupère après un crash : relance la même commande (il réinitialise d'abord
  l'état du scénario). Il affiche aussi un chrono `[mm:ss]` + un heartbeat pour montrer qu'un long
  scénario est bien vivant.
- Voir `tools/integration-runner/README.md` pour la référence complète des options et les détails
  tier/`RUNNING`.

#### Contamination d'état entre scénarios

Les scénarios partagent les singletons runtime de CTLD (`PlayerManager`, `MenuManager`, registre
JTAC). Certains laissent des résidus (joueurs fantômes, menu joueur effacé, JTAC orphelins) qui
feraient avorter un scénario *ultérieur* — lancé seul c'est bon, un balayage enchaîné accumule.
`net.load_mission` n'existe pas sur un client DCS, donc impossible de recharger la mission par
Lua. `--reset-before-each` injecte `tests/dcs/_reset_state.lua` avant chaque scénario pour
restaurer une base propre player/menu + JTAC sans reload. Si un scénario nécessite un reset plus
profond, recharger la mission manuellement (Shift+R).

---

## Vue d'ensemble de l'architecture

```text
RELEASE
  |
  +- L1  CI busted unit        tests/ci/unit/*_spec.lua          ~105 tests  (automatic)
  +- L2  CI busted functional  tests/ci/functional/*_spec.lua    ~45 tests   (automatic)
  |
  +- L3  DCS noPlayer          tests/dcs/noPlayer/               ~136 scripts (developer, before push)
  |         U-xxx  unit-level dcs-bridge scripts
  |         F-xxx  targeted functional dcs-bridge scripts
  |         scenario_*  multi-step integration scenarios
  |
  +- L4  DCS pilotPassive      tests/dcs/pilotPassive/           ~30 scripts  (developer, before push)
  |         player in cockpit, script drives all steps automatically
  |
  +- L5  DCS pilotActive       tests/dcs/pilotActive/            2 scripts    (developer, before push)
  |         player in cockpit AND must take F10 actions between steps
  |
  +- L6  Manual sequences      tests/manual_test_sequences.md    4 MT-xx      (developer, new features only)
```

---

## Ordre de publication

```text
Modify src/
    |
[LOCAL] L3 noPlayer  -- inject relevant F-xxx + scenario_* for modified module
    | (PASS)
[LOCAL] L4 pilotPassive  -- if feature touches player flow (menus, spawns, effects)
    | (PASS)
[LOCAL] L5 pilotActive  -- if feature modifies an F10 menu visible to the player
    | (PASS, or skip if not applicable)
git push  ->  CI L1/L2 runs automatically
    | (CI green)
PR  ->  merge to master
    |
git tag vX.Y  ->  CI Release job builds and publishes CTLD.lua
```

> **Règle :** L3 à L5 doivent passer **avant** le push. La CI (L1/L2) utilise des stubs DCS et ne peut
> pas détecter les régressions propres à un vrai DCS. Une CI verte avec un L3 en échec signifie que le code est cassé
> sans que la CI le sache.
>
> **Exception :** la documentation, les commentaires et les refactos non fonctionnels peuvent être poussés sans L3 à L5.

---

## L1 — CI busted unit (automatique)

**Qui :** GitHub Actions.
**Quand :** à chaque push sur `master` ou `feature_*`, à chaque PR.
**Scripts :** `tests/ci/unit/*_spec.lua` — 21 fichiers, ~105 tests.
**Runner :** `busted tests/ci/` (Job 3 dans `.github/workflows/ci.yml`).

Périmètre : Config, EventDispatcher, Zones, Crates, Troops, JTAC, Menu, Utils, i18n, ModValidator.
Tous les appels à l'API DCS sont remplacés par des stubs dans `tests/ci/helpers/dcs_stubs.lua`.

---

## L2 — CI busted functional (automatique)

**Qui :** GitHub Actions.
**Quand :** mêmes déclencheurs que L1.
**Scripts :** `tests/ci/functional/*_spec.lua` — 8 fichiers, ~45 tests.

| Fichier de spec | Tests |
| --- | --- |
| `troop_manager_spec.lua` | embarkFromTroopZone, disembark, returnToTroopZone, embarkFromField |
| `jtac_manager_spec.lua` | spawnJTAC, setJTACInTransit, requestSmoke, killJTAC |
| `parachute_spec.lua` | parachuteCrates/Troops/Vehicles, slingload hover/release/cut |
| `utils_spec.lua` | getCentroid, calcDropPosition, getSpawnObjectPositions |
| `config_spec.lua` | YAML override, singleton reset, i18n fallback/FR/ES/KO |
| `mark_ids_spec.lua` | Monotonicité du compteur global d'ID de marque |
| `vehicle_spec.lua` | findLoadableVehicles, loadVehicle, unloadVehicle, _spawnUnpacked |
| `troop_multi_spec.lua` | Transit multi-groupes, disembarkAll/Index, _menuCheckCargo |

> Note : `tests/dcs/noPlayer/F-xxx.lua` et `U-xxx.lua` sont des scripts d'injection dcs-bridge (L3),
> pas des specs busted. Ils ne sont pas pris en compte par la CI (pas de suffixe `_spec`).

---

## L3 — DCS noPlayer (développeur, avant le push)

**Qui :** le développeur.
**Quand :** avant chaque push qui modifie `src/`.
**Comment :** injecter des scripts dans une mission DCS en cours d'exécution. Aucun slot joueur requis.
**Succès :** `fail=0` dans la ligne de résultat + aucun `[FAIL]` dans `tests/dcs/CTLD.log`.

> La majorité du L3 est de tier `auto`/`auto-check` et peut tourner sans intervention humaine via
> `tools/integration-runner/run_scenarios.py --headless` (voir
> [Niveaux d'automatisation](#niveaux-dautomatisation)) plutôt qu'en injectant les fichiers
> ci-dessous à la main.

### L3a — Tests ciblés (U-xxx / F-xxx)

Injecter les fichiers couvrant le module modifié :

| Module modifié | Fichiers à injecter |
| --- | --- |
| `CTLD_troop.lua` | F-033 to F-036, F-059, F-060, F-140 to F-146 |
| `CTLD_jtac.lua` | F-037 to F-040, F-110 to F-112 |
| `CTLD_crate.lua` | F-027 to F-032, F-057, F-058, F-061 to F-071, F-120 to F-123 |
| `CTLD_vehicle.lua` | F-015 to F-020, F-120 to F-123 |
| `CTLD_core.lua` (AI) | F-133, F-134, F-176 to F-182 |
| `CTLD_zone.lua` | F-003 to F-005 |
| `CTLD_recon.lua` | F-009 to F-011, F-115 to F-119 |
| `CTLD_config.lua` / i18n | F-101 to F-105 |
| `CTLD_menu.lua` | U-045 to U-053, U-057 to U-066 |

### L3b — Scénarios d'intégration

Lancer les scénarios correspondant à la fonctionnalité modifiée :

| Domaine fonctionnel | Scénario |
| --- | --- |
| Transport IA / stocks | `aiTransport_featureT_*.lua`, `aiTransport_featureU_*.lua` |
| JTAC toggle / corrections | `scenario_jtac_toggle_lasing.lua`, `scenario_jtac_spot_corrections.lua` |
| Menu crate / chargement | `scenario_b3_load_crate_from_menu.lua`, `scenario_crate_menu_flight_visibility.lua` |
| Transport de véhicule | `scenario_fq_vehicle_whole_transport.lua`, `scenario_mt05_crate_vehicle.lua` |
| Zones IA | `scenario_fr_ai_zones.lua` |
| Groupes extractibles | `scenario_fo_extractable_groups.lua` |
| Spawn FARP Countryside/Metal | `scenario_farp_countryside_spawn.lua`, `scenario_farp_metal_spawn.lua` |

---

## L4 — DCS pilotPassive (développeur + slot joueur, avant le push)

**Qui :** le développeur dans un slot de transport BLUE (UH-1H ou équivalent).
**Quand :** avant le push, pour les changements de fonctionnalités visibles par le joueur.
**Comment :** prendre le slot, injecter le scénario, observer — aucune action F10 requise.
**Succès :** toutes les étapes rapportent `[PASS]`, les vérifications visuelles correspondent à l'attendu.

Scénarios clés :

| Scénario | Fonctionnalité |
| --- | --- |
| `scenarioTroopsFullCycle_v2.lua` | Cycle de vie complet des troops + JTAC |
| `scenario_multigroup_transport.lua` | Transport multi-groupes |
| `scenario_fob_scene.lua`, `scenario_p2_fob_parachute.lua` | Scène FOB + parachute |
| `scenario_p3_csfarp_parachute.lua`, `scenario_p4_metal_farp.lua` | Scènes FARP |
| `scenario_farp_repack.lua`, `scenario_warehouse_cycle.lua` | Repack FARP + warehouse |
| `scenario_feature_f_recon_farp.lua` | Couche RECON FARP/FOB |
| `scenario_feature_k_jtac_vehicle.lua` | JTAC embarqué dans un véhicule |
| `scenario_ai_troops.lua` + `scenario_mt08_ai_vehicle.lua`..`scenario_mt14_ai_aa_system.lua` | Batterie de transport IA (`auto-slow` ; `mt08`/`mt14` en `disabled`/quarantaine — pose IA DCS) |

---

## L5 — DCS pilotActive (développeur + actions F10 du joueur, avant le push)

**Qui :** le développeur dans un slot de transport BLUE — doit exécuter des actions du menu F10 à la demande.
**Quand :** avant le push, uniquement quand la structure ou la visibilité du menu F10 change.

| Scénario | Ce que le joueur doit faire |
| --- | --- |
| `scenario_crate_menu_sol_vol_visual.lua` | Confirmer le menu Crate Commands au sol / en vol / après atterrissage |
| `scenario_troop_menu_sol_vol_visual.lua` | Confirmer le menu Troop Commands au sol / en vol / après atterrissage |

---

## L6 — Séquences manuelles (développeur, nouvelles fonctionnalités uniquement)

Checklists pas à pas dans `tests/manual_test_sequences.md`. Aucun script — pure observation.

| Séquence | Fonctionnalité | Déclencheur |
| --- | --- | --- |
| MT-01 | Transport multi-groupes de troops + menu de débarquement | Tout changement de transport de troops |
| MT-02 | Chargement / déchargement / parachute de véhicule entier | Changement de transport de véhicule |
| MT-03 | Chargement / déchargement / parachute multi-véhicules | Changement de capacité ou de chargement multiple de véhicules |
| MT-06 | Couche RECON FARP/FOB | Changement RECON ou CTLDStaticWatcher |

---

## Récapitulatif — effort par version

| Niveau | Qui | Quand | Effort approx. |
| --- | --- | --- | --- |
| L1 CI unit | GitHub Actions | Automatique | 0 |
| L2 CI functional | GitHub Actions | Automatique | 0 |
| L3a F-xxx ciblés | Développeur | Avant le push — modules impactés uniquement | ~5 min/module |
| L3b scénario noPlayer | Développeur | Avant le push — fonctionnalités impactées uniquement | ~10 min |
| L4 pilotPassive | Développeur + cockpit | Avant le push — fonctionnalités visibles par le joueur | ~20 min |
| L5 pilotActive | Développeur + cockpit | Avant le push — changements de menu F10 uniquement | ~10 min |
| L6 MT-xx manuel | Développeur + cockpit | Nouvelles fonctionnalités visibles par le joueur | ~15 min/MT |

---

## Checklist de pré-publication

Avant de tagger `vX.Y` :

- [ ] Tous les jobs CI verts sur `master` (lint, build, busted).
- [ ] Tout nouveau fichier `src/` ajouté à `tools/build/listToMerge.txt`.
- [ ] L3 passé — `python tools/integration-runner/run_scenarios.py --headless` (ou injection ciblée
      module par module) pour tous les modules modifiés depuis le dernier tag.
- [ ] L4 passé pour toutes les fonctionnalités visibles par le joueur modifiées depuis le dernier tag.
- [ ] L5 passé si la structure d'un menu F10 a changé.
- [ ] Cette page mise à jour (taxonomie des tiers / liste des scénarios) si un scénario ou un tier a été ajouté.
- [ ] Statuts de fonctionnalité de `migration/MODERNIZATION-PLAN.md` à jour.
- [ ] `docs/pilot/` et `docs/mission-maker/` mis à jour si un comportement visible par l'utilisateur a changé.
