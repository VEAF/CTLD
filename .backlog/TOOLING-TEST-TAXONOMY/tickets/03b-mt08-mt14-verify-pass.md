Status: ✅ done
Type: HITL (DCS live + dcs-bridge requis)

# 03b — Vérifier PASS de mt08/mt14 en DCS live

## What to build

Valider en DCS live que le fix de waypoint (ticket 03a) suffit à débloquer `mt08` et
`mt14` : les deux scénarios doivent atteindre PASS sous `--tier auto-slow`.

Prérequis avant de commencer :
- dcs-bridge installé et opérationnel (`tools/dcs-bridge/install.ps1` exécuté,
  `dcs-client.yaml` configuré, `dcs-serve` démarré)
- Mission `Test_CTLDNEXT_01.miz` rechargée avec le fix du ticket 03a
- Joueur parqué dans un slot BLUE (UH-1H)

Commande de vérification :
```
python tools/integration-runner/run_scenarios.py --tier auto-slow --poll-timeout 900
```

Si l'un des deux scénarios échoue encore, diagnostiquer (CTLD.log + positions des
waypoints) et ajuster le waypoint jusqu'à PASS. Si le blocage s'avère non fixable par
un simple déplacement de waypoint, retagger `disabled` et documenter la cause dans
l'ADR 0006 (mise à jour des exemples).

## Acceptance criteria

- [ ] `mt08_ai_vehicle_transport` : verdict `PASS` sous `--tier auto-slow --poll-timeout 900`
- [ ] `mt14_ai_aa_system` : verdict `PASS` sous `--tier auto-slow --poll-timeout 900`
- [ ] Aucune régression sur les autres scénarios `auto-slow` (`mt09`–`mt13`,
  `scenario_ai_troops`, `scenario_unpack_jtac_drone`)

## Blocked by

- Ticket 03a (fix waypoint + retag)
- dcs-bridge installé (todo externe au lot)
