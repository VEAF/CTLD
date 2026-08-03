Status: ⬜ ready

# PRD — UX-FASTROPE-INFLIGHT : "Disembark Troops" visible en vol

## Problem Statement

Le pilote d'hélicoptère qui vole en stationnaire bas avec des troupes à bord ne voit pas
l'entrée "Débarquer les troupes" dans le menu F10 CTLD. Cette entrée n'est rendue que
lorsque l'appareil est au sol (`if not inAir`). Le fast-rope — dépose de troupes en vol
stationnaire sans se poser — est donc inaccessible par le menu, même quand toutes les
conditions sont réunies. Le pilote est contraint d'atterrir pour déclencher le débarquement,
ce qui est incohérent avec la réalité opérationnelle et la feature fast-rope déjà implémentée
dans le moteur.

Le message d'erreur actuel quand les conditions ne sont pas remplies est générique :
"Too high or too fast to drop troops!" — sans distinguer quelle condition bloque ni quelle
action corrective prendre.

## Solution

Afficher l'entrée "Disembark Troops" / "Débarquer les troupes" en vol dès que
`enableFastRopeInsertion = true` et que des troupes sont à bord. Quand le pilote clique :
- Conditions réunies → fast-rope immédiat (comportement inchangé)
- Trop haut seulement → message "Trop haut — descendez sous X ft"
- Trop rapide seulement → message "Trop rapide — passez en stationnaire"
- Les deux conditions manquantes → les deux messages

Si `enableFastRopeInsertion = false` : aucune entrée en vol (comportement actuel conservé).

## User Stories

1. As a helicopter pilot, I want to see the "Disembark Troops" option in the F10 menu while
   hovering low, so that I can fast-rope troops without landing first.
2. As a helicopter pilot who took a slot while already airborne, I want the "Disembark Troops"
   option to appear immediately (within ~1 s) in the F10 menu if I have troops and fast-rope
   is enabled, so that I don't have to land and take off again to make the option appear.
3. As a helicopter pilot hovering too high, I want to see a specific message telling me I need
   to descend below X feet, so that I know exactly what to correct.
4. As a helicopter pilot flying too fast, I want to see a specific message telling me to slow
   down and hover, so that I know exactly what to correct.
5. As a helicopter pilot who is both too high and too fast, I want to see both messages, so
   that I can correct both issues.
6. As a mission maker who has disabled fast-rope (`enableFastRopeInsertion = false`), I want
   the "Disembark Troops" option to remain absent while the aircraft is in flight, so that
   the behaviour is unchanged and pilots must land.
7. As a helicopter pilot on the ground with troops onboard, I want the "Disembark Troops"
   option to continue working exactly as before, so that ground operations are unaffected.
8. As a helicopter pilot, I want the "Disembark Troops" option to disappear from the in-flight
   menu once I have disembarked all troop groups, so that the menu stays consistent with the
   aircraft's actual state.

## Implementation Decisions

- **`refreshMenuSection` — bloc `inAir`** : le bloc `if not inAir then` qui rend l'entrée
  "Disembark Troops" est extrait (ou dupliqué) pour s'appliquer aussi à `inAir == true`,
  sous la condition supplémentaire `enableFastRopeInsertion == true`. Les deux chemins
  (sol et vol) partagent le même handler de callback.

- **`disembark()` — messages d'erreur distincts** : remplacer le message unique "Too high or
  too fast" par deux messages séparés, émis seulement si la condition correspondante échoue :
  - Altitude AGL > `fastRopeMaximumHeight` → message "altitude" avec valeur en pieds
  - Vitesse ≥ 2.2 m/s → message "vitesse"
  Les deux peuvent s'afficher simultanément (`outTextForGroup` appelé deux fois).

- **Refresh au takeoff/landing** : `S_EVENT_TAKEOFF` (via le poller 0.5 s existant) déclenche
  déjà `refreshMenuSection`. Aucune modification du cycle de refresh n'est nécessaire : le
  menu en vol sera construit correctement dès que `_isFlying = true` et que `refreshMenuSection`
  est appelé. La prise de slot en vol est couverte par le poller 0.5 s (`_inAirDebounce`)
  qui détecte l'état vol et déclenche le refresh dans la seconde suivant la prise de slot.

- **Multi-groupe en vol** : le sous-menu "Disembark Troops" avec une entrée par groupe
  (chemin `#inTransitList > 1`) doit également être rendu en vol, sous les mêmes conditions.

- **i18n** : deux nouvelles clés distinctes remplacent la clé combinée existante :
  - `"Too high to fast-rope! Descend below %1 ft."`
  - `"Too fast to fast-rope! Slow down and hover."`
  La clé combinée existante peut devenir STALE (commentée) si elle n'est plus utilisée
  ailleurs.

## Testing Decisions

Les bons tests vérifient le comportement observable externe, pas l'implémentation :
- Pour `_safeToFastRope` : retour booléen selon les combinaisons AGL/vitesse
- Pour `disembark` : quels messages sont émis selon l'état de l'unité
- Pour `refreshMenuSection` : quelles entrées de menu sont présentes/absentes selon le
  contexte (inAir, hasTroops, enableFastRopeInsertion)

**Modules testés :**
- `CTLDTroopManager:_safeToFastRope(unit)` — conditions AGL / vitesse séparément et combinées
- `CTLDTroopManager:disembark(unit)` — messages d'erreur distincts selon la condition manquante
- `CTLDTroopManager:refreshMenuSection(playerObj, overrideInAir)` — présence/absence de
  l'entrée "Disembark Troops" selon `overrideInAir`, `hasTroops`, `enableFastRopeInsertion`

**Prior art :**
- `tests/ci/unit/troop_manager_spec.lua` — mock DCS APIs, tests unitaires du TroopManager
- `tests/ci/unit/jtac_drone_globals_spec.lua` — pattern de test pour fonctions à paramètre config

## Out of Scope

- Modification du label de l'entrée de menu (reste "Disembark Troops" en vol et au sol)
- Ajout d'une animation ou d'un effet visuel fast-rope
- Débarquement automatique sans action pilote
- Modification du comportement au sol

## Further Notes

Le moteur fast-rope existe depuis l'origine : `_safeToFastRope` + la garde dans `disembark()`
sont déjà en place. Ce lot ne modifie pas la logique métier du fast-rope — il corrige
uniquement la visibilité du menu et la qualité des messages d'erreur.
