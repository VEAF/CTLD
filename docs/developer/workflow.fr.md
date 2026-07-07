# Workflow de développement

Cette page documente la manière dont le développement de CTLD est mené : le processus de
backlog, le Git Flow, le développement piloté par les tests, la construction et les portes de
qualité, ainsi que les skills d'écriture utilisés pour conduire le travail. C'est le manuel
opératoire des contributeurs — le « comment nous travaillons », en complément du « comment
c'est construit » du reste de cette section.

## Processus de backlog

CTLD **n'utilise pas** les GitHub Issues comme tracker. Il utilise un **backlog markdown local**
sous `.backlog/`, versionné avec le code. Cela maintient la planification dans le même flux de
revue que le changement lui-même.

- **Un lot = un répertoire** `.backlog/<LOT-ID>/`. Un *lot* est une unité de travail cohérente
  qui est livrée sous forme d'une seule branche et d'une seule pull request.
- **PRD** — `.backlog/<LOT-ID>/PRD.md` contient l'énoncé du problème, la solution, les décisions,
  le périmètre, la définition de « terminé » et les notes de hors-périmètre. Il cite son ou ses
  ADR le cas échéant.
- **Tickets** — `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`, numérotés à partir de `01` dans
  l'ordre des dépendances, sous forme de tranches verticales « tracer-bullet ».
- **Index** — `.backlog/README.md` est un tableau maintenu à la main de chaque lot et de son
  statut (pas de générateur).
- **Archivage** — les lots clos depuis plus de trois jours sont compactés dans
  `.backlog/archive/<LOT-ID>.md`, en préservant le tableau des tickets.

### Convention d'identifiant de lot

Préfixes sémantiques : `FEAT-*`, `FIX-*`, `DOC-*`, `TOOLING-*`, `UX-*`, `RELEASE`. Par exemple
`FEAT-JTAC-DRONE-ORBIT`, `FIX-MENU-REFRESH`, `TOOLING-INTEGRATION-TEST-RUNNER`.

### Vocabulaire des statuts

Une ligne `Status:` en tête de chaque fichier PRD / ticket fait foi pour son état de cycle de
vie ; `.backlog/README.md` la reflète dans l'index.

| Statut | Emoji | Signification |
| --- | --- | --- |
| ready | ⬜ | prêt à être pris en charge |
| in-progress | 🔄 | en cours de traitement |
| waiting-human | 🧑 | nécessite une décision humaine ou plus d'informations |
| done | ✅ | livré |
| wontfix | 🚫 | délibérément non traité |

La configuration du tracker vit dans `dev/agents/issue-tracker.md` ; le vocabulaire des statuts
dans `dev/agents/triage-labels.md`.

## Git Flow

- Le travail se déroule sur des branches `feature/*` ou `fix/*` issues de `develop`. Ne jamais
  committer directement sur `develop` ou `master`.
- **Une branche / une PR par lot** — tous les tickets d'un lot atterrissent ensemble, même si le
  backlog les découpe individuellement.
- Les commits suivent les **Conventional Commits** en anglais.
- `develop` est la branche d'intégration ; les releases sont promues de `develop` vers `master`
  (voir le processus de release).

## Développement piloté par les tests

Toute logique nouvelle ou modifiée est livrée **test-first** : écrire une spec
[busted](building-and-testing.md) qui échoue, la faire passer, puis refactorer. La porte de
couverture est un **cliquet** — la CI impose un plancher qui ne fait que monter, si bien que la
couverture ne peut pas régresser.

Voir [Construction et tests](building-and-testing.md) pour les commandes concrètes, le cliquet de
couverture, la journalisation et la configuration de débogage.

## Construction et portes de qualité

- **Livrable** — seul `CTLD.lua` doit être du **Lua 5.1** pur (DCS tourne en Lua 5.1 ; pas de
  syntaxe 5.2+). Il est *généré* par `tools/build/merge_CTLD.ps1` et ne doit jamais être édité à
  la main ; reconstruire après tout changement dans `src/`.
- **Portes de CI** (au push sur `develop` et sur les PR qui la ciblent) :
    - `lua-lint` — vérification syntaxique avec `luac5.1 -p`.
    - `luacheck` — `--config .luacheckrc src/` doit être propre.
    - tests **busted** + cliquet de couverture.
    - scan de secrets **gitleaks**.
    - Build de fusion — `CTLD.lua` est produit d'une seule manière canonique à partir de `src/`.
- **Docs** — quand un comportement ou une interface change, les pages `docs/` concernées changent
  dans la même PR.

## Skills d'écriture

Le programme de ré-outillage est mené avec trois skills d'écriture agnostiques du tracker (ils
écrivent dans le `.backlog/` local, pas dans GitHub) :

| Skill | Rôle dans le flux |
| --- | --- |
| `grill-with-docs` | Éprouve un plan face au modèle de domaine du projet et aux décisions documentées (`CONTEXT.md`, ADR), affine la terminologie et met à jour cette documentation au fil de l'eau à mesure que les décisions se cristallisent. Utilisé **avant** de s'engager sur une conception. |
| `to-prd` | Transforme la conversation/le contexte qui en résulte en un `PRD.md` pour le lot. Utilisé pour **ouvrir** un lot. |
| `to-issues` | Découpe le plan/PRD en tickets indépendamment saisissables sous forme de tranches verticales « tracer-bullet ». Utilisé pour **remplir** le `tickets/` d'un lot. |

Séquence typique pour un nouveau lot : `grill-with-docs` (converger sur la conception) → `to-prd`
(rédiger le PRD) → `to-issues` (découper les tickets) → implémenter sur une branche `feature/*`
(TDD) → PR vers `develop`.

## Séquence de bout en bout par défaut

1. Synchroniser `develop` (`git pull --ff-only`).
2. Créer le lot dans `.backlog/` (PRD + tickets).
3. Créer la branche (`feature/*` ou `fix/*`).
4. Implémenter avec les tests (TDD) ; reconstruire `CTLD.lua` si `src/` a changé ; mettre à jour
   `docs/`.
5. Lancer `busted tests/ci/` et `luacheck`.
6. Mettre à jour `CHANGELOG.md` `[Unreleased]`.
7. Committer + pusher ; ouvrir une PR vers `develop`.
8. Traiter la revue / la CI ; merger ; revenir à `develop`.
