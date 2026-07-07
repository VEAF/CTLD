# Subsystems

Each CTLD domain is owned by a singleton manager (see [Architecture](../architecture.md)). The
pages below document the internal model, pipelines, and public surface of each subsystem.

| Subsystem | What it covers |
| --- | --- |
| [Scene engine](scenes.md) | Scene data model, step execution, FARP pack flow, authoring a new scene |
| [Crate spawn pipeline](crates.md) | Crate spawn / load / unload / assembly and `spawnableCrates` processing |
| [Troop + JTAC lifecycle](troops-jtac.md) | Troop group state machine, JTAC instance model, transition rules |
| [Zone management](zones.md) | Zone types, TRZ naming, discovery algorithm, public methods |
| [Vehicle system](vehicles.md) | `CTLDVehicle` state machine, load/unload pipeline, native cargo |
| [Beacon system](beacons.md) | Beacon groups, mark ID allocation, battery model |
| [Recon system](recon.md) | Scan → mark pipeline, layer lifecycle |
| [F10 menu system](menu.md) | Dynamic menu architecture, section registration, flight-state refresh |
| [Player tracking](players.md) | Player object schema, lifecycle, cargo weight tracking |
| [AA system assembly](aa.md) | AA template format, assembly check, AI zone delivery |
