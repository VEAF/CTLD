# Documentation développeur { #developer-documentation }

Cette section est la référence technique pour travailler **sur** CTLD — son architecture, ses
sous-systèmes, son outillage de build et de test, son modèle d'événements, son
internationalisation et le workflow de développement utilisé pour mener le projet. Si vous
intégrez CTLD dans une mission plutôt que de le modifier, consultez plutôt le guide Mission Maker.

## Organisation de cette section { #how-this-section-is-organised }

| Page | Ce que vous y trouverez |
| --- | --- |
| [Workflow de développement](workflow.md) | Processus de backlog, Git Flow, TDD, quality gates, écriture de skills |
| [Architecture](architecture.md) | Structure du dépôt, pattern manager, séquence d'init, bibliothèques internes |
| [Sous-systèmes](subsystems/index.md) | Scenes, crates, troops/JTAC, zones, véhicules, beacons, recon, menu, joueurs, AA |
| [Événements](events.md) | Le bus d'événements interne et le catalogue complet des événements |
| [Internationalisation](i18n.md) | Fonctionnement de l'i18n, ajout de clés et de langues, overrides mission-maker |
| [Build & tests](building-and-testing.md) | Pipeline de build, busted, couverture, logging, configuration de debug |
| [Tests d'intégration](integration-testing.md) | Niveaux de test DCS live (L1–L6), la configuration martyr, tiers, exécution des scénarios |
| [Migration v1 → v2](migration-v1-v2.md) | Principe du wrapper legacy, table de migration, exemple concret |
| [Référence API](api-reference.md) | Méthodes publiques de chaque manager |
| [Spécification de conception](design-spec.md) | La justification derrière l'architecture v2 |

## L'architecture en un coup d'œil { #architecture-at-a-glance }

CTLD v2 est une **réécriture modulaire et testable** du script monolithique d'origine. Le source
Lua 5.1 pur vit sous `src/` (une classe par fichier) et est fusionné dans l'unique livrable
`CTLD.lua` par un build PowerShell.

Le runtime utilise un pattern de **manager singleton** : un manager par domaine, chacun obtenu
via `Manager.getInstance()`. Les managers n'appellent jamais directement les rouages internes des
autres pour les préoccupations transverses — ils communiquent à travers le bus d'événements
interne, `EventDispatcher`.

```
CTLDCoreManager          ← orchestrator, owns the init sequence
CTLDPlayerManager        ← tracks connected players, owns the F10 menu
CTLDZoneManager          ← pickup / extract / waypoint / logistic zones
CTLDTroopManager         ← troops boarding / deploying / extracting
CTLDCrateManager         ← crate spawn / load / unload / assembly
CTLDVehicleSpawner       ← vehicle request / pack
CTLDFOBManager           ← FOB construction pipeline
CTLDBeaconManager        ← radio beacons
CTLDJTACManager          ← JTAC auto-lase / orbit
CTLDReconManager         ← recon layer + F10 map marks
CTLDCrateAssemblyManager ← AA system assembly
CTLDSceneManager         ← scene engine (FARP, FOB, minefield…)
CTLDDCSEventBridge       ← single DCS event handler, routes to managers
```

La configuration est en **lecture seule** et accédée via `ctld.gs("paramName")` — n'appelez
jamais `config:getSetting()` directement.

Consultez [Architecture](architecture.md) pour la structure du dépôt, l'idiome
manager/singleton, la séquence d'init de `CTLDCoreManager` et les bibliothèques internes.
