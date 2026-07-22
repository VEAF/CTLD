Status: open

# Ticket 01 — Ajouter le niveau INFO au startup report et migrer INIT-E

## Parent

[STARTUP-REPORT-INFO-LEVEL PRD](../PRD.md)

## What to build

Étendre `ctld.startupReport.flush()` pour supporter un troisième niveau de sévérité `INFO` :
les entrées `INFO` sont écrites dans le bloc `CTLD_STARTUP_REPORT` de `DCS.log` mais ne
déclenchent aucun `outText`. `[OK]` n'est affiché que si le collecteur est totalement vide.

Migrer INIT-E (`CTLDCoreManager._initExtractableGroups`) de `"NOTICE"` vers `"INFO"` : une
substitution d'une chaîne dans un seul appel `ctld.startupReport.add()`.

Amender ADR 0010 pour y ajouter `INFO` dans la table des sévérités.

## Acceptance criteria

- [ ] `flush()` avec une entrée `INFO` seule : le bloc log contient `[INFO] ...`, aucun `outText`,
      `[OK]` absent.
- [ ] `flush()` avec `INFO` + `NOTICE` : `outText` émis (NOTICE uniquement), entrée `INFO` dans
      le log.
- [ ] `flush()` avec `INFO` + `ERROR` : bannière alarme à l'écran, entrée `INFO` dans le log.
- [ ] `flush()` sans entrée : `[OK]` présent dans le log, aucun `outText` (comportement inchangé).
- [ ] INIT-E émet `"INFO"` (non `"NOTICE"`) → plus aucun `outText` pour les groupes extractables
      absents.
- [ ] `busted tests/ci/unit` 991+ tests pass.
- [ ] ADR 0010 amendé.
- [ ] CHANGELOG.md `[Unreleased]` mis à jour.

## Blocked by

None — can start immediately.
