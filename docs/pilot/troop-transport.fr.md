# Transport de troupes

Votre aéronef de transport peut emmener des équipes d'infanterie au combat et les en extraire.
Les troops ne sont jamais spawnées comme des unités DCS dans votre cabine — elles sont conservées
« à bord » en mémoire jusqu'à ce que vous les déposiez, de sorte que le chargement et le
déchargement sont instantanés et sans poids pour le pilotage, tout en comptant dans votre capacité.

Tout se passe via **F10 → CTLD → Troop Commands**. Le menu est contextuel : les entrées
apparaissent selon que vous êtes au sol ou en vol, et selon que vous vous trouvez ou non dans une
zone pertinente. Il est reconstruit automatiquement à chaque atterrissage ou décollage, et
immédiatement après chaque chargement ou dépose.

## Le cycle de transport

Une sortie typique enchaîne ces étapes. Chacune fait passer le groupe dans un nouvel état :

1. **Charger depuis une pickup zone** — atterrissez dans une troop zone (`TRZ_`) et embarquez une
   équipe. → le groupe est désormais `TRZ_LOADED` (à bord).
2. **Disembark** — déposez-les sur l'objectif. → `deployed` au sol comme groupe actif.
   - Si vous débarquez dans une **extract zone** (`EXZ_`), il s'agit à la place d'une dépose
     silencieuse sur objectif : le compteur de la zone est incrémenté et **aucun groupe n'est
     spawné**. → `DEPLOYED_EXZ`.
3. **Extract from the field** — atterrissez près d'un groupe que vous (ou un autre pilote) avez
   déposé plus tôt et reprenez-le. → `FIELD_LOADED` (de nouveau à bord).
4. **Disembark** à nouveau à un nouvel endroit — répétez les étapes 3–4 autant que nécessaire.
5. **Revenir à une pickup zone** — atterrissez dans une `TRZ_` alors que vous transportez des
   troops pour les rendre ; le stock de la zone est restauré. → `RETURNED_TO_TRZ`.

D'où proviennent les pickup zones, les extract zones et les équipes chargeables est défini par le
mission maker — voir [Configuration des zones](../mission-maker/zones.md) et
[Configuration](../mission-maker/configuration.md).

> Les deux flux sont détaillés dans les diagrammes de référence :
> [flux de transport de troops](../assets/troops_transport_flows.svg) et
> [cycle de vie troop + JTAC](../assets/troops_jtac_lifecycle.svg).

## Le menu F10

```
CTLD
  └── Troop Commands
        ├── Disembark Troops                    ← on the ground, when carrying troops
        │   or Disembark Troops (submenu)       ← if 2+ groups on board:
        │       ├── Disembark All
        │       ├── [1] <group name>
        │       └── [2] <group name>
        ├── Embark / Extract Troops             ← on the ground
        │     ├── Load from TRZ_<zone>          ←   one submenu per pickup zone you are inside
        │     │     ├── Load <team name>        ←     teams that fit your remaining capacity
        │     │     └── ...
        │     ├── Extract: <group name>         ←   a single group is nearby
        │     │   or Extract from field         ←   2+ groups nearby → submenu with distances:
        │     │       ├── <group name> (25m)
        │     │       └── <group name> (87m)
        │     └── (greyed out if there is nothing to load or extract)
        ├── Check Cargo                         ← on the ground
        └── Parachute Troops                    ← airborne only, if your aircraft can air-drop
            or Parachute Troops (submenu)       ← if 2+ groups on board (+ "Parachute All")
```

**Disembark Troops**, **Embark / Extract Troops** et **Check Cargo** n'apparaissent que lorsque
vous êtes au sol. **Parachute Troops** n'apparaît qu'en vol (et uniquement sur les aéronefs
configurés pour les largages aériens). Si **Embark / Extract Troops** n'a rien à proposer — vous
êtes à pleine capacité, aucune pickup zone n'est à portée et aucun groupe ami n'est dans le rayon
d'extraction — l'entrée est grisée.

## Charger des troops

Atterrissez dans une pickup zone (`TRZ_`), puis **F10 → CTLD → Troop Commands → Embark / Extract
Troops → Load from TRZ_&lt;zone&gt;**, et choisissez une équipe. Seules les équipes qui tiennent
dans la capacité de troops restante de votre aéronef (et que la zone a encore en stock) sont
listées.

Vous devez réellement être **à l'intérieur** de la zone et au sol, la zone doit être **active**, et
il doit lui rester des troops en stock — sinon le chargement est refusé avec un message expliquant
pourquoi.

## Débarquer des troops

Avec des troops à bord, **F10 → CTLD → Troop Commands → Disembark Troops**. Ce qui se passe dépend
de l'endroit où vous vous trouvez :

| Où vous êtes | Ce que fait « Disembark Troops » |
| --- | --- |
| En vol | Bouton non affiché — utilisez **Parachute Troops**, ou passez en vol stationnaire bas pour faire du fast-rope (voir ci-dessous) |
| Au sol, dans une extract zone (`EXZ_`) | Dépose silencieuse sur objectif — le compteur de la zone est incrémenté, aucun groupe spawné |
| Au sol, dans une zone de pickup uniquement (`TRZ_`) | Les troops sont rendues au stock de la zone |
| Au sol, dans aucune zone | Dépose de combat — le groupe spawne autour de vous |

Lors d'une simple dépose de combat, l'équipe spawne dans un **cercle centré juste à côté de votre
aéronef**, tous orientés selon votre cap, afin que personne ne spawne sous les rotors. Si vous
déposez dans une waypoint zone (`WPZ_`), l'équipe marche automatiquement vers le centre de la zone,
armes libres.

### Fast-rope

Vous pouvez déposer des troops sans vous poser complètement en passant en **vol stationnaire bas et
lent** :

- Le fast-rope doit être activé par la mission (`enableFastRopeInsertion`, activé par défaut).
- Hauteur inférieure ou égale à environ **60 ft** AGL (`fastRopeMaximumHeight`, ≈ 18,28 m).
- Vitesse sol inférieure à environ **8 km/h** (2,2 m/s) — essentiellement un stationnaire stable.

Si ces conditions sont réunies, **Disembark Troops** fait descendre l'équipe en fast-rope ; la
confirmation indique « fast-roped ... into combat. » Si vous êtes trop haut ou trop rapide, la
dépose est refusée avec un message vous demandant de descendre en stationnaire ou d'atterrir.

## Extraire depuis le terrain

Pour récupérer un groupe déposé plus tôt, atterrissez dans le rayon d'extraction (par défaut
**125 m**, `maxExtractDistance`) et utilisez **Embark / Extract Troops** :

- Un seul groupe à proximité → un bouton direct **Extract: &lt;group name&gt;**.
- Plusieurs à proximité → un sous-menu **Extract from field** listant chaque groupe avec sa
  distance, par ex. `Bravo (25m)`.

Vous devez être au sol, et vous avez besoin d'assez de capacité disponible pour prendre le groupe à
bord. L'équipe extraite conserve son identité et ses éventuels ordres, de sorte que vous pouvez la
redéposer ailleurs.

Les mission makers peuvent aussi rendre extractables de cette façon des groupes pré-placés sur la
carte, sans pickup zone — voir [Configuration des zones](../mission-maker/zones.md).

## Parachuter des troops

En vol au-dessus de la zone de largage, **F10 → CTLD → Troop Commands → Parachute Troops** largue
l'équipe par parachute virtuel (disponible uniquement sur les aéronefs autorisés par la mission aux
largages aériens). Voir [Parachute](parachute.md) pour l'ensemble des mécaniques de largage.

## Vérifier le chargement

Au sol, **F10 → CTLD → Troop Commands → Check Cargo** rapporte ce que vous transportez — nom de
l'équipe, nombre de troops et poids, avec une ligne de total lorsque plusieurs groupes sont à bord.

## Transporter plusieurs groupes à la fois

Vous pouvez charger plus d'une équipe, tant que le nombre total de troops reste dans la capacité de
votre aéronef. Chaque groupe est suivi séparément. Dès que vous en avez deux ou plus à bord, les
entrées **Disembark Troops** et **Parachute Troops** se transforment en sous-menus :

- **Disembark All** / **Parachute All** — déployer tous les groupes à la suite.
- **[1] &lt;name&gt;**, **[2] &lt;name&gt;** — déployer un groupe précis.

## Équipes JTAC

Certaines équipes incluent un JTAC. Lorsque vous débarquez un tel groupe, le JTAC commence
automatiquement à illuminer des cibles ; si vous extrayez ou rendez le groupe, son illumination
s'arrête. Voir [JTAC](jtac.md) pour l'utilisation des JTAC une fois au sol.

## Voir aussi

- [Parachute](parachute.md) — larguer troops et crates par voie aérienne
- [JTAC](jtac.md) — déployer et utiliser des équipes JTAC
- [Configuration des zones](../mission-maker/zones.md) — comment sont définies les pickup, extract et waypoint zones
- [Configuration](../mission-maker/configuration.md) — capacité de troops par aéronef et réglages de fast-rope
