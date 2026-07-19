# CTLD 2.0.0-rc1 — version candidate

CTLD 2.0 est une **réécriture complète** du script CTLD v1 : le code monolithique devient un
ensemble de modules Lua **testables** (architecture orientée objet Manager/Entité), couvert par une
intégration continue — build unique, ~150 tests unitaires et fonctionnels, plus des tests
d'intégration en DCS réel. **Le comportement en jeu reste identique à la v1** : cette refonte vise
la maintenabilité et la fiabilité, pas un changement d'usage pour les pilotes.

Cette **rc1** est une version candidate, destinée aux tests avant la 2.0.0 stable.

## Nouveautés

- **Scènes personnalisables et plugins.** Les scènes (FARP, FOB, champ de mines…) sont désormais
  indépendantes de leur position de chargement et peuvent être fournies en **plugins** externes. La
  **Metal FARP** (dépendante d'un mod) est extraite du livrable vers le dépôt
  [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) — supprimant au passage l'avertissement
  affiché à chaque démarrage.
- **Validation de votre configuration à la conception.** Un compagnon optionnel
  `CTLD_asset_check.lua` (fourni avec la release) signale les types DCS inconnus de votre config,
  sans rien spawner. Nouveau réglage `modTypes` pour déclarer les types issus de mods. CTLD ne
  « sonde » plus l'environnement au démarrage (fini les événements `S_EVENT_BIRTH` parasites).
- **Configuration utilisateur séparée.** `CTLD_userConfig.lua` est livré comme fichier autonome.

## Changements importants pour les concepteurs de mission

⚠️ **Les déclencheurs de chargement changent** par rapport à la v1. Ordre à respecter dans le
Mission Editor : (1) `CTLD_userConfig.lua` (optionnel), (2) `CTLD.lua`, (3) les éventuels **plugins
de scène après** CTLD. Si vous utilisez la Metal FARP, chargez désormais son plugin.

→ Voir [Ordre de chargement dans le Mission Editor](https://veaf.github.io/CTLD/dev/fr/mission-maker/configuration/#ordre-de-chargement-dans-le-mission-editor)
et le [guide Scènes & FOB](https://veaf.github.io/CTLD/dev/fr/mission-maker/scenes-fob/).

## Corrections visibles en jeu

- **Request Equipment** : le spawn d'un **véhicule entier** (transports `canTransportWholeVehicle`)
  fonctionne à nouveau.
- **Menu troupes après atterrissage** : « Parachuter » / « Débarquer les troupes » reflètent
  immédiatement l'état au sol (plus de menu figé à l'atterrissage).
- **Transport IA (stock virtuel)** : plus de spawn erroné quand un véhicule dépasse la limite de
  poids de l'hélico ; type invalide `M1025 HMMWV Armament` corrigé (spawnait un Leopard-2 par
  erreur).
- Rafraîchissement immédiat des crates de scène chargées par plugin ; divers correctifs de
  robustesse (poll de position au sol, validation du stock des zones IA).

## Contributeurs

**FullGas** (développeur principal), **Zip** (assistance technique) — VEAF.
