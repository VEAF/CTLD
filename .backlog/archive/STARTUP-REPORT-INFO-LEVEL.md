# STARTUP-REPORT-INFO-LEVEL

**Status:** ✅ merged (PR #58). Compacted from `STARTUP-REPORT-INFO-LEVEL/` on 2026-08-01; the ticket files live on in git history.

Ajouter le niveau `INFO` au `ctld.startupReport` (log-only, sans écho écran) ; migrer INIT-E de `NOTICE` vers `INFO` pour supprimer le bruit des 25 placeholders `extractableGroups`.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-add-info-severity-and-migrate-init-e` | open | Ticket 01 — Ajouter le niveau INFO au startup report et migrer INIT-E |

## PRD

Status: open

## PRD — STARTUP-REPORT-INFO-LEVEL

> Ajouter un troisième niveau de sévérité `INFO` au `ctld.startupReport` — log-only, sans écho
> à l'écran — et migrer INIT-E de `NOTICE` vers `INFO`.
> Cadré via grill-with-docs (2026-07-22).

### Problem Statement

`ctld.startupReport` dispose de deux niveaux de sévérité (`ERROR` / `NOTICE`), tous deux capables
de déclencher un `outText` à l'écran. La décision `flush()` actuelle est :

| Niveau   | DCS.log | Écran |
|----------|---------|-------|
| `ERROR`  | ✅      | ✅ bannière alarme |
| `NOTICE` | ✅      | ✅ texte complet   |

INIT-E (`CTLDCoreManager._initExtractableGroups`) émet un `NOTICE` pour chaque groupe de la
config `extractableGroups` absent de la mission. Comme la config par défaut contient 25 noms
fictifs (`extract1`–`extract25`), toute mission qui ne configure pas cette fonctionnalité reçoit
25 messages à l'écran à chaque démarrage — alors que ces entrées ne signalent rien d'actionnable.

La cause profonde est l'absence d'un niveau intermédiaire : une entrée informative, non bloquante,
utile pour un MM qui consulte `DCS.log` mais qui ne mérite pas d'écran.

### Solution

Ajouter le niveau `INFO` au startup report, avec le comportement suivant :

| Niveau   | DCS.log | Écran |
|----------|---------|-------|
| `ERROR`  | ✅      | ✅ bannière alarme |
| `NOTICE` | ✅      | ✅ texte complet   |
| `INFO`   | ✅      | ❌                 |

`[OK]` est réservé à l'absence totale d'entrées (toutes sévérités confondues). Quand seules des
entrées `INFO` sont présentes : le bloc `CTLD_STARTUP_REPORT` les liste, l'écran reste silencieux,
`[OK]` n'est pas affiché.

Migrer INIT-E de `NOTICE` vers `INFO` : les groupes extractables absents de la mission sont une
information de diagnostic, pas un problème actionnable pour le MM.

### Implementation Decisions

- **`flush()` dans `CTLD_utils.lua`** : la boucle de construction du bloc log est inchangée
  (toutes les entrées sont formatées `[SEVERITY] source: message`). La logique `hasError` /
  `hasNotice` ignore les entrées `INFO`. L'émission `outText` est conditionnée uniquement par
  `hasError` ou `hasNotice`. `[OK]` n'est affiché que si `#entries == 0`.

- **`add()` dans `CTLD_utils.lua`** : aucun changement de signature — `severity` est une string
  libre, `"INFO"` est simplement une valeur supplémentaire acceptée.

- **Migration INIT-E** (`CTLD_core.lua:528`) : `"NOTICE"` → `"INFO"`. Une seule ligne.

- **Pas de nouveau fichier source** : tout est dans `CTLD_utils.lua` (flush) et `CTLD_core.lua`
  (INIT-E). Modification chirurgicale.

- **ADR 0010** : amender la table des sévérités pour y ajouter `INFO` (pas de nouvel ADR — c'est
  une extension directe du modèle existant, pas un nouveau trade-off architectural).

- **i18n** : aucune nouvelle clé — le message INIT-E existant est conservé, seule la sévérité
  change.

### Testing Decisions

- **`startup_report_spec.lua`** (extension) :
  - `add("INFO", ...)` + `flush()` → entrée présente dans le bloc log, zéro `outText`.
  - `add("INFO", ...)` seul → `[OK]` absent du log (le bloc contient l'entrée INFO).
  - `add("INFO", ...)` + `add("NOTICE", ...)` → `outText` émis (NOTICE), entrée INFO dans le log.
  - `add("INFO", ...)` + `add("ERROR", ...)` → bannière alarme à l'écran, entrée INFO dans le log.

- **`CTLD_core.lua` / INIT-E** : le test existant dans `zone_manager_spec.lua` (pattern) n'est
  pas applicable directement — INIT-E est testé par le scénario DCS F-200 (existant). Pas de
  nouveau scénario nécessaire : la migration est une substitution de string.

### Out of Scope

- Modifier les valeurs par défaut de `extractableGroups` (lot séparé si souhaité).
- Ajouter `INFO` dans d'autres managers que INIT-E — uniquement ce call site est migré.
- Filtrage ou agrégation des entrées INFO multiples.
