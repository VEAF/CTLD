Status: ✅ done
Type: AFK

# 03a — Fix waypoint Land de mt08/mt14 dans la mission de test

## What to build

Déplacer le waypoint `Land` des groupes `heliai_vehicle` (mt08) et `heliai_mt14` (mt14)
dans `Test_CTLDNEXT_01.miz` vers un terrain dégagé, éloigné de la zone urbaine qui cause
le blocage du pathfinding DCS. Les hélicos atteignent actuellement la zone de pickup mais
orbitent sans se poser (timeout 900 s), malgré un point `Land` géométriquement dans la
zone — le sol est trop accidenté / la proximité urbaine perturbe le pathfinding DCS.

La correction n'est pas dans le code CTLD ni dans la logique du scénario, mais dans la
mission elle-même : déplacer le waypoint vers un terrain plat et dégagé, toujours à
l'intérieur du rayon de la pickup zone, à l'écart de toute zone urbaine.

Une fois la mission corrigée, retagger les deux scénarios :
- `tests/dcs/pilotPassive/scenario_mt08_ai_vehicle_transport.lua` : `disabled` → `auto-slow`
- `tests/dcs/pilotPassive/scenario_mt14_ai_aa_system.lua` : `disabled` → `auto-slow`

La vérification PASS en DCS live est couverte par le ticket 03b (nécessite dcs-bridge).

## Acceptance criteria

- [ ] Waypoint `Land` de `heliai_vehicle` déplacé vers terrain dégagé dans la mission
- [ ] Waypoint `Land` de `heliai_mt14` déplacé vers terrain dégagé dans la mission
- [ ] Les deux scénarios retaggés `auto-slow` (header `-- @tier:` mis à jour)
- [ ] `-- @tier: disabled` n'apparaît plus dans ces deux fichiers

## Blocked by

- Ticket 01 (l'ADR 0006 doit exister avant de retirer le tag `disabled`, pour que le
  pattern soit documenté)
