Status: open

# PRD — FIX-I18N-HARDCODED

> Corriger les chaînes UI player-facing hardcodées qui ne passent pas par `ctld.tr()`.
> Audit codebase complet — deux zones identifiées : noms de couches RECON et messages AA system.
> Cadré via grill-with-docs (2026-07-22).

## Problem Statement

Un audit i18n de `src/` a révélé deux zones où des chaînes player-facing ne passent pas par
`ctld.tr()`, rendant ces textes intraduisibles quelle que soit la langue configurée :

1. **RECON layer names** (`CTLD_recon.lua`) : les 7 noms de couches (`"Infantry"`,
   `"Air Defense (AA)"`, `"Ground Vehicles"`, `"Helicopters"`, `"Aircraft"`, `"Ships"`,
   `"FARP / FOB"`) sont des littéraux hardcodés dans `_defaultLayers`. Ils sont injectés
   directement dans les labels F10 (`string.format("%s %s", layer.name, action)`) et dans
   un message outText (`ctld.tr("Recon layer '%1': %2", layer.name, state)`).

2. **AA system outText** (`CTLD_aasystem.lua`) : 6 appels `outTextForCoalition`/
   `outTextForGroup` utilisent `string.format("literal %s/%d", ...)` sans `ctld.tr()` :
   - Ligne 262 : `"Cannot deploy %s: AA system limit reached (%d/%d)"`
   - Ligne 327 : `"AI deployed a full %s.\n\nAA Active System limit: %d\nActive: %d"`
   - Ligne 497 : `"%s successfully deployed a full %s in the field.\n\nAA Active System limit: %d\nActive: %d"`
   - Ligne 569 : `"%s successfully rearmed a full %s in the field"`
   - Ligne 591 : `"Cannot repair %s. No damaged %s within %dm"`
   - Ligne 634 : `"%s successfully repaired a full %s in the field."`

Les `desc` fields de `CTLD_config.lua` et les noms de scènes sont déjà correctement passés
par `ctld.tr()` à leur site d'utilisation — ils sont hors scope.

## Solution

### Étape 1 — RECON layer names

Wrapper `layer.name` dans `ctld.tr(layer.name)` aux deux sites d'utilisation :
- `CTLD_recon.lua:1017` : `string.format("%s %s", layer.name, action)`
  → `string.format("%s %s", ctld.tr(layer.name), action)`
- `CTLD_recon.lua:812` : `ctld.tr("Recon layer '%1': %2", layer.name, state)`
  → `ctld.tr("Recon layer '%1': %2", ctld.tr(layer.name), state)`

La table `_defaultLayers` reste inchangée — les strings EN servent de clés i18n.
Ajouter les 7 clés dans `CTLD_i18n_en.lua` et leurs traductions FR dans `CTLD_i18n_fr.lua`.

### Étape 2 — AA system messages

Remplacer chaque `string.format("literal %s/%d", ...)` par `ctld.tr("literal %1/%2", ...)`
en convertissant les placeholders `%s`/`%d` en `%1`/`%2`/`%3` (convention ctld.tr).
Ajouter les 6 clés dans `CTLD_i18n_en.lua` et leurs traductions FR.

## Implementation Decisions

- **Site de wrapping RECON** : aux deux sites d'utilisation (ligne 812 et 1017), pas dans
  `_defaultLayers` — la table garde les strings EN comme clés i18n. Cohérent avec le
  pattern existant partout dans le code.
- **Placeholders AA** : `%s`/`%d` → `%1`/`%2`/`%3` (convention ctld.tr existante,
  voir ligne 433 du même fichier pour exemple).
- **Tests** : tests unitaires busted mockant `ctld.tr` pour vérifier qu'il est appelé
  sur les layer names et les messages AA.
- **Rebuild obligatoire** : `merge_CTLD.ps1` après tout changement `src/`.
- **Pas d'ADR** : fix straightforward, pas de trade-off architectural.

## Out of Scope

- `desc` fields CTLD_config.lua (déjà via ctld.tr au site d'utilisation).
- Noms de scènes (déjà via ctld.tr au site d'utilisation).
- Debug log `CTLD_crate.lua:952` (message interne non player-facing).
- Message scene manager `"[CTLD] Scene '%s' requires CTLD >= %s..."` (dev/MM-facing,
  écrit en log seulement).
- Langues ES/KO (les clés sont ajoutées au dict EN — les traductions ES/KO restent vides
  et seront remplies par auto-translate ou manuellement).
