Status: open

# PRD — BUILD-DICT-AI-TRANSLATE

> Générer automatiquement les traductions manquantes des dictionnaires i18n via l'API Claude,
> si `ANTHROPIC_API_KEY` est disponible localement. Câbler le rapport des clés vides dans
> `ctld.startupReport` au runtime. Cadré via grill-with-docs (2026-07-22).

## Problem Statement

Après `generate_i18n_dicts.ps1 -Apply`, les nouvelles clés sont ajoutées comme stubs vides
dans FR/ES/KO. Ces stubs doivent être remplis manuellement — ce qui ne se fait pas en pratique.
Deux manques complémentaires :

1. **Pas de traduction automatique** : les stubs restent vides jusqu'à intervention humaine.
2. **Pas de visibilité runtime** : aucun mécanisme n'alimente `ctld.startupReport` pour signaler
   les clés vides à l'opérateur en jeu.

## Solution

### Étape 1 — Rapport runtime des clés vides (Lua)

Câbler `ctld.i18n_auditAll()` pendant l'init CTLD (après chargement des dicts) :
- Pour la langue active (`ctld.gs("i18n_lang")`), ajouter des entrées `INFO` dans
  `ctld.startupReport` pour chaque clé vide (`untranslated` = valeur identique à EN).
- Si la langue active est EN, skip (pas de traduction à vérifier).
- Format : `"[i18n] N untranslated key(s) in <lang> — rebuild to translate"`.

`ctld.i18n_check()` existante écrit via `env.error/warning` directement — elle ne sera pas
modifiée. La nouvelle intégration passe exclusivement par `ctld.i18n_audit()` (données pures).

### Étape 2 — Script de traduction locale (Python)

`tools/build/translate_i18n.py` + `tools/build/requirements-translate.txt` :
- Lit les 4 fichiers dict (`src/CTLD_i18n_*.lua`), identifie les stubs vides par rapport à EN.
- Pour chaque langue cible (FR, ES, KO), appelle l'API Claude en un seul batch
  (prompt = contexte DCS/militaire + dict EN + liste des clés vides → réponse JSON `{key: tr}`).
- Modèle : `claude-haiku-4-5-20251001` (rapide, économique, strings courtes).
- Écrit les traductions générées dans les fichiers dict (en place, UTF-8 sans BOM).
- En cas d'erreur API : WARNING console, stubs restent vides, build continue.
- Dépendance unique : `anthropic` (pip).

### Étape 3 — Intégration dans merge_CTLD.ps1

Après le bloc `generate_i18n_dicts.ps1 -Apply`, si `$env:ANTHROPIC_API_KEY` est défini :
- Appelle `python tools/build/translate_i18n.py`.
- Log le résultat (N clés traduites par langue ou WARNING si erreur).
- Si Python ou le script est absent → WARNING, build continue (non-bloquant).

## Implementation Decisions

- **Local-only** : `ANTHROPIC_API_KEY` est une variable d'env locale, absente en CI → le bloc
  est skippé silencieusement en CI.
- **Toutes les langues** : FR + ES + KO (toutes les langues non-EN du projet).
- **Un appel API par langue** : batch complet, pas de pagination (dicts ~200 clés max).
- **Modèle** : `claude-haiku-4-5-20251001`.
- **Non-bloquant** : échec API ou Python absent → WARNING + build continue. Le STARTUP-REPORT
  signale les clés encore vides au runtime.
- **Emplacement** : `tools/build/translate_i18n.py` + `tools/build/requirements-translate.txt`.
  Pas de poetry, pas de venv dédié — pip seul.
- **`ctld.i18n_check()` inchangée** : elle reste un outil dev/QA via `env.error/warning`.
  Le câblage startup-report utilise `ctld.i18n_audit()` (pure data).
- **Pas d'ADR** : pas de trade-off architectural surprenant.

## Out of Scope

- Traduction automatique en CI.
- Modification de `generate_i18n_dicts.ps1` ou `ctld.i18n_check()`.
- Support de nouvelles langues (hors FR/ES/KO).
- Vérification de la qualité des traductions générées (responsabilité du traducteur humain).
