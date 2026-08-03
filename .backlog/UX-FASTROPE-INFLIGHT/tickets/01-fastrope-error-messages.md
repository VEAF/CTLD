Status: ⬜ ready

# 01 — Messages d'erreur fast-rope distincts

## Parent

[UX-FASTROPE-INFLIGHT PRD](../PRD.md)

## What to build

Remplacer le message d'erreur générique "Too high or too fast to drop troops!" par deux
messages distincts émis indépendamment selon la condition qui bloque le fast-rope :

- Altitude AGL > `fastRopeMaximumHeight` → message avec la hauteur max en pieds
- Vitesse ≥ 2.2 m/s → message demandant de passer en stationnaire

Les deux peuvent s'afficher simultanément si les deux conditions échouent. Les deux clés
i18n sont ajoutées en EN et FR. L'ancienne clé combinée devient STALE.

Les tests unitaires couvrent les quatre cas : seul trop haut, seul trop rapide, les deux,
et aucun (fast-rope réussi — pas de message).

## Acceptance criteria

- [ ] Cliquer "Disembark Troops" quand trop haut (vitesse ok) affiche uniquement le message altitude
- [ ] Cliquer "Disembark Troops" quand trop rapide (altitude ok) affiche uniquement le message vitesse
- [ ] Cliquer quand les deux conditions échouent affiche les deux messages
- [ ] Cliquer quand les conditions sont réunies : aucun message de blocage, débarquement déclenché
- [ ] Clés i18n EN et FR présentes et non vides
- [ ] Ancienne clé combinée marquée STALE dans les fichiers i18n
- [ ] Tests unitaires verts dans `busted tests/ci/`

## Blocked by

None — can start immediately.
