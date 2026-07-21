# 01 — FR nav_translations + harmonise page H1s (French text, English anchors)

Status: 🚧 in progress
Type: AFK
Repo: CTLD
GitHub: —

## What to build

### 1. `mkdocs.yml` — FR `nav_translations`

Under `plugins → i18n → languages → (locale: fr)`, add a `nav_translations:` map. The plugin
replaces nav labels by **exact text match**, so one entry per unique EN label. Agreed table:

| EN | FR |
|----|----|
| Home | Accueil |
| Pilot | Pilote |
| Overview | Vue d'ensemble |
| Troop transport | Transport de troupes |
| Crates | Caisses (crates) |
| Vehicles | Véhicules |
| Sling-load | Élingue (sling-load) |
| Parachute | Parachute |
| JTAC | JTAC |
| Recon | Reconnaissance (recon) |
| Beacons | Balises (beacons) |
| Smoke | Fumigène (smoke) |
| Pack | Pack |
| Mission Maker | Concepteur de mission (mission maker) |
| Configuration | Configuration |
| Configure with ctld-tools | Configurer avec ctld-tools |
| Zone setup | Configuration des zones |
| Scenes & FOB | Scènes & FOB |
| Crate catalogue | Catalogue de caisses (crates) |
| Minefield | Champ de mines |
| Validating your config | Valider votre configuration |
| Translations | Traductions |
| Legacy API | API historique |
| Developer | Développeur |
| Development workflow | Workflow de développement |
| Architecture | Architecture |
| Subsystems | Sous-systèmes |
| Scene engine | Moteur de scènes |
| Crate spawn pipeline | Pipeline de spawn des caisses (crates) |
| Troop + JTAC lifecycle | Cycle de vie troupes + JTAC (troops) |
| Zone management | Gestion des zones |
| Vehicle system | Système de véhicules |
| Beacon system | Système de balises (beacons) |
| Recon system | Système de reconnaissance (recon) |
| F10 menu system | Système de menu F10 |
| Player tracking | Suivi des joueurs |
| AA system assembly | Assemblage des systèmes AA |
| Events | Événements |
| Internationalisation | Internationalisation |
| Building & testing | Build et tests |
| Integration testing | Tests d'intégration |
| Migration v1 → v2 | Migration v1 → v2 |
| API reference | Référence de l'API |
| Design spec | Spécification de conception |

### 2. `.fr.md` H1s — `French (dcs-term) { #english-slug }`

Rewrite every FR H1 so the text is French (jargon in the `FR (term)` form) and the anchor is the
English page slug. The English slug = the slug mkdocs generates from the EN page's own H1.

### 3. Drop "CTLD Next"

`developer/integration-testing.md` (EN) H1 → `# Release Testing Procedure`; the FR H1 →
`# Procédure de test de version { #release-testing-procedure }`.

## Acceptance criteria

- [ ] `nav_translations` present under the FR locale with the full table above.
- [ ] Each FR H1 = French text + explicit `{ #english-slug }`.
- [ ] No "CTLD Next" anywhere in `docs/`.
- [ ] `mkdocs build --strict` clean (or CI docs build green).
