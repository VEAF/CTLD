# FIX-AIZONE-NAME-COLLISION — an AI zone whose name is already taken is dropped without a word

**Status:** open.

Opened 2026-08-01, found while reading the code for `FIX-DROPOFFZONES-PARITY` ticket 01. Independent
of that lot, which shipped the migration signal it was about; this is the silent failure the reading
turned up on the way.

## The defect

`_loadAIZonesFromConfig` skips any entry whose `dcsZoneName` is already a registered troop zone:

```lua
if dzn and not skip[dzn] and not self._troopZones[dzn] then
```

That guard is right in itself — an explicitly discovered zone wins, as everywhere else in the
manager. What is wrong is that the skip is **completely silent**: no WARN, no NOTICE, no log line.
The mission maker gets an AI zone that does nothing, and nothing tells them why.

It is reachable by accident, because the two namespaces look unrelated but are not. `_discoverTRZ`
registers a zone under its **parsed** name, so a trigger zone called `TRZ_dropzone1_B_0_nil_0` occupies
the key `dropzone1`. An `aiZones` entry pointing at a *different* Mission Editor zone, genuinely named
`dropzone1`, then collides with it and is dropped.

The obvious way to hit this is the workaround the v1→v2 migration guide documents: an AI drop-off zone
is never smoked, so the guide suggests superimposing an inert `TRZ_` zone to mark the spot. Name that
marker after the AI zone — the natural thing to do — and the AI zone stops working. The guide warns
about it in prose ([migration-v1-v2.md](../../docs/developer/migration-v1-v2.md)); the engine says
nothing.

## Why it is not just a doc problem

`_validateZoneNames` already reports this class of problem thoroughly for AI zones — duplicate
`dcsZoneName`, zone absent from the Mission Editor, missing coalition, a zone that is neither pickup
nor dropoff — each as an `ERROR ... entry ignored` in the startup report. A collision with a TRZ/WPZ
name is the same outcome (entry ignored) reached by a different route, and it is the only one of them
that says nothing.

The constraint to design around: `_validateZoneNames` runs **before** `_discoverTRZ`, so it cannot
consult `_troopZones`. The names it would need are computable without discovery — parse the `TRZ_` /
`WPZ_` trigger zone names the same way discovery will — or the check moves to where the skip happens.
Both are open to the implementer.

## Definition of done

- An `aiZones` entry dropped because its name is already taken produces one startup report entry
  saying so, naming the zone and what took the name.
- Severity matches the existing AIZ vocabulary (`ERROR ... entry ignored`), or the ticket argues in
  writing for a different one.
- A config with no collision produces nothing new.
- The migration guide's prose warning and the engine message agree.

## Out of scope

- Changing the precedence itself. The discovered zone winning is the established rule
  ([ADR 0011](../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md) and every other
  discovery pass); this lot makes the loss visible, it does not relitigate who wins.
- The same guard in `_loadLegacyZones` (a legacy `troopZones` entry naming an AI zone is dropped too).
  Worth a look in ticket 01, but the legacy path is on its way out and does not deserve its own
  message unless the check is free.
