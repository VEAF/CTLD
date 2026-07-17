Status: ✅ done
Type: AFK

# 02 — Correction chemins recette/ dans MT-06

## What to build

Corriger deux chemins de scripts périmés dans les prérequis de MT-06
(`tests/manual_test_sequences.md`). Le dossier `recette/` a été renommé `tests/dcs/util/`
lors du lot `DCS-BRIDGE-MCP` mais les références dans MT-06 n'ont pas été mises à jour,
rendant la séquence inexécutable telle quelle.

Deux occurrences à corriger :
- `recette/enable_debug.lua` → `tests/dcs/util/enable_debug.lua`
- `recette/inject_red_fob.lua` → `tests/dcs/util/inject_red_fob.lua`

## Acceptance criteria

- [ ] Les deux chemins dans les prérequis de MT-06 pointent vers `tests/dcs/util/`
- [ ] Les deux fichiers cibles existent bien à leurs nouveaux chemins (vérification
  préalable au commit)
- [ ] Aucune autre occurrence de `recette/` dans `tests/manual_test_sequences.md`

## Blocked by

None — can start immediately.
