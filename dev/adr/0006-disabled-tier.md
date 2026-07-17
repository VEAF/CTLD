# Quarantine failing scenarios as `disabled` rather than deleting or leaving them red

When a scenario cannot reach a verdict due to a blocker external to CTLD — DCS AI
pathfinding that prevents a helicopter from landing on a specific spot, or a mission mod
that is absent from the test environment — we tag it `-- @tier: disabled` rather than
deleting it or leaving it permanently failing.

Deleted tests lose traceability: there is no record that the behavior was once covered or
why coverage was dropped. Permanently failing tests poison sweeps and erode trust in the
suite. Quarantine keeps the scenario visible in the corpus, excludes it from all default
sweeps (`--headless`, `--tier auto-slow`), and makes the blocker explicit in the tier
comment. The scenario is reachable on demand via `--tier disabled` for manual
investigation. Logic coverage for the quarantined path lives in fast deterministic tests
that do not depend on the external condition.

**Concrete cases at the time of writing:**
- `mt08_ai_vehicle_transport` and `mt14_ai_aa_system` — DCS AI helicopter reaches the
  pickup zone but orbits without landing due to pathfinding interference from adjacent
  urban terrain. Waypoint geometry is correct; the blocker is the DCS engine.
  (Being fixed in `TOOLING-TEST-TAXONOMY` ticket 03a/03b — may be re-enabled as
  `auto-slow` once the waypoint is moved to clear terrain.)
- `scenario_warehouse_cycle` — requires the `Farp_FG_Petit_Helipad` mod, absent from
  the standard test environment. Deferred pending a `scene-as-plugins` architecture
  review.
