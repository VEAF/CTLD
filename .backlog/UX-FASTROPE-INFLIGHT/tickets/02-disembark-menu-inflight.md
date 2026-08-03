Status: ⬜ ready

# 02 — "Disembark Troops" visible en vol

## Parent

[UX-FASTROPE-INFLIGHT PRD](../PRD.md)

## What to build

Rendre l'entrée "Disembark Troops" dans le menu F10 CTLD quand l'hélico est en vol,
sous les conditions suivantes :

- `enableFastRopeInsertion = true`
- Des troupes sont à bord

Le comportement au clic reste identique (délégue à `disembark()` qui gère le fast-rope
ou bloque avec les messages du ticket 01). Le chemin multi-groupe (sous-menu avec une
entrée par groupe + "Disembark All") est également rendu en vol.

Si `enableFastRopeInsertion = false` : aucune entrée en vol (comportement actuel conservé).
Le comportement au sol est inchangé dans tous les cas.

La prise de slot en vol est couverte par le poller 0.5 s existant (`_inAirDebounce`) qui
déclenche `refreshMenuSection` dans la seconde suivant la prise de slot.

Les tests unitaires couvrent la présence/absence de l'entrée selon les combinaisons :
`inAir` × `hasTroops` × `enableFastRopeInsertion`.

## Acceptance criteria

- [ ] En vol avec troupes et `enableFastRopeInsertion=true` : entrée "Disembark Troops" présente dans le menu F10
- [ ] En vol avec troupes et `enableFastRopeInsertion=false` : entrée absente
- [ ] En vol sans troupes : entrée absente
- [ ] Prise de slot en vol : entrée apparaît dans la seconde (poller 0.5 s)
- [ ] Multi-groupe en vol : sous-menu avec une entrée par groupe + "Disembark All"
- [ ] Après débarquement du dernier groupe : entrée disparaît du menu en vol
- [ ] Comportement au sol inchangé (entrée présente si troupes, absente sinon)
- [ ] Tests unitaires verts dans `busted tests/ci/`

## Blocked by

- [01 — Messages d'erreur fast-rope distincts](01-fastrope-error-messages.md)
