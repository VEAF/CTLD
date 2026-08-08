# Build et tests { #building-testing }

Cette page couvre tout ce dont vous avez besoin pour transformer `src/` en livrable final et pour
exécuter la suite de tests automatisés en local. Les deux sont également appliqués en intégration
continue, si bien que les commandes ci-dessous reflètent ce que fait la CI à chaque push.

Les tests d'intégration en DCS live — charger votre build dans la mission de test et y exécuter des
scénarios — sont couverts dans [Tests d'intégration](integration-testing.md). Cette page se
limite à la chaîne de build et aux tests basés sur busted qui s'exécutent entièrement sans DCS.

## Chaîne de build { #build-pipeline }

CTLD est distribué sous forme d'un fichier unique, `CTLD.lua`. Il est **généré** en fusionnant les
modules en Lua pur situés sous `src/` dans l'ordre de dépendance — ne le modifiez jamais à la main,
et reconstruisez-le après toute modification de `src/`.

Il **ne figure pas dans le dépôt** : un clone neuf n'a pas de `CTLD.lua`, et celui que vous
construisez se pose à la racine du dépôt, ignoré par git. Où en obtenir un sans le construire :

| Vous êtes | Prenez-le |
|---|---|
| contributeur | via le build ci-dessous |
| concepteur de mission | dans `ctld-tools.exe`, qui l'embarque — ou dans les fichiers joints à une [release](https://github.com/VEAF/CTLD/releases) |
| testeur d'un correctif non publié | dans la [pré-version flottante `dev`](https://github.com/VEAF/CTLD/releases/tag/dev), reconstruite à chaque fusion dans `develop` |

**Build local (Windows) :**

```
powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
```

Sortie : `CTLD.lua` à la racine du dépôt, écrit en **UTF-8 sans BOM** (requis par le moteur Lua de
DCS — le script s'interrompt si un BOM est détecté). Le build :

- lit l'ordre de fusion depuis `tools/build/listToMerge.txt` (commentaires et lignes vides ignorés) ;
- extrait `ctld.VERSION` de `src/CTLD_config.lua` et appose un commentaire d'en-tête
  (`Version`, `Built`, `Source`, `Licence`) ainsi que `---@meta` / `---@diagnostic disable` ;
- concatène chaque fichier listé, encadré par des marqueurs `-- Start :` / `-- End :` ;
- échoue avec un code de sortie non nul si aucun fichier n'a été fusionné ou si un BOM s'est glissé.

L'ordre dans `listToMerge.txt` fait foi (les fondations d'abord, puis les managers de domaine, puis
les scenes, puis `CTLD_core.lua`, `legacy/`, et `CTLD_bootstrap.lua` en dernier). Voir
[Architecture](architecture.md) pour la justification et pour savoir comment insérer un nouveau
module dans la liste.

**Build en CI :** le job `build` exécute le même `merge_CTLD.ps1` sur `windows-latest`, vérifie que
la sortie existe et n'est pas vide, et téléverse `CTLD.lua` en tant qu'artefact de build.

## Configuration moteur (`ctld-tools`) { #engine-configuration-ctld-tools }

Les valeurs par défaut du moteur sont des **données**, pas du code : elles vivent dans
`src/CTLD_config.yaml` (source de vérité unique, sectionnée `mm_facing` / `advanced`). Au moment du
build, `merge_CTLD.ps1` embarque le YAML verbatim dans un module chaîne Lua —
`src/CTLD_config_default_yaml.lua`, qui définit `ctld.configDefault` (via `ctld-tools embed`) — que
`CTLDConfig:load()` parse à l'exécution. **Éditez le YAML** — le Lua généré est un **artefact de build
(ignoré par git)**, jamais édité à la main ni committé.

Pour changer un défaut : éditez `src/CTLD_config.yaml`, rebuild (`merge_CTLD.ps1` ré-embarque
automatiquement), committez le YAML. **Le build nécessite Python** : lancez `poetry install` dans
`tools/ctld-tools` une fois (le merge appelle `ctld-tools` ; il s'arrête avec un message clair si
poetry est absent).

`tools/ctld-tools/` est un projet poetry isolé (typer, ruamel.yaml, pytest + ruff + mypy), suivant
les conventions Python de VMCT. Le job CI `python-quality` applique un **garde de dérive de l'oracle** :
la référence de round-trip committée `tests/ci/data/config_defaults.json` (émise par `ctld-tools gen`)
doit égaler une génération fraîche depuis le YAML. La suite busted vérifie ensuite que le
`CTLDConfig.parseYAML` Lua reproduit cet oracle — deux parsers indépendants qui concordent.

## Exécuter les tests (busted, sans DCS) { #running-tests-busted-no-dcs }

La suite automatisée s'exécute avec [busted](https://lunarmodules.github.io/busted/). Chaque appel
à l'API DCS est stubbé, aucune installation de DCS n'est donc requise.

```bash
# Installation (une seule fois)
luarocks install busted

# Exécuter toute la suite
busted tests/ci/

# Exécuter uniquement les specs fonctionnelles
busted tests/ci/functional/

# Exécuter une seule spec
busted tests/ci/functional/troop_manager_spec.lua
```

### Quand busted refuse de s'installer { #when-busted-will-not-install }

`luarocks` exige Lua ≤ 5.4, ce qu'un poste Windows ne fournit pas toujours. `tools/lua-test/`
rejoue toute la suite `tests/ci/unit/` avec un interpréteur **Lua 5.1** ordinaire — la version que
DCS exécute — en une seconde environ :

```powershell
powershell -ExecutionPolicy Bypass -File tools\lua-test\run_specs.ps1          # tout
powershell -ExecutionPolicy Bypass -File tools\lua-test\run_specs.ps1 beacon   # filtre par nom
```

C'est une vérification rapide avant commit, **pas** un second gate : il n'implémente que le
sous-ensemble de busted utilisé par les specs, donc une spec faisant appel à `spy` / `mock` /
`stub` y échoue et passe en CI. Voir
[`tools/lua-test/README.md`](https://github.com/VEAF/CTLD/blob/develop/tools/lua-test/README.md)
pour la surface exacte et ses limites. busted + luacheck en CI restent l'autorité.

La configuration `.busted` (racine du dépôt) définit `pattern = "_spec"` et nomme un `helper` chargé
avant chaque spec : `tests/ci/helpers/init.lua`. Ce helper fait deux choses, dans l'ordre :

1. `dofile` sur `tests/ci/helpers/dcs_stubs.lua` — injecte les stubs de l'API DCS dans
   l'environnement global (les globales doivent exister avant le chargement de tout module `src/`).
2. `dofile` sur `tests/ci/helpers/loader.lua` — charge tous les modules `src/` dans le même ordre de
   dépendance que `listToMerge.txt` (idempotent, protégé par `_CTLD_LOADED`).

Les specs sont réparties dans deux répertoires :

| Répertoire | Portée |
| --- | --- |
| `tests/ci/unit/` | Specs unitaires — un module isolé (`*_spec.lua`) |
| `tests/ci/functional/` | Specs fonctionnelles — plusieurs managers interagissant via l'event bus |

Le loader coupe la journalisation dans un fichier pendant les tests en fixant `ctld.debug = false` et
en pointant `ctldLogPath` vers le répertoire temporaire de l'OS, si bien que les exécutions ne
touchent jamais un vrai `CTLD.log`.

Lorsque vous ajoutez un module, répercutez la modification dans **les deux**
`tools/build/listToMerge.txt` et `tests/ci/helpers/loader.lua`, puis ajoutez des specs sous
`tests/ci/unit/` ou `tests/ci/functional/` (test-first — écrivez la spec qui échoue avant le code).

## Ratchet de couverture { #coverage-ratchet }

Le job CI `busted` s'exécute avec la couverture (`busted --coverage tests/ci/`), puis `luacov`
produit `luacov.report.out`. Le job parse le pourcentage `Total` et le compare à un plancher stocké
dans la variable d'environnement `COVERAGE_FLOOR` (actuellement `59`).

Le plancher est un **ratchet — il ne fait que monter, jamais descendre**. Il a été initialisé
légèrement en dessous de la première couverture mesurée (61,56 %). Lorsque vous augmentez la
couverture globale, relevez `COVERAGE_FLOOR` dans `.github/workflows/ci.yml` pour verrouiller le
gain ; le job échoue si la couverture passe sous le plancher.

## Intégration continue { #continuous-integration }

La CI (`.github/workflows/ci.yml`) s'exécute à chaque push et pull request vers `develop` / `master`,
et peut être déclenchée manuellement. Quatre jobs indépendants :

| Job | Runner | Ce qu'il vérifie |
| --- | --- | --- |
| `lua-lint` | `ubuntu-latest` | Vérifie la syntaxe de chaque `src/**/*.lua` avec `luac5.1 -p` — attrape les constructions Lua 5.2+ (`goto`, `<const>`, suffixes entiers…) invalides dans DCS |
| `gitleaks` | `ubuntu-latest` | Analyse de secrets sur tout l'historique (configuration dans `.gitleaks.toml`) |
| `build` | `windows-latest` | Exécute `merge_CTLD.ps1`, vérifie que `CTLD.lua` n'est pas vide, le téléverse en tant qu'artefact |
| `busted` | `ubuntu-latest` | Exécute la suite avec la couverture et applique le ratchet de couverture |

Les releases sont gérées par un workflow distinct (`.github/workflows/release.yml`), pas par
celui-ci.

`luacheck --config .luacheckrc src/` est disponible comme étape d'analyse statique en local ; la
barrière syntaxique appliquée par la CI est `luac5.1 -p` dans le job `lua-lint`.

## Configuration de la journalisation et du debug { #logging-debug-configuration }

CTLD écrit un log d'exécution dans `CTLD.log`. La journalisation dans un fichier est **conditionnée
au paramètre `debug`** — elle est désactivée par défaut et n'ouvre le fichier que lorsque `debug`
vaut true (et que l'installation DCS n'est pas sanitizée).

La configuration est en lecture seule à l'exécution et est toujours lue via `ctld.gs("param")` ; pour
activer la sortie de debug, vous fixez ces valeurs dans l'instantané de configuration porté par votre
mission — `ctld.configUser` dans `CTLD_userConfig.lua`, produit le plus simplement avec `ctld-tools`.
Les quatre vivent dans la section `advanced` :

```yaml
advanced:
  debug: true                  # opens CTLD.log and enables verbose logging
  ctldLogPath: ""              # path override; empty = DCS Saved Games folder
  debugScreenLog: true         # also echo each log line on screen via outText
  debugScreenLogDuration: 10   # on-screen display duration (seconds)
```

Notes :

- `debug = false` (la valeur par défaut) supprime entièrement `CTLD.log` — sûr sur les serveurs
  sanitizés.
- `ctldLogPath` ne remplace **que** l'emplacement où le fichier est écrit ; il n'active pas la
  journalisation à lui seul. Laissez-le vide pour utiliser l'emplacement DCS Saved Games par défaut.
  C'est un chemin local, jamais committé.
- Les lignes de log sont émises via `ctld.utils.log(level, fmt, ...)` (niveaux tels que `INFO`,
  `WARN`, `ERROR`) ; chaque ligne va vers `env.info` et, quand le fichier est ouvert, vers
  `CTLD.log`.

Pour diagnostiquer un script qui ne se charge pas ou une fonctionnalité qui se comporte mal dans une
mission en cours, utilisez le workflow `dcs-runtime-debug` — le chemin de debug live, en jeu, est
hors du périmètre de cette page.
