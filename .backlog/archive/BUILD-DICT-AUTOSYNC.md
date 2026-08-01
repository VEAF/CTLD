# BUILD-DICT-AUTOSYNC

**Status:** ✅ merged (PR #59). Compacted from `BUILD-DICT-AUTOSYNC/` on 2026-08-01; the ticket files live on in git history.

Intégrer `generate_i18n_dicts.ps1 -Apply` dans `merge_CTLD.ps1` + hook `pre-push` cross-platform (bloquant sur MISSING, warn sur STALE) + doc activation dans `CLAUDE.md`.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-integrate-apply-in-build-and-prepush-hook` | open | Ticket 01 — Intégrer -Apply dans merge_CTLD.ps1 et créer le hook pre-push |

## PRD

Status: open

## PRD — BUILD-DICT-AUTOSYNC

> Intégrer `generate_i18n_dicts.ps1 -Apply` dans `merge_CTLD.ps1` et fournir un hook
> `pre-push` cross-platform qui bloque sur les clés manquantes avant tout PR.
> Cadré via grill-with-docs (2026-07-22).

### Problem Statement

`generate_i18n_dicts.ps1` doit être lancé manuellement par le dev après chaque ajout de
`ctld.tr()`. En pratique il ne l'est pas — ce qui a conduit à 72 clés manquantes dans les
dictionnaires (lot FIX-I18N-DICT-SYNC, PR #57).

Deux mécanismes complémentaires sont nécessaires :

1. **Auto-sync au build** : à chaque `merge_CTLD.ps1`, les dictionnaires sont synchronisés
   (`-Apply`) avant la fusion, donc `CTLD.lua` est toujours construit avec des dicts à jour.

2. **Garde pre-push** : un hook git bloque le push si des clés MISSING subsistent (= le dev
   a commité un `ctld.tr()` sans rebuilder), et avertit sur les clés STALE (résidus à
   nettoyer manuellement).

### Solution

#### Étape 1 — Auto-sync dans merge_CTLD.ps1

Appeler `generate_i18n_dicts.ps1 -Apply` juste après le bloc `gen-config` (lignes 17–35),
avant le merge loop. Le build continue même si des stubs vides ont été ajoutés
(comportement permissif) — la sortie console liste les clés ajoutées.

#### Étape 2 — Hook pre-push cross-platform

Créer `.githooks/pre-push` (script bash, répertoire tracké) :
- Détecte `pwsh` (PowerShell Core, cross-platform) puis `powershell` (Windows PS5).
- Si aucun PowerShell disponible → avertit et laisse passer (non-bloquant).
- Lance `generate_i18n_dicts.ps1` en dry-run.
- **MISSING** → `exit 1` (bloquant) : le dev doit rebuilder pour ajouter les stubs.
- **STALE** → avertissement console, `exit 0` (non-bloquant) : nettoyage manuel.

Documenter l'activation dans `CLAUDE.md` :
```
git config core.hooksPath .githooks
```

### Implementation Decisions

- **Emplacement dans merge_CTLD.ps1** : après `Pop-Location` du bloc gen-config (ligne 35),
  avant `$utf8NoBOM = ...`. Même pattern que gen-config : `Write-Host` + appel script +
  gestion erreur.

- **Gestion d'erreur dans merge_CTLD.ps1** : si le script retourne un code non-nul
  (erreur interne), le build s'arrête (`throw` + `exit 1`). Les clés ajoutées comme stubs
  ne constituent pas une erreur — le script retourne 0 dans ce cas.

- **Cross-platform hook** : bash shebang `#!/usr/bin/env bash`. Chemin du script PS
  calculé relativement à la racine du repo (`git rev-parse --show-toplevel`).

- **Pas de nouveau lot pour l'étape AI** : la génération automatique des traductions
  manquantes via Claude API fait l'objet d'un lot séparé (BUILD-DICT-AI-TRANSLATE).

- **Pas d'ADR** : intégration de build straightforward, pas de trade-off architectural
  surprenant.

### Out of Scope

- Génération automatique des traductions (BUILD-DICT-AI-TRANSLATE, lot séparé).
- Script `tools/setup.sh` / `tools/setup.ps1` (une seule ligne à configurer → CLAUDE.md suffit).
- Modification de la logique de `generate_i18n_dicts.ps1`.
