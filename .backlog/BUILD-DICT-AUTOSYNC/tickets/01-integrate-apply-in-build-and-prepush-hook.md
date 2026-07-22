Status: open

# Ticket 01 — Intégrer -Apply dans merge_CTLD.ps1 et créer le hook pre-push

## Parent

[BUILD-DICT-AUTOSYNC PRD](../PRD.md)

## What to build

1. `merge_CTLD.ps1` : appeler `generate_i18n_dicts.ps1 -Apply` après gen-config, avant le
   merge loop. Le build continue même si des stubs ont été ajoutés.

2. `.githooks/pre-push` : script bash cross-platform (pwsh / powershell / skip). Dry-run,
   bloquant sur MISSING, avertissement sur STALE.

3. `CLAUDE.md` : ajouter `git config core.hooksPath .githooks` dans la section Build.

## Acceptance criteria

- [ ] `merge_CTLD.ps1` appelle `generate_i18n_dicts.ps1 -Apply` avant le merge loop
- [ ] Le build ne s'arrête pas si des stubs vides sont ajoutés (exit 0 du script)
- [ ] Le build s'arrête si le script échoue (erreur interne, exit non-nul)
- [ ] `.githooks/pre-push` existe, est exécutable, shebang `#!/usr/bin/env bash`
- [ ] Le hook détecte `pwsh` puis `powershell`, avertit et passe si aucun disponible
- [ ] Le hook bloque (`exit 1`) si le dry-run détecte des clés MISSING
- [ ] Le hook avertit mais laisse passer (`exit 0`) si seulement des clés STALE
- [ ] `CLAUDE.md` documente `git config core.hooksPath .githooks`
- [ ] CHANGELOG.md `[Unreleased]` mis à jour

## Blocked by

None — can start immediately.
