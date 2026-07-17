Status: ✅ done
Type: AFK

# 01 — Glossaire + ADR 0006

## What to build

Mettre à jour la section "Testing terms" de `CONTEXT.md` pour refléter la taxonomie
actuelle issue de `CATCH-UP-PILOT-SCENARIOS`, et créer `dev/adr/0006-disabled-tier.md`.

**CONTEXT.md — termes à ajouter / corriger :**
- `Tier` — réécrire la définition pour couvrir les cinq valeurs actuelles : `auto`,
  `auto-check`, `auto-slow`, `human` (`human (fly)` / `human (menu)`), `disabled`.
  Lister `ia` et `--no-ai` comme termes bannis.
- `Headless sweep` — nouveau terme canonique pour l'exécution
  `run_scenarios.py --headless --reset-before-each`. Banni : `--no-ai sweep`.
- `L1–L6` — ajouter une table des six niveaux de test (dossier + qui pilote) absente
  du glossaire à ce jour.
- `Runner` — ajuster la définition pour nommer `run_scenarios.py` et
  `run_manual_scenario.py` (ancien nom `run_ia_scenario.py` banni).

**ADR 0006 — pattern `disabled` :**
Quand un scénario ne peut atteindre de verdict pour une raison externe à CTLD
(pathfinding DCS, mod absent), il est mis en quarantaine `disabled` plutôt que
supprimé ou laissé en rouge permanent. Exclu de tous les sweeps par défaut ;
atteignable uniquement via `--tier disabled`. La couverture logique vit dans des tests
déterministes rapides. Exemples concrets : `mt08`/`mt14` (pathfinding DCS) et
`scenario_warehouse_cycle` (mod `Farp_FG_Petit_Helipad` absent).

## Acceptance criteria

- [ ] `CONTEXT.md` — section "Testing terms" reflète les cinq tiers actuels, avec
  alias bannis (`ia`, `--no-ai`)
- [ ] `CONTEXT.md` — `Headless sweep` défini comme terme canonique
- [ ] `CONTEXT.md` — table L1–L6 présente avec dossier + qui pilote
- [ ] `dev/adr/0006-disabled-tier.md` créé, référencé dans `dev/adr/README.md`
- [ ] `luac -p` propre (pas de Lua modifié dans ce ticket, mais vérification de forme)

## Blocked by

None — can start immediately.
