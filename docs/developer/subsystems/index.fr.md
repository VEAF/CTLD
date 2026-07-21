# Sous-systèmes { #subsystems }

Chaque domaine de CTLD est géré par un manager singleton (voir [Architecture](../architecture.md)). Les
pages ci-dessous documentent le modèle interne, les pipelines et la surface publique de chaque sous-système.

| Sous-système | Ce qu'il couvre |
| --- | --- |
| [Scene engine](scenes.md) | Modèle de données des scènes, exécution des étapes, flux de pack FARP, création d'une nouvelle scène |
| [Crate spawn pipeline](crates.md) | Spawn / chargement / déchargement / assemblage des crates et traitement des `spawnableCrates` |
| [Troop + JTAC lifecycle](troops-jtac.md) | Machine à états des groupes de troops, modèle d'instance JTAC, règles de transition |
| [Zone management](zones.md) | Types de zones, nommage des TRZ, algorithme de découverte, méthodes publiques |
| [Vehicle system](vehicles.md) | Machine à états `CTLDVehicle`, pipeline de chargement/déchargement, cargo natif |
| [Beacon system](beacons.md) | Groupes de beacons, allocation des ID de mark, modèle de batterie |
| [Recon system](recon.md) | Pipeline scan → mark, cycle de vie des couches |
| [F10 menu system](menu.md) | Architecture du menu dynamique, enregistrement des sections, rafraîchissement selon l'état du vol |
| [Player tracking](players.md) | Schéma de l'objet player, cycle de vie, suivi du poids du cargo |
| [AA system assembly](aa.md) | Format des templates AA, vérification d'assemblage, livraison en zone IA |
